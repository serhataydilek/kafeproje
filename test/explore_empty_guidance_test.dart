import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/screens/explore_screen.dart';
import 'package:kafeproje/widgets/ui/shimmer_loading.dart';

import 'test_helpers.dart';

void main() {
  group('Explore empty guidance UX', () {
    testWidgets('shows loading state distinctly while discovery bootstraps', (
      tester,
    ) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentUser: testUser,
          hasInitializedDiscovery: false,
          cafeSyncState: CafeSyncState.loading,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ExploreScreen()),
      );
      await tester.pump();

      expect(find.byType(ShimmerCafeList), findsOneWidget);
    });

    testWidgets('shows clear-search CTA when active search yields no results', (
      tester,
    ) async {
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

      expect(
          find.byKey(const Key('explore-empty-clear-search')), findsOneWidget);
      expect(
          find.byKey(const Key('explore-empty-reset-filters')), findsNothing);
    });

    testWidgets('shows reset-filters CTA when active filters yield no results',
        (
      tester,
    ) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(
                id: 'cafe-1', name: 'Kadikoy Brew', district: 'Kadikoy'),
          ],
          currentUser: testUser,
          exploreFilters: const Filters(district: 'Besiktas'),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ExploreScreen()),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('explore-empty-reset-filters')), findsOneWidget);
      expect(find.byKey(const Key('explore-empty-clear-search')), findsNothing);
    });

    testWidgets(
        'clear and reset CTAs recover filter/search state deterministically', (
      tester,
    ) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(
                id: 'cafe-1', name: 'Kadikoy Brew', district: 'Kadikoy'),
          ],
          currentUser: testUser,
          exploreFilters: const Filters(
            district: 'Besiktas',
            searchQuery: 'no-match-query',
          ),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ExploreScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('explore-empty-clear-search')));
      await tester.pumpAndSettle();

      final afterClear = container.read(exploreFiltersProvider);
      expect(afterClear.searchQuery, isNull);
      expect(afterClear.district, isNotNull);
      expect(afterClear.activeCount, 1);

      await tester.tap(find.byKey(const Key('explore-empty-reset-filters')));
      await tester.pumpAndSettle();

      final afterReset = container.read(exploreFiltersProvider);
      expect(afterReset.searchQuery, isNull);
      expect(afterReset.district, isNull);
      expect(afterReset.activeCount, 0);
    });

    testWidgets(
      'explains compare selections when current Explore filters are empty',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: [
              buildTestCafe(
                  id: 'cafe-1', name: 'Kadikoy Brew', district: 'Kadikoy'),
              buildTestCafe(
                  id: 'cafe-2', name: 'Moda Work', district: 'Kadikoy'),
            ],
            compareList: const ['cafe-1', 'cafe-2'],
            currentUser: testUser,
            exploreFilters: const Filters(district: 'Besiktas'),
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const ExploreScreen()),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'No cafes match current filters, but you still have selected cafes ready to compare.',
          ),
          findsOneWidget,
        );
        expect(
            find.byKey(const Key('explore-empty-go-compare')), findsOneWidget);

        await tester.tap(find.byKey(const Key('explore-empty-reset-filters')));
        await tester.pumpAndSettle();

        expect(container.read(exploreFiltersProvider).activeCount, 0);
        expect(container.read(compareListProvider), const ['cafe-1', 'cafe-2']);
      },
    );

    testWidgets('keeps empty state scrollable when keyboard is visible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Blue Bottle')],
          currentUser: testUser,
          exploreFilters: const Filters(searchQuery: 'no-match-query'),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: Builder(
            builder: (context) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  viewInsets: const EdgeInsets.only(bottom: 260),
                ),
                child: const ExploreScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore-keyboard-state-scroll')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps search results stable when keyboard is visible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(id: 'cafe-1', name: 'Blue Bottle'),
            buildTestCafe(id: 'cafe-2', name: 'Work Bench'),
          ],
          currentUser: testUser,
          exploreFilters: const Filters(searchQuery: 'Blue'),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: Builder(
            builder: (context) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  viewInsets: const EdgeInsets.only(bottom: 280),
                ),
                child: const ExploreScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('explore-cafe-cafe-1')), findsOneWidget);
      expect(find.text('Blue Bottle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
