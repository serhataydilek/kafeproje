import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';

import 'test_helpers.dart';

void main() {
  group('filter context isolation', () {
    test('map district filters sync to explore without mutating saved pools',
        () async {
      final connectivity = TestConnectivityService(initiallyOnline: true);
      final cafes = [
        buildTestCafe(
          id: 'cafe-kadikoy',
          name: 'Moda Cafe',
          district: 'Kadikoy',
        ),
        buildTestCafe(
          id: 'cafe-besiktas',
          name: 'Ortakoy Cafe',
          district: 'Besiktas',
        ),
        buildTestCafe(
          id: 'cafe-sisli',
          name: 'Bomonti Cafe',
          district: 'Sisli',
        ),
      ];

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          favorites: const ['cafe-kadikoy', 'cafe-sisli'],
          compareList: const ['cafe-besiktas', 'cafe-sisli'],
          exploreFilters: const Filters(district: 'Kadikoy'),
          currentUser: testUser,
          hasInitializedDiscovery: true,
        ),
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onFetch: (_) async =>
                  CafeRepositoryResult(cafes: cafes, usedRemote: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(connectivity.dispose);

      expect(
        container.read(favoriteCafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-kadikoy', 'cafe-sisli'],
      );
      expect(
        container.read(comparedCafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-besiktas', 'cafe-sisli'],
      );
      expect(
        container
            .read(exploreCafeResultsProvider)
            .map((cafe) => cafe.id)
            .toList(),
        ['cafe-kadikoy'],
      );

      await container
          .read(cafeProvider.notifier)
          .setMapFilters(const Filters(district: 'Besiktas'));

      expect(
        container.read(mapCafeResultsProvider).map((cafe) => cafe.id).toList(),
        ['cafe-besiktas'],
      );
      expect(
        container
            .read(exploreFiltersProvider)
            .effectiveDistricts
            .toList(growable: false),
        ['Beşiktaş'],
      );
      expect(
        container
            .read(exploreCafeResultsProvider)
            .map((cafe) => cafe.id)
            .toList(),
        ['cafe-besiktas'],
      );
      expect(
        container.read(favoriteCafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-kadikoy', 'cafe-sisli'],
      );
      expect(
        container.read(comparedCafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-besiktas', 'cafe-sisli'],
      );
    });
  });
}
