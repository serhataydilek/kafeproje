import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/l10n/app_localizations.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'package:kafeproje/screens/compare_screen.dart';
import 'package:kafeproje/screens/explore_screen.dart';
import 'package:kafeproje/screens/favorites_screen.dart';
import 'package:kafeproje/screens/home_screen.dart';
import 'package:kafeproje/screens/map_screen.dart';
import 'test_helpers.dart';

void main() {
  group('empty cafes behavior', () {
    test('loadCafes succeeds with an empty list and clears loading state',
        () async {
      final connectivity = TestConnectivityService(initiallyOnline: true);
      final container = createTestContainer(
        state: buildTestAppShellState(cafes: const [], currentUser: testUser),
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
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
      addTearDown(connectivity.dispose);

      await container.read(cafeProvider.notifier).loadCafes();

      expect(container.read(cafesProvider), isEmpty);
      expect(container.read(isCafesLoadingProvider), isFalse);
      expect(container.read(cafesErrorProvider), isNull);
      expect(container.read(featuredCafesProvider), isEmpty);
      expect(container.read(filteredCafesProvider), isEmpty);
      expect(container.read(browseDistrictsProvider), isNotNull);
    });

    testWidgets('home screen shows localized empty state with zero cafes',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(cafes: const [], currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final l10n =
          AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
      expect(find.text(l10n.homeEmptyTitle), findsOneWidget);
      expect(find.text(l10n.homeEmptyMessage), findsOneWidget);
    });

    testWidgets('explore screen shows localized empty state with zero cafes',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(cafes: const [], currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ExploreScreen()),
      );
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(ExploreScreen)))!;
      expect(find.text(l10n.homeEmptyTitle), findsOneWidget);
      expect(find.text(l10n.homeEmptyMessage), findsOneWidget);
      expect(find.byKey(const Key('explore-empty-retry')), findsOneWidget);
    });

    testWidgets('favorites screen shows localized empty state with zero cafes',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(cafes: const [], currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const FavoritesScreen()),
      );
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(FavoritesScreen)))!;
      expect(find.text(l10n.favoritesEmptyTitle), findsOneWidget);
      expect(find.text(l10n.favoritesEmptyMessage), findsOneWidget);
    });

    testWidgets('compare screen handles empty cafes safely', (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          compareList: const ['ghost-cafe'],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const CompareScreen()),
      );
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(CompareScreen)))!;
      expect(find.text(l10n.compareUnresolvedMessage), findsOneWidget);
    });

    testWidgets('map screen builds safely with zero cafes', (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(cafes: const [], currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: MapScreen(
            hasMapsConfigOverride: true,
            mapLayerBuilder: (
              context,
              cafes,
              selectedCafeId,
              onTapMarker,
              onTapMap,
            ) {
              return const ColoredBox(
                key: Key('test-map-layer'),
                color: Colors.black12,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(MapScreen)))!;
      expect(find.byKey(const Key('test-map-layer')), findsOneWidget);
      expect(find.byKey(const Key('map-empty-overlay')), findsOneWidget);
      expect(find.text(l10n.mapEmptyTitle), findsOneWidget);
      expect(find.text(l10n.mapDataUnavailableOverlayMessage), findsOneWidget);
    });

    testWidgets(
        'explore screen shows localized error state when cafe load fails',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentUser: testUser,
          cafeSyncState: CafeSyncState.error,
          cafesErrorMessage: 'Unable to load cafes right now.',
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ExploreScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load cafes right now.'), findsOneWidget);
    });

    testWidgets(
        'explore screen shows retryable offline failure when no cache is available',
        (tester) async {
      final connectivity = TestConnectivityService(initiallyOnline: false);
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentUser: testUser,
          hasInitializedDiscovery: true,
          cafeSyncState: CafeSyncState.error,
          cafesErrorMessage: 'Network error while trying to load cafes.',
        ),
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(connectivity.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ExploreScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network error while trying to load cafes.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('home screen surfaces stale cache notices to the user',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(id: 'cafe-1', name: 'Cached Cafe'),
          ],
          currentUser: testUser,
          cafesLastUpdated: DateTime.utc(2026, 3, 28, 14, 30),
          cafeSyncState: CafeSyncState.showingCachedWhileRefreshing,
          isServingStaleCache: true,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.textContaining('Showing cached cafes from'),
        findsOneWidget,
      );
    });

    testWidgets('home screen shows offline fallback messaging for cached cafes',
        (tester) async {
      final connectivity = TestConnectivityService(initiallyOnline: false);
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(id: 'cafe-1', name: 'Offline Cafe'),
          ],
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

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline. Showing cafes last updated'),
          findsOneWidget);
    });

    testWidgets('home screen can show a fresh cache notice without stale state',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(id: 'cafe-1', name: 'Fresh Cache Cafe'),
          ],
          currentUser: testUser,
          cafesLastUpdated: DateTime.utc(2026, 3, 28, 9, 30),
          cafesNoticeMessage:
              'Updated from cache a moment ago while we confirm freshness.',
          hasInitializedDiscovery: true,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Updated from cache a moment ago while we confirm freshness.'),
        findsOneWidget,
      );
    });
  });
}
