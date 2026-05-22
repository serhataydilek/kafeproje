import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/constants/app_cache_config.dart';
import 'package:kafeproje/models/cafe_cache.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'test_helpers.dart';

void main() {
  group('cafe caching', () {
    test(
        'loadCafes shows cached cafes first and replaces them with remote data',
        () async {
      final cachedCafe = buildTestCafe(id: 'cafe-1', name: 'Cached Cafe');
      final remoteCafes = [
        buildTestCafe(id: 'cafe-2', name: 'Fresh Cafe'),
        buildTestCafe(id: 'cafe-3', name: 'Fresh Cafe Two'),
      ];
      final remoteCompleter = Completer<CafeRepositoryResult>();

      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onLoadCachedCafeList: (_) async => CafeListCacheSnapshot(
                cafes: [cachedCafe],
                lastUpdated: DateTime.utc(2026, 3, 18),
                cacheKey: 'test-cache',
              ),
              onFetch: (_) => remoteCompleter.future,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final loadFuture = container.read(cafeProvider.notifier).loadCafes();
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(cafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-1'],
      );
      expect(container.read(isCafesLoadingProvider), isFalse);
      expect(
        container.read(cafeSyncStateProvider),
        CafeSyncState.showingCachedWhileRefreshing,
      );

      remoteCompleter.complete(
        CafeRepositoryResult(
          cafes: remoteCafes,
          usedRemote: true,
        ),
      );
      await loadFuture;

      expect(
        container.read(cafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-2', 'cafe-3'],
      );
      expect(container.read(cafeSyncStateProvider), CafeSyncState.ready);
    });

    test('loadCafes keeps cached cafes when remote refresh fails', () async {
      final cachedCafe = buildTestCafe(id: 'cafe-1', name: 'Cached Cafe');

      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onLoadCachedCafeList: (_) async => CafeListCacheSnapshot(
                cafes: [cachedCafe],
                lastUpdated: DateTime.utc(2026, 3, 18),
                cacheKey: 'test-cache',
              ),
              onFetch: (_) async => throw Exception('network timeout'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).loadCafes();

      expect(
        container.read(cafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-1'],
      );
      expect(container.read(cafesErrorProvider), isNull);
      expect(
        container.read(cafeSyncStateProvider),
        CafeSyncState.errorWithCache,
      );
    });

    test('loadCafes treats empty remote success as a completed empty state',
        () async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onFetch: (_) async => const CafeRepositoryResult(
                cafes: <Cafe>[],
                usedRemote: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).loadCafes();

      expect(container.read(cafesProvider), isEmpty);
      expect(container.read(isCafesLoadingProvider), isFalse);
      expect(container.read(cafesErrorProvider), isNull);
      expect(container.read(cafeSyncStateProvider), CafeSyncState.empty);
    });

    test('loadCafes keeps warning notices out of the error state on success',
        () async {
      const warningMessage =
          'Location access is unavailable or denied. Showing cafes around Istanbul.';
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onFetch: (_) async => const CafeRepositoryResult(
                cafes: <Cafe>[],
                usedRemote: true,
                warningMessage: warningMessage,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).loadCafes();

      expect(container.read(cafesErrorProvider), isNull);
      expect(container.read(cafesNoticeProvider), isNotNull);
      expect(container.read(cafesNoticeProvider), warningMessage);
      expect(container.read(cafeSyncStateProvider), CafeSyncState.empty);
    });

    test('loadCafes upgrades weak seed fetch into a full background refresh',
        () async {
      final seedCafe = buildTestCafe(id: 'cafe-seed', name: 'Seed Cafe');
      final fullCafe = buildTestCafe(id: 'cafe-full', name: 'Full Cafe');
      final fullCompleter = Completer<CafeRepositoryResult>();

      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onFetch: (_) async => const CafeRepositoryResult(
                cafes: <Cafe>[],
                usedRemote: true,
              ),
              onFetchRequest: ({
                String? pageToken,
                double? lat,
                double? lng,
                String? district,
                int radius = 5000,
                bool seedOnly = false,
                String? discoveryCacheKey,
              }) {
                if (seedOnly) {
                  return Future.value(
                    CafeRepositoryResult(
                      cafes: [seedCafe],
                      usedRemote: true,
                    ),
                  );
                }
                return fullCompleter.future;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).loadCafes();

      expect(
        container.read(cafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-seed'],
      );
      expect(
        container.read(cafeSyncStateProvider),
        CafeSyncState.showingCachedWhileRefreshing,
      );

      fullCompleter.complete(
        CafeRepositoryResult(
          cafes: [fullCafe],
          usedRemote: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(cafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-full'],
      );
      expect(container.read(cafeSyncStateProvider), CafeSyncState.ready);
    });

    test('loadCafes skips full background refresh when seed results are strong',
        () async {
      final seedCafes = List<Cafe>.generate(
        RequestTuningConfig.seedAdequateCafeCount,
        (index) => buildTestCafe(
          id: 'seed-$index',
          name: 'Seed Cafe $index',
        ),
        growable: false,
      );
      var seedFetches = 0;
      var fullFetches = 0;

      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onFetch: (_) async => const CafeRepositoryResult(
                cafes: <Cafe>[],
                usedRemote: true,
              ),
              onFetchRequest: ({
                String? pageToken,
                double? lat,
                double? lng,
                String? district,
                int radius = 5000,
                bool seedOnly = false,
                String? discoveryCacheKey,
              }) async {
                if (seedOnly) {
                  seedFetches += 1;
                  return CafeRepositoryResult(
                      cafes: seedCafes, usedRemote: true);
                }

                fullFetches += 1;
                return const CafeRepositoryResult(
                  cafes: <Cafe>[],
                  usedRemote: true,
                );
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).loadCafes();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(seedFetches, 1);
      expect(fullFetches, 0);
      expect(container.read(cafesProvider), hasLength(seedCafes.length));
      expect(container.read(cafeSyncStateProvider), CafeSyncState.ready);
    });

    test(
        'large radius completes full discovery even when seed results are strong',
        () async {
      final seedCafes = List<Cafe>.generate(
        RequestTuningConfig.seedAdequateCafeCount,
        (index) => buildTestCafe(
          id: 'large-seed-$index',
          name: 'Large Seed Cafe $index',
        ),
        growable: false,
      );
      final fullCafe = buildTestCafe(
        id: 'large-full',
        name: 'Large Full Discovery Cafe',
      );
      var seedFetches = 0;
      var fullFetches = 0;

      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: testUser,
          mapRadiusPreset: MapRadiusPreset.large,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onFetch: (_) async => const CafeRepositoryResult(
                cafes: <Cafe>[],
                usedRemote: true,
              ),
              onFetchRequest: ({
                String? pageToken,
                double? lat,
                double? lng,
                String? district,
                int radius = 5000,
                bool seedOnly = false,
                String? discoveryCacheKey,
              }) async {
                if (seedOnly) {
                  seedFetches += 1;
                  return CafeRepositoryResult(
                      cafes: seedCafes, usedRemote: true);
                }

                fullFetches += 1;
                return CafeRepositoryResult(
                  cafes: [fullCafe, ...seedCafes],
                  usedRemote: true,
                );
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).loadCafes();
      await Future<void>.delayed(Duration.zero);

      expect(seedFetches, 1);
      expect(fullFetches, 1);
      expect(container.read(cafesProvider).first.id, 'large-full');
      expect(container.read(cafeSyncStateProvider), CafeSyncState.ready);
    });

    test('loadCafes treats missing cache timestamps as stale but usable',
        () async {
      final cachedCafe = buildTestCafe(id: 'cafe-legacy', name: 'Legacy Cafe');
      final connectivity = TestConnectivityService(initiallyOnline: true);
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onLoadCachedCafeList: (_) async => CafeListCacheSnapshot(
                cafes: [cachedCafe],
                cacheKey: 'legacy-cache',
              ),
              onFetch: (_) async => throw Exception('still offline'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(connectivity.dispose);

      await container.read(cafeProvider.notifier).loadCafes();

      expect(container.read(cafesProvider).single.id, 'cafe-legacy');
      expect(container.read(isServingStaleCafeCacheProvider), isTrue);
      expect(container.read(cafeCacheStatusProvider)?.kind,
          CafeCacheStatusKind.staleCached);
    });

    test(
        'cache status provider reports offline fallback when cached data is shown',
        () async {
      final connectivity = TestConnectivityService(initiallyOnline: false);
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Offline Cafe')],
          currentUser: testUser,
          cafesLastUpdated: DateTime.utc(2026, 3, 28, 9, 30),
          hasInitializedDiscovery: true,
        ),
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(connectivity.dispose);

      final status = container.read(cafeCacheStatusProvider);

      expect(status, isNotNull);
      expect(status!.kind, CafeCacheStatusKind.offlineFallback);
      expect(status.message, contains('Offline.'));
    });
  });
}
