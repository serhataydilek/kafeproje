import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:kafeproje/constants/network_config.dart';
import 'package:kafeproje/models/cafe_cache.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/models/service_result.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'package:kafeproje/services/connectivity_service.dart';
import 'package:kafeproje/services/local_storage_service.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/service_error.dart';
import 'package:kafeproje/utils/istanbul_region.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_helpers.dart';

void main() {
  group('AppShellNotifier.preloadStartupState', () {
    test('does not eagerly fetch cafes during shell startup preload', () async {
      var fetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return const CafeRepositoryResult(cafes: [], usedRemote: true);
        },
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentUser: null,
        isAuthReady: true,
        hasInitializedDiscovery: false,
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appShellProvider.notifier).preloadStartupState();

      expect(fetchCount, 0);
      expect(
        container.read(cafeProvider).hasInitializedDiscovery,
        isFalse,
      );
    });

    test('hydrates cached cafes before first remote refresh', () async {
      final cachedCafes = [
        buildTestCafe(id: 'cafe-1', name: 'Minoa'),
        buildTestCafe(id: 'cafe-2', name: 'Walter'),
      ];
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onLoadCachedCafeList: (_) async => CafeListCacheSnapshot(
          cafes: cachedCafes,
          lastUpdated: DateTime.now().toUtc(),
          cacheKey: 'test-cache',
          nextPageToken: 'next-page',
        ),
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentUser: null,
        isAuthReady: true,
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appShellProvider.notifier).preloadStartupState();

      expect(container.read(cafesProvider), cachedCafes);
      expect(container.read(cafeSyncStateProvider), CafeSyncState.ready);
      expect(container.read(paginatedCafesProvider).nextPageToken, 'next-page');
      expect(container.read(hasMoreCafePagesProvider), isTrue);
    });

    test('keeps normal map startup radius at the 1 km product default',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('map_radius_test');
      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('app_state');
      final storage = LocalStorageService(box);
      await storage.saveCafeDiscoveryState(
        filters: Filters.empty,
        radiusMeters: MapRadiusPreset.large.radiusMeters,
      );
      addTearDown(() async {
        await Hive.close();
        await tempDir.delete(recursive: true);
      });

      String? loadedCacheKey;
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onLoadCachedCafeList: (cacheKey) async {
          loadedCacheKey = cacheKey;
          return null;
        },
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWith((_) => storage),
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(
            buildTestAppShellState(
              cafes: const [],
              currentUser: null,
              isAuthReady: true,
              hasInitializedDiscovery: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appShellProvider.notifier).preloadStartupState();

      expect(container.read(mapRadiusPresetProvider), MapRadiusPreset.small);
      expect(
        loadedCacheKey,
        contains('radius=${MapRadiusPreset.small.radiusMeters}'),
      );
    });

    test('marks stale cache as refreshing while showing cached data', () async {
      final cachedCafes = [
        buildTestCafe(id: 'cafe-3', name: 'Roma'),
      ];
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onLoadCachedCafeList: (_) async => CafeListCacheSnapshot(
          cafes: cachedCafes,
          lastUpdated: DateTime.now()
              .toUtc()
              .subtract(StartupConfig.cafeCacheFreshness)
              .subtract(const Duration(seconds: 1)),
          cacheKey: 'test-cache',
        ),
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentUser: null,
        isAuthReady: true,
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appShellProvider.notifier).preloadStartupState();

      expect(container.read(cafesProvider), cachedCafes);
      expect(
        container.read(cafeSyncStateProvider),
        CafeSyncState.showingCachedWhileRefreshing,
      );
    });

    test('hydrates cached cafes on offline startup and marks fallback status',
        () async {
      final connectivity = TestConnectivityService(initiallyOnline: false);
      var fetchCount = 0;
      final cachedCafes = [
        buildTestCafe(id: 'cafe-offline', name: 'Offline Cache Cafe'),
      ];
      final repository = FakeCafeRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return const CafeRepositoryResult(cafes: [], usedRemote: true);
        },
        onLoadCachedCafeList: (_) async => CafeListCacheSnapshot(
          cafes: cachedCafes,
          lastUpdated: DateTime.utc(2026, 3, 28, 9, 30),
          cacheKey: 'offline-startup-cache',
        ),
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentUser: null,
        isAuthReady: true,
      );

      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(connectivity.dispose);

      await container.read(appShellProvider.notifier).preloadStartupState();

      expect(fetchCount, 0);
      expect(container.read(cafesProvider), cachedCafes);
      expect(
        container.read(cafeCacheStatusProvider)?.kind,
        CafeCacheStatusKind.offlineFallback,
      );
      expect(
        container.read(cafeCacheStatusProvider)?.message,
        contains('Offline.'),
      );
    });
  });

  group('CafeNotifier.ensureVisibleCafeDataLoaded', () {
    test('loads cafes lazily on first screen demand', () async {
      final remoteCafes = [
        buildTestCafe(id: 'cafe-10', name: 'Lazy Cafe'),
      ];
      var fetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return CafeRepositoryResult(cafes: remoteCafes, usedRemote: true);
        },
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentUser: null,
        isAuthReady: true,
        hasInitializedDiscovery: false,
        filters: const Filters(district: 'Kadikoy'),
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).ensureVisibleCafeDataLoaded();

      expect(fetchCount, 2);
      expect(container.read(cafesProvider), remoteCafes);
      expect(
        container.read(cafeProvider).hasInitializedDiscovery,
        isTrue,
      );
    });

    test('refreshes stale cached cafes when a screen requests discovery',
        () async {
      final cachedCafes = [
        buildTestCafe(id: 'cafe-11', name: 'Cached Cafe'),
      ];
      final remoteCafes = [
        buildTestCafe(id: 'cafe-12', name: 'Refreshed Cafe'),
      ];
      var fetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return CafeRepositoryResult(cafes: remoteCafes, usedRemote: true);
        },
        onLoadCachedCafeList: (_) async => CafeListCacheSnapshot(
          cafes: cachedCafes,
          lastUpdated: DateTime.now()
              .toUtc()
              .subtract(StartupConfig.cafeCacheFreshness)
              .subtract(const Duration(seconds: 1)),
          cacheKey: 'test-cache',
        ),
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentUser: null,
        isAuthReady: true,
        hasInitializedDiscovery: false,
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appShellProvider.notifier).preloadStartupState();
      expect(container.read(cafesProvider), cachedCafes);
      expect(container.read(cafeSyncStateProvider),
          CafeSyncState.showingCachedWhileRefreshing);

      await container.read(cafeProvider.notifier).ensureVisibleCafeDataLoaded();

      expect(fetchCount, 1);
      expect(container.read(cafesProvider), remoteCafes);
      expect(container.read(cafeSyncStateProvider), CafeSyncState.ready);
    });

    test('refreshes stale cached cafes when connectivity returns', () async {
      final connectivity = _TestConnectivityService(initiallyOnline: false);
      final cachedCafes = [
        buildTestCafe(id: 'cafe-stale', name: 'Cached Cafe'),
      ];
      final remoteCafes = [
        buildTestCafe(id: 'cafe-fresh', name: 'Fresh Cafe'),
      ];
      var fetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return CafeRepositoryResult(cafes: remoteCafes, usedRemote: true);
        },
        onLoadCachedCafeList: (_) async => CafeListCacheSnapshot(
          cafes: cachedCafes,
          lastUpdated: DateTime.now()
              .toUtc()
              .subtract(StartupConfig.cafeCacheFreshness)
              .subtract(const Duration(seconds: 1)),
          cacheKey: 'test-cache',
        ),
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentUser: null,
        isAuthReady: true,
        hasInitializedDiscovery: false,
      );

      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
          cafeRepositoryProvider.overrideWithValue(repository),
          appShellProvider.overrideWith(
            (ref) => AppShellNotifier.test(ref, initialState: state),
          ),
          cafeProvider.overrideWith(
            (ref) => CafeNotifier(ref, initialState: state.cafeState),
          ),
          profileProvider.overrideWith(
            (ref) => ProfileNotifier.test(
              ref,
              initialState: state.profileState,
            ),
          ),
          friendsProvider.overrideWith(
            (ref) => FriendsNotifier.test(
              ref,
              initialState: state.friendsState,
            ),
          ),
          offlineSyncProvider.overrideWith(
            (ref) => OfflineSyncNotifier.test(
              ref,
              initialState: state.offlineSyncState,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(connectivity.dispose);

      await container.read(appShellProvider.notifier).preloadStartupState();
      expect(container.read(cafesProvider), cachedCafes);
      expect(container.read(isServingStaleCafeCacheProvider), isTrue);

      connectivity.emit(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(fetchCount, 1);
      expect(container.read(cafesProvider), remoteCafes);
      expect(container.read(isServingStaleCafeCacheProvider), isFalse);
    });
  });

  group('CafeNotifier discovery refresh behavior', () {
    test('expanding radius keeps current cafes visible while refreshing',
        () async {
      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Visible Cafe'),
      ];
      final completer = Completer<CafeRepositoryResult>();
      var fetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) {
          fetchCount += 1;
          return completer.future;
        },
      );
      final state = buildTestAppShellState(
        cafes: cafes,
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      final refreshFuture =
          container.read(cafeProvider.notifier).setMapRadiusPreset(
                MapRadiusPreset.large,
              );
      await Future<void>.delayed(Duration.zero);

      expect(fetchCount, 1);
      expect(container.read(cafesProvider), cafes);
      expect(
        container.read(cafeSyncStateProvider),
        CafeSyncState.showingCachedWhileRefreshing,
      );
      expect(container.read(isCafesLoadingProvider), isFalse);
      expect(container.read(isRadiusRefreshInFlightProvider), isTrue);

      completer.complete(
        CafeRepositoryResult(cafes: cafes, usedRemote: true),
      );
      await refreshFuture;
      expect(container.read(isRadiusRefreshInFlightProvider), isFalse);
    });

    test('shrinking radius updates nearby visibility without refetching',
        () async {
      final cafes = [
        buildTestCafe(
          id: 'cafe-1',
          name: 'Nearby Cafe',
        ).copyWith(
          coordinates: const Coordinates(lat: 41.0422, lng: 29.0067),
        ),
        buildTestCafe(
          id: 'cafe-2',
          name: 'Far Cafe',
        ).copyWith(
          coordinates: const Coordinates(lat: 41.0602, lng: 29.0067),
        ),
      ];
      var fetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) async {
          fetchCount += 1;
          return CafeRepositoryResult(cafes: cafes, usedRemote: true);
        },
      );
      final state = buildTestAppShellState(
        cafes: cafes,
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
        selectedCafeId: 'cafe-1',
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).setMapRadiusPreset(
            MapRadiusPreset.small,
          );

      expect(fetchCount, 0);
      expect(container.read(mapRadiusPresetProvider), MapRadiusPreset.small);
      expect(container.read(selectedCafeIdProvider), 'cafe-1');
      expect(container.read(isRadiusRefreshInFlightProvider), isFalse);
      expect(
        container
            .read(mapVisibleCafesProvider)
            .map((cafe) => cafe.id)
            .toList(growable: false),
        ['cafe-1'],
      );
    });

    test(
        'map visibility keeps selected favorite cafes outside the current radius',
        () async {
      final favoriteFarId = 'favorite-far-cafe-${List.filled(500, 'x').join()}';
      final plainFarId = 'plain-far-cafe-${List.filled(500, 'y').join()}';
      final cafes = [
        buildTestCafe(
          id: 'nearby-cafe',
          name: 'Nearby Cafe',
        ).copyWith(
          coordinates: istanbulCenterCoordinates,
        ),
        buildTestCafe(
          id: favoriteFarId,
          name: 'Favorite Far Cafe',
        ).copyWith(
          coordinates: const Coordinates(lat: 42.0, lng: 30.5),
        ),
        buildTestCafe(
          id: plainFarId,
          name: 'Plain Far Cafe',
        ).copyWith(
          coordinates: const Coordinates(lat: 42.0, lng: 30.6),
        ),
      ];
      final state = buildTestAppShellState(
        cafes: cafes,
        favorites: [favoriteFarId],
        currentLocation: istanbulCenterCoordinates,
      );

      final container = ProviderContainer(
        overrides: testStateOverrides(state),
      );
      addTearDown(container.dispose);

      expect(
        container
            .read(mapVisibleCafesProvider)
            .map((cafe) => cafe.id)
            .toList(growable: false),
        ['nearby-cafe'],
      );

      container.read(cafeProvider.notifier).selectCafeForMap(favoriteFarId);

      expect(
        container
            .read(mapVisibleCafesProvider)
            .map((cafe) => cafe.id)
            .toList(growable: false),
        ['nearby-cafe', favoriteFarId],
      );
    });

    test('district-scoped discovery does not refetch when only radius changes',
        () async {
      final cafes = [
        buildTestCafe(id: 'cafe-2', name: 'District Cafe', district: 'Sisli'),
      ];
      var fetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) async {
          fetchCount += 1;
          return CafeRepositoryResult(cafes: cafes, usedRemote: true);
        },
      );
      final state = buildTestAppShellState(
        cafes: cafes,
        currentLocation: const Coordinates(lat: 41.0586, lng: 28.9939),
        filters: const Filters(district: 'Sisli'),
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).setMapRadiusPreset(
            MapRadiusPreset.large,
          );

      expect(fetchCount, 0);
      expect(container.read(mapRadiusPresetProvider), MapRadiusPreset.small);
      expect(container.read(cafesProvider), cafes);
    });

    test('older discovery responses cannot overwrite newer filter results',
        () async {
      final connectivity = _TestConnectivityService(initiallyOnline: true);
      final firstRequest = Completer<CafeRepositoryResult>();
      final secondRequest = Completer<CafeRepositoryResult>();
      var requestCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) {
          requestCount += 1;
          return requestCount == 1 ? firstRequest.future : secondRequest.future;
        },
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
      );

      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(connectivity.dispose);

      final firstLoad = container.read(cafeProvider.notifier).loadCafes();
      await Future<void>.delayed(Duration.zero);

      final secondLoad = container.read(cafeProvider.notifier).setFilters(
            const Filters(district: 'Besiktas'),
          );
      await Future<void>.delayed(Duration.zero);

      secondRequest.complete(
        CafeRepositoryResult(
          cafes: [buildTestCafe(id: 'fresh', name: 'Fresh Cafe')],
          usedRemote: true,
        ),
      );
      await secondLoad;

      firstRequest.complete(
        CafeRepositoryResult(
          cafes: [buildTestCafe(id: 'stale', name: 'Stale Cafe')],
          usedRemote: true,
        ),
      );
      await firstLoad;

      expect(
        container.read(cafesProvider).map((cafe) => cafe.id).toList(),
        ['fresh'],
      );
    });
  });

  group('CafeNotifier filter sanitization', () {
    test('canonicalizes district filters and clears stale neighborhood state',
        () async {
      final connectivity = _TestConnectivityService(initiallyOnline: true);
      String? requestedDistrict;
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) async {
          requestedDistrict = district;
          return const CafeRepositoryResult(cafes: [], usedRemote: true);
        },
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
        filters: const Filters(
          district: 'Kadıköy',
          neighborhood: 'Moda',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(connectivity.dispose);

      await container.read(cafeProvider.notifier).setFilters(
            const Filters(
              district: 'Besiktas',
              neighborhood: 'Moda',
            ),
          );

      final nextFilters = container.read(cafeProvider).filters;
      expect(nextFilters.district, 'Beşiktaş');
      expect(nextFilters.neighborhood, isNull);
      expect(requestedDistrict, 'Beşiktaş');
    });
  });

  group('CafeNotifier detail loading', () {
    test('superseded detail responses do not overwrite the latest state',
        () async {
      final firstDetail = Completer<void>();
      var detailFetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchCafeDetails: (cafeId, fallback, cancellationToken) async {
          detailFetchCount += 1;
          if (detailFetchCount == 1) {
            await firstDetail.future;
            cancellationToken?.throwIfCancelled();
            return buildTestCafe(id: 'cafe-1', name: 'Slow Cafe');
          }
          return buildTestCafe(id: cafeId, name: 'Fast Cafe');
        },
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      final firstFuture =
          container.read(cafeProvider.notifier).ensureCafeLoaded('cafe-1');
      await Future<void>.delayed(Duration.zero);
      final secondFuture =
          container.read(cafeProvider.notifier).ensureCafeLoaded('cafe-1');

      await secondFuture;
      firstDetail.complete();
      await firstFuture;

      expect(
        container.read(cafeByIdProvider('cafe-1'))?.name,
        'Fast Cafe',
      );
    });

    test('cancelled detail requests clear loading without surfacing an error',
        () async {
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchCafeDetails: (cafeId, fallback, cancellationToken) async {
          cancellationToken?.throwIfCancelled();
          await Future<void>.delayed(const Duration(milliseconds: 1));
          cancellationToken?.throwIfCancelled();
          return buildTestCafe(id: cafeId, name: 'Should Not Land');
        },
      );
      final state = buildTestAppShellState(
        cafes: const [],
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      final future =
          container.read(cafeProvider.notifier).ensureCafeLoaded('cafe-1');
      container.read(cafeProvider.notifier).cancelCafeDetailLoad('cafe-1');
      await future;

      expect(container.read(isCafeDetailLoadingProvider('cafe-1')), isFalse);
      expect(container.read(cafeDetailErrorProvider('cafe-1')), isNull);
      expect(container.read(cafeByIdProvider('cafe-1')), isNull);
    });

    test(
        'existing skeletal cafes still refresh through detail loading before the route renders',
        () async {
      var detailFetchCount = 0;
      final initialCafe = buildTestCafe(
        id: 'cafe-1',
        name: 'Partial Cafe',
        images: const [],
      ).copyWith(
        description: '',
        openingHours: const [],
        phoneNumber: null,
        websiteUri: null,
      );
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchCafeDetails: (cafeId, fallback, cancellationToken) async {
          detailFetchCount += 1;
          return buildTestCafe(
            id: cafeId,
            name: 'Detailed Cafe',
            images: const ['https://example.com/photo.jpg'],
          ).copyWith(
            description: 'Freshly loaded detail',
            phoneNumber: '+90 555 000 00 00',
            websiteUri: 'https://example.com',
          );
        },
      );
      final state = buildTestAppShellState(
        cafes: [initialCafe],
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      final loaded = await container
          .read(cafeProvider.notifier)
          .ensureCafeLoaded('cafe-1');

      expect(loaded, isTrue);
      expect(detailFetchCount, 1);
      expect(container.read(cafeByIdProvider('cafe-1'))?.name, 'Detailed Cafe');
      expect(
        container.read(cafeByIdProvider('cafe-1'))?.description,
        'Freshly loaded detail',
      );
    });
  });

  group('Admin role resolution', () {
    test(
        'preserves resolved admin state for same-user transient profile failures',
        () {
      const previousUser = CurrentUser(
        id: 'admin-user',
        email: 'admin@example.com',
        name: 'Admin User',
        isAdmin: true,
      );
      const previousState = AppShellState(
        currentUser: previousUser,
        isAuthReady: true,
        isAdmin: true,
        isAdminRoleResolved: true,
      );

      final profileResult = ServiceResult<UserProfile?>.failure(
        message: 'Profile lookup timed out',
        errorType: ServiceErrorType.timeout,
      );

      final resolution = resolveAdminRoleState(
        previousState: previousState,
        userId: 'admin-user',
        profile: null,
        profileResult: profileResult,
        unresolvedMessage: 'Admin role unresolved.',
      );

      expect(resolution.isAdmin, isTrue);
      expect(resolution.isAdminRoleResolved, isTrue);
      expect(resolution.adminRoleStatusMessage, isNull);
    });

    test('does not preserve admin state for non-transient profile failures',
        () {
      const previousUser = CurrentUser(
        id: 'admin-user',
        email: 'admin@example.com',
        name: 'Admin User',
        isAdmin: true,
      );
      const previousState = AppShellState(
        currentUser: previousUser,
        isAuthReady: true,
        isAdmin: true,
        isAdminRoleResolved: true,
      );

      final profileResult = ServiceResult<UserProfile?>.failure(
        message: 'Permission denied',
        errorType: ServiceErrorType.auth,
      );

      final resolution = resolveAdminRoleState(
        previousState: previousState,
        userId: 'admin-user',
        profile: null,
        profileResult: profileResult,
        unresolvedMessage: 'Admin role unresolved.',
      );

      expect(resolution.isAdmin, isFalse);
      expect(resolution.isAdminRoleResolved, isFalse);
      expect(resolution.adminRoleStatusMessage, 'Admin role unresolved.');
    });

    test(
        'dedupes same-user startup hydration so admin and avatar cannot be overwritten',
        () async {
      const profile = UserProfile(
        id: 'admin-user',
        username: 'admin',
        firstName: 'Ada',
        lastName: 'Admin',
        fullName: 'Ada Admin',
        email: 'admin@example.com',
        role: ProfileRole.admin,
        createdAt: '2026-04-19T09:00:00.000Z',
        avatarUrl: 'https://example.com/avatar.png',
      );
      final profilesService = _CountingProfilesService(profile);
      final container = ProviderContainer(
        overrides: [
          profilesServiceProvider.overrideWithValue(profilesService),
          ...testStateOverrides(
            buildTestAppShellState(
              currentUser: null,
              isAuthReady: false,
              isAdmin: false,
              isAdminRoleResolved: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(appShellProvider.notifier);
      final user = _buildAuthUser(
        id: 'admin-user',
        email: 'admin@example.com',
      );

      await Future.wait([
        notifier.bootstrapAuthenticatedUserForTesting(
          user,
          source: 'current_session',
        ),
        notifier.bootstrapAuthenticatedUserForTesting(
          user,
          source: 'auth_stream:initialSession',
        ),
      ]);

      final shellState = container.read(appShellProvider);
      expect(profilesService.fetchCount, 1);
      expect(shellState.currentUser?.id, 'admin-user');
      expect(
          shellState.currentUser?.avatarUrl, 'https://example.com/avatar.png');
      expect(shellState.currentUser?.isAdmin, isTrue);
      expect(shellState.isAdmin, isTrue);
      expect(shellState.isAdminRoleResolved, isTrue);
      expect(shellState.adminRoleStatusMessage, isNull);
    });
  });

  group('Home and map corpus isolation', () {
    test('home featured content stays stable when map discovery updates cafes',
        () async {
      final homeCafes = [
        buildTestCafe(id: 'home-1', name: 'Home One', rating: 4.8),
        buildTestCafe(id: 'home-2', name: 'Home Two', rating: 4.6),
      ];
      final mapCafes = [
        buildTestCafe(id: 'map-1', name: 'Map Only', district: 'Sisli'),
      ];

      final repository = FakeCafeRepository(
        onFetch: (_) async => const CafeRepositoryResult(
          cafes: <Cafe>[],
          usedRemote: false,
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
          return CafeRepositoryResult(cafes: mapCafes, usedRemote: true);
        },
      );
      final state = buildTestAppShellState(
        cafes: homeCafes,
        homeCafes: homeCafes,
        featuredCafes: [
          homeCafes.first.copyWith(isFeatured: true),
        ],
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(featuredCafesProvider).map((cafe) => cafe.id),
        contains('home-1'),
      );

      await container.read(cafeProvider.notifier).setMapFilters(
            const Filters(district: 'Sisli'),
          );

      expect(
        container.read(cafesProvider).map((cafe) => cafe.id),
        contains('map-1'),
      );
      final homeFeaturedIds =
          container.read(featuredCafesProvider).map((cafe) => cafe.id).toList();
      expect(homeFeaturedIds, contains('home-1'));
      expect(homeFeaturedIds, isNot(contains('map-1')));
    });

    test('home sponsored source remains stable across map discovery refreshes',
        () async {
      final sponsoredHomeCafe = buildTestCafe(
        id: 'sponsored-home',
        name: 'Sponsored Home',
      ).copyWith(
        isFeatured: true,
        featuredPriority: 10,
      );
      final repository = FakeCafeRepository(
        onFetch: (_) async => const CafeRepositoryResult(
          cafes: <Cafe>[],
          usedRemote: false,
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
          return CafeRepositoryResult(
            cafes: [buildTestCafe(id: 'map-2', name: 'Map Two')],
            usedRemote: true,
          );
        },
      );
      final state = buildTestAppShellState(
        cafes: [buildTestCafe(id: 'home-base', name: 'Home Base')],
        homeCafes: [buildTestCafe(id: 'home-base', name: 'Home Base')],
        featuredCafes: [sponsoredHomeCafe],
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
        contains('sponsored-home'),
      );

      await container.read(cafeProvider.notifier).setMapFilters(
            const Filters(district: 'Sisli'),
          );

      expect(
        container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
        contains('sponsored-home'),
      );
    });

    test('home sponsored source retries after transient featured fetch failure',
        () async {
      var featuredFetchAttempts = 0;
      final sponsoredHomeCafe = buildTestCafe(
        id: 'sponsored-home',
        name: 'Sponsored Home',
      ).copyWith(
        isFeatured: true,
        featuredPriority: 10,
      );
      final repository = FakeCafeRepository(
        onFetch: (_) async => CafeRepositoryResult(
          cafes: [buildTestCafe(id: 'home-base', name: 'Home Base')],
          usedRemote: true,
        ),
        onFetchFeaturedCafes: () async {
          featuredFetchAttempts += 1;
          if (featuredFetchAttempts == 1) {
            throw Exception('temporary featured fetch failure');
          }
          return [sponsoredHomeCafe];
        },
      );
      final state = buildTestAppShellState(
        cafes: [buildTestCafe(id: 'home-base', name: 'Home Base')],
        homeCafes: [buildTestCafe(id: 'home-base', name: 'Home Base')],
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).ensureHomeCafeDataLoaded();
      expect(featuredFetchAttempts, greaterThanOrEqualTo(2));
      expect(container.read(cafeProvider).hasLoadedFeaturedCafes, isTrue);
      expect(
        container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
        ['sponsored-home'],
      );
    });

    test('home keeps last good cafes visible during background refresh',
        () async {
      final initialHomeCafes = [
        buildTestCafe(id: 'home-old', name: 'Home Old'),
      ];
      final refreshCompleter = Completer<CafeRepositoryResult>();
      final repository = FakeCafeRepository(
        onFetch: (_) async => const CafeRepositoryResult(
          cafes: <Cafe>[],
          usedRemote: false,
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
          return refreshCompleter.future;
        },
      );
      final state = buildTestAppShellState(
        cafes: [buildTestCafe(id: 'map-cafe', name: 'Map Cafe')],
        homeCafes: initialHomeCafes,
        currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
      );

      final container = ProviderContainer(
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
          ...testStateOverrides(state),
        ],
      );
      addTearDown(container.dispose);

      final refreshFuture = container
          .read(cafeProvider.notifier)
          .ensureHomeCafeDataLoaded(forceRemote: true);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(homeCafesProvider).map((cafe) => cafe.id),
        ['home-old'],
      );
      expect(container.read(isHomeCafesLoadingProvider), isFalse);

      refreshCompleter.complete(
        CafeRepositoryResult(
          cafes: [buildTestCafe(id: 'home-new', name: 'Home New')],
          usedRemote: true,
        ),
      );
      await refreshFuture;

      expect(
        container.read(homeCafesProvider).map((cafe) => cafe.id),
        ['home-new'],
      );
      expect(container.read(isHomeCafesLoadingProvider), isFalse);
    });
  });
}

class _TestConnectivityService extends ConnectivityService {
  _TestConnectivityService({required bool initiallyOnline})
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

  void emit(bool isOnline) {
    _currentlyOnline = isOnline;
    _controller.add(isOnline);
  }

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _CountingProfilesService extends ProfilesService {
  _CountingProfilesService(this.profile)
      : super(
          SupabaseClient(
            'https://example.com',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final UserProfile profile;
  int fetchCount = 0;

  @override
  Future<ServiceResult<UserProfile?>> fetchProfileById(String userId) async {
    fetchCount += 1;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (userId != profile.id) {
      return ServiceResult.failure(
        message: 'Profile not found.',
        errorType: ServiceErrorType.notFound,
      );
    }
    return ServiceResult.success(data: profile);
  }
}

User _buildAuthUser({
  required String id,
  required String email,
  Map<String, dynamic> userMetadata = const <String, dynamic>{},
}) {
  return User.fromJson({
    'id': id,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': email,
    'app_metadata': const <String, dynamic>{},
    'user_metadata': userMetadata,
    'created_at': '2026-04-19T09:00:00.000Z',
  })!;
}
