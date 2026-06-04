import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kafeproje/constants/error_codes.dart';
import 'package:kafeproje/models/offline_queue_entry.dart';
import 'package:kafeproje/models/review.dart';
import 'package:kafeproje/models/service_result.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/services/connectivity_service.dart';
import 'package:kafeproje/services/favorites_service.dart';
import 'package:kafeproje/services/local_storage_service.dart';
import 'package:kafeproje/services/offline_queue.dart';
import 'package:kafeproje/services/reviews_service.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/service_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_helpers.dart';

class _FakeFavoritesSyncGateway extends FavoritesSyncGateway {
  _FakeFavoritesSyncGateway(this._handler) : super(null);

  final Future<bool> Function({
    required String userId,
    required String cafeId,
    required bool isAdding,
  }) _handler;

  @override
  Future<bool> syncFavorite({
    required String userId,
    required String cafeId,
    required bool isAdding,
  }) {
    return _handler(userId: userId, cafeId: cafeId, isAdding: isAdding);
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    await Hive.close();
    tempDir = await Directory.systemTemp.createTemp(
      'kafeproje-offline-queue-test-',
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('OfflineQueueService', () {
    test('dedupes queued review submissions per user and cafe', () async {
      final storage = await _openStorage(tempDir);
      final connectivity = _FakeConnectivityService(initiallyOnline: false);
      final service = OfflineQueueService(
        storage: storage,
        connectivity: connectivity,
        reviewsService: null,
        profilesService: null,
      );

      await service.enqueueReviewSubmission({
        'cafeId': 'cafe-1',
        'userId': 'user-1',
        'rating': 3,
      });
      await service.enqueueReviewSubmission({
        'cafeId': 'cafe-1',
        'userId': 'user-1',
        'rating': 5,
      });

      final queue = await storage.loadOfflineQueue();
      expect(queue, hasLength(1));
      expect(queue.single.action, OfflineQueueAction.reviewSubmission);
      expect(queue.single.payload['rating'], 5);

      await service.dispose();
      await connectivity.dispose();
    });

    test('dedupes queued profile updates per user', () async {
      final storage = await _openStorage(tempDir);
      final connectivity = _FakeConnectivityService(initiallyOnline: false);
      final service = OfflineQueueService(
        storage: storage,
        connectivity: connectivity,
        reviewsService: null,
        profilesService: null,
      );

      await service.enqueueProfileUpdate({
        'userId': 'user-1',
        'username': 'first',
      });
      await service.enqueueProfileUpdate({
        'userId': 'user-1',
        'username': 'second',
      });

      final queue = await storage.loadOfflineQueue();
      expect(queue, hasLength(1));
      expect(queue.single.action, OfflineQueueAction.profileUpdate);
      expect(queue.single.payload['username'], 'second');

      await service.dispose();
      await connectivity.dispose();
    });

    test('dedupes queued favorite toggles and replays only latest action',
        () async {
      final storage = await _openStorage(tempDir);
      final connectivity = _FakeConnectivityService(initiallyOnline: false);
      final favoriteOps = <String>[];
      final favoritesService = _FakeFavoritesService(
        onAddFavorite: (userId, cafeId) async {
          favoriteOps.add('add:$userId:$cafeId');
          return true;
        },
        onRemoveFavorite: (userId, cafeId) async {
          favoriteOps.add('remove:$userId:$cafeId');
          return true;
        },
      );

      final service = OfflineQueueService(
        storage: storage,
        connectivity: connectivity,
        reviewsService: null,
        profilesService: null,
        favoritesService: favoritesService,
      );

      await service.enqueueFavoriteToggle(
        userId: 'user-1',
        cafeId: 'cafe-1',
        isAdding: true,
      );
      await service.enqueueFavoriteToggle(
        userId: 'user-1',
        cafeId: 'cafe-1',
        isAdding: false,
      );

      final queueBeforeReplay = await storage.loadOfflineQueue();
      expect(queueBeforeReplay, hasLength(1));
      expect(
          queueBeforeReplay.single.action, OfflineQueueAction.favoriteToggle);
      expect(queueBeforeReplay.single.payload['isAdding'], isFalse);

      connectivity.setOnline(true, notify: false);
      await service.processQueue();

      expect(await storage.loadOfflineQueue(), isEmpty);
      expect(await storage.loadOfflineDeadLetters(), isEmpty);
      expect(favoriteOps, ['remove:user-1:cafe-1']);

      await service.dispose();
      await connectivity.dispose();
    });

    test('drains legacy favorite queue entries without retrying remote sync',
        () async {
      final storage = await _openStorage(tempDir);
      await storage.saveOfflineQueue([
        OfflineQueueEntry(
          id: 'legacy-favorite',
          action: OfflineQueueAction.favoriteToggle,
          payload: const {
            'scope': 'user-1',
            'favorites': ['cafe-1'],
          },
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]);

      final connectivity = _FakeConnectivityService(initiallyOnline: true);
      final service = OfflineQueueService(
        storage: storage,
        connectivity: connectivity,
        reviewsService: null,
        profilesService: null,
      );

      await service.processQueue();

      expect(await storage.loadOfflineQueue(), isEmpty);
      expect(await storage.loadOfflineDeadLetters(), isEmpty);

      await service.dispose();
      await connectivity.dispose();
    });

    test('offline review replay bypasses submission cooldown', () async {
      final storage = await _openStorage(tempDir);
      await storage.saveOfflineQueue([
        OfflineQueueEntry(
          id: 'review-1',
          action: OfflineQueueAction.reviewSubmission,
          payload: const {
            'cafeId': 'cafe-1',
            'userId': 'user-1',
            'rating': 4,
          },
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        OfflineQueueEntry(
          id: 'review-2',
          action: OfflineQueueAction.reviewSubmission,
          payload: const {
            'cafeId': 'cafe-2',
            'userId': 'user-1',
            'rating': 5,
          },
          createdAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
        ),
      ]);

      final reviewsService = _FakeReviewsService(
        onSubmitReview: ({
          required String cafeId,
          String? userId,
          required int rating,
          int? wifiQuality,
          int? noiseLevel,
          int? studyFriendliness,
          int? seatingComfort,
          String? socketAvailability,
          String? smokingPolicy,
          String? content,
          bool bypassSubmissionCooldown = false,
        }) async {
          expect(bypassSubmissionCooldown, isTrue);
          return ServiceResult.success(
            data: ReviewMutationResult(
              review: CafeReview.fromSupabaseRow({
                'id': '$cafeId-review',
                'cafe_id': cafeId,
                'user_id': userId ?? 'user-1',
                'rating': rating,
                'content': content,
                'created_at': DateTime.now().toUtc().toIso8601String(),
              }),
              didUpdateExisting: false,
            ),
          );
        },
      );
      final connectivity = _FakeConnectivityService(initiallyOnline: true);
      final service = OfflineQueueService(
        storage: storage,
        connectivity: connectivity,
        reviewsService: reviewsService,
        profilesService: null,
      );

      await service.processQueue();

      expect(await storage.loadOfflineQueue(), isEmpty);
      expect(await storage.loadOfflineDeadLetters(), isEmpty);
      expect(reviewsService.submittedCafeIds, ['cafe-1', 'cafe-2']);

      await service.dispose();
      await connectivity.dispose();
    });

    test('failed offline profile update cleans up newly uploaded avatar',
        () async {
      final storage = await _openStorage(tempDir);
      await storage.saveOfflineQueue([
        OfflineQueueEntry(
          id: 'profile-1',
          action: OfflineQueueAction.profileUpdate,
          payload: const {
            'userId': 'user-1',
            'username': 'newname',
            'avatarBytes': [1, 2, 3],
            'avatarExtension': 'png',
            'previousAvatarUrl': 'profiles/user-1/old.png',
          },
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]);

      final profilesService = _FakeProfilesService(
        onUploadAvatar: ({
          required String userId,
          required List<int> bytes,
          required String fileExtension,
        }) async {
          return ServiceResult.success(
            data: const AvatarUploadResult(
              publicUrl: 'https://example.com/avatar.png',
              path: 'profiles/user-1/new.png',
            ),
          );
        },
        onUpdateProfile: (_, __) async => ServiceResult.failure(
          errorCode: AppErrorCode.networkError,
          errorType: ServiceErrorType.network,
        ),
      );
      final connectivity = _FakeConnectivityService(initiallyOnline: true);
      final service = OfflineQueueService(
        storage: storage,
        connectivity: connectivity,
        reviewsService: null,
        profilesService: profilesService,
      );

      await service.processQueue();

      expect(profilesService.deletedAvatarUrls, ['profiles/user-1/new.png']);
      expect(await storage.loadOfflineQueue(), hasLength(1));
      expect(await storage.loadOfflineDeadLetters(), isEmpty);

      await service.dispose();
      await connectivity.dispose();
    });
  });

  group('ProfileNotifier', () {
    test('offline favorite toggles stay local and do not enqueue sync work',
        () async {
      final storage = await _openStorage(tempDir);
      final connectivity = _FakeConnectivityService(initiallyOnline: false);
      final container = createTestContainer(
        state: buildTestAppShellState(),
        overrides: [
          localStorageServiceProvider.overrideWith((_) => storage),
          connectivityServiceProvider.overrideWith((_) => connectivity),
        ],
      );

      await container.read(profileProvider.notifier).toggleFavorite('cafe-1');

      expect(await storage.loadFavorites(testUser.id), ['cafe-1']);
      expect(await storage.loadOfflineQueue(), isEmpty);

      container.dispose();
      await connectivity.dispose();
    });

    test('failed favorite sync is queued and local favorite is kept', () async {
      final storage = await _openStorage(tempDir);
      final connectivity = _FakeConnectivityService(initiallyOnline: false);
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Cafe One')],
          favorites: const [],
          currentUser: testUser,
        ),
        overrides: [
          localStorageServiceProvider.overrideWith((_) => storage),
          connectivityServiceProvider.overrideWith((_) => connectivity),
          favoritesSyncGatewayProvider.overrideWithValue(
            _FakeFavoritesSyncGateway(
              ({required userId, required cafeId, required isAdding}) async {
                return false;
              },
            ),
          ),
        ],
      );

      await container.read(profileProvider.notifier).toggleFavorite('cafe-1');

      expect(container.read(isCafeFavoritedProvider('cafe-1')), isTrue);
      expect(
        container.read(isFavoriteMutationPendingProvider('cafe-1')),
        isFalse,
      );
      expect(
        container.read(hasFavoriteMutationErrorProvider('cafe-1')),
        isFalse,
      );
      expect(container.read(cafesProvider).first.favoriteCount, 1);

      final queue = await storage.loadOfflineQueue();
      expect(queue, hasLength(1));
      expect(queue.single.action, OfflineQueueAction.favoriteToggle);
      expect(queue.single.payload['userId'], testUser.id);
      expect(queue.single.payload['cafeId'], 'cafe-1');
      expect(queue.single.payload['isAdding'], isTrue);

      container.dispose();
      await connectivity.dispose();
    });
  });
}

Future<LocalStorageService> _openStorage(Directory tempDir) {
  return LocalStorageService.open(
    secureKeyStore: _FakeSecureKeyValueStore(),
    hiveInitializer: () async => Hive.init(tempDir.path),
  );
}

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService({required bool initiallyOnline})
      : _currentlyOnline = initiallyOnline;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _currentlyOnline;

  @override
  bool get currentlyOnline => _currentlyOnline;

  @override
  Stream<bool> get isOnline async* {
    yield _currentlyOnline;
    yield* _controller.stream;
  }

  @override
  Future<void> ensureStarted() async {}

  void setOnline(bool value, {bool notify = true}) {
    _currentlyOnline = value;
    if (notify && !_controller.isClosed) {
      _controller.add(value);
    }
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class _FakeReviewsService extends ReviewsService {
  _FakeReviewsService({
    required this.onSubmitReview,
  }) : super(SupabaseClient('https://example.com', 'test-anon-key'));

  final Future<ServiceResult<ReviewMutationResult>> Function({
    required String cafeId,
    String? userId,
    required int rating,
    int? wifiQuality,
    int? noiseLevel,
    int? studyFriendliness,
    int? seatingComfort,
    String? socketAvailability,
    String? smokingPolicy,
    String? content,
    bool bypassSubmissionCooldown,
  }) onSubmitReview;

  final List<String> submittedCafeIds = [];

  @override
  Future<ServiceResult<ReviewMutationResult>> submitReview({
    required String cafeId,
    String? userId,
    required int rating,
    int? wifiQuality,
    int? noiseLevel,
    int? studyFriendliness,
    int? seatingComfort,
    String? socketAvailability,
    String? smokingPolicy,
    String? content,
    bool bypassSubmissionCooldown = false,
  }) async {
    submittedCafeIds.add(cafeId);
    return onSubmitReview(
      cafeId: cafeId,
      userId: userId,
      rating: rating,
      wifiQuality: wifiQuality,
      noiseLevel: noiseLevel,
      studyFriendliness: studyFriendliness,
      seatingComfort: seatingComfort,
      socketAvailability: socketAvailability,
      smokingPolicy: smokingPolicy,
      content: content,
      bypassSubmissionCooldown: bypassSubmissionCooldown,
    );
  }
}

class _FakeProfilesService extends ProfilesService {
  _FakeProfilesService({
    this.onUploadAvatar,
    this.onUpdateProfile,
  }) : super(SupabaseClient('https://example.com', 'test-anon-key'));

  final Future<ServiceResult<AvatarUploadResult>> Function({
    required String userId,
    required List<int> bytes,
    required String fileExtension,
  })? onUploadAvatar;
  final Future<ServiceResult<void>> Function(
    String userId,
    Map<String, dynamic> fields,
  )? onUpdateProfile;

  final List<String?> deletedAvatarUrls = [];

  @override
  Future<ServiceResult<AvatarUploadResult>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final callback = onUploadAvatar;
    if (callback == null) {
      return ServiceResult.failure(
        errorCode: AppErrorCode.avatarUploadFailed,
        errorType: ServiceErrorType.unavailable,
      );
    }
    return callback(
      userId: userId,
      bytes: bytes,
      fileExtension: fileExtension,
    );
  }

  @override
  Future<ServiceResult<void>> updateProfile(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    final callback = onUpdateProfile;
    if (callback == null) {
      return ServiceResult.success();
    }
    return callback(userId, fields);
  }

  @override
  Future<void> deleteAvatarByPublicUrl(String? publicUrl) async {
    deletedAvatarUrls.add(publicUrl);
  }
}

class _FakeFavoritesService extends FavoritesService {
  _FakeFavoritesService({
    required this.onAddFavorite,
    required this.onRemoveFavorite,
  }) : super(SupabaseClient('https://example.com', 'test-anon-key'));

  final Future<bool> Function(String userId, String cafeId) onAddFavorite;
  final Future<bool> Function(String userId, String cafeId) onRemoveFavorite;

  @override
  Future<bool> addFavorite(String userId, String cafeId) {
    return onAddFavorite(userId, cafeId);
  }

  @override
  Future<bool> removeFavorite(String userId, String cafeId) {
    return onRemoveFavorite(userId, cafeId);
  }
}
