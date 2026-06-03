import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/l10n/app_localizations.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/navigation/app_router.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'package:kafeproje/screens/cafe_detail_screen.dart';
import 'package:kafeproje/screens/compare_screen.dart';
import 'package:kafeproje/screens/home_screen.dart';
import 'package:go_router/go_router.dart';

import 'test_helpers.dart';

void main() {
  group('compare flow', () {
    test('toggleCompare keeps compared cafes derived state synchronized',
        () async {
      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
        buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
        buildTestCafe(id: 'cafe-3', name: 'Cafe Three'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(cafes: cafes, currentUser: testUser),
      );
      addTearDown(container.dispose);

      final notifier = container.read(profileProvider.notifier);

      await notifier.toggleCompare('cafe-1');
      await notifier.toggleCompare('cafe-2');

      expect(container.read(compareListProvider), ['cafe-1', 'cafe-2']);
      expect(
        container.read(comparedCafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-1', 'cafe-2'],
      );

      await notifier.toggleCompare('cafe-1');

      expect(container.read(compareListProvider), ['cafe-2']);
      expect(
        container.read(comparedCafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-2'],
      );
    });

    test('toggleCompare keeps at most two cafes and replaces the oldest',
        () async {
      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
        buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
        buildTestCafe(id: 'cafe-3', name: 'Cafe Three'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(cafes: cafes, currentUser: testUser),
      );
      addTearDown(container.dispose);

      final notifier = container.read(profileProvider.notifier);
      await notifier.toggleCompare('cafe-1');
      await notifier.toggleCompare('cafe-2');
      await notifier.toggleCompare('cafe-3');

      expect(container.read(compareListProvider), ['cafe-2', 'cafe-3']);
      expect(
          container.read(normalizedCompareListProvider), ['cafe-2', 'cafe-3']);
      expect(container.read(isCompareListFullProvider), isTrue);
    });

    test('favorite selectors stay scoped to the targeted cafe', () async {
      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
        buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          favorites: const ['cafe-1'],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      var favoriteCafeOneNotifications = 0;
      var favoriteCafeTwoNotifications = 0;
      final subOne = container.listen<bool>(
        isCafeFavoritedProvider('cafe-1'),
        (_, __) => favoriteCafeOneNotifications += 1,
        fireImmediately: true,
      );
      final subTwo = container.listen<bool>(
        isCafeFavoritedProvider('cafe-2'),
        (_, __) => favoriteCafeTwoNotifications += 1,
        fireImmediately: true,
      );
      addTearDown(subOne.close);
      addTearDown(subTwo.close);

      await container.read(profileProvider.notifier).toggleFavorite('cafe-2');

      expect(container.read(isCafeFavoritedProvider('cafe-1')), isTrue);
      expect(container.read(isCafeFavoritedProvider('cafe-2')), isTrue);
      expect(favoriteCafeOneNotifications, 1);
      expect(favoriteCafeTwoNotifications, 2);
      expect(
        container.read(favoriteCafesProvider).map((cafe) => cafe.id).toList(),
        ['cafe-1', 'cafe-2'],
      );
    });

    test('compare selectors stay scoped to the targeted cafe', () async {
      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
        buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          compareList: const ['cafe-1'],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      var compareCafeOneNotifications = 0;
      var compareCafeTwoNotifications = 0;
      final subOne = container.listen<bool>(
        isCafeInCompareListProvider('cafe-1'),
        (_, __) => compareCafeOneNotifications += 1,
        fireImmediately: true,
      );
      final subTwo = container.listen<bool>(
        isCafeInCompareListProvider('cafe-2'),
        (_, __) => compareCafeTwoNotifications += 1,
        fireImmediately: true,
      );
      addTearDown(subOne.close);
      addTearDown(subTwo.close);

      await container.read(profileProvider.notifier).toggleCompare('cafe-2');

      expect(container.read(isCafeInCompareListProvider('cafe-1')), isTrue);
      expect(container.read(isCafeInCompareListProvider('cafe-2')), isTrue);
      expect(compareCafeOneNotifications, 1);
      expect(compareCafeTwoNotifications, 2);
    });

    test(
        'compared cafe stays resolvable outside current visible cafes without leaking into discovery',
        () async {
      final remoteCompared =
          buildTestCafe(id: 'remote-compare-1', name: 'Remote Compared');
      final nonComparedFar =
          buildTestCafe(id: 'remote-noncompare-2', name: 'Remote Non Compare');
      final nearby = buildTestCafe(id: 'nearby-1', name: 'Nearby Cafe');

      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onGetCafesByIds: (_) async => [remoteCompared, nonComparedFar],
      );

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [nearby],
          compareList: const ['remote-compare-1'],
          currentUser: testUser,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(resolvedComparedCafesProvider.future);

      expect(
        container
            .read(comparedCafesProvider)
            .map((cafe) => cafe.id)
            .toList(growable: false),
        ['remote-compare-1'],
      );
      expect(
        container
            .read(exploreCafeResultsProvider)
            .map((cafe) => cafe.id)
            .toList(growable: false),
        ['nearby-1'],
      );
    });

    test(
        'compared cafe remembered from the previous radius remains renderable after radius refresh',
        () async {
      final comparedFar = buildTestCafe(
        id: 'compared-far',
        name: 'Compared Far',
      ).copyWith(coordinates: const Coordinates(lat: 41.2, lng: 29.2));
      final nonComparedFar = buildTestCafe(
        id: 'noncompared-far',
        name: 'Non Compared Far',
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
          cafes: [nearby, comparedFar, nonComparedFar],
          compareList: const ['compared-far'],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
          mapRadiusPreset: MapRadiusPreset.small,
          currentUser: testUser,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(resolvedComparedCafesProvider.future);
      await container
          .read(cafeProvider.notifier)
          .setMapRadiusPreset(MapRadiusPreset.medium);
      await container.read(resolvedComparedCafesProvider.future);

      expect(
        container.read(comparedCafesProvider).map((cafe) => cafe.id),
        ['compared-far'],
      );
      expect(
        container.read(exploreCafeResultsProvider).map((cafe) => cafe.id),
        ['nearby-1'],
      );
      expect(
        container.read(exploreCafeResultsProvider).map((cafe) => cafe.id),
        isNot(contains('noncompared-far')),
      );
    });

    testWidgets(
      'detail compare action opens compare with the selected cafe',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
          buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          initialLocation: '/cafe/cafe-1',
          routes: [
            GoRoute(
              path: '/cafe/:id',
              builder: (_, state) => CafeDetailScreen(
                cafeId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/compare',
              builder: (_, __) => const CompareScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestRouterApp(container: container, router: router),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CafeDetailScreen)),
        )!;
        await tester.ensureVisible(find.text(l10n.cafeDetailCompare).last);
        await tester.tap(find.text(l10n.cafeDetailCompare).last);
        await tester.pumpAndSettle();

        expect(find.byType(CompareScreen), findsOneWidget);
        expect(find.text('Cafe One'), findsWidgets);
        expect(find.byKey(const ValueKey('compare-remove-cafe-1')),
            findsOneWidget);
        expect(container.read(compareListProvider), const ['cafe-1']);
      },
    );

    testWidgets(
      'compare screen shows loading while selected IDs resolve outside visible Explore results',
      (tester) async {
        final remoteCafes = [
          buildTestCafe(id: 'remote-1', name: 'Remote Cafe One'),
          buildTestCafe(id: 'remote-2', name: 'Remote Cafe Two'),
        ];
        final resolution = Completer<List<Cafe>>();
        final repository = FakeCafeRepository(
          onFetch: (_) async =>
              const CafeRepositoryResult(cafes: [], usedRemote: false),
          onGetCafesByIds: (_) => resolution.future,
        );
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: [buildTestCafe(id: 'visible-1', name: 'Visible Cafe')],
            compareList: const ['remote-1', 'remote-2'],
            exploreFilters: const Filters(searchQuery: 'visible'),
            currentUser: testUser,
          ),
          overrides: [
            cafeRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Remote Cafe One'), findsNothing);

        resolution.complete(remoteCafes);
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Remote Cafe One'), findsWidgets);
        expect(find.text('Remote Cafe Two'), findsWidgets);
        expect(
          container.read(exploreCafeResultsProvider).map((cafe) => cafe.id),
          ['visible-1'],
        );
      },
    );

    testWidgets(
      'compare screen renders resolved cafes with a warning for unresolved selected IDs',
      (tester) async {
        final repository = FakeCafeRepository(
          onFetch: (_) async =>
              const CafeRepositoryResult(cafes: [], usedRemote: false),
          onGetCafesByIds: (_) async => [
            buildTestCafe(id: 'remote-1', name: 'Remote Cafe One'),
          ],
        );
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: const [],
            compareList: const ['remote-1', 'missing-cafe'],
            currentUser: testUser,
          ),
          overrides: [
            cafeRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        final l10n =
            AppLocalizations.of(tester.element(find.byType(CompareScreen)))!;
        expect(find.text('Remote Cafe One'), findsWidgets);
        expect(find.text(l10n.compareUnresolvedSlot), findsWidgets);
        expect(find.text(l10n.compareUnresolvedMessage), findsOneWidget);
        expect(
          find.byKey(const ValueKey('compare-remove-remote-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'removing one cafe leaves remaining compared cafes visible with no stale item',
      (tester) async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
          buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
          buildTestCafe(id: 'cafe-3', name: 'Cafe Three'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            compareList: const ['cafe-1', 'cafe-2'],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cafe One'), findsWidgets);
        expect(find.text('Cafe Two'), findsWidgets);
        expect(find.text('Cafe Three'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('compare-remove-cafe-2')));
        await tester.pumpAndSettle();

        expect(find.text('Cafe One'), findsWidgets);
        expect(find.text('Cafe Three'), findsNothing);
        expect(find.text('Cafe Two'), findsNothing);
        expect(
          find.byKey(const ValueKey('compare-remove-cafe-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('compare-remove-cafe-2')),
          findsNothing,
        );
        expect(
          container.read(comparedCafesProvider).map((cafe) => cafe.id).toList(),
          ['cafe-1'],
        );
      },
    );

    testWidgets(
      'compare screen keeps a single cafe visible and offers add/remove actions',
      (tester) async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
          buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            compareList: const ['cafe-1', 'cafe-2'],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('compare-remove-cafe-1')));
        await tester.pumpAndSettle();

        final l10n =
            AppLocalizations.of(tester.element(find.byType(CompareScreen)))!;
        expect(find.text('Cafe One'), findsNothing);
        expect(find.text('Cafe Two'), findsWidgets);
        expect(
            find.byKey(const Key('compare-add-cafe-button')), findsOneWidget);
        expect(find.text(l10n.compareAddCafeAction), findsWidgets);
        expect(find.text(l10n.compareAddAnotherPrompt), findsWidgets);
        expect(
          find.byKey(const ValueKey('compare-remove-cafe-2')),
          findsOneWidget,
        );
        expect(
          container.read(compareListProvider),
          const ['cafe-2'],
        );
      },
    );

    testWidgets('removing the last cafe from compare shows the empty state',
        (tester) async {
      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          compareList: const ['cafe-1'],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const CompareScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('compare-remove-cafe-1')));
      await tester.pumpAndSettle();

      final localizations = AppLocalizations.of(
        tester.element(find.byType(CompareScreen)),
      )!;

      expect(find.text(localizations.compareEmptyMessage), findsOneWidget);
      expect(
        find.byKey(const Key('compare-empty-add-cafes-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('compare-empty-explore-cafes-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('compare-add-cafe-button')), findsNothing);
      expect(container.read(compareListProvider), isEmpty);
    });

    testWidgets(
      'compare state stays synchronized between home and compare screens',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
          buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
          buildTestCafe(id: 'cafe-3', name: 'Cafe Three'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            compareList: const ['cafe-1', 'cafe-2'],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const HomeScreen()),
        );
        await tester.pumpAndSettle();

        final homeL10n =
            AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
        expect(find.text(homeL10n.cafeCardCompared), findsNWidgets(2));
        expect(find.text(homeL10n.cafeCardCompare), findsOneWidget);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('compare-remove-cafe-1')));
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          buildTestApp(container: container, child: const HomeScreen()),
        );
        await tester.pumpAndSettle();

        final updatedHomeL10n =
            AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
        expect(find.text(updatedHomeL10n.cafeCardCompared), findsOneWidget);
        expect(find.text(updatedHomeL10n.cafeCardCompare), findsNWidgets(2));
        expect(container.read(compareListProvider), const ['cafe-2']);
      },
    );

    testWidgets(
      'dirty compare state is normalized so only real unique cafes appear selected',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
          buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
          buildTestCafe(id: 'cafe-3', name: 'Cafe Three'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            compareList: const ['cafe-1', 'cafe-1', 'cafe-2', 'ghost-cafe'],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const HomeScreen()),
        );
        await tester.pumpAndSettle();

        final homeL10n =
            AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
        expect(find.text(homeL10n.cafeCardCompared), findsNWidgets(2));
        expect(find.text(homeL10n.cafeCardCompare), findsOneWidget);
        expect(container.read(comparedCafeIdsProvider), {'cafe-1', 'cafe-2'});
        expect(
          container.read(comparedCafesProvider).map((cafe) => cafe.id).toList(),
          ['cafe-1', 'cafe-2'],
        );
      },
    );

    testWidgets('shell compare fab stays hidden on the map route',
        (tester) async {
      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
        buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          compareList: const ['cafe-1', 'cafe-2'],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-compare-fab')), findsOneWidget);

      router.go('/map');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-compare-fab')), findsNothing);

      router.go('/');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-compare-fab')), findsOneWidget);
    });

    testWidgets(
      'compare screen stays stable on narrow screens with long values',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final longFeatureTags = List<String>.generate(
          12,
          (index) => 'comfort feature with readable detail ${index + 1}',
        );
        final cafes = [
          buildTestCafe(
            id: 'cafe-1',
            name: 'Very Long Cafe Name For Narrow Screens One',
            tags: longFeatureTags,
          ),
          buildTestCafe(
            id: 'cafe-2',
            name: 'Very Long Cafe Name For Narrow Screens Two',
            tags: longFeatureTags,
          ),
          buildTestCafe(
            id: 'cafe-3',
            name: 'Very Long Cafe Name For Narrow Screens Three',
            tags: const ['breakfast', 'brunch', 'late night'],
          ),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            compareList: const ['cafe-1', 'cafe-2'],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('compare-grid')), findsOneWidget);
        final scrollView = tester.widget<SingleChildScrollView>(
          find.byKey(const Key('compare-table-scroll')),
        );
        expect(scrollView.scrollDirection, Axis.vertical);
        expect(
          tester
              .getSize(find.byKey(const Key('compare-table-cell-7-0')))
              .height,
          lessThanOrEqualTo(76),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'compare screen renders attribute-left matrix headers for both slots',
      (tester) async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
          buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            compareList: const ['cafe-1', 'cafe-2'],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('compare-table-scroll')), findsOneWidget);
        expect(
          find.byKey(const Key('compare-table-header-attribute')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('compare-table-header-slot-0')),
            findsOneWidget);
        expect(find.byKey(const Key('compare-table-header-slot-1')),
            findsOneWidget);
      },
    );

    testWidgets(
      'compare screen title is text only and empty state explains features',
      (tester) async {
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: const <Cafe>[],
            compareList: const <String>[],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CompareScreen)),
        )!;
        expect(find.byKey(const Key('compare-screen-title')), findsOneWidget);
        expect(find.text(l10n.compareTitle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.compare_arrows_rounded),
          ),
          findsNothing,
        );
        expect(
          find.byKey(const Key('compare-empty-feature-explanations')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('compare-empty-add-cafes-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('compare-empty-explore-cafes-button')),
          findsOneWidget,
        );
        expect(find.text(l10n.compareEmptyAddCafes), findsOneWidget);
        expect(find.text(l10n.compareEmptyExploreCafes), findsOneWidget);
        expect(find.text(l10n.compareCommunityRating), findsOneWidget);
        expect(
            find.text(l10n.compareEmptyFeatureCommunityRating), findsOneWidget);
        expect(find.text(l10n.comparePrice), findsOneWidget);
        expect(find.text(l10n.compareEmptyFeaturePrice), findsOneWidget);
        expect(find.text(l10n.compareWifi), findsOneWidget);
        expect(find.text(l10n.compareEmptyFeatureWifi), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'compare table uses compact icon-only attribute column',
      (tester) async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
          buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            compareList: const ['cafe-1', 'cafe-2'],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        final attributeCell =
            find.byKey(const Key('compare-table-attribute-0'));
        expect(attributeCell, findsOneWidget);
        expect(
          find.descendant(
            of: attributeCell,
            matching: find.byType(Icon),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: attributeCell,
            matching: find.text('Community rating'),
          ),
          findsNothing,
        );
        expect(tester.getSize(attributeCell).width, lessThanOrEqualTo(48));
      },
    );

    testWidgets(
      'compare screen renders useful single-cafe table without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final cafes = [
          buildTestCafe(
            id: 'cafe-1',
            name: 'Single Cafe',
            tags: const ['very long feature value that should not overflow'],
          ),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            compareList: const ['cafe-1'],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Single Cafe'), findsWidgets);
        expect(find.byKey(const Key('compare-table-cell-0-0')), findsOneWidget);
        expect(
            find.byKey(const Key('compare-add-cafe-button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'compare slot cards and cafe headers keep consistent sizing',
      (tester) async {
        final cafes = [
          buildTestCafe(
            id: 'cafe-1',
            name: 'Short Name',
          ),
          buildTestCafe(
            id: 'cafe-2',
            name: 'A Very Long Cafe Header Name That Spans Two Lines',
          ),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            compareList: const ['cafe-1', 'cafe-2'],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        final slot0 = find.byKey(const Key('compare-slot-0'));
        final slot1 = find.byKey(const Key('compare-slot-1'));
        final header0 = find.byKey(const Key('compare-table-header-slot-0'));
        final header1 = find.byKey(const Key('compare-table-header-slot-1'));

        expect(slot0, findsOneWidget);
        expect(slot1, findsOneWidget);
        expect(header0, findsOneWidget);
        expect(header1, findsOneWidget);

        expect(tester.getSize(slot0).height, tester.getSize(slot1).height);
        expect(tester.getSize(header0).height, tester.getSize(header1).height);
      },
    );

    testWidgets(
      'compare screen never renders literal null text for sparse cafe data',
      (tester) async {
        final sparseCafe = buildTestCafe(
          id: 'cafe-sparse',
          name: 'Sparse Cafe',
          district: '',
          neighborhood: '',
          rating: 0,
          tags: const <String>[],
          images: const <String>[],
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: [sparseCafe],
            compareList: const ['cafe-sparse', 'ghost-cafe'],
            currentUser: testUser,
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(container: container, child: const CompareScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('null'), findsNothing);
        expect(find.text('Sparse Cafe'), findsWidgets);
      },
    );
  });
}
