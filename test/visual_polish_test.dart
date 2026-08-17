import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/l10n/app_localizations.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/screens/cafe_detail_screen.dart';
import 'package:kafeproje/screens/compare_screen.dart';
import 'package:kafeproje/screens/explore_screen.dart';
import 'package:kafeproje/screens/favorites_screen.dart';
import 'package:kafeproje/screens/home_screen.dart';
import 'package:kafeproje/theme/app_theme.dart';
import 'package:kafeproje/widgets/cafes/cafe_card.dart';
import 'package:kafeproje/widgets/cafes/map_cafe_preview_card.dart';

import 'test_helpers.dart';

void main() {
  group('visual polish edge cases', () {
    testWidgets('cafe card truncates long names on a 320px surface',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const longName =
          'Karadeniz Kahve Atolyesi ve Cok Uzun Bir Kafe Adi Denemesi';
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: CafeCardListItem(
                cafe: buildTestCafe(
                  id: 'long-name',
                  name: longName,
                  district: 'Kadikoy',
                  neighborhood: 'Caferaga Mahallesi Cok Uzun',
                ),
                onPress: () {},
                colors: lightColors,
                surface: 'test',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(longName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cafe card stays stable with missing photo, rating, and tags',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'sparse-card',
        name: 'Sparse Card Cafe',
        images: const [],
        tags: const [],
        rating: 0,
      );
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: Scaffold(
            body: CafeCardListItem(
              cafe: cafe,
              onPress: () {},
              colors: lightColors,
              surface: 'test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sparse Card Cafe'), findsOneWidget);
      expect(find.text('4.5'), findsNothing);
      expect(find.text('Coffee'), findsNothing);
      expect(find.text('Study'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('favorites empty state stays readable on a narrow screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const FavoritesScreen()),
      );
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(FavoritesScreen)))!;
      expect(find.text(l10n.favoritesTitle), findsOneWidget);
      expect(find.text(l10n.favoritesEmptyTitle), findsOneWidget);
      expect(find.text(l10n.favoritesEmptyMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('explore empty search result keeps cafe discovery as the focus',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Blue Bottle')],
          currentUser: testUser,
          exploreFilters: const Filters(searchQuery: 'no-match-query'),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ExploreScreen()),
      );
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(ExploreScreen)))!;
      expect(find.text(l10n.exploreEmptyTitle), findsOneWidget);
      expect(
          find.byKey(const Key('explore-empty-clear-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('home title and subtitle render on a compact phone width',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(id: 'cafe-1', name: 'Moda Brew'),
          ],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final l10n =
          AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
      expect(find.text(l10n.homeTitle), findsOneWidget);
      expect(find.text(l10n.homeSubtitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'cafe detail hides empty favorite count and keeps fallback copy',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'detail-sparse',
        name: 'A Very Long Detail Cafe Name That Should Wrap Gracefully',
        images: const [],
        tags: const [],
        rating: 0,
      ).copyWith(
        description: '',
        favoriteCount: 0,
        openingHours: const [],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'detail-sparse'),
        ),
      );
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(CafeDetailScreen)))!;
      expect(
        find.byKey(const ValueKey('cafe-detail-favorite-count-detail-sparse')),
        findsNothing,
      );
      expect(find.text(l10n.cafeNoRatingsYet), findsWidgets);
      expect(find.text(l10n.cafeDetailDescriptionFallback), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compare board shows missing values without overflowing at 320',
        (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cafes = [
        buildTestCafe(
          id: 'cafe-a',
          name: 'Short Cafe',
          rating: 0,
          tags: const [],
        ),
        buildTestCafe(
          id: 'cafe-b',
          name: 'Another Extremely Long Cafe Name For Compare Columns',
          rating: 0,
          tags: const [],
        ),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          compareList: const ['cafe-a', 'cafe-b'],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const CompareScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Short Cafe'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('map preview stays compact without duplicating card metadata',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cafe = buildTestCafe(
        id: 'map-preview',
        name: 'Map Preview Cafe With A Long Name',
        tags: const ['Coffee', 'Study', 'Outdoor'],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: Scaffold(
            body: MapCafePreviewCard(
              colors: lightColors,
              cafe: cafe,
              onTap: () {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Map Preview Cafe'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);
      expect(find.text('Study'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
