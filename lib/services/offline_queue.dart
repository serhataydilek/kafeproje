import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../constants/error_codes.dart';
import '../services/favorites_service.dart';
import '../models/offline_queue_entry.dart';
import '../models/service_result.dart';
import '../services/connectivity_service.dart';
import '../services/local_storage_service.dart';
import '../services/reviews_service.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';
import '../utils/service_error.dart';

/// Offline retry queue for remote mutations only.
///
/// Responsibilities:
/// - persist write operations that could not reach the backend
/// - retry them when connectivity returns
/// - keep pending/dead-letter counts reactive for the UI
///
/// Non-responsibilities:
/// - read/fetch fallback
/// - cafe/profile cache hydration
/// - general offline browsing state
class OfflineQueueService {
  OfflineQueueService({
    required LocalStorageService? storage,
    required ConnectivityService connectivity,
    required ReviewsService? reviewsService,
    required ProfilesService? profilesService,
    FavoritesService? favoritesService,
  })  : _storage = storage,
        _connectivity = connectivity,
        _reviewsService = reviewsService,
        _profilesService = profilesService,
        _favoritesService = favoritesService {
    _init();
  }

  static const int maxRetryCount = 3;

  final LocalStorageService? _storage;
  final ConnectivityService _connectivity;
  final ReviewsService? _reviewsService;
  final ProfilesService? _profilesService;
  final FavoritesService? _favoritesService;
  final ValueNotifier<int> _pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<int> _deadLetterCount = ValueNotifier<int>(0);
  final StreamController<String> _notifications =
      StreamController<String>.broadcast();
  final Uuid _uuid = const Uuid();
  StreamSubscription<bool>? _connectivitySub;
  bool _isProcessing = false;

  ValueListenable<int> get pendingCountListenable => _pendingCount;
  ValueListenable<int> get deadLetterCountListenable => _deadLetterCount;
  Stream<String> get notifications => _notifications.stream;

  Future<void> _init() async {
    await _refreshCounts();
    _connectivitySub = _connectivity.isOnline.listen((isOnline) {
      if (isOnline) {
        unawaited(processQueue());
      }
    });
    if (_connectivity.currentlyOnline) {
      unawaited(processQueue());
    }
  }

  Future<void> enqueueReviewSubmission(Map<String, dynamic> payload) async {
    await _enqueue(
      OfflineQueueEntry(
        id: _uuid.v4(),
        action: OfflineQueueAction.reviewSubmission,
        payload: payload,
        createdAt: DateTime.now().toUtc(),
      ),
      dedupeKey: _reviewSubmissionKey(payload),
    );
  }

  Future<void> enqueueProfileUpdate(Map<String, dynamic> payload) async {
    await _enqueue(
      OfflineQueueEntry(
        id: _uuid.v4(),
        action: OfflineQueueAction.profileUpdate,
        payload: payload,
        createdAt: DateTime.now().toUtc(),
      ),
      dedupeKey: _profileUpdateKey(payload),
    );
  }

  Future<bool> enqueueFavoriteToggle({
    required String userId,
    required String cafeId,
    required bool isAdding,
  }) {
    return _enqueue(
      OfflineQueueEntry(
        id: _uuid.v4(),
        action: OfflineQueueAction.favoriteToggle,
        payload: {
          'userId': userId,
          'cafeId': cafeId,
          'isAdding': isAdding,
        },
        createdAt: DateTime.now().toUtc(),
      ),
      dedupeKey: _favoriteToggleKey({
        'userId': userId,
        'cafeId': cafeId,
      }),
    );
  }

  Future<bool> _enqueue(
    OfflineQueueEntry entry, {
    String? dedupeKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      return false;
    }

    try {
      final queue = await storage.loadOfflineQueue();
      if (dedupeKey != null) {
        queue.removeWhere((queued) => _dedupeKeyFor(queued) == dedupeKey);
      }
      queue.add(entry);
      await storage.saveOfflineQueue(queue);
      await _refreshCounts();
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Offline queue enqueue failed for ${entry.action.name}',
        error: error,
        stackTrace: stackTrace,
        key: 'offline-queue-enqueue-${entry.action.name}-${entry.id}',
      );
      return false;
    }
  }

  Future<void> processQueue() async {
    if (_isProcessing || !_connectivity.currentlyOnline) {
      return;
    }

    final storage = _storage;
    if (storage == null) {
      return;
    }

    _isProcessing = true;
    try {
      final queue = await storage.loadOfflineQueue();
      if (queue.isEmpty) {
        await _refreshCounts();
        return;
      }

      queue.sort((left, right) => left.createdAt.compareTo(right.createdAt));
      final deadLetters = await storage.loadOfflineDeadLetters();
      final remaining = <OfflineQueueEntry>[];

      for (final entry in queue) {
        final outcome = await _processEntry(entry);
        switch (outcome) {
          case _OfflineProcessOutcome.success:
            break;
          case _OfflineProcessOutcome.retryableFailure:
            final updated = entry.copyWith(
              retryCount: entry.retryCount + 1,
              lastError: () => 'retryable_failure',
            );
            if (updated.retryCount >= maxRetryCount) {
              deadLetters.add(updated);
              _notifications.add('offline_queue_dead_letter');
            } else {
              remaining.add(updated);
            }
            break;
          case _OfflineProcessOutcome.permanentFailure:
            deadLetters.add(
              entry.copyWith(lastError: () => 'permanent_failure'),
            );
            _notifications.add('offline_queue_dead_letter');
            break;
        }
      }

      await storage.saveOfflineQueue(remaining);
      await storage.saveOfflineDeadLetters(deadLetters);
      await _refreshCounts();
    } finally {
      _isProcessing = false;
    }
  }

  Future<_OfflineProcessOutcome> _processEntry(OfflineQueueEntry entry) async {
    try {
      switch (entry.action) {
        case OfflineQueueAction.favoriteToggle:
          final payload = entry.payload;
          final userId = (payload['userId'] as String?)?.trim();
          final cafeId = (payload['cafeId'] as String?)?.trim();

          // Legacy payloads from old local-only queue behavior are safe to
          // drop once seen so upgraded installs do not carry phantom work.
          if (userId == null ||
              userId.isEmpty ||
              cafeId == null ||
              cafeId.isEmpty) {
            return _OfflineProcessOutcome.success;
          }

          final isAdding = payload['isAdding'];
          if (isAdding is! bool) {
            return _OfflineProcessOutcome.permanentFailure;
          }

          final service = _favoritesService;
          if (service == null) {
            return _OfflineProcessOutcome.retryableFailure;
          }

          final ok = isAdding
              ? await service.addFavorite(userId, cafeId)
              : await service.removeFavorite(userId, cafeId);
          return ok
              ? _OfflineProcessOutcome.success
              : _OfflineProcessOutcome.retryableFailure;
        case OfflineQueueAction.reviewSubmission:
          final service = _reviewsService;
          if (service == null) {
            return _OfflineProcessOutcome.retryableFailure;
          }
          final payload = entry.payload;
          final result = await service.submitReview(
            cafeId: payload['cafeId'] as String? ?? '',
            userId: payload['userId'] as String?,
            rating: (payload['rating'] as num?)?.toInt() ?? 0,
            wifiQuality: (payload['wifiQuality'] as num?)?.toInt(),
            noiseLevel: (payload['noiseLevel'] as num?)?.toInt(),
            studyFriendliness: (payload['studyFriendliness'] as num?)?.toInt(),
            seatingComfort: (payload['seatingComfort'] as num?)?.toInt(),
            socketAvailability: payload['socketAvailability'] as String?,
            smokingPolicy: payload['smokingPolicy'] as String?,
            content: payload['content'] as String?,
            bypassSubmissionCooldown: true,
          );
          return _resultToOutcome(result);
        case OfflineQueueAction.profileUpdate:
          final service = _profilesService;
          if (service == null) {
            return _OfflineProcessOutcome.retryableFailure;
          }
          final payload = Map<String, dynamic>.from(entry.payload);
          final userId = payload.remove('userId') as String? ?? '';
          final avatarBytes = (payload.remove('avatarBytes') as List?)
              ?.whereType<int>()
              .toList(growable: false);
          final avatarExtension = payload.remove('avatarExtension') as String?;
          final removeAvatar = payload.remove('removeAvatar') as bool? ?? false;
          final previousAvatarUrl =
              payload.remove('previousAvatarUrl') as String?;

          String? nextAvatarStoredValue =
              removeAvatar ? null : previousAvatarUrl;
          String? uploadedAvatarPath;
          if (avatarBytes != null &&
              avatarBytes.isNotEmpty &&
              avatarExtension != null &&
              avatarExtension.isNotEmpty) {
            final upload = await service.uploadAvatar(
              userId: userId,
              bytes: Uint8List.fromList(avatarBytes),
              fileExtension: avatarExtension,
            );
            if (!upload.ok || upload.data == null) {
              return _resultToOutcome(upload);
            }
            nextAvatarStoredValue = upload.data!.path;
            uploadedAvatarPath = upload.data!.path;
          }

          payload['avatar_url'] = nextAvatarStoredValue;
          final update = await service.updateProfile(userId, payload);
          if (!update.ok && uploadedAvatarPath != null) {
            await service.deleteAvatarByPublicUrl(uploadedAvatarPath);
          }
          if (update.ok &&
              previousAvatarUrl != null &&
              previousAvatarUrl != nextAvatarStoredValue) {
            await service.deleteAvatarByPublicUrl(previousAvatarUrl);
          }
          return _resultToOutcome(update);
      }
    } catch (error) {
      AppLogger.error(
        'Offline queue entry processing failed for ${entry.action.name}',
        error: error,
        key: 'offline-queue-process-${entry.action.name}-${entry.id}',
      );
      return _OfflineProcessOutcome.retryableFailure;
    }
  }

  _OfflineProcessOutcome _resultToOutcome(ServiceResult<dynamic> result) {
    if (result.ok) {
      return _OfflineProcessOutcome.success;
    }
    if (result.errorCode == AppErrorCode.reviewSubmissionRateLimited) {
      return _OfflineProcessOutcome.retryableFailure;
    }
    if (result.errorType.isTransient) {
      return _OfflineProcessOutcome.retryableFailure;
    }
    return _OfflineProcessOutcome.permanentFailure;
  }

  Future<void> _refreshCounts() async {
    final storage = _storage;
    if (storage == null) {
      _pendingCount.value = 0;
      _deadLetterCount.value = 0;
      return;
    }
    _pendingCount.value = (await storage.loadOfflineQueue()).length;
    _deadLetterCount.value = (await storage.loadOfflineDeadLetters()).length;
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _notifications.close();
    _pendingCount.dispose();
    _deadLetterCount.dispose();
  }

  String? _dedupeKeyFor(OfflineQueueEntry entry) {
    switch (entry.action) {
      case OfflineQueueAction.favoriteToggle:
        final key = _favoriteToggleKey(entry.payload);
        if (key != null) {
          return key;
        }

        // Backward compatibility for legacy queued payload shape.
        final scope = (entry.payload['scope'] as String?)?.trim();
        if (scope == null || scope.isEmpty) {
          return null;
        }
        return 'favoriteToggle:$scope';
      case OfflineQueueAction.reviewSubmission:
        return _reviewSubmissionKey(entry.payload);
      case OfflineQueueAction.profileUpdate:
        return _profileUpdateKey(entry.payload);
    }
  }

  String? _favoriteToggleKey(Map<String, dynamic> payload) {
    final userId = (payload['userId'] as String?)?.trim();
    final cafeId = (payload['cafeId'] as String?)?.trim();
    if (userId == null ||
        userId.isEmpty ||
        cafeId == null ||
        cafeId.isEmpty) {
      return null;
    }
    return 'favoriteToggle:$userId:$cafeId';
  }

  String? _reviewSubmissionKey(Map<String, dynamic> payload) {
    final cafeId = (payload['cafeId'] as String?)?.trim();
    final userId = (payload['userId'] as String?)?.trim();
    if (cafeId == null || cafeId.isEmpty || userId == null || userId.isEmpty) {
      return null;
    }
    return 'reviewSubmission:$userId:$cafeId';
  }

  String? _profileUpdateKey(Map<String, dynamic> payload) {
    final userId = (payload['userId'] as String?)?.trim();
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return 'profileUpdate:$userId';
  }
}

enum _OfflineProcessOutcome {
  success,
  retryableFailure,
  permanentFailure,
}
