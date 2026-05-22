part of 'app_core_providers.dart';

/// Reactive UI source of truth for offline queue counts and actions.
class OfflineSyncState {
  const OfflineSyncState({
    this.pendingCount = 0,
    this.deadLetterCount = 0,
  });

  final int pendingCount;
  final int deadLetterCount;

  OfflineSyncState copyWith({
    int? pendingCount,
    int? deadLetterCount,
  }) {
    return OfflineSyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      deadLetterCount: deadLetterCount ?? this.deadLetterCount,
    );
  }
}

/// Bridges queue service events into Riverpod state for widgets.
class OfflineSyncNotifier extends StateNotifier<OfflineSyncState> {
  OfflineSyncNotifier(this._ref,
      {OfflineSyncState initialState = const OfflineSyncState()})
      : super(initialState) {
    _bind();
  }

  OfflineSyncNotifier.test(this._ref,
      {OfflineSyncState initialState = const OfflineSyncState()})
      : super(initialState);

  final Ref _ref;
  OfflineQueueService? _service;
  VoidCallback? _pendingListener;
  VoidCallback? _deadLetterListener;

  void _bind() {
    final service = _ref.read(offlineQueueServiceProvider);
    _service = service;
    void syncCounts() {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        pendingCount: service.pendingCountListenable.value,
        deadLetterCount: service.deadLetterCountListenable.value,
      );
    }

    _pendingListener = syncCounts;
    _deadLetterListener = syncCounts;
    service.pendingCountListenable.addListener(syncCounts);
    service.deadLetterCountListenable.addListener(syncCounts);
    syncCounts();
  }

  Future<void> enqueueReviewSubmission(Map<String, dynamic> payload) {
    return _ref.read(offlineQueueServiceProvider).enqueueReviewSubmission(
          payload,
        );
  }

  Future<void> enqueueProfileUpdate(Map<String, dynamic> payload) {
    return _ref.read(offlineQueueServiceProvider).enqueueProfileUpdate(payload);
  }

  Future<bool> enqueueFavoriteToggle({
    required String userId,
    required String cafeId,
    required bool isAdding,
  }) {
    return _ref.read(offlineQueueServiceProvider).enqueueFavoriteToggle(
          userId: userId,
          cafeId: cafeId,
          isAdding: isAdding,
        );
  }

  Future<void> processQueue() {
    return _ref.read(offlineQueueServiceProvider).processQueue();
  }

  @override
  void dispose() {
    final service = _service;
    final pendingListener = _pendingListener;
    final deadLetterListener = _deadLetterListener;
    if (service != null && pendingListener != null) {
      service.pendingCountListenable.removeListener(pendingListener);
    }
    if (service != null && deadLetterListener != null) {
      service.deadLetterCountListenable.removeListener(deadLetterListener);
    }
    super.dispose();
  }
}

final offlineSyncProvider =
    StateNotifierProvider<OfflineSyncNotifier, OfflineSyncState>((ref) {
  return OfflineSyncNotifier(ref);
});
