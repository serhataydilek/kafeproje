part of 'app_core_providers.dart';

/// Reactive UI source of truth for the signed-in user's social graph snapshot.
class FriendsState {
  const FriendsState({
    this.relationships =
        const AsyncData<List<FriendRelationship>>(<FriendRelationship>[]),
    this.presence = const AsyncData<List<FriendLocationPresence>>(
        <FriendLocationPresence>[]),
  });

  final AsyncValue<List<FriendRelationship>> relationships;
  final AsyncValue<List<FriendLocationPresence>> presence;

  FriendsState copyWith({
    AsyncValue<List<FriendRelationship>>? relationships,
    AsyncValue<List<FriendLocationPresence>>? presence,
  }) {
    return FriendsState(
      relationships: relationships ?? this.relationships,
      presence: presence ?? this.presence,
    );
  }
}

/// Loads and owns friend relationship/presence UI state.
class FriendsNotifier extends StateNotifier<FriendsState> {
  FriendsNotifier(this._ref, {FriendsState initialState = const FriendsState()})
      : super(initialState);

  FriendsNotifier.test(this._ref,
      {FriendsState initialState = const FriendsState()})
      : super(initialState);

  final Ref _ref;
  int _requestVersion = 0;

  Future<void> handleSessionChanged() async {
    final currentUser = _ref.read(currentUserProvider);
    final requestVersion = ++_requestVersion;
    if (currentUser == null) {
      state = const FriendsState();
      return;
    }

    state = state.copyWith(
      relationships: const AsyncLoading<List<FriendRelationship>>(),
      presence: const AsyncLoading<List<FriendLocationPresence>>(),
    );

    try {
      final repository = _ref.read(friendRepositoryProvider);
      final results = await Future.wait<Object>([
        repository.fetchFriendRelationships(currentUser.id),
        repository.fetchFriendPresence(currentUser.id),
      ]);
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      state = state.copyWith(
        relationships: AsyncData(
          results[0] as List<FriendRelationship>,
        ),
        presence: AsyncData(
          results[1] as List<FriendLocationPresence>,
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      AppLogger.warn(
        'FriendsNotifier.handleSessionChanged failed',
        key: 'friends-load-failed',
      );
      state = state.copyWith(
        relationships: AsyncError<List<FriendRelationship>>(
          error,
          stackTrace,
        ),
        presence: AsyncError<List<FriendLocationPresence>>(
          error,
          stackTrace,
        ),
      );
    }
  }
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, FriendsState>((
  ref,
) {
  return FriendsNotifier(ref);
});
