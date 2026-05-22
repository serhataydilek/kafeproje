import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'package:kafeproje/screens/home_screen.dart';
import 'package:kafeproje/theme/app_theme.dart';
import 'package:kafeproje/widgets/cafes/cafe_card.dart';

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
  group('favorite ux flow', () {
    test(
        'favorite cafe stays resolvable outside current visible cafes without leaking into discovery',
        () async {
      final remoteFavorite = buildTestCafe(
        id: 'remote-favorite-1',
        name: 'Remote Favorite',
      );
      final nonFavoriteFar = buildTestCafe(
          id: 'remote-nonfavorite-2', name: 'Remote Non Favorite');
      final nearby = buildTestCafe(id: 'nearby-1', name: 'Nearby Cafe');

      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onGetCafesByIds: (_) async => [remoteFavorite, nonFavoriteFar],
      );

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [nearby],
          favorites: const ['remote-favorite-1'],
          currentLocation: nearby.coordinates,
          currentUser: testUser,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(resolvedFavoriteCafesProvider.future);

      expect(
        container
            .read(favoriteCafesProvider)
            .map((cafe) => cafe.id)
            .toList(growable: false),
        ['remote-favorite-1'],
      );
      expect(
        container
            .read(exploreCafeResultsProvider)
            .map((cafe) => cafe.id)
            .toList(growable: false),
        ['nearby-1'],
      );
      expect(
        container
            .read(mapCafeResultsProvider)
            .map((cafe) => cafe.id)
            .toList(growable: false),
        ['nearby-1'],
      );

      container
          .read(cafeProvider.notifier)
          .selectCafeForMap('remote-favorite-1');

      expect(
        container
            .read(mapCafeResultsProvider)
            .map((cafe) => cafe.id)
            .toList(growable: false),
        ['nearby-1', 'remote-favorite-1'],
      );
    });

    test(
        'favorite cafe remembered from the previous radius remains visible after radius refresh',
        () async {
      final favoriteFar = buildTestCafe(
        id: 'favorite-far',
        name: 'Favorite Far',
      ).copyWith(coordinates: const Coordinates(lat: 41.2, lng: 29.2));
      final nonFavoriteFar = buildTestCafe(
        id: 'nonfavorite-far',
        name: 'Non Favorite Far',
      ).copyWith(coordinates: const Coordinates(lat: 41.22, lng: 29.22));
      final nearby = buildTestCafe(
        id: 'nearby-1',
        name: 'Nearby Cafe',
      ).copyWith(coordinates: const Coordinates(lat: 41.0, lng: 29.0));
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
        }) async =>
            CafeRepositoryResult(cafes: [nearby], usedRemote: true),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [nearby, favoriteFar, nonFavoriteFar],
          favorites: const ['favorite-far'],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
          mapRadiusPreset: MapRadiusPreset.small,
          currentUser: testUser,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(resolvedFavoriteCafesProvider.future);
      await container
          .read(cafeProvider.notifier)
          .setMapRadiusPreset(MapRadiusPreset.medium);
      await container.read(resolvedFavoriteCafesProvider.future);

      expect(
        container.read(favoriteCafesProvider).map((cafe) => cafe.id),
        ['favorite-far'],
      );
      expect(
        container.read(exploreCafeResultsProvider).map((cafe) => cafe.id),
        ['nearby-1'],
      );
      expect(
        container.read(mapCafeResultsProvider).map((cafe) => cafe.id),
        ['nearby-1'],
      );
      expect(
        container.read(exploreCafeResultsProvider).map((cafe) => cafe.id),
        isNot(contains('nonfavorite-far')),
      );
    });

    test('optimistic toggle sets pending and patches count until sync settles',
        () async {
      final completer = Completer<bool>();
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Cafe One')],
          favorites: const [],
          currentUser: testUser,
        ),
        overrides: [
          favoritesSyncGatewayProvider.overrideWithValue(
            _FakeFavoritesSyncGateway(
              ({required userId, required cafeId, required isAdding}) {
                return completer.future;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final pendingFuture =
          container.read(profileProvider.notifier).toggleFavorite('cafe-1');

      expect(container.read(isCafeFavoritedProvider('cafe-1')), isTrue);
      expect(
          container.read(isFavoriteMutationPendingProvider('cafe-1')), isTrue);
      expect(
          container.read(hasFavoriteMutationErrorProvider('cafe-1')), isFalse);
      expect(container.read(cafesProvider).first.favoriteCount, 1);

      completer.complete(true);
      await pendingFuture;

      expect(container.read(isCafeFavoritedProvider('cafe-1')), isTrue);
      expect(
          container.read(isFavoriteMutationPendingProvider('cafe-1')), isFalse);
      expect(
          container.read(hasFavoriteMutationErrorProvider('cafe-1')), isFalse);
      expect(container.read(cafesProvider).first.favoriteCount, 1);
    });

    test('already-favorited cafes show a non-zero count immediately', () async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(id: 'cafe-1', name: 'Cafe One').copyWith(
              favoriteCount: 0,
            ),
          ],
          favorites: const ['cafe-1'],
          currentUser: testUser,
        ),
        overrides: [
          favoritesSyncGatewayProvider.overrideWithValue(
            _FakeFavoritesSyncGateway(
              ({required userId, required cafeId, required isAdding}) async {
                return true;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(isCafeFavoritedProvider('cafe-1')), isTrue);
      expect(container.read(cafesProvider).first.favoriteCount, 1);
      expect(container.read(cafeByIdProvider('cafe-1'))?.favoriteCount, 1);
      expect(container.read(favoriteCafesProvider).single.favoriteCount, 1);

      await container.read(profileProvider.notifier).toggleFavorite('cafe-1');

      expect(container.read(isCafeFavoritedProvider('cafe-1')), isFalse);
      expect(container.read(cafesProvider).first.favoriteCount, 0);

      await container.read(profileProvider.notifier).toggleFavorite('cafe-1');

      expect(container.read(isCafeFavoritedProvider('cafe-1')), isTrue);
      expect(container.read(cafesProvider).first.favoriteCount, 1);
    });

    test('repository-resolved favorite cafes use local favorite as count floor',
        () async {
      final remoteFavorite = buildTestCafe(
        id: 'remote-favorite-count',
        name: 'Remote Favorite Count',
      ).copyWith(favoriteCount: 0);
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onGetCafesByIds: (_) async => [remoteFavorite],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          favorites: const ['remote-favorite-count'],
          currentUser: testUser,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(resolvedFavoriteCafesProvider.future);

      expect(container.read(favoriteCafesProvider).single.favoriteCount, 1);
    });

    testWidgets(
        'sponsored cafe favorite count is visible on initial home render without tapping',
        (tester) async {
      final sponsor = buildTestCafe(
        id: 'sponsor-1',
        name: 'Sponsor One',
      ).copyWith(
        isFeatured: true,
        featuredPriority: 50,
        favoriteCount: 1,
        featuredUntil: () => DateTime.utc(2035, 1, 1),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          homeCafes: const [],
          featuredCafes: [sponsor],
          favorites: const [],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home-sponsored-sponsor-1')),
        findsOneWidget,
      );
      expect(find.text('Sponsored cafes'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
    });

    test('failed sync rolls back favorite and count and marks retry state',
        () async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Cafe One')],
          favorites: const [],
          currentUser: testUser,
        ),
        overrides: [
          favoritesSyncGatewayProvider.overrideWithValue(
            _FakeFavoritesSyncGateway(
              ({required userId, required cafeId, required isAdding}) async {
                return false;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(profileProvider.notifier).toggleFavorite('cafe-1');

      expect(container.read(isCafeFavoritedProvider('cafe-1')), isFalse);
      expect(
          container.read(isFavoriteMutationPendingProvider('cafe-1')), isFalse);
      expect(
          container.read(hasFavoriteMutationErrorProvider('cafe-1')), isTrue);
      expect(container.read(cafesProvider).first.favoriteCount, 0);
    });

    test('retry after failure succeeds and clears retry state', () async {
      var callCount = 0;
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Cafe One')],
          favorites: const [],
          currentUser: testUser,
        ),
        overrides: [
          favoritesSyncGatewayProvider.overrideWithValue(
            _FakeFavoritesSyncGateway(
              ({required userId, required cafeId, required isAdding}) async {
                callCount += 1;
                return callCount >= 2;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(profileProvider.notifier).toggleFavorite('cafe-1');
      expect(
          container.read(hasFavoriteMutationErrorProvider('cafe-1')), isTrue);
      expect(container.read(isCafeFavoritedProvider('cafe-1')), isFalse);
      expect(container.read(cafesProvider).first.favoriteCount, 0);

      await container.read(profileProvider.notifier).toggleFavorite('cafe-1');

      expect(container.read(isCafeFavoritedProvider('cafe-1')), isTrue);
      expect(
          container.read(isFavoriteMutationPendingProvider('cafe-1')), isFalse);
      expect(
          container.read(hasFavoriteMutationErrorProvider('cafe-1')), isFalse);
      expect(container.read(cafesProvider).first.favoriteCount, 1);
    });

    testWidgets('card favorite action shows pending indicator while syncing',
        (tester) async {
      final completer = Completer<bool>();
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Cafe One')],
          favorites: const [],
          currentUser: testUser,
        ),
        overrides: [
          favoritesSyncGatewayProvider.overrideWithValue(
            _FakeFavoritesSyncGateway(
              ({required userId, required cafeId, required isAdding}) {
                return completer.future;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: Scaffold(
            body: CafeCardListItem(
              cafe: buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
              onPress: () {},
              colors: lightColors,
              surface: 'test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cafe-card-favorite-cafe-1')));
      await tester.pump();

      expect(find.byKey(const Key('favorite-action-pending-indicator')),
          findsOneWidget);
      expect(
          container.read(isFavoriteMutationPendingProvider('cafe-1')), isTrue);

      completer.complete(true);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('favorite-action-pending-indicator')),
          findsNothing);
      expect(
          container.read(isFavoriteMutationPendingProvider('cafe-1')), isFalse);
      expect(container.read(isCafeFavoritedProvider('cafe-1')), isTrue);
    });
  });
}
