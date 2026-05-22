part of 'app_core_providers.dart';

class _CafeDiscoveryRequest {
  const _CafeDiscoveryRequest({
    required this.discoveryCacheKey,
    required this.districts,
    required this.fetchCenter,
    required this.fetchRadiusMeters,
  });

  final String discoveryCacheKey;
  final List<String> districts;
  final Coordinates? fetchCenter;
  final int fetchRadiusMeters;

  String? get district => districts.length == 1 ? districts.single : null;

  bool get hasDistrictScope => districts.isNotEmpty;
}

/// Reactive UI source of truth for cafe discovery and map selection state.
class CafeState {
  const CafeState({
    this.cafes = const <Cafe>[],
    this.homeCafes = const <Cafe>[],
    this.currentLocation,
    this.cafesLastUpdated,
    this.hasInitializedDiscovery = false,
    this.hasLoadedHomeCafes = false,
    this.isCafesLoading = false,
    this.isHomeCafesLoading = false,
    this.isRadiusRefreshInFlight = false,
    this.isServingStaleCache = false,
    this.cafesErrorMessage,
    this.cafesNoticeMessage,
    this.filters = Filters.empty,
    this.exploreFilters = Filters.empty,
    this.mapFilters = Filters.empty,
    this.displayedFilters = Filters.empty,
    this.homeFeaturedDistrict,
    this.featuredCafes = const <Cafe>[],
    this.hasLoadedFeaturedCafes = false,
    this.isFeaturedCafesLoading = false,
    this.nextPageToken,
    this.hasMorePages = false,
    this.isLoadingMore = false,
    this.loadMoreErrorMessage,
    this.cafeSyncState = CafeSyncState.ready,
    this.selectedCafeId,
    this.selectedCafeFocusVersion = 0,
    this.cafeSearchScopeKey,
    this.mapRadiusPreset = MapRadiusPreset.defaultPreset,
    this.displayedMapRadiusPreset = MapRadiusPreset.defaultPreset,
    this.discoveryDiagnostics,
    this.loadingCafeDetailIds = const <String>{},
    this.cafeDetailErrorMessages = const <String, String>{},
  });

  final List<Cafe> cafes;
  final List<Cafe> homeCafes;
  final Coordinates? currentLocation;
  final DateTime? cafesLastUpdated;
  // Distinguishes "no discovery has run yet" from a completed empty result.
  final bool hasInitializedDiscovery;
  final bool hasLoadedHomeCafes;
  final bool isCafesLoading;
  final bool isHomeCafesLoading;
  final bool isRadiusRefreshInFlight;
  final bool isServingStaleCache;
  final String? cafesErrorMessage;
  final String? cafesNoticeMessage;
  final Filters filters;

  /// Independent filter state for the Explore screen.
  /// Decoupled from [filters] (discovery cache key) and [mapFilters].
  final Filters exploreFilters;
  final Filters mapFilters;
  final Filters displayedFilters;
  final String? homeFeaturedDistrict;
  final List<Cafe> featuredCafes;
  final bool hasLoadedFeaturedCafes;
  final bool isFeaturedCafesLoading;
  final String? nextPageToken;
  final bool hasMorePages;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;
  final CafeSyncState cafeSyncState;
  final String? selectedCafeId;
  final int selectedCafeFocusVersion;
  final String? cafeSearchScopeKey;
  final MapRadiusPreset mapRadiusPreset;
  final MapRadiusPreset displayedMapRadiusPreset;
  final CafeDiscoveryDiagnostics? discoveryDiagnostics;
  final Set<String> loadingCafeDetailIds;
  final Map<String, String> cafeDetailErrorMessages;

  CafeState copyWith({
    List<Cafe>? cafes,
    List<Cafe>? homeCafes,
    Coordinates? Function()? currentLocation,
    DateTime? Function()? cafesLastUpdated,
    bool? hasInitializedDiscovery,
    bool? hasLoadedHomeCafes,
    bool? isCafesLoading,
    bool? isHomeCafesLoading,
    bool? isRadiusRefreshInFlight,
    bool? isServingStaleCache,
    String? Function()? cafesErrorMessage,
    String? Function()? cafesNoticeMessage,
    Filters? filters,
    Filters? exploreFilters,
    Filters? mapFilters,
    Filters? displayedFilters,
    String? Function()? homeFeaturedDistrict,
    List<Cafe>? featuredCafes,
    bool? hasLoadedFeaturedCafes,
    bool? isFeaturedCafesLoading,
    String? Function()? nextPageToken,
    bool? hasMorePages,
    bool? isLoadingMore,
    String? Function()? loadMoreErrorMessage,
    CafeSyncState? cafeSyncState,
    String? Function()? selectedCafeId,
    int? selectedCafeFocusVersion,
    String? Function()? cafeSearchScopeKey,
    MapRadiusPreset? mapRadiusPreset,
    MapRadiusPreset? displayedMapRadiusPreset,
    CafeDiscoveryDiagnostics? Function()? discoveryDiagnostics,
    Set<String>? loadingCafeDetailIds,
    Map<String, String>? cafeDetailErrorMessages,
  }) {
    return CafeState(
      cafes: cafes ?? this.cafes,
      homeCafes: homeCafes ?? this.homeCafes,
      currentLocation:
          currentLocation != null ? currentLocation() : this.currentLocation,
      cafesLastUpdated:
          cafesLastUpdated != null ? cafesLastUpdated() : this.cafesLastUpdated,
      hasInitializedDiscovery:
          hasInitializedDiscovery ?? this.hasInitializedDiscovery,
      hasLoadedHomeCafes: hasLoadedHomeCafes ?? this.hasLoadedHomeCafes,
      isCafesLoading: isCafesLoading ?? this.isCafesLoading,
      isHomeCafesLoading: isHomeCafesLoading ?? this.isHomeCafesLoading,
      isRadiusRefreshInFlight:
          isRadiusRefreshInFlight ?? this.isRadiusRefreshInFlight,
      isServingStaleCache: isServingStaleCache ?? this.isServingStaleCache,
      cafesErrorMessage: cafesErrorMessage != null
          ? cafesErrorMessage()
          : this.cafesErrorMessage,
      cafesNoticeMessage: cafesNoticeMessage != null
          ? cafesNoticeMessage()
          : this.cafesNoticeMessage,
      filters: filters ?? this.filters,
      exploreFilters: exploreFilters ?? this.exploreFilters,
      mapFilters: mapFilters ?? this.mapFilters,
      displayedFilters: displayedFilters ?? this.displayedFilters,
      homeFeaturedDistrict: homeFeaturedDistrict != null
          ? homeFeaturedDistrict()
          : this.homeFeaturedDistrict,
      featuredCafes: featuredCafes ?? this.featuredCafes,
      hasLoadedFeaturedCafes:
          hasLoadedFeaturedCafes ?? this.hasLoadedFeaturedCafes,
      isFeaturedCafesLoading:
          isFeaturedCafesLoading ?? this.isFeaturedCafesLoading,
      nextPageToken:
          nextPageToken != null ? nextPageToken() : this.nextPageToken,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreErrorMessage: loadMoreErrorMessage != null
          ? loadMoreErrorMessage()
          : this.loadMoreErrorMessage,
      cafeSyncState: cafeSyncState ?? this.cafeSyncState,
      selectedCafeId:
          selectedCafeId != null ? selectedCafeId() : this.selectedCafeId,
      selectedCafeFocusVersion:
          selectedCafeFocusVersion ?? this.selectedCafeFocusVersion,
      cafeSearchScopeKey: cafeSearchScopeKey != null
          ? cafeSearchScopeKey()
          : this.cafeSearchScopeKey,
      mapRadiusPreset: mapRadiusPreset ?? this.mapRadiusPreset,
      displayedMapRadiusPreset:
          displayedMapRadiusPreset ?? this.displayedMapRadiusPreset,
      discoveryDiagnostics: discoveryDiagnostics != null
          ? discoveryDiagnostics()
          : this.discoveryDiagnostics,
      loadingCafeDetailIds: loadingCafeDetailIds ?? this.loadingCafeDetailIds,
      cafeDetailErrorMessages:
          cafeDetailErrorMessages ?? this.cafeDetailErrorMessages,
    );
  }
}

/// Owns cafe list presentation state.
///
/// The repository remains the local cache/merge source of truth; this notifier
/// projects that data into reactive state for widgets.
class CafeNotifier extends StateNotifier<CafeState> {
  CafeNotifier(this._ref, {CafeState initialState = const CafeState()})
      : super(initialState) {
    _bindConnectivityRefresh();
  }

  CafeNotifier.test(this._ref, {CafeState initialState = const CafeState()})
      : super(initialState);

  final Ref _ref;
  Future<void>? _startupHydrationFuture;
  Future<void>? _lazyDiscoveryFuture;
  Future<void>? _homeCafeDataFuture;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _refreshWhenOnline = false;
  int _cafesRequestVersion = 0;
  int _homeCafesRequestVersion = 0;
  RequestCancellationController? _activeCafeListRequest;
  RequestCancellationController? _activeHomeCafeListRequest;
  RequestCancellationController? _activeLoadMoreRequest;
  final Map<String, RequestCancellationController> _detailRequestControllers =
      <String, RequestCancellationController>{};
  final Map<String, int> _detailRequestVersions = <String, int>{};

  void _bindConnectivityRefresh() {
    _connectivitySubscription =
        _ref.read(connectivityServiceProvider).isOnline.listen((isOnline) {
      if (!isOnline || !_refreshWhenOnline || !mounted) {
        return;
      }
      _refreshWhenOnline = false;
      unawaited(refreshCafes());
    });
  }

  void _scheduleRefreshWhenOnline() {
    _refreshWhenOnline = true;
  }

  void _clearRefreshWhenOnlineFlag() {
    _refreshWhenOnline = false;
  }

  Future<void> preloadStartupState() {
    return _startupHydrationFuture ??= _preloadStartupStateInternal();
  }

  Future<void> _preloadStartupStateInternal() async {
    await _restorePersistedDiscoveryPreferences();
    await _hydrateStartupCafeCache();
  }

  Future<void> _restorePersistedDiscoveryPreferences() async {
    final storage = _ref.read(localStorageServiceProvider);
    if (storage == null) {
      return;
    }

    final restoredFilters = await storage.loadCafeFilters();
    if (!mounted) {
      return;
    }

    state = state.copyWith(
      filters: _sanitizeStartupFilters(restoredFilters),
      mapFilters: Filters.empty,
      displayedFilters: _sanitizeStartupFilters(restoredFilters),
      homeFeaturedDistrict: () => null,
      // Normal Map opens intentionally start from the product default radius.
      // Explicit focus flows preserve their selected cafe through route state,
      // not by restoring the last user-selected radius from storage.
      mapRadiusPreset: MapRadiusPreset.defaultPreset,
      displayedMapRadiusPreset: MapRadiusPreset.defaultPreset,
    );
  }

  Future<MapViewCacheSnapshot?> loadPersistedMapView() async {
    return _ref.read(localStorageServiceProvider)?.loadMapViewCache();
  }

  Future<void> persistMapView({
    required double lat,
    required double lng,
    required double zoom,
    String? selectedCafeId,
  }) async {
    await _ref.read(localStorageServiceProvider)?.saveMapViewCache(
          lat: lat,
          lng: lng,
          zoom: zoom,
          selectedCafeId: selectedCafeId,
        );
  }

  Future<void> _hydrateStartupCafeCache() async {
    final repository = _ref.read(cafeRepositoryProvider);
    final discoveryRequest = _buildCafeDiscoveryRequest(
      currentLocation: state.currentLocation,
      filters: state.filters,
      radiusPreset: state.mapRadiusPreset,
    );
    final cachedSnapshot = await repository.loadCachedCafeList(
      cacheKey: discoveryRequest.discoveryCacheKey,
    );
    if (!mounted || cachedSnapshot == null) {
      return;
    }

    final canApplySnapshot = state.cafes.isEmpty ||
        state.cafeSearchScopeKey == null ||
        state.cafeSearchScopeKey == discoveryRequest.discoveryCacheKey;
    if (!canApplySnapshot) {
      return;
    }

    final isFresh = !CafeCachePolicy.isStaleList(cachedSnapshot.cachedAt);

    state = state.copyWith(
      cafes: cachedSnapshot.cafes,
      homeCafes: cachedSnapshot.cafes,
      cafesLastUpdated: () => cachedSnapshot.lastUpdated,
      hasInitializedDiscovery: true,
      hasLoadedHomeCafes: true,
      isCafesLoading: false,
      isHomeCafesLoading: false,
      isLoadingMore: false,
      cafesErrorMessage: () => null,
      cafesNoticeMessage: () => null,
      displayedFilters: state.filters,
      loadMoreErrorMessage: () => null,
      nextPageToken: () => cachedSnapshot.nextPageToken,
      hasMorePages: cachedSnapshot.nextPageToken != null &&
          cachedSnapshot.nextPageToken!.isNotEmpty,
      isServingStaleCache: !isFresh,
      cafeSyncState: isFresh
          ? CafeSyncState.ready
          : CafeSyncState.showingCachedWhileRefreshing,
      cafeSearchScopeKey: () => discoveryRequest.discoveryCacheKey,
      displayedMapRadiusPreset: state.mapRadiusPreset,
    );
    if (!isFresh) {
      _scheduleRefreshWhenOnline();
    }
  }

  /// Hydrates persisted discovery state first, then starts remote loading only
  /// when a feature screen actually needs cafe data.
  Future<void> ensureVisibleCafeDataLoaded() async {
    await preloadStartupState();
    if (!mounted) {
      return;
    }
    await ensureFeaturedCafesLoaded();

    final needsFirstLoad = !state.hasInitializedDiscovery;
    final needsStaleCacheRefresh =
        state.cafeSyncState == CafeSyncState.showingCachedWhileRefreshing;
    if (!needsFirstLoad && !needsStaleCacheRefresh) {
      return;
    }

    final inflight = _lazyDiscoveryFuture;
    if (inflight != null) {
      await inflight;
      return;
    }

    final future = loadCafes();
    _lazyDiscoveryFuture = future;
    await future.whenComplete(() {
      if (identical(_lazyDiscoveryFuture, future)) {
        _lazyDiscoveryFuture = null;
      }
    });
  }

  Future<void> ensureHomeCafeDataLoaded({bool forceRemote = false}) {
    final inflight = _homeCafeDataFuture;
    if (!forceRemote && inflight != null) {
      return inflight;
    }
    final future = _ensureHomeCafeDataLoadedInternal(forceRemote: forceRemote);
    _homeCafeDataFuture = future;
    return future.whenComplete(() {
      if (identical(_homeCafeDataFuture, future)) {
        _homeCafeDataFuture = null;
      }
    });
  }

  Future<void> _ensureHomeCafeDataLoadedInternal({
    required bool forceRemote,
  }) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.debug(
      '[HOME_INIT] ensureHomeCafeDataLoaded called forceRemote=$forceRemote',
      key: 'home-init-called',
      throttle: Duration.zero,
    );
    await preloadStartupState();
    AppLogger.debug(
      '[HOME_PERF] stage=init elapsedMs=${stopwatch.elapsedMilliseconds}',
      key: 'home-perf-init',
      throttle: Duration.zero,
    );
    if (!mounted) {
      return;
    }

    final featuredStopwatch = Stopwatch()..start();
    await ensureFeaturedCafesLoaded(forceRemote: forceRemote);
    AppLogger.debug(
      '[HOME_PERF] stage=featuredFetch elapsedMs=${featuredStopwatch.elapsedMilliseconds}',
      key: 'home-perf-featured-fetch',
      throttle: Duration.zero,
    );
    if (!mounted) {
      return;
    }

    final requestVersion = ++_homeCafesRequestVersion;
    final cancellationToken = _beginHomeCafeListRequest();
    final discoveryRequest = _buildCafeDiscoveryRequest(
      currentLocation: state.currentLocation,
      filters: Filters.empty,
      radiusPreset: MapRadiusPreset.defaultPreset,
    );
    final repository = _ref.read(cafeRepositoryProvider);
    final cacheStopwatch = Stopwatch()..start();
    final cachedSnapshot = await repository.loadCachedCafeList(
      cacheKey: discoveryRequest.discoveryCacheKey,
    );
    AppLogger.debug(
      '[HOME_PERF] stage=cacheHydrate count=${cachedSnapshot?.cafes.length ?? 0} elapsedMs=${cacheStopwatch.elapsedMilliseconds}',
      key: 'home-perf-cache-hydrate',
      throttle: Duration.zero,
    );
    if (!_isCurrentHomeCafeRequest(requestVersion) || !mounted) {
      return;
    }

    final hasVisibleHomeCafes = state.homeCafes.isNotEmpty;
    final hasCachedHomeCafes =
        cachedSnapshot != null && cachedSnapshot.cafes.isNotEmpty;
    final canKeepVisibleHomeCafes = hasVisibleHomeCafes || hasCachedHomeCafes;
    final shouldUseFreshCacheOnly = !forceRemote &&
        cachedSnapshot != null &&
        !CafeCachePolicy.isStaleList(cachedSnapshot.cachedAt) &&
        (state.homeCafes.isEmpty ||
            cachedSnapshot.cafes.length >= state.homeCafes.length);

    if (cachedSnapshot != null) {
      final hydratedHomeCafes =
          _hydrateMissingCachedCafes(state.homeCafes, cachedSnapshot.cafes);
      state = state.copyWith(
        homeCafes: hydratedHomeCafes,
        hasLoadedHomeCafes: true,
        isHomeCafesLoading: false,
      );

      if (shouldUseFreshCacheOnly) {
        return;
      }
      if (!forceRemote) {
        return;
      }
    } else {
      state = state.copyWith(
        hasLoadedHomeCafes: true,
        isHomeCafesLoading: forceRemote && !canKeepVisibleHomeCafes,
      );
    }

    if (!state.hasLoadedFeaturedCafes && !state.isFeaturedCafesLoading) {
      await ensureFeaturedCafesLoaded(forceRemote: true);
      if (!mounted || !_isCurrentHomeCafeRequest(requestVersion)) {
        return;
      }
    }

    if (!forceRemote) {
      return;
    }

    if (!canKeepVisibleHomeCafes) {
      state = state.copyWith(isHomeCafesLoading: true);
    }

    try {
      final result = await repository.fetchDiscoverableCafes(
        lat: discoveryRequest.fetchCenter?.lat,
        lng: discoveryRequest.fetchCenter?.lng,
        district: discoveryRequest.district,
        radius: discoveryRequest.fetchRadiusMeters,
        seedOnly: false,
        discoveryCacheKey: discoveryRequest.discoveryCacheKey,
        cancellationToken: cancellationToken,
      );
      if (!_isCurrentHomeCafeRequest(requestVersion) || !mounted) {
        return;
      }
      if (!result.ok) {
        throw _CafeLoadException.fromRepositoryResult(
          result,
          fallbackMessage: 'Unable to load cafes right now.',
        );
      }

      state = state.copyWith(
        homeCafes: result.cafes,
        hasLoadedHomeCafes: true,
        isHomeCafesLoading: false,
      );
    } catch (error) {
      if (!_isCurrentHomeCafeRequest(requestVersion) || !mounted) {
        return;
      }
      if (classifyServiceError(error) == ServiceErrorType.cancelled) {
        return;
      }
      AppLogger.warn(
        'CafeNotifier.ensureHomeCafeDataLoaded failed',
        key: 'home-cafes-load-failed',
      );
      state = state.copyWith(
        hasLoadedHomeCafes: true,
        isHomeCafesLoading: false,
      );
    }
  }

  Future<void> ensureFeaturedCafesLoaded({bool forceRemote = false}) async {
    if (!forceRemote &&
        (state.hasLoadedFeaturedCafes || state.isFeaturedCafesLoading)) {
      return;
    }

    AppLogger.debug(
      '[FEATURED_FETCH_START] forceRemote=$forceRemote loaded=${state.hasLoadedFeaturedCafes} loading=${state.isFeaturedCafesLoading} currentCount=${state.featuredCafes.length}',
      key: 'featured-fetch-start-tagged',
      throttle: Duration.zero,
    );
    AppLogger.debug(
      '[FEATURED_FETCH] phase=start forceRemote=$forceRemote loaded=${state.hasLoadedFeaturedCafes} loading=${state.isFeaturedCafesLoading} currentCount=${state.featuredCafes.length}',
      key: 'featured-fetch-start',
      throttle: Duration.zero,
    );
    state = state.copyWith(isFeaturedCafesLoading: true);
    try {
      final featured =
          await _ref.read(cafeRepositoryProvider).fetchFeaturedCafes(
                limit: 40,
              );
      if (!mounted) {
        return;
      }

      final previousFeatured = state.featuredCafes;
      final hasIncomingFeatured = featured.isNotEmpty;
      final hadExistingFeatured = previousFeatured.isNotEmpty;
      final shouldMarkLoaded =
          hasIncomingFeatured || hadExistingFeatured || forceRemote;
      final resolvedFeatured =
          hasIncomingFeatured ? featured : previousFeatured;

      final decision = hasIncomingFeatured
          ? 'loaded_nonempty'
          : shouldMarkLoaded
              ? (forceRemote
                  ? (hadExistingFeatured
                      ? 'kept_existing_after_empty_force_refresh'
                      : 'loaded_confirmed_empty')
                  : 'loaded_preserved_existing')
              : 'pending_force_remote_retry';

      final usedCache = !hasIncomingFeatured && hadExistingFeatured;
      AppLogger.debug(
        '[FEATURED_CACHE] forceRemote=$forceRemote previousCount=${previousFeatured.length} incomingCount=${featured.length} resolvedCount=${resolvedFeatured.length} usedCache=$usedCache',
        key: 'featured-cache-decision',
        throttle: Duration.zero,
      );

      state = state.copyWith(
        featuredCafes: resolvedFeatured,
        hasLoadedFeaturedCafes: shouldMarkLoaded,
        isFeaturedCafesLoading: false,
      );
      AppLogger.debug(
        '[FEATURED_FETCH_RESULT] outcome=success forceRemote=$forceRemote incomingCount=${featured.length} previousCount=${previousFeatured.length} resolvedCount=${resolvedFeatured.length} loaded=${state.hasLoadedFeaturedCafes} decision=$decision',
        key: 'featured-fetch-result',
        throttle: Duration.zero,
      );
      AppLogger.debug(
        '[FEATURED_FETCH] phase=success forceRemote=$forceRemote incomingCount=${featured.length} previousCount=${previousFeatured.length} resolvedCount=${resolvedFeatured.length} loaded=${state.hasLoadedFeaturedCafes} decision=$decision',
        key: 'featured-fetch-success',
        throttle: Duration.zero,
      );
      AppLogger.debug(
        '[FEATURED_PROVIDER] setCount=${state.featuredCafes.length}',
        key: 'featured-provider-set-count',
        throttle: Duration.zero,
      );
      unawaited(_hydrateFeaturedGoogleRatingMetadata(resolvedFeatured));
    } catch (error) {
      AppLogger.warn(
        'CafeNotifier.ensureFeaturedCafesLoaded failed type=${classifyServiceError(error)}',
        key: 'featured-cafes-load-failed',
      );
      if (!mounted) {
        return;
      }
      final hasExistingFeaturedData = state.featuredCafes.isNotEmpty;
      state = state.copyWith(
        hasLoadedFeaturedCafes: hasExistingFeaturedData,
        isFeaturedCafesLoading: false,
      );
      AppLogger.debug(
        '[FEATURED_FETCH_RESULT] outcome=failure forceRemote=$forceRemote existingCount=${state.featuredCafes.length} loaded=${state.hasLoadedFeaturedCafes} errorType=${classifyServiceError(error)}',
        key: 'featured-fetch-result',
        throttle: Duration.zero,
      );
      AppLogger.debug(
        '[FEATURED_FETCH] phase=failure forceRemote=$forceRemote existingCount=${state.featuredCafes.length} resolvedLoaded=${state.hasLoadedFeaturedCafes} errorType=${classifyServiceError(error)}',
        key: 'featured-fetch-failure',
        throttle: Duration.zero,
      );
      if (!hasExistingFeaturedData) {
        _scheduleRefreshWhenOnline();
      }
    }
  }

  Future<void> _hydrateFeaturedGoogleRatingMetadata(List<Cafe> cafes) async {
    final missing = cafes.where((cafe) {
      final placeId = cafe.placeId?.trim();
      return cafe.isActiveFeatured &&
          placeId != null &&
          placeId.isNotEmpty &&
          (cafe.googleRating == null ||
              cafe.googleReviewCount == null ||
              _featuredCafeNeedsImageRefresh(cafe));
    }).toList(growable: false);
    if (missing.isEmpty) {
      return;
    }
    final updated = await _ref
        .read(cafeRepositoryProvider)
        .hydrateFeaturedGoogleRatingMetadata(missing);
    if (!mounted || updated.isEmpty) {
      return;
    }
    final updatedById = {for (final cafe in updated) cafe.id: cafe};
    final nextFeatured = state.featuredCafes
        .map((cafe) => updatedById[cafe.id] ?? cafe)
        .toList(growable: false);
    state = state.copyWith(featuredCafes: nextFeatured);
  }

  bool _featuredCafeNeedsImageRefresh(Cafe cafe) {
    if (cafe.photoUrls.isEmpty) {
      return true;
    }
    for (final url in cafe.photoUrls) {
      final normalized = resolveCafeImageUrl(url);
      if (normalized == null || isKnownFailedCafeImageUrl(normalized)) {
        continue;
      }
      if (!isGeneratedPlacesMediaImageUrl(normalized)) {
        return false;
      }
    }
    return true;
  }

  /// Explore owns presentation filters, but only geography changes the remote
  /// discovery dataset. Search text hydrates Supabase name matches only when
  /// the already-loaded discovery corpus has no local match.
  Future<void> ensureExploreQueryLoaded() async {
    await ensureVisibleCafeDataLoaded();
    if (!mounted) {
      return;
    }
    await _ensureDiscoveryOwnerMatchesFilters(
      state.exploreFilters,
      owner: 'explore',
    );
    await _hydrateTextSearchResultsIfNeeded(
      state.exploreFilters,
      owner: 'explore',
    );
  }

  /// Map owns radius and map filters. A district map filter switches discovery
  /// to district scope; clearing it switches back to nearby/radius scope.
  Future<void> ensureMapQueryLoaded() async {
    await ensureVisibleCafeDataLoaded();
    if (!mounted) {
      return;
    }
    await _ensureDiscoveryOwnerMatchesFilters(
      state.mapFilters,
      owner: 'map',
    );
    await _hydrateTextSearchResultsIfNeeded(
      state.mapFilters,
      owner: 'map',
    );
  }

  List<Cafe> _upsertCafeInCollection(
    List<Cafe> source,
    Cafe cafe, {
    bool preserveExistingMedia = true,
    bool appendIfMissing = true,
  }) {
    final updated = List<Cafe>.from(source);
    final index = updated.indexWhere(
      (current) => _cafesShareIdentity(current, cafe),
    );
    if (index >= 0) {
      updated[index] = preserveExistingMedia
          ? _mergeCafePreservingMedia(
              current: updated[index],
              incoming: cafe,
            )
          : cafe;
    } else if (appendIfMissing) {
      updated.add(cafe);
    }
    return updated;
  }

  List<Cafe> _patchFeaturedCafeCollection(
    Cafe cafe, {
    bool preserveExistingMedia = true,
  }) {
    final exists = state.featuredCafes.any(
      (current) => _cafesShareIdentity(current, cafe),
    );
    if (!exists) {
      return state.featuredCafes;
    }
    if (!cafe.isFeatured || !cafe.isVisibleInPublic) {
      return state.featuredCafes
          .where((current) => !_cafesShareIdentity(current, cafe))
          .toList(growable: false);
    }
    return _upsertCafeInCollection(
      state.featuredCafes,
      cafe,
      preserveExistingMedia: preserveExistingMedia,
      appendIfMissing: false,
    );
  }

  List<Cafe> _upsertCafeInState(
    Cafe cafe, {
    bool preserveExistingMedia = true,
  }) {
    return _upsertCafeInCollection(
      state.cafes,
      cafe,
      preserveExistingMedia: preserveExistingMedia,
    );
  }

  /// Public API for external controllers to patch a single cafe in state.
  ///
  /// If [remove] is true, the cafe is removed from the list (used for deletes).
  /// This avoids triggering a full remote reload.
  void upsertCafe(
    Cafe cafe, {
    bool remove = false,
    bool preserveExistingMedia = true,
  }) {
    if (!mounted) return;
    final matchedFeatured = state.featuredCafes.any(
      (current) => _cafesShareIdentity(current, cafe),
    );
    AppLogger.debug(
      '[FEATURED_MUTATION_GUARD] source=upsertCafe remove=$remove cafe=${cafe.id} matchedFeatured=$matchedFeatured appendFeatured=false',
      key: 'featured-mutation-guard-${cafe.id}',
      throttle: Duration.zero,
    );
    if (remove || cafe.isDeleted) {
      final updatedCafes = state.cafes
          .where((c) => !_cafesShareIdentity(c, cafe))
          .toList(growable: false);
      final updatedHomeCafes = state.homeCafes
          .where((c) => !_cafesShareIdentity(c, cafe))
          .toList(growable: false);
      final updatedFeaturedCafes = state.featuredCafes
          .where((c) => !_cafesShareIdentity(c, cafe))
          .toList(growable: false);
      state = state.copyWith(
        cafes: updatedCafes,
        homeCafes: updatedHomeCafes,
        featuredCafes: updatedFeaturedCafes,
      );
    } else {
      final nextHomeCafes = _upsertCafeInCollection(
        state.homeCafes,
        cafe,
        preserveExistingMedia: preserveExistingMedia,
        appendIfMissing: false,
      );
      final nextFeaturedCafes = _patchFeaturedCafeCollection(
        cafe,
        preserveExistingMedia: preserveExistingMedia,
      );
      state = state.copyWith(
        cafes: _upsertCafeInState(
          cafe,
          preserveExistingMedia: preserveExistingMedia,
        ),
        homeCafes: nextHomeCafes,
        featuredCafes: nextFeaturedCafes,
      );
    }
  }

  ({int removedCafes, int removedHome, int removedFeatured})
      removeCafesByIdentity(Iterable<String> rawIds) {
    final ids =
        rawIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (!mounted || ids.isEmpty) {
      return (removedCafes: 0, removedHome: 0, removedFeatured: 0);
    }

    bool matches(Cafe cafe) {
      final keys = _cafeControllerRemovalIdentityKeys(cafe);
      return keys.any(ids.contains);
    }

    final cafesBefore = state.cafes.length;
    final homeBefore = state.homeCafes.length;
    final featuredBefore = state.featuredCafes.length;
    final nextCafes =
        state.cafes.where((cafe) => !matches(cafe)).toList(growable: false);
    final nextHome =
        state.homeCafes.where((cafe) => !matches(cafe)).toList(growable: false);
    final nextFeatured = state.featuredCafes
        .where((cafe) => !matches(cafe))
        .toList(growable: false);
    final nextSelectedCafeId =
        state.selectedCafeId != null && ids.contains(state.selectedCafeId)
            ? null
            : state.selectedCafeId;

    state = state.copyWith(
      cafes: nextCafes,
      homeCafes: nextHome,
      featuredCafes: nextFeatured,
      selectedCafeId: () => nextSelectedCafeId,
    );

    return (
      removedCafes: cafesBefore - nextCafes.length,
      removedHome: homeBefore - nextHome.length,
      removedFeatured: featuredBefore - nextFeatured.length,
    );
  }

  Set<String> _cafeControllerRemovalIdentityKeys(Cafe cafe) {
    final keys = <String>{cafe.id.trim(), cafe.canonicalIdentityKey.trim()};
    final placeId = cafe.placeId?.trim();
    if (placeId != null && placeId.isNotEmpty) {
      keys.add(placeId);
      keys.add('place:$placeId');
    }
    final fallback =
        'fallback:${normalizeSearchText(cafe.name)}|${normalizeSearchText(cafe.district)}|${normalizeSearchText(cafe.neighborhood)}|${normalizeSearchText(cafe.address)}';
    keys.add(fallback);
    keys.removeWhere((key) => key.isEmpty);
    return keys;
  }

  List<Cafe> _mergeCafeCollections(
    Iterable<Cafe> primary,
    Iterable<Cafe> secondary,
  ) {
    final merged = <String, Cafe>{};
    for (final cafe in [...primary, ...secondary]) {
      final key = cafe.canonicalIdentityKey;
      final existing = merged[key];
      if (existing == null) {
        merged[key] = cafe;
        continue;
      }

      merged[key] = _mergeCafePreservingMedia(
        current: existing,
        incoming: cafe,
      );
    }

    return applySharedBrandPricing(merged.values.toList(growable: false));
  }

  List<Cafe> _hydrateMissingCachedCafes(
    List<Cafe> currentCafes,
    List<Cafe> cachedCafes,
  ) {
    if (currentCafes.isEmpty || cachedCafes.length >= currentCafes.length) {
      return cachedCafes;
    }

    final hydrated = List<Cafe>.from(currentCafes);
    final seenIdentities = <String>{
      for (final cafe in hydrated) cafe.canonicalIdentityKey,
    };
    for (final cachedCafe in cachedCafes) {
      if (!seenIdentities.add(cachedCafe.canonicalIdentityKey)) {
        continue;
      }
      final aliasCollision = hydrated.any(
        (current) => _cafesShareIdentity(current, cachedCafe),
      );
      if (aliasCollision) {
        continue;
      }
      hydrated.add(cachedCafe);
    }
    return applySharedBrandPricing(hydrated);
  }

  bool _cafesShareIdentity(Cafe left, Cafe right) {
    if (left.dedupKey == right.dedupKey) {
      return true;
    }

    final leftPlaceId = left.placeId?.trim();
    final rightPlaceId = right.placeId?.trim();

    if (left.id == right.id || left.id == rightPlaceId) {
      return true;
    }
    if (right.id == leftPlaceId) {
      return true;
    }
    if (leftPlaceId != null &&
        leftPlaceId.isNotEmpty &&
        rightPlaceId != null &&
        rightPlaceId.isNotEmpty &&
        leftPlaceId == rightPlaceId) {
      return true;
    }

    return false;
  }

  Cafe _mergeCafePreservingMedia({
    required Cafe current,
    required Cafe incoming,
  }) {
    final normalizedCurrentImages = normalizeCafeImageUrls(current.photoUrls);
    final normalizedIncomingImages = normalizeCafeImageUrls(incoming.photoUrls);
    final shouldPreserveCurrentImages =
        normalizedIncomingImages.isEmpty && normalizedCurrentImages.isNotEmpty;
    if (shouldPreserveCurrentImages) {
      AppLogger.debug(
        '[CAFE_DIAG_PHOTO] source=state-merge preserveExisting=true cafe=${current.id} current=${normalizedCurrentImages.length} incomingRaw=${incoming.photoUrls.length} incomingNormalized=${normalizedIncomingImages.length}',
        key: 'cafe-diag-photo-state-merge-${current.id}',
        throttle: Duration.zero,
      );
    }
    final mergedImages = shouldPreserveCurrentImages
        ? normalizedCurrentImages
        : normalizedIncomingImages;
    final mergedOpeningHours = incoming.openingHours.isNotEmpty
        ? incoming.openingHours
        : current.openingHours;
    final mergedDescription = incoming.description.trim().isNotEmpty
        ? incoming.description
        : current.description;
    final mergedPhone = (incoming.phoneNumber?.trim().isNotEmpty ?? false)
        ? incoming.phoneNumber
        : current.phoneNumber;
    final mergedWebsite = (incoming.websiteUri?.trim().isNotEmpty ?? false)
        ? incoming.websiteUri
        : current.websiteUri;

    return incoming.copyWith(
      images: mergedImages,
      openingHours: mergedOpeningHours,
      description: mergedDescription,
      phoneNumber: mergedPhone,
      websiteUri: mergedWebsite,
    );
  }

  bool _isCurrentCafeRequest(int requestVersion) {
    return requestVersion == _cafesRequestVersion;
  }

  bool _isCurrentHomeCafeRequest(int requestVersion) {
    return requestVersion == _homeCafesRequestVersion;
  }

  bool _isCurrentCafeDetailRequest(String cafeId, int requestVersion) {
    return _detailRequestVersions[cafeId] == requestVersion;
  }

  RequestCancellationToken _beginCafeListRequest() {
    _activeCafeListRequest
        ?.cancel('Superseded by a newer cafe search request.');
    _activeLoadMoreRequest?.cancel(
      'Superseded by a newer cafe search request.',
    );
    final controller = RequestCancellationController(
      defaultReason: 'Cafe search request was cancelled.',
    );
    _activeCafeListRequest = controller;
    return controller.token;
  }

  RequestCancellationToken _beginHomeCafeListRequest() {
    _activeHomeCafeListRequest
        ?.cancel('Superseded by a newer home cafe request.');
    final controller = RequestCancellationController(
      defaultReason: 'Home cafe request was cancelled.',
    );
    _activeHomeCafeListRequest = controller;
    return controller.token;
  }

  RequestCancellationToken _beginLoadMoreRequest() {
    _activeLoadMoreRequest?.cancel(
      'Superseded by a newer pagination request.',
    );
    final controller = RequestCancellationController(
      defaultReason: 'Cafe pagination request was cancelled.',
    );
    _activeLoadMoreRequest = controller;
    return controller.token;
  }

  RequestCancellationToken _beginCafeDetailRequest(String cafeId) {
    _detailRequestControllers.remove(cafeId)?.cancel(
          'Superseded by a newer cafe detail request.',
        );
    final controller = RequestCancellationController(
      defaultReason: 'Cafe detail request was cancelled.',
    );
    _detailRequestControllers[cafeId] = controller;
    return controller.token;
  }

  void cancelCafeDetailLoad(String cafeId) {
    _detailRequestControllers.remove(cafeId)?.cancel(
          'Cafe detail screen was closed.',
        );
  }

  void _setCafeDetailLoading(String cafeId, bool isLoading) {
    final next = Set<String>.from(state.loadingCafeDetailIds);
    if (isLoading) {
      next.add(cafeId);
    } else {
      next.remove(cafeId);
    }
    state = state.copyWith(loadingCafeDetailIds: next);
  }

  void _setCafeDetailError(String cafeId, String? message) {
    final next = Map<String, String>.from(state.cafeDetailErrorMessages);
    if (message == null || message.trim().isEmpty) {
      next.remove(cafeId);
    } else {
      next[cafeId] = message;
    }
    state = state.copyWith(cafeDetailErrorMessages: next);
  }

  Future<Coordinates?> _resolveCafeFetchCoordinates() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null &&
          isWithinIstanbul(
            lastKnownPosition.latitude,
            lastKnownPosition.longitude,
          )) {
        return Coordinates(
          lat: lastKnownPosition.latitude,
          lng: lastKnownPosition.longitude,
        );
      }

      final position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 2),
      );
      if (!isWithinIstanbul(position.latitude, position.longitude)) {
        return null;
      }
      return Coordinates(
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (_) {
      AppLogger.warn(
        'Unable to resolve device location for cafe fetch. Falling back to default search area.',
        key: 'cafe-fetch-location-unavailable',
      );
      return null;
    }
  }

  Future<Coordinates?> ensureCurrentLocation() async {
    final coordinates = await _resolveCafeFetchCoordinates();
    if (!mounted) {
      return coordinates;
    }
    state = state.copyWith(currentLocation: () => coordinates);
    return coordinates;
  }

  List<String> _activeDistricts(Filters filters) {
    return filters.effectiveDistricts
        .map((district) => district.trim())
        .where((district) => district.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort((left, right) =>
          normalizeSearchText(left).compareTo(normalizeSearchText(right)));
  }

  Future<void> _persistDiscoveryPreferences() async {
    final storage = _ref.read(localStorageServiceProvider);
    if (storage == null) {
      return;
    }

    await storage.saveCafeDiscoveryState(
      filters: state.filters,
      radiusMeters: state.mapRadiusPreset.radiusMeters,
    );
  }

  _CafeDiscoveryRequest _buildCafeDiscoveryRequest({
    required Coordinates? currentLocation,
    required Filters filters,
    required MapRadiusPreset radiusPreset,
  }) {
    final districts = _activeDistricts(filters);
    if (districts.isNotEmpty) {
      return _CafeDiscoveryRequest(
        discoveryCacheKey: CafeCacheKeys.discovery(
          radiusMeters: radiusPreset.radiusMeters,
          districts: districts,
        ),
        districts: districts,
        fetchCenter: null,
        fetchRadiusMeters: radiusPreset.radiusMeters,
      );
    }
    final center = currentLocation ?? istanbulCenterCoordinates;
    return _CafeDiscoveryRequest(
      discoveryCacheKey: CafeCacheKeys.discovery(
        center: center,
        radiusMeters: radiusPreset.radiusMeters,
      ),
      districts: const <String>[],
      fetchCenter: center,
      fetchRadiusMeters: radiusPreset.radiusMeters,
    );
  }

  void _logCafeLoadFailure(
    String action,
    _CafeLoadException error, {
    String? pageToken,
  }) {
    final pageLabel =
        (pageToken == null || pageToken.isEmpty) ? 'first-page' : 'page-token';
    AppLogger.error(
      '$action failed (type: ${error.errorType.name}, page: $pageLabel, remoteMessage: ${error.remoteMessage ?? 'n/a'})',
      error: error,
      key:
          '${action.toLowerCase().replaceAll(' ', '-')}-${error.errorType.name}-$pageLabel',
    );
  }

  Future<CafeRepositoryResult> _fetchDiscoverableForRequest({
    required CafeRepository repository,
    required _CafeDiscoveryRequest discoveryRequest,
    required RequestCancellationToken cancellationToken,
    String? pageToken,
    bool seedOnly = false,
    bool bypassRateLimit = false,
  }) async {
    if (discoveryRequest.districts.length <= 1) {
      return repository.fetchDiscoverableCafes(
        pageToken: pageToken,
        lat: discoveryRequest.fetchCenter?.lat,
        lng: discoveryRequest.fetchCenter?.lng,
        district: discoveryRequest.district,
        radius: discoveryRequest.fetchRadiusMeters,
        seedOnly: seedOnly,
        bypassRateLimit: bypassRateLimit,
        discoveryCacheKey: discoveryRequest.discoveryCacheKey,
        cancellationToken: cancellationToken,
      );
    }

    if (pageToken?.trim().isNotEmpty == true) {
      return const CafeRepositoryResult.failure(
        errorMessage: 'Pagination is not available for district groups.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    var merged = const <Cafe>[];
    final warnings = <String>[];
    for (final district in discoveryRequest.districts) {
      cancellationToken.throwIfCancelled();
      final districtCacheKey = CafeCacheKeys.discovery(
        radiusMeters: discoveryRequest.fetchRadiusMeters,
        district: district,
      );
      final result = await repository.fetchDiscoverableCafes(
        district: district,
        radius: discoveryRequest.fetchRadiusMeters,
        seedOnly: seedOnly,
        bypassRateLimit: bypassRateLimit,
        discoveryCacheKey: districtCacheKey,
        cancellationToken: cancellationToken,
      );
      if (!result.ok) {
        return result;
      }
      merged = _mergeCafeCollections(merged, result.cafes);
      final warning = result.warningMessage?.trim();
      if (warning != null && warning.isNotEmpty) {
        warnings.add(warning);
      }
    }

    if (!seedOnly) {
      await repository.saveCafeListSnapshot(
        discoveryRequest.discoveryCacheKey,
        merged,
      );
    }

    return CafeRepositoryResult(
      cafes: merged,
      usedRemote: true,
      warningMessage: warnings.isEmpty ? null : warnings.toSet().join(' '),
      nextPageToken: null,
    );
  }

  Future<void> loadCafes({bool forceRemote = false}) async {
    final requestVersion = ++_cafesRequestVersion;
    final cancellationToken = _beginCafeListRequest();
    if (mounted && !state.hasInitializedDiscovery) {
      state = state.copyWith(hasInitializedDiscovery: true);
    }
    final repository = _ref.read(cafeRepositoryProvider);
    var coordinates = state.currentLocation;
    final filters = state.filters;
    final activeRadiusPreset = state.mapRadiusPreset;
    if (coordinates == null) {
      coordinates = await _resolveCafeFetchCoordinates();
      if (mounted && _isCurrentCafeRequest(requestVersion)) {
        state = state.copyWith(currentLocation: () => coordinates);
      }
    }
    final discoveryRequest = _buildCafeDiscoveryRequest(
      currentLocation: coordinates,
      filters: filters,
      radiusPreset: activeRadiusPreset,
    );
    AppLogger.debug(
      '[CAFE_DIAG_REQUEST] cacheKey=${discoveryRequest.discoveryCacheKey} district=${discoveryRequest.district ?? 'none'} radius=${discoveryRequest.fetchRadiusMeters} forceRemote=$forceRemote',
      key: 'cafe-diag-request',
      throttle: Duration.zero,
    );
    final cachedSnapshot = await repository.loadCachedCafeList(
      cacheKey: discoveryRequest.discoveryCacheKey,
    );
    if (!_isCurrentCafeRequest(requestVersion)) {
      return;
    }

    final shouldUseFreshCacheOnly = !forceRemote &&
        cachedSnapshot != null &&
        !CafeCachePolicy.isStaleList(cachedSnapshot.cachedAt) &&
        (state.cafes.isEmpty ||
            cachedSnapshot.cafes.length >= state.cafes.length);
    final shouldRunSeedFetch = cachedSnapshot == null && !forceRemote;
    final canKeepVisibleCafesWhileRefreshing = state.cafes.isNotEmpty;
    final cachedHydratedCafes = cachedSnapshot == null
        ? state.cafes
        : _hydrateMissingCachedCafes(state.cafes, cachedSnapshot.cafes);

    if (cachedSnapshot != null) {
      AppLogger.debug(
        '[CAFE_DIAG_CACHE] cacheKey=${discoveryRequest.discoveryCacheKey} cachedCount=${cachedSnapshot.cafes.length} stale=${!shouldUseFreshCacheOnly}',
        key: 'cafe-diag-cache',
        throttle: Duration.zero,
      );
    }

    if (cachedSnapshot != null) {
      state = state.copyWith(
        cafes: cachedHydratedCafes,
        cafesLastUpdated: () => cachedSnapshot.lastUpdated,
        isCafesLoading: false,
        isLoadingMore: false,
        cafesErrorMessage: () => null,
        cafesNoticeMessage: () => null,
        displayedFilters: filters,
        loadMoreErrorMessage: () => null,
        nextPageToken: () => cachedSnapshot.nextPageToken,
        hasMorePages: cachedSnapshot.nextPageToken != null &&
            cachedSnapshot.nextPageToken!.isNotEmpty,
        isServingStaleCache: !shouldUseFreshCacheOnly,
        cafeSyncState: shouldUseFreshCacheOnly
            ? CafeSyncState.ready
            : CafeSyncState.showingCachedWhileRefreshing,
        cafeSearchScopeKey: () => discoveryRequest.discoveryCacheKey,
        displayedMapRadiusPreset: activeRadiusPreset,
        discoveryDiagnostics: () => null,
      );
      if (!shouldUseFreshCacheOnly) {
        _scheduleRefreshWhenOnline();
      } else {
        _clearRefreshWhenOnlineFlag();
      }
      if (shouldUseFreshCacheOnly) {
        await ensureFeaturedCafesLoaded(forceRemote: forceRemote);
        if (!mounted || !_isCurrentHomeCafeRequest(requestVersion)) {
          return;
        }
        if (!state.hasLoadedFeaturedCafes && !state.isFeaturedCafesLoading) {
          await ensureFeaturedCafesLoaded(forceRemote: true);
        }
        return;
      }
    } else {
      state = state.copyWith(
        cafes:
            canKeepVisibleCafesWhileRefreshing ? state.cafes : const <Cafe>[],
        isCafesLoading: !canKeepVisibleCafesWhileRefreshing,
        isLoadingMore: false,
        isServingStaleCache: canKeepVisibleCafesWhileRefreshing,
        cafesErrorMessage: () => null,
        cafesNoticeMessage: () => null,
        loadMoreErrorMessage: () => null,
        nextPageToken: () => null,
        hasMorePages: false,
        cafeSyncState: canKeepVisibleCafesWhileRefreshing
            ? CafeSyncState.showingCachedWhileRefreshing
            : CafeSyncState.loading,
      );
    }

    try {
      final result = await _fetchDiscoverableForRequest(
        repository: repository,
        discoveryRequest: discoveryRequest,
        cancellationToken: cancellationToken,
        seedOnly: shouldRunSeedFetch,
      );
      if (!_isCurrentCafeRequest(requestVersion)) {
        return;
      }
      if (!result.ok) {
        throw _CafeLoadException.fromRepositoryResult(
          result,
          fallbackMessage: 'Unable to load cafes right now.',
        );
      }

      final mergedCafes = result.cafes;
      AppLogger.debug(
        '[CAFE_DIAG_REMOTE] cacheKey=${discoveryRequest.discoveryCacheKey} freshMergedCount=${mergedCafes.length} seedOnly=$shouldRunSeedFetch',
        key: 'cafe-diag-remote',
        throttle: Duration.zero,
      );

      if (shouldRunSeedFetch) {
        const seedAdequacyThreshold = RequestTuningConfig.seedAdequateCafeCount;
        final isSeedAdequate = mergedCafes.length >= seedAdequacyThreshold;
        final shouldCompleteLargeRadiusDiscovery =
            activeRadiusPreset == MapRadiusPreset.large;
        if (isSeedAdequate && !shouldCompleteLargeRadiusDiscovery) {
          AppLogger.debug(
            '[PLACES_SKIP_FULL_DISCOVERY] seedCafeCount=${mergedCafes.length} threshold=$seedAdequacyThreshold',
            key: 'places-skip-full-discovery',
            throttle: Duration.zero,
          );

          _applyCafeLoadSuccess(
            cafes: mergedCafes,
            coordinates: coordinates,
            nextPageToken: result.nextPageToken,
            requestScopeKey: discoveryRequest.discoveryCacheKey,
            noticeMessage: result.warningMessage,
            diagnostics: result.diagnostics,
          );
          return;
        }
        if (isSeedAdequate && shouldCompleteLargeRadiusDiscovery) {
          AppLogger.debug(
            '[PLACES_FULL_DISCOVERY_AFTER_SEED] seedCafeCount=${mergedCafes.length} radius=${activeRadiusPreset.radiusMeters}',
            key: 'places-full-discovery-after-seed',
            throttle: Duration.zero,
          );
        }

        state = state.copyWith(
          cafes: mergedCafes,
          currentLocation: () => coordinates,
          cafesLastUpdated: () => DateTime.now().toUtc(),
          isCafesLoading: false,
          cafesErrorMessage: () => null,
          cafesNoticeMessage: () => result.warningMessage,
          displayedFilters: filters,
          nextPageToken: () => result.nextPageToken,
          hasMorePages:
              result.nextPageToken != null && result.nextPageToken!.isNotEmpty,
          isServingStaleCache: false,
          cafeSyncState: mergedCafes.isEmpty
              ? CafeSyncState.empty
              : CafeSyncState.showingCachedWhileRefreshing,
          cafeSearchScopeKey: () => discoveryRequest.discoveryCacheKey,
          displayedMapRadiusPreset: activeRadiusPreset,
          discoveryDiagnostics: () => result.diagnostics,
        );
        _clearRefreshWhenOnlineFlag();

        // Weak seed-mode results should be followed by a full discovery refresh.
        unawaited(
          _completeFullCafeDiscovery(
            requestVersion: requestVersion,
            repository: repository,
            coordinates: coordinates,
            requestScopeKey: discoveryRequest.discoveryCacheKey,
            discoveryRequest: discoveryRequest,
          ),
        );
        return;
      }

      _applyCafeLoadSuccess(
        cafes: mergedCafes,
        coordinates: coordinates,
        nextPageToken: result.nextPageToken,
        requestScopeKey: discoveryRequest.discoveryCacheKey,
        noticeMessage: result.warningMessage,
        diagnostics: result.diagnostics,
      );
    } catch (error) {
      if (!_isCurrentCafeRequest(requestVersion)) {
        return;
      }
      if (classifyServiceError(error) == ServiceErrorType.cancelled) {
        return;
      }
      if (error is _CafeLoadException) {
        _logCafeLoadFailure('Cafe list refresh', error);
      }
      AppLogger.error(
        'CafeNotifier.loadCafes failed',
        error: error,
        key: 'load-cafes-failed',
      );
      if (cachedSnapshot != null) {
        state = state.copyWith(
          currentLocation: () => coordinates,
          isCafesLoading: false,
          cafesLastUpdated: () => cachedSnapshot.lastUpdated,
          cafesErrorMessage: () => null,
          cafesNoticeMessage: () => null,
          displayedFilters: filters,
          nextPageToken: () => cachedSnapshot.nextPageToken,
          hasMorePages: cachedSnapshot.nextPageToken != null &&
              cachedSnapshot.nextPageToken!.isNotEmpty,
          isServingStaleCache: true,
          cafeSyncState: CafeSyncState.errorWithCache,
          cafeSearchScopeKey: () => discoveryRequest.discoveryCacheKey,
          displayedMapRadiusPreset: activeRadiusPreset,
        );
        _scheduleRefreshWhenOnline();
      } else {
        state = state.copyWith(
          currentLocation: () => coordinates,
          isCafesLoading: false,
          cafesErrorMessage: () => _toUserFacingCafeMessage(error),
          cafesNoticeMessage: () => null,
          isServingStaleCache: false,
          cafeSyncState: CafeSyncState.error,
          cafeSearchScopeKey: () => discoveryRequest.discoveryCacheKey,
        );
      }
    }
  }

  Future<void> _completeFullCafeDiscovery({
    required int requestVersion,
    required CafeRepository repository,
    required Coordinates? coordinates,
    required String requestScopeKey,
    required _CafeDiscoveryRequest discoveryRequest,
  }) async {
    try {
      final cancellationToken = _activeCafeListRequest?.token;
      if (cancellationToken == null) {
        return;
      }
      final result = await _fetchDiscoverableForRequest(
        repository: repository,
        discoveryRequest: discoveryRequest,
        cancellationToken: cancellationToken,
        bypassRateLimit: true,
      );
      if (!_isCurrentCafeRequest(requestVersion)) {
        return;
      }
      if (!result.ok) {
        throw _CafeLoadException.fromRepositoryResult(
          result,
          fallbackMessage: 'Unable to load cafes right now.',
        );
      }

      final mergedCafes = result.cafes;
      _applyCafeLoadSuccess(
        cafes: mergedCafes,
        coordinates: coordinates,
        nextPageToken: result.nextPageToken,
        requestScopeKey: requestScopeKey,
        noticeMessage: result.warningMessage,
        diagnostics: result.diagnostics,
      );
    } catch (error) {
      if (!_isCurrentCafeRequest(requestVersion)) {
        return;
      }
      if (classifyServiceError(error) == ServiceErrorType.cancelled) {
        return;
      }
      if (error is _CafeLoadException) {
        _logCafeLoadFailure('Background cafe list refresh', error);
      }
      AppLogger.error(
        'CafeNotifier._completeFullCafeDiscovery failed',
        error: error,
        key: 'complete-full-cafe-discovery-failed',
      );

      if (state.cafes.isNotEmpty) {
        state = state.copyWith(
          currentLocation: () => coordinates,
          isCafesLoading: false,
          cafesLastUpdated: () => state.cafesLastUpdated,
          cafesErrorMessage: () => null,
          cafesNoticeMessage: () => null,
          nextPageToken: () => null,
          hasMorePages: false,
          isServingStaleCache: true,
          cafeSyncState: CafeSyncState.ready,
          cafeSearchScopeKey: () => requestScopeKey,
        );
        _scheduleRefreshWhenOnline();
        return;
      }

      state = state.copyWith(
        currentLocation: () => coordinates,
        isCafesLoading: false,
        cafesErrorMessage: () => _toUserFacingCafeMessage(error),
        cafesNoticeMessage: () => null,
        nextPageToken: () => null,
        hasMorePages: false,
        isServingStaleCache: false,
        cafeSyncState: CafeSyncState.error,
        cafeSearchScopeKey: () => requestScopeKey,
      );
    }
  }

  void _applyCafeLoadSuccess({
    required List<Cafe> cafes,
    required Coordinates? coordinates,
    required String? nextPageToken,
    required String requestScopeKey,
    String? noticeMessage,
    CafeDiscoveryDiagnostics? diagnostics,
  }) {
    final shouldPreserveSameScopeCafes =
        state.cafeSearchScopeKey == requestScopeKey &&
            state.cafes.isNotEmpty &&
            cafes.length < state.cafes.length;
    final nextCafes = shouldPreserveSameScopeCafes
        ? _mergeCafeCollections(state.cafes, cafes)
        : cafes;
    if (shouldPreserveSameScopeCafes) {
      AppLogger.debug(
        '[CAFE_DIAG_PRESERVE] cacheKey=$requestScopeKey existing=${state.cafes.length} incoming=${cafes.length} merged=${nextCafes.length}',
        key: 'cafe-diag-preserve',
        throttle: Duration.zero,
      );
    }

    state = state.copyWith(
      cafes: nextCafes,
      currentLocation: () => coordinates,
      cafesLastUpdated: () => DateTime.now().toUtc(),
      isCafesLoading: false,
      cafesErrorMessage: () => null,
      cafesNoticeMessage: () => noticeMessage,
      displayedFilters: state.filters,
      nextPageToken: () => nextPageToken,
      hasMorePages: nextPageToken != null && nextPageToken.isNotEmpty,
      isServingStaleCache: false,
      cafeSyncState:
          nextCafes.isEmpty ? CafeSyncState.empty : CafeSyncState.ready,
      cafeSearchScopeKey: () => requestScopeKey,
      displayedMapRadiusPreset: state.mapRadiusPreset,
      discoveryDiagnostics: () => diagnostics,
    );
    final districts = _ref.read(activeDistrictsProvider);
    final finalVisibleCount = applyFilters(
      nextCafes,
      state.filters,
      districts: districts,
    ).length;
    AppLogger.debug(
      '[CAFE_DIAG_UI] cacheKey=$requestScopeKey finalListCount=${nextCafes.length} finalVisibleCount=$finalVisibleCount',
      key: 'cafe-diag-ui',
      throttle: Duration.zero,
    );
    _clearRefreshWhenOnlineFlag();
  }

  Future<void> loadMoreCafes() async {
    if (!state.hasMorePages ||
        state.isLoadingMore ||
        state.isCafesLoading ||
        state.nextPageToken == null ||
        state.cafeSyncState == CafeSyncState.showingCachedWhileRefreshing) {
      return;
    }

    final requestVersion = _cafesRequestVersion;
    final cancellationToken = _beginLoadMoreRequest();
    final pageToken = state.nextPageToken;
    state = state.copyWith(
      isLoadingMore: true,
      loadMoreErrorMessage: () => null,
    );

    final repository = _ref.read(cafeRepositoryProvider);
    final discoveryRequest = _buildCafeDiscoveryRequest(
      currentLocation: state.currentLocation,
      filters: state.filters,
      radiusPreset: state.mapRadiusPreset,
    );

    try {
      final result = await _fetchDiscoverableForRequest(
        repository: repository,
        discoveryRequest: discoveryRequest,
        cancellationToken: cancellationToken,
        pageToken: pageToken,
      );
      if (!_isCurrentCafeRequest(requestVersion)) {
        return;
      }
      if (!result.ok) {
        throw _CafeLoadException.fromRepositoryResult(
          result,
          fallbackMessage: 'Unable to load more cafes right now.',
        );
      }

      final updatedCafes = _mergeCafeCollections(state.cafes, result.cafes);
      state = state.copyWith(
        cafes: updatedCafes,
        isLoadingMore: false,
        loadMoreErrorMessage: () => null,
        nextPageToken: () => result.nextPageToken,
        hasMorePages:
            result.nextPageToken != null && result.nextPageToken!.isNotEmpty,
      );
      if (!_isCurrentCafeRequest(requestVersion)) {
        return;
      }
      final cacheKey = state.cafeSearchScopeKey;
      if (cacheKey != null) {
        await repository.saveCafeListSnapshot(
          cacheKey,
          updatedCafes,
          nextPageToken: result.nextPageToken,
        );
      }
    } catch (error) {
      if (!_isCurrentCafeRequest(requestVersion)) {
        return;
      }
      if (classifyServiceError(error) == ServiceErrorType.cancelled) {
        state = state.copyWith(
          isLoadingMore: false,
          loadMoreErrorMessage: () => null,
        );
        return;
      }
      if (error is _CafeLoadException) {
        _logCafeLoadFailure(
          'Cafe pagination',
          error,
          pageToken: pageToken,
        );
      }
      AppLogger.error(
        'CafeNotifier.loadMoreCafes failed',
        error: error,
        key: 'load-more-cafes-failed',
      );
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorMessage: () => _toUserFacingCafeMessage(error),
      );
    }
  }

  String? _toUserFacingCafeMessage(Object? error) {
    if (error == null) {
      return null;
    }

    final raw = error.toString();
    if (raw.trim().isEmpty) {
      return null;
    }

    final normalized = raw.toLowerCase();
    const unavailableMessage = 'This feature is currently unavailable.';
    const loadFailedMessage = 'Unable to load cafes right now.';

    if (normalized.contains('google_maps_api_key') ||
        normalized.contains('google_places_api_key') ||
        normalized.contains('places api') ||
        normalized.contains('supabase') ||
        normalized.contains('config') ||
        normalized.contains('not configured')) {
      return unavailableMessage;
    }

    if (normalized.contains('socket') ||
        normalized.contains('timeout') ||
        normalized.contains('network') ||
        normalized.contains('http') ||
        normalized.contains('failed to fetch')) {
      return loadFailedMessage;
    }

    return loadFailedMessage;
  }

  Future<void> refreshCafes() async {
    state = state.copyWith(
      isLoadingMore: false,
      loadMoreErrorMessage: () => null,
      cafesNoticeMessage: () => null,
      nextPageToken: () => null,
      hasMorePages: false,
    );
    await ensureFeaturedCafesLoaded(forceRemote: true);
    await loadCafes(forceRemote: true);
  }

  Filters _discoveryFiltersForUiFilters(Filters filters) {
    // Remote discovery ownership is intentionally narrow: district changes the
    // remote dataset; category/rating/amenity/open/search filters are local
    // projections over that dataset.
    final districts = _activeDistricts(filters);
    return Filters(
      district: districts.length == 1 ? districts.single : null,
      selectedDistricts: Set<String>.unmodifiable(districts),
    );
  }

  Future<void> _ensureDiscoveryOwnerMatchesFilters(
    Filters uiFilters, {
    required String owner,
    bool forceRemote = false,
  }) async {
    final discoveryFilters = _discoveryFiltersForUiFilters(uiFilters);
    if (_filtersEqual(state.filters, discoveryFilters)) {
      return;
    }

    AppLogger.debug(
      '[CAFE_QUERY_OWNER] owner=$owner discoveryFilters=${CafeCacheKeys.filtersSignature(discoveryFilters)} uiFilters=${CafeCacheKeys.filtersSignature(uiFilters)}',
      key: 'cafe-query-owner-$owner',
      throttle: Duration.zero,
    );

    state = state.copyWith(
      filters: discoveryFilters,
      loadMoreErrorMessage: () => null,
      nextPageToken: () => null,
      hasMorePages: false,
    );
    await _persistDiscoveryPreferences();
    await loadCafes(forceRemote: forceRemote);
  }

  Future<void> _hydrateTextSearchResultsIfNeeded(
    Filters filters, {
    required String owner,
  }) async {
    final query = _cleanOptionalText(filters.searchQuery);
    if (query == null) {
      return;
    }

    final districts = _ref.read(activeDistrictsProvider);
    final localMatches = applyFilters(
      state.cafes,
      filters,
      districts: districts,
    );
    if (localMatches.isNotEmpty) {
      return;
    }

    final canKeepVisibleCafes = state.cafes.isNotEmpty;
    state = state.copyWith(
      isCafesLoading: !canKeepVisibleCafes,
      isServingStaleCache: canKeepVisibleCafes,
      cafesErrorMessage: () => null,
      cafeSyncState: canKeepVisibleCafes
          ? CafeSyncState.showingCachedWhileRefreshing
          : CafeSyncState.loading,
    );

    try {
      final result = await _ref.read(cafeRepositoryProvider).searchCafesByName(
            query,
            limit: 40,
          );
      if (!mounted) {
        return;
      }

      if (result.ok && result.cafes.isNotEmpty) {
        state = state.copyWith(
          cafes: _mergeCafeCollections(state.cafes, result.cafes),
          cafesLastUpdated: () => DateTime.now().toUtc(),
          isCafesLoading: false,
          isServingStaleCache: false,
          cafesErrorMessage: () => null,
          cafeSyncState: CafeSyncState.ready,
        );
        return;
      }

      state = state.copyWith(
        isCafesLoading: false,
        isServingStaleCache: false,
        cafesErrorMessage: () => result.ok ? null : state.cafesErrorMessage,
        cafeSyncState:
            state.cafes.isEmpty ? CafeSyncState.empty : CafeSyncState.ready,
      );
    } catch (error) {
      if (!mounted ||
          classifyServiceError(error) == ServiceErrorType.cancelled) {
        return;
      }
      AppLogger.warn(
        'CafeNotifier text search hydration failed for owner=$owner',
        key: 'cafe-text-search-hydration-$owner',
      );
      state = state.copyWith(
        isCafesLoading: false,
        isServingStaleCache: false,
        cafeSyncState:
            state.cafes.isEmpty ? CafeSyncState.empty : CafeSyncState.ready,
      );
    }
  }

  Future<void> setMapRadiusPreset(MapRadiusPreset preset) async {
    final previousPreset = state.mapRadiusPreset;
    if (previousPreset == preset) {
      return;
    }

    final previousRadiusMeters = previousPreset.radiusMeters;
    final nextRadiusMeters = preset.radiusMeters;
    final isExpandingRadius = nextRadiusMeters > previousRadiusMeters;
    final hasDistrictScope = _activeDistricts(state.mapFilters).isNotEmpty ||
        _activeDistricts(state.filters).isNotEmpty;

    AppLogger.debug(
      '[CAFE_DIAG_RADIUS] previous=$previousRadiusMeters next=$nextRadiusMeters expanding=$isExpandingRadius districtScoped=$hasDistrictScope',
      key: 'cafe-diag-radius',
      throttle: Duration.zero,
    );
    if (hasDistrictScope) {
      return;
    }
    _ref.read(analyticsServiceProvider).trackMapRadiusChanged(
          preset: preset.name,
          radiusMeters: nextRadiusMeters,
        );

    state = state.copyWith(
      mapRadiusPreset: preset,
      displayedMapRadiusPreset: preset,
      isRadiusRefreshInFlight: false,
      loadMoreErrorMessage: () => null,
    );
    await _persistDiscoveryPreferences();

    if (!mounted || !state.hasInitializedDiscovery) {
      return;
    }

    if (!isExpandingRadius || hasDistrictScope) {
      return;
    }

    final canKeepVisibleCafes = state.cafes.isNotEmpty;
    state = state.copyWith(
      isRadiusRefreshInFlight: true,
      isCafesLoading: !canKeepVisibleCafes,
      cafeSyncState: canKeepVisibleCafes
          ? CafeSyncState.showingCachedWhileRefreshing
          : CafeSyncState.loading,
      cafesErrorMessage: () => null,
      cafesNoticeMessage: () => null,
    );

    try {
      await loadCafes(forceRemote: true);
    } finally {
      if (mounted) {
        state = state.copyWith(isRadiusRefreshInFlight: false);
      }
    }
  }

  Future<void> setExploreFilters(Filters filters) async {
    final previousFilters = state.exploreFilters;
    final sanitizedFilters =
        _sanitizeFilters(filters, previous: previousFilters);
    if (_filtersEqual(previousFilters, sanitizedFilters)) {
      return;
    }
    _trackFilterAnalytics(previousFilters, sanitizedFilters);

    state = state.copyWith(
      exploreFilters: sanitizedFilters,
      mapFilters: _withDistrictSelection(
        state.mapFilters,
        sanitizedFilters.effectiveDistricts,
      ),
      loadMoreErrorMessage: () => null,
    );
    await _ensureDiscoveryOwnerMatchesFilters(
      sanitizedFilters,
      owner: 'explore',
    );
    await _hydrateTextSearchResultsIfNeeded(
      sanitizedFilters,
      owner: 'explore',
    );
  }

  Future<void> setMapFilters(Filters filters) async {
    final previousFilters = state.mapFilters;
    final sanitizedFilters =
        _sanitizeFilters(filters, previous: previousFilters);
    if (_filtersEqual(previousFilters, sanitizedFilters)) {
      return;
    }
    _trackFilterAnalytics(previousFilters, sanitizedFilters);

    state = state.copyWith(
      mapFilters: sanitizedFilters,
      exploreFilters: _withDistrictSelection(
        state.exploreFilters,
        sanitizedFilters.effectiveDistricts,
      ),
      selectedCafeId: () => null,
    );
    await _ensureDiscoveryOwnerMatchesFilters(
      sanitizedFilters,
      owner: 'map',
    );
    await _hydrateTextSearchResultsIfNeeded(
      sanitizedFilters,
      owner: 'map',
    );
  }

  Future<void> resetExploreFilters() {
    return setExploreFilters(Filters.empty);
  }

  Future<void> resetMapFilters() {
    return setMapFilters(Filters.empty);
  }

  void setHomeFeaturedDistrict(String? district) {
    final normalizedDistrict = _cleanOptionalText(district);
    final currentDistrict = _cleanOptionalText(state.homeFeaturedDistrict);
    if (normalizeSearchText(currentDistrict ?? '') ==
        normalizeSearchText(normalizedDistrict ?? '')) {
      return;
    }
    state = state.copyWith(homeFeaturedDistrict: () => normalizedDistrict);
  }

  Future<bool> ensureCafeLoaded(String cafeId) async {
    final requestVersion = (_detailRequestVersions[cafeId] ?? 0) + 1;
    _detailRequestVersions[cafeId] = requestVersion;
    final cancellationToken = _beginCafeDetailRequest(cafeId);
    final existing = state.cafes.where((cafe) => cafe.id == cafeId).firstOrNull;
    if (existing != null && existing.isDeleted) {
      AppLogger.debug(
        '[DETAIL_DELETED_GUARD] cafeId=$cafeId reason=is_deleted_or_deleted_at',
        key: 'detail-deleted-guard-existing-$cafeId',
        throttle: Duration.zero,
      );
      removeCafesByIdentity(<String>[
        cafeId,
        existing.id,
        if (existing.placeId?.trim().isNotEmpty == true)
          existing.placeId!.trim(),
      ]);
      _setCafeDetailError(cafeId, 'Cafe not available.');
      return false;
    }
    if (existing != null && _hasEnoughDetailData(existing)) {
      _setCafeDetailError(cafeId, null);
      _ref.read(analyticsServiceProvider).trackCafeDetailOpened(cafeId);
      return true;
    }

    final repository = _ref.read(cafeRepositoryProvider);
    _setCafeDetailLoading(cafeId, true);
    _setCafeDetailError(cafeId, null);
    final cachedCafe = await repository.loadCachedCafeDetail(
      cafeId,
      fallback: state.cafes,
    );
    if (cachedCafe != null &&
        mounted &&
        _isCurrentCafeDetailRequest(cafeId, requestVersion)) {
      state = state.copyWith(cafes: _upsertCafeInState(cachedCafe));
    }

    try {
      final remoteCafe = await repository.fetchCafeDetails(
        cafeId,
        fallback: state.cafes,
        cancellationToken: cancellationToken,
      );
      if (!_isCurrentCafeDetailRequest(cafeId, requestVersion)) {
        return cachedCafe != null;
      }
      if (remoteCafe == null) {
        removeCafesByIdentity(<String>[
          cafeId,
          if (cachedCafe != null) cachedCafe.id,
          if (cachedCafe?.placeId?.trim().isNotEmpty == true)
            cachedCafe!.placeId!.trim(),
        ]);
        _setCafeDetailError(
          cafeId,
          'Cafe not available.',
        );
        return false;
      }

      if (mounted) {
        state = state.copyWith(cafes: _upsertCafeInState(remoteCafe));
      }
      _setCafeDetailError(cafeId, null);
      _ref.read(analyticsServiceProvider).trackCafeDetailOpened(cafeId);
      return true;
    } catch (error) {
      if (classifyServiceError(error) == ServiceErrorType.cancelled ||
          !_isCurrentCafeDetailRequest(cafeId, requestVersion)) {
        return cachedCafe != null;
      }
      _setCafeDetailError(cafeId, _toUserFacingCafeMessage(error));
      return cachedCafe != null;
    } finally {
      if (_isCurrentCafeDetailRequest(cafeId, requestVersion) && mounted) {
        _setCafeDetailLoading(cafeId, false);
      }
      if (_detailRequestVersions[cafeId] == requestVersion) {
        _detailRequestControllers.remove(cafeId);
      }
    }
  }

  void selectCafeForMap(String cafeId) {
    state = state.copyWith(
      selectedCafeId: () => cafeId,
      selectedCafeFocusVersion: state.selectedCafeFocusVersion + 1,
    );
  }

  void clearSelectedCafe() {
    if (state.selectedCafeId == null) {
      return;
    }

    state = state.copyWith(
      selectedCafeId: () => null,
      selectedCafeFocusVersion: state.selectedCafeFocusVersion + 1,
    );
  }

  Future<void> setFilters(Filters filters) async {
    // Legacy entry point: updates both global filters (for discovery)
    // and explore filters (for UI display).
    await setExploreFilters(filters);
  }

  Filters _sanitizeFilters(
    Filters filters, {
    Filters? previous,
  }) {
    final districts = _ref.read(activeDistrictsProvider);
    final cleanedDistricts = filters.effectiveDistricts
        .map(_cleanOptionalText)
        .whereType<String>()
        .map(
          (district) => canonicalDistrictName(
            district,
            districts: districts,
          ),
        )
        .whereType<String>()
        .toSet();
    final cleanedNeighborhood = _cleanOptionalText(filters.neighborhood);
    final cleanedSearchQuery = _cleanOptionalText(filters.searchQuery);
    final canonicalDistricts = Set<String>.unmodifiable(cleanedDistricts);
    final previousDistricts = previous == null
        ? const <String>{}
        : Set<String>.unmodifiable(
            previous.effectiveDistricts
                .map(_cleanOptionalText)
                .whereType<String>()
                .map(
                  (district) => canonicalDistrictName(
                    district,
                    districts: districts,
                  ),
                )
                .whereType<String>(),
          );
    final districtChanged =
        !_normalizedStringSetsEqual(canonicalDistricts, previousDistricts);

    return Filters(
      category: filters.category,
      district:
          canonicalDistricts.length == 1 ? canonicalDistricts.single : null,
      selectedDistricts: canonicalDistricts,
      neighborhood: districtChanged ? null : cleanedNeighborhood,
      minRating: filters.minRating,
      priceLevel: filters.priceLevel,
      wifiQuality: filters.wifiQuality,
      outletAvailability: filters.outletAvailability,
      quietnessLevel: filters.quietnessLevel,
      outdoorSeating: filters.outdoorSeating,
      petFriendly: filters.petFriendly,
      studyFriendly: filters.studyFriendly,
      openNow: filters.openNow,
      smokingPolicy: filters.smokingPolicy,
      searchQuery: cleanedSearchQuery,
    );
  }

  Filters _withDistrictSelection(
    Filters filters,
    Set<String> selectedDistricts,
  ) {
    return filters.copyWith(
      district: () =>
          selectedDistricts.length == 1 ? selectedDistricts.single : null,
      selectedDistricts: () => Set<String>.unmodifiable(selectedDistricts),
      neighborhood: () =>
          selectedDistricts.isEmpty ? filters.neighborhood : null,
    );
  }

  Filters _sanitizeStartupFilters(Filters filters) {
    final sanitized = _sanitizeFilters(filters);
    return sanitized.copyWith(
      district: () => null,
      selectedDistricts: () => const <String>{},
      neighborhood: () => null,
      searchQuery: () => null,
    );
  }

  String? _cleanOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  bool _filtersEqual(Filters left, Filters right) {
    return left.category == right.category &&
        _normalizedStringSetsEqual(
          left.effectiveDistricts,
          right.effectiveDistricts,
        ) &&
        normalizeSearchText(left.neighborhood ?? '') ==
            normalizeSearchText(right.neighborhood ?? '') &&
        left.minRating == right.minRating &&
        left.priceLevel == right.priceLevel &&
        left.wifiQuality == right.wifiQuality &&
        left.outletAvailability == right.outletAvailability &&
        left.quietnessLevel == right.quietnessLevel &&
        left.outdoorSeating == right.outdoorSeating &&
        left.petFriendly == right.petFriendly &&
        left.studyFriendly == right.studyFriendly &&
        left.openNow == right.openNow &&
        left.smokingPolicy == right.smokingPolicy &&
        normalizeSearchText(left.searchQuery ?? '') ==
            normalizeSearchText(right.searchQuery ?? '');
  }

  bool _normalizedStringSetsEqual(Set<String> left, Set<String> right) {
    final normalizedLeft = left.map(normalizeSearchText).toSet();
    final normalizedRight = right.map(normalizeSearchText).toSet();
    return setEquals(normalizedLeft, normalizedRight);
  }

  Future<void> resetFilters() {
    return resetExploreFilters();
  }

  void _trackFilterAnalytics(Filters previous, Filters next) {
    final analytics = _ref.read(analyticsServiceProvider);
    final previousSearch = previous.searchQuery?.trim() ?? '';
    final nextSearch = next.searchQuery?.trim() ?? '';
    if (previousSearch != nextSearch && nextSearch.isNotEmpty) {
      analytics.trackSearchPerformed(queryLength: nextSearch.length);
    }

    final previousCategories = _analyticsFilterCategories(previous);
    final nextCategories = _analyticsFilterCategories(next);
    for (final category in nextCategories) {
      if (!previousCategories.contains(category)) {
        analytics.trackFilterApplied(filterCategory: category);
      }
    }
  }

  Set<String> _analyticsFilterCategories(Filters filters) {
    return <String>{
      if (filters.category != null) 'category',
      if (filters.effectiveDistricts.isNotEmpty) 'district',
      if (filters.neighborhood?.trim().isNotEmpty == true) 'neighborhood',
      if (filters.minRating != null) 'min_rating',
      if (filters.priceLevel != null) 'price_level',
      if (filters.wifiQuality != null) 'wifi_quality',
      if (filters.outletAvailability != null) 'outlet_availability',
      if (filters.quietnessLevel != null) 'quietness_level',
      if (filters.outdoorSeating != null) 'outdoor_seating',
      if (filters.petFriendly != null) 'pet_friendly',
      if (filters.studyFriendly != null) 'study_friendly',
      if (filters.openNow != null) 'open_now',
      if (filters.smokingPolicy != null) 'smoking_policy',
    };
  }

  bool _hasEnoughDetailData(Cafe cafe) {
    return cafe.description.trim().isNotEmpty ||
        cafe.phoneNumber?.trim().isNotEmpty == true ||
        cafe.websiteUri?.trim().isNotEmpty == true ||
        cafe.hasWorkingHours ||
        cafe.photoUrls.isNotEmpty;
  }

  @override
  void dispose() {
    _activeCafeListRequest?.cancel('Cafe notifier disposed.');
    _activeHomeCafeListRequest?.cancel('Cafe notifier disposed.');
    _activeLoadMoreRequest?.cancel('Cafe notifier disposed.');
    for (final controller in _detailRequestControllers.values) {
      controller.cancel('Cafe notifier disposed.');
    }
    _detailRequestControllers.clear();
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }
}

final cafeProvider = StateNotifierProvider<CafeNotifier, CafeState>((ref) {
  return CafeNotifier(ref);
});

class _CafeLoadException implements Exception {
  const _CafeLoadException({
    required this.message,
    required this.errorType,
    this.remoteMessage,
  });

  factory _CafeLoadException.fromRepositoryResult(
    CafeRepositoryResult result, {
    required String fallbackMessage,
  }) {
    return _CafeLoadException(
      message: result.errorMessage ?? fallbackMessage,
      errorType: result.errorType,
      remoteMessage: result.errorMessage,
    );
  }

  final String message;
  final ServiceErrorType errorType;
  final String? remoteMessage;

  @override
  String toString() => message;
}
