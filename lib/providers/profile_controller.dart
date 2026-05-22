part of 'app_core_providers.dart';

/// Reactive UI source of truth for user-owned collections and preferences.
class ProfileState {
  const ProfileState({
    this.favorites = const <String>[],
    this.isFavoritesLoading = false,
    this.favoritePendingIds = const <String>{},
    this.favoriteFailedIds = const <String>{},
    this.compareList = const <String>[],
    this.preferences = const <PreferenceKey>[],
  });

  final List<String> favorites;
  final bool isFavoritesLoading;
  final Set<String> favoritePendingIds;
  final Set<String> favoriteFailedIds;
  final List<String> compareList;
  final List<PreferenceKey> preferences;

  ProfileState copyWith({
    List<String>? favorites,
    bool? isFavoritesLoading,
    Set<String>? favoritePendingIds,
    Set<String>? favoriteFailedIds,
    List<String>? compareList,
    List<PreferenceKey>? preferences,
  }) {
    return ProfileState(
      favorites: favorites ?? this.favorites,
      isFavoritesLoading: isFavoritesLoading ?? this.isFavoritesLoading,
      favoritePendingIds: favoritePendingIds ?? this.favoritePendingIds,
      favoriteFailedIds: favoriteFailedIds ?? this.favoriteFailedIds,
      compareList: compareList ?? this.compareList,
      preferences: preferences ?? this.preferences,
    );
  }
}

/// Owns favorites, compare state, and profile-derived UI preferences.
class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier(this._ref, {ProfileState initialState = const ProfileState()})
      : super(initialState);

  ProfileNotifier.test(this._ref,
      {ProfileState initialState = const ProfileState()})
      : super(initialState);

  final Ref _ref;
  final Set<String> _favoriteMutationLocks = <String>{};
  final Set<String> _compareMutationLocks = <String>{};
  int _sessionLoadVersion = 0;
  static const int maxCompareCafes = 2;

  String _favoritesScope([CurrentUser? user]) => user?.id ?? 'guest';
  String _compareScope([CurrentUser? user]) => user?.id ?? 'guest';
  String _preferencesScope([CurrentUser? user]) => user?.id ?? 'guest';

  LocalStorageService? _safeStorage() {
    final storage = _ref.read(localStorageServiceProvider);
    if (storage == null) {
      AppLogger.warn(
        'Local storage is unavailable. Falling back to in-memory state only.',
        key: 'local-storage-unavailable',
      );
    }
    return storage;
  }

  List<String> _normalizeCompareList(
    Iterable<String> compareList, {
    Iterable<String>? allowedIds,
  }) {
    final allowedIdSet = allowedIds?.toSet();
    final normalized = <String>[];
    final seen = <String>{};

    for (final rawId in compareList) {
      final cafeId = rawId.trim();
      if (cafeId.isEmpty || !seen.add(cafeId)) {
        continue;
      }
      if (allowedIdSet != null &&
          allowedIdSet.isNotEmpty &&
          !allowedIdSet.contains(cafeId)) {
        continue;
      }
      normalized.add(cafeId);
      if (normalized.length == maxCompareCafes) {
        break;
      }
    }

    return List<String>.unmodifiable(normalized);
  }

  Future<void> handleSessionChanged() async {
    final loadVersion = ++_sessionLoadVersion;
    final storage = _safeStorage();
    final currentUser = _ref.read(currentUserProvider);
    if (kDebugMode) {
      AppLogger.debug(
        '[FAVORITE_COUNT] phase=session_start loadVersion=$loadVersion scope=${_favoritesScope(currentUser)} currentUser=${currentUser?.id ?? 'guest'}',
        key: 'favorite-count-session-start-$loadVersion',
        throttle: Duration.zero,
      );
    }

    if (storage == null) {
      if (!mounted || loadVersion != _sessionLoadVersion) return;
      state = state.copyWith(
        favorites: const <String>[],
        compareList: const <String>[],
        preferences: const <PreferenceKey>[],
        isFavoritesLoading: false,
      );
      if (kDebugMode) {
        AppLogger.debug(
          '[FAVORITE_COUNT] phase=session_storage_unavailable loadVersion=$loadVersion scope=${_favoritesScope(currentUser)}',
          key: 'favorite-count-session-storage-unavailable-$loadVersion',
          throttle: Duration.zero,
        );
      }
      return;
    }

    state = state.copyWith(
      favorites: const <String>[],
      compareList: const <String>[],
      favoritePendingIds: const <String>{},
      favoriteFailedIds: const <String>{},
      isFavoritesLoading: true,
    );

    // Load Hive cache and remote concurrently for fastest display.
    final scope = _favoritesScope(currentUser);
    final hiveFavsFuture = storage.loadFavorites(scope);
    final supabaseFavsFuture = currentUser != null
        ? _ref.read(favoritesServiceProvider)?.loadFavorites(currentUser.id)
        : Future<List<String>?>.value(null);

    final results = await Future.wait([
      hiveFavsFuture,
      supabaseFavsFuture ?? Future<List<String>?>.value(null),
      storage.loadCompareList(_compareScope(currentUser)),
      storage.loadPreferences(_preferencesScope(currentUser)),
    ]);

    if (!mounted || loadVersion != _sessionLoadVersion) return;

    final hiveFavs = results[0] as List<String>;
    final supabaseFavs = results[1] as List<String>?;
    final compareList = results[2] as List<String>;
    final preferences = results[3] as List<PreferenceKey>;

    // Supabase is source of truth; fall back to Hive if fetch failed.
    final favorites = supabaseFavs ?? hiveFavs;

    // Sync Hive with the authoritative Supabase list so offline is fresh.
    if (supabaseFavs != null && supabaseFavs.length != hiveFavs.length) {
      unawaited(() async {
        try {
          await storage.saveFavorites(scope, favorites);
        } catch (error, stackTrace) {
          AppLogger.error(
            'ProfileNotifier._loadFromStorageAndSync failed to persist synced favorites for scope=$scope',
            error: error,
            stackTrace: stackTrace,
            key: 'profile-favorites-persist-sync-$scope',
          );
        }
      }());
    }

    state = state.copyWith(
      favorites: favorites,
      compareList: _normalizeCompareList(compareList),
      preferences: preferences,
      favoritePendingIds: const <String>{},
      favoriteFailedIds: const <String>{},
      isFavoritesLoading: false,
    );
    if (kDebugMode) {
      AppLogger.debug(
        '[FAVORITE_COUNT] phase=session_resolved loadVersion=$loadVersion scope=$scope hive=${hiveFavs.length} remote=${supabaseFavs?.length ?? -1} resolved=${favorites.length}',
        key: 'favorite-count-session-resolved-$scope-$loadVersion',
        throttle: Duration.zero,
      );
    }
  }

  Future<void> toggleFavorite(String cafeId) async {
    if (!_favoriteMutationLocks.add(cafeId)) return;

    final storage = _safeStorage();
    final currentUser = _ref.read(currentUserProvider);

    // --- Optimistic update ---
    final previous = state.favorites;
    final isAdding = !previous.contains(cafeId);
    final optimistic = isAdding
        ? [...previous, cafeId]
        : previous.where((id) => id != cafeId).toList(growable: false);

    final pendingIds = Set<String>.from(state.favoritePendingIds)..add(cafeId);
    final failedIds = Set<String>.from(state.favoriteFailedIds)..remove(cafeId);

    state = state.copyWith(
      favorites: List<String>.unmodifiable(optimistic),
      favoritePendingIds: pendingIds,
      favoriteFailedIds: failedIds,
    );

    // Optimistically patch the cafe's favoriteCount in the shared cafe state.
    _patchCafeFavoriteCount(cafeId, delta: isAdding ? 1 : -1);

    // Persist to Hive immediately for offline availability.
    if (storage != null) {
      unawaited(() async {
        try {
          await storage.saveFavorites(
            _favoritesScope(currentUser),
            optimistic,
          );
        } catch (error, stackTrace) {
          AppLogger.error(
            'ProfileNotifier.toggleFavorite failed to persist optimistic favorites for cafeId=$cafeId',
            error: error,
            stackTrace: stackTrace,
            key: 'profile-favorites-persist-optimistic-$cafeId',
          );
        }
      }());
    }

    // --- Supabase sync ---
    bool supabaseOk = true;
    var queuedForReplay = false;
    final userId = currentUser?.id;
    if (userId != null) {
      supabaseOk = await _ref.read(favoritesSyncGatewayProvider).syncFavorite(
            userId: userId,
            cafeId: cafeId,
            isAdding: isAdding,
          );
      if (!supabaseOk) {
        queuedForReplay = await _ref
            .read(offlineSyncProvider.notifier)
            .enqueueFavoriteToggle(
              userId: userId,
              cafeId: cafeId,
              isAdding: isAdding,
            );
        supabaseOk = queuedForReplay;
      }
    }

    _favoriteMutationLocks.remove(cafeId);

    if (!mounted) return;

    final settledPendingIds = Set<String>.from(state.favoritePendingIds)
      ..remove(cafeId);

    if (!supabaseOk) {
      // Rollback both local state and the cafe count patch.
      AppLogger.warn(
        'ProfileNotifier.toggleFavorite: sync and queue failed, rolling back',
        key: 'toggle-favorite-rollback-$cafeId',
      );
      final rollbackFailedIds = Set<String>.from(state.favoriteFailedIds)
        ..add(cafeId);
      state = state.copyWith(
        favorites: previous,
        favoritePendingIds: settledPendingIds,
        favoriteFailedIds: rollbackFailedIds,
      );
      _patchCafeFavoriteCount(cafeId, delta: isAdding ? -1 : 1);

      // Restore Hive to the pre-mutation value on rollback.
      if (storage != null) {
        unawaited(() async {
          try {
            await storage.saveFavorites(
              _favoritesScope(currentUser),
              previous,
            );
          } catch (error, stackTrace) {
            AppLogger.error(
              'ProfileNotifier.toggleFavorite failed to persist rollback favorites for cafeId=$cafeId',
              error: error,
              stackTrace: stackTrace,
              key: 'profile-favorites-persist-rollback-$cafeId',
            );
          }
        }());
      }
      return;
    }

    if (queuedForReplay) {
      AppLogger.warn(
        'ProfileNotifier.toggleFavorite: queued offline replay for cafeId=$cafeId',
        key: 'toggle-favorite-queued-$cafeId',
      );
    }

    final successFailedIds = Set<String>.from(state.favoriteFailedIds)
      ..remove(cafeId);
    state = state.copyWith(
      favoritePendingIds: settledPendingIds,
      favoriteFailedIds: successFailedIds,
    );
    _ref.read(analyticsServiceProvider).trackFavoriteToggled(
          cafeId,
          isFavorite: isAdding,
        );
  }

  /// Patches `cafe.favoriteCount` in CafeNotifier state by [delta] (+1 / -1).
  void _patchCafeFavoriteCount(String cafeId, {required int delta}) {
    try {
      final cafeNotifier = _ref.read(cafeProvider.notifier);
      final cafe = _ref
          .read(cafeProvider)
          .cafes
          .where(
            (c) => c.id == cafeId || c.placeId == cafeId,
          )
          .firstOrNull;
      if (cafe == null) return;
      final updated = cafe.copyWith(
        favoriteCount: (cafe.favoriteCount + delta).clamp(0, 1 << 30),
      );
      cafeNotifier.upsertCafe(updated);
    } catch (_) {
      // Non-critical — the count will self-correct on next full load.
    }
  }

  Future<void> toggleCompare(String cafeId) async {
    if (!_compareMutationLocks.add(cafeId)) {
      return;
    }

    final storage = _safeStorage();
    final current = List<String>.from(_normalizeCompareList(state.compareList));
    final previous = state.compareList;
    final normalizedCafeId = cafeId.trim();
    if (normalizedCafeId.isEmpty) {
      _compareMutationLocks.remove(cafeId);
      return;
    }
    late final bool addedToCompare;
    if (current.contains(normalizedCafeId)) {
      current.remove(normalizedCafeId);
      addedToCompare = false;
    } else {
      if (current.length >= maxCompareCafes) {
        current.removeAt(0);
      }
      current.add(normalizedCafeId);
      addedToCompare = true;
    }
    final normalizedCurrent = _normalizeCompareList(current);
    state = state.copyWith(compareList: normalizedCurrent);

    if (storage == null) {
      _compareMutationLocks.remove(cafeId);
      _trackCompareMutation(normalizedCafeId, added: addedToCompare);
      return;
    }

    try {
      await storage.saveCompareList(
        _compareScope(_ref.read(currentUserProvider)),
        normalizedCurrent,
      );
    } catch (error) {
      AppLogger.error(
        'ProfileNotifier.toggleCompare failed to persist compare list',
        error: error,
        key: 'toggle-compare-persist-failed',
      );
      state = state.copyWith(compareList: previous);
    } finally {
      if (state.compareList == normalizedCurrent) {
        _trackCompareMutation(normalizedCafeId, added: addedToCompare);
      }
      _compareMutationLocks.remove(cafeId);
    }
  }

  void _trackCompareMutation(String cafeId, {required bool added}) {
    final analytics = _ref.read(analyticsServiceProvider);
    if (added) {
      analytics.trackCompareAdded(cafeId);
    } else {
      analytics.trackCompareRemoved(cafeId);
    }
  }

  void removeCafeReferences(Iterable<String> cafeIds) {
    final removalIds =
        cafeIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (removalIds.isEmpty) {
      return;
    }

    final nextFavorites = state.favorites
        .where((id) => !removalIds.contains(id.trim()))
        .toList(growable: false);
    final nextCompareList = state.compareList
        .where((id) => !removalIds.contains(id.trim()))
        .toList(growable: false);
    final nextPending = Set<String>.from(state.favoritePendingIds)
      ..removeWhere(removalIds.contains);
    final nextFailed = Set<String>.from(state.favoriteFailedIds)
      ..removeWhere(removalIds.contains);

    if (nextFavorites.length == state.favorites.length &&
        nextCompareList.length == state.compareList.length &&
        nextPending.length == state.favoritePendingIds.length &&
        nextFailed.length == state.favoriteFailedIds.length) {
      return;
    }

    state = state.copyWith(
      favorites: List<String>.unmodifiable(nextFavorites),
      compareList: List<String>.unmodifiable(nextCompareList),
      favoritePendingIds: Set<String>.unmodifiable(nextPending),
      favoriteFailedIds: Set<String>.unmodifiable(nextFailed),
    );
  }

  void setPreferences(List<PreferenceKey> preferences) {
    state = state.copyWith(preferences: preferences);
    final storage = _safeStorage();
    if (storage == null) {
      return;
    }

    final scope = _preferencesScope(_ref.read(currentUserProvider));
    unawaited(() async {
      try {
        await storage.savePreferences(scope, preferences);
      } catch (error) {
        AppLogger.error(
          'ProfileNotifier.setPreferences failed to persist preferences',
          error: error,
          key: 'set-preferences-persist-failed',
        );
      }
    }());
  }

  /// Projects persisted profile edits into the shell session snapshot.
  void updateCurrentUser(CurrentUser Function(CurrentUser) updater) {
    _ref.read(appShellProvider.notifier).updateCurrentUser(updater);
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((
  ref,
) {
  return ProfileNotifier(ref);
});
