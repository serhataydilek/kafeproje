import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kafeproje/l10n/app_localizations.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/navigation/app_router.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'package:kafeproje/screens/cafe_detail_screen.dart';
import 'package:kafeproje/screens/compare_screen.dart';
import 'package:kafeproje/screens/favorites_screen.dart';
import 'package:kafeproje/screens/home_screen.dart';
import 'package:kafeproje/screens/map_screen.dart';
import 'package:kafeproje/theme/app_theme.dart';
import 'package:kafeproje/widgets/cafes/cafe_card.dart';
import 'package:kafeproje/widgets/cafes/cafe_image_carousel.dart';
import 'package:kafeproje/widgets/cafes/map_bottom_overlay.dart';
import 'package:kafeproje/widgets/cafes/map_cafe_preview_card.dart';
import 'package:kafeproje/widgets/cafes/map_radius_selector.dart';
import 'package:kafeproje/widgets/ui/state_views.dart';

import 'test_helpers.dart';

const _testCafeMapCenter = Coordinates(lat: 41.006, lng: 29.006);

void main() {
  group('map state behavior', () {
    testWidgets('initial map load suppresses empty overlay while fetching',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentUser: testUser,
          hasInitializedDiscovery: true,
          isCafesLoading: true,
          cafeSyncState: CafeSyncState.ready,
        ),
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
              return const ColoredBox(color: Colors.black12);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('map-empty-overlay')), findsNothing);
      expect(find.byType(LoadingStateView), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('map shows empty overlay after completed empty fetch',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentUser: testUser,
          hasInitializedDiscovery: true,
          isCafesLoading: false,
          cafeSyncState: CafeSyncState.empty,
        ),
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
              return const ColoredBox(color: Colors.black12);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('map-empty-overlay')), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('radius selector exposes exactly the three radius presets',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: Scaffold(
            body: Center(
              child: MapRadiusSelector(
                colors: lightColors,
                selectedPreset: MapRadiusPreset.small,
                isEnabled: true,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('map-radius-small')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-radius-medium')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-radius-large')), findsOneWidget);
      expect(find.text('1 km'), findsOneWidget);
      expect(find.text('2 km'), findsOneWidget);
      expect(find.text('4 km'), findsOneWidget);
      expect(find.text('500 m'), findsNothing);
      expect(find.text('8 km'), findsNothing);
    });

    testWidgets('selecting cafes updates selected details and photo state',
        (tester) async {
      final cafes = [
        buildTestCafe(
          id: 'cafe-1',
          name: 'Cafe One',
          images: const [
            'https://example.com/1.png',
            'https://example.com/2.png'
          ],
        ),
        buildTestCafe(
          id: 'cafe-2',
          name: 'Cafe Two',
          images: const [],
        ),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          currentUser: testUser,
          currentLocation: _testCafeMapCenter,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: MapScreen(
            hasMapsConfigOverride: true,
            imageProviderBuilder: (_) => transparentImageProvider,
            mapLayerBuilder: (
              context,
              cafes,
              selectedCafeId,
              onTapMarker,
              onTapMap,
            ) {
              return SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Material(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('selected:$selectedCafeId'),
                          for (final cafe in cafes)
                            TextButton(
                              key: ValueKey('map-marker-${cafe.id}'),
                              onPressed: () => onTapMarker(cafe.id),
                              child: Text(cafe.name),
                            ),
                          TextButton(
                            key: const Key('map-clear-selection'),
                            onPressed: onTapMap,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('map-marker-cafe-1')),
          )
          .onPressed!
          .call();
      await tester.pumpAndSettle();

      expect(container.read(selectedCafeIdProvider), 'cafe-1');
      expect(find.byKey(const ValueKey('map-selected-sheet-cafe-1')),
          findsOneWidget);
      expect(
        find.byKey(const ValueKey('map-selected-sheet-host-cafe-1')),
        findsOneWidget,
      );
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('map-selected-sheet-cafe-1')),
          matching: find.text('Cafe One'),
        ),
        findsOneWidget,
      );

      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('map-marker-cafe-2')),
          )
          .onPressed!
          .call();
      await tester.pumpAndSettle();

      expect(container.read(selectedCafeIdProvider), 'cafe-2');
      expect(find.byKey(const ValueKey('map-selected-sheet-cafe-2')),
          findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('map-selected-sheet-cafe-2')),
          matching: find.text('Cafe Two'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('map-selected-sheet-cafe-1')),
          findsNothing);
    });

    testWidgets('rapid consecutive marker taps keep latest cafe selected',
        (tester) async {
      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
        buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          currentUser: testUser,
          currentLocation: _testCafeMapCenter,
        ),
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
              return SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Material(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final cafe in cafes)
                          TextButton(
                            key: ValueKey('rapid-map-marker-${cafe.id}'),
                            onPressed: () => onTapMarker(cafe.id),
                            child: Text(cafe.name),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('rapid-map-marker-cafe-1')),
          )
          .onPressed!
          .call();
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('rapid-map-marker-cafe-2')),
          )
          .onPressed!
          .call();
      await tester.pumpAndSettle();

      expect(container.read(selectedCafeIdProvider), 'cafe-2');
      expect(find.byKey(const ValueKey('map-selected-sheet-cafe-2')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('map-selected-sheet-cafe-1')),
          findsNothing);
    });

    testWidgets('map screen opens with a clean selection across remounts',
        (tester) async {
      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          currentUser: testUser,
          currentLocation: _testCafeMapCenter,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: _MapHost(
            childBuilder: () => MapScreen(
              hasMapsConfigOverride: true,
              mapLayerBuilder: (
                context,
                cafes,
                selectedCafeId,
                onTapMarker,
                onTapMap,
              ) {
                return Material(
                  child: Column(
                    children: [
                      Text('selected:$selectedCafeId'),
                      for (final cafe in cafes)
                        TextButton(
                          key: ValueKey('host-map-marker-${cafe.id}'),
                          onPressed: () => onTapMarker(cafe.id),
                          child: Text(cafe.name),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('host-map-marker-cafe-1')),
          )
          .onPressed!
          .call();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('map-selected-sheet-cafe-1')),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('toggle-map-host')));
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsNothing);

      await tester.tap(find.byKey(const Key('toggle-map-host')));
      await tester.pumpAndSettle();

      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('map-selected-sheet-cafe-1')),
          findsNothing);
      expect(container.read(selectedCafeIdProvider), isNull);
      expect(find.text('selected:null'), findsOneWidget);
    });

    testWidgets('map clears cached selected cafe on first open',
        (tester) async {
      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          currentUser: testUser,
          currentLocation: _testCafeMapCenter,
          selectedCafeId: 'cafe-1',
        ),
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
              return Material(
                child: Column(
                  children: [
                    Text('selected:$selectedCafeId'),
                    for (final cafe in cafes)
                      TextButton(
                        key: ValueKey('fresh-map-marker-${cafe.id}'),
                        onPressed: () => onTapMarker(cafe.id),
                        child: Text(cafe.name),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(selectedCafeIdProvider), isNull);
      expect(find.text('selected:null'), findsOneWidget);
      expect(find.byKey(const ValueKey('map-selected-sheet-cafe-1')),
          findsNothing);

      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('fresh-map-marker-cafe-1')),
          )
          .onPressed!
          .call();
      await tester.pumpAndSettle();

      expect(container.read(selectedCafeIdProvider), 'cafe-1');
      expect(find.byKey(const ValueKey('map-selected-sheet-cafe-1')),
          findsOneWidget);
    });

    testWidgets(
        'map screen resolves selected cafe when selection uses place id',
        (tester) async {
      const placeId = 'ChIJPlaceIdForMapSelection';
      final cafes = [
        buildTestCafe(id: 'cafe-uuid-1', name: 'Cafe One').copyWith(
          placeId: placeId,
          coordinates: _testCafeMapCenter,
        ),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          currentUser: testUser,
          currentLocation: _testCafeMapCenter,
        ),
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
              return const ColoredBox(color: Colors.black12);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      container.read(cafeProvider.notifier).selectCafeForMap(placeId);
      await tester.pumpAndSettle();

      expect(container.read(selectedCafeIdProvider), placeId);
      expect(
        find.byKey(const ValueKey('map-selected-sheet-cafe-uuid-1')),
        findsOneWidget,
      );
    });

    testWidgets(
      'selected cafe sheet and compare action both remain usable on narrow map layouts',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
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
            compareList: const ['cafe-1', 'cafe-2'],
            currentUser: testUser,
            currentLocation: _testCafeMapCenter,
          ),
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          initialLocation: '/map',
          routes: [
            GoRoute(
              path: '/map',
              builder: (_, __) => MapScreen(
                hasMapsConfigOverride: true,
                imageProviderBuilder: (_) => transparentImageProvider,
                mapLayerBuilder: (
                  context,
                  cafes,
                  selectedCafeId,
                  onTapMarker,
                  onTapMap,
                ) {
                  return SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Material(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('selected:$selectedCafeId'),
                              for (final cafe in cafes)
                                TextButton(
                                  key: ValueKey('narrow-map-marker-${cafe.id}'),
                                  onPressed: () => onTapMarker(cafe.id),
                                  child: Text(cafe.name),
                                ),
                              TextButton(
                                key: const Key('narrow-map-clear-selection'),
                                onPressed: onTapMap,
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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

        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('narrow-map-marker-cafe-1')),
            )
            .onPressed!
            .call();
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('map-selected-sheet-cafe-1')),
            findsOneWidget);
        expect(find.byKey(const Key('map-compare-fab')), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(const Key('map-compare-fab'))).dy,
          lessThan(
            tester.getTopLeft(find.byKey(const Key('map-action-rail'))).dy,
          ),
        );

        await tester.tap(find.byKey(const Key('map-compare-fab')));
        await tester.pumpAndSettle();

        expect(find.byType(CompareScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'radius changes show local selector progress without the global refresh bar',
      (tester) async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
        ];
        final completer = Completer<CafeRepositoryResult>();
        final container = createTestContainer(
          state: buildTestAppShellState(
            cafes: cafes,
            currentUser: testUser,
            currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
          ),
          overrides: [
            cafeRepositoryProvider.overrideWithValue(
              FakeCafeRepository(
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
            child: MapScreen(
              hasMapsConfigOverride: true,
              mapLayerBuilder: (
                context,
                cafes,
                selectedCafeId,
                onTapMarker,
                onTapMap,
              ) {
                return const ColoredBox(color: Colors.black12);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('map-radius-large')));
        await tester.pump();

        expect(find.byKey(const Key('map-radius-refresh-indicator')),
            findsOneWidget);
        expect(find.byType(InlineRefreshBar), findsNothing);

        completer.complete(
          CafeRepositoryResult(cafes: cafes, usedRemote: true),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('map-radius-refresh-indicator')),
            findsNothing);
      },
    );

    testWidgets('district mode disables radius changes', (tester) async {
      var fetchCount = 0;
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(id: 'cafe-1', name: 'Cafe One', district: 'Kadikoy'),
          ],
          currentUser: testUser,
          currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
          mapFilters: const Filters(
            selectedDistricts: {'Kadikoy'},
          ),
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onFetch: (_) async {
                fetchCount++;
                return const CafeRepositoryResult(
                  cafes: [],
                  usedRemote: false,
                );
              },
            ),
          ),
        ],
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
              return const ColoredBox(color: Colors.black12);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      fetchCount = 0;

      await tester.tap(find.byKey(const ValueKey('map-radius-large')));
      await tester.pump();

      expect(fetchCount, 0);
      expect(container.read(mapRadiusPresetProvider), MapRadiusPreset.small);
      expect(
        find.byKey(const Key('map-radius-refresh-indicator')),
        findsNothing,
      );
    });

    testWidgets('multi-district filters show badge count without top summary',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(id: 'cafe-1', name: 'Cafe One', district: 'Kadikoy'),
            buildTestCafe(
              id: 'cafe-2',
              name: 'Cafe Two',
              district: 'Besiktas',
            ),
          ],
          currentUser: testUser,
          currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
          mapFilters: const Filters(
            selectedDistricts: {'Kadikoy', 'Besiktas'},
          ),
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(
            FakeCafeRepository(
              onFetch: (_) async {
                return const CafeRepositoryResult(
                  cafes: [],
                  usedRemote: false,
                );
              },
            ),
          ),
        ],
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
              return const ColoredBox(color: Colors.black12);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-filter-fab')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('2 filters'), findsNothing);
      expect(find.text('2 filtre'), findsNothing);
    });

    testWidgets('locate action keeps the default 1 km radius intent',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: testUser,
          currentLocation: const Coordinates(lat: 41.0422, lng: 29.0067),
        ),
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
              return const ColoredBox(color: Colors.black12);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(mapRadiusPresetProvider), MapRadiusPreset.small);
      expect(find.byKey(const Key('map-location-fab')), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-location-fab')));
      await tester.pump();

      expect(container.read(mapRadiusPresetProvider), MapRadiusPreset.small);
    });

    testWidgets(
      'map cafe preview card applies matching rounded shape and clipping',
      (tester) async {
        final container = createTestContainer(
          state: buildTestAppShellState(currentUser: testUser),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: Center(
              child: MapCafePreviewCard(
                colors: lightColors,
                cafe: buildTestCafe(
                  id: 'cafe-1',
                  name: 'Cafe One',
                  images: const ['https://example.com/1.png'],
                ),
                onTap: () {},
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final materials = tester.widgetList<Material>(
          find.descendant(
            of: find.byType(MapCafePreviewCard),
            matching: find.byType(Material),
          ),
        );
        expect(
          materials.any((material) => material.clipBehavior == Clip.antiAlias),
          isTrue,
        );

        final imageFrame = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(MapCafePreviewCard),
                matching: find.byType(Container),
              ),
            )
            .firstWhere(
                (container) => container.clipBehavior == Clip.antiAlias);
        expect(imageFrame.decoration, isA<BoxDecoration>());

        final inkWell = tester.widget<InkWell>(
          find
              .descendant(
                of: find.byType(MapCafePreviewCard),
                matching: find.byType(InkWell),
              )
              .first,
        );
        expect(inkWell.customBorder, isA<RoundedRectangleBorder>());
      },
    );

    testWidgets('map preview card keeps long labels bounded on compact widths',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: Center(
            child: SizedBox(
              width: 320,
              child: MapCafePreviewCard(
                colors: lightColors,
                cafe: buildTestCafe(
                  id: 'long-label-cafe',
                  name: 'Very Long Independent Workspace Coffee Roastery Name',
                  district: 'Kadikoy',
                  neighborhood:
                      'Very Long Neighborhood Name With A Long Street Address',
                  tags: const [
                    'extremely long specialty workspace tag',
                  ],
                ),
                onTap: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final closeButtonSize =
          tester.getSize(find.byKey(const Key('map-selected-close')));
      expect(closeButtonSize.width, greaterThanOrEqualTo(40));
      expect(closeButtonSize.height, greaterThanOrEqualTo(40));
    });

    testWidgets(
        'map preview keeps Google rating secondary when app rating is missing',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      final cafe = buildTestCafe(
        id: 'google-only-cafe',
        name: 'Google Only Cafe',
        rating: 0,
      ).copyWith(
        googlePlaceData: () => const GooglePlaceData(
          googleRating: 4.9,
          googleReviewCount: 120,
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: Center(
            child: SizedBox(
              width: 360,
              child: MapCafePreviewCard(
                colors: lightColors,
                cafe: cafe,
                onTap: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MapCafePreviewCard)),
      )!;
      expect(find.text('4.9'), findsNothing);
      expect(find.text(l10n.cafeNoRatingsYet), findsOneWidget);
    });

    testWidgets('map overlay controls use stable compact touch targets',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: SizedBox(
            width: 360,
            height: 640,
            child: MapBottomOverlay(
              colors: lightColors,
              filtersActiveCount: 2,
              compareCount: 1,
              selectedCafe: null,
              radiusPreset: MapRadiusPreset.small,
              isRadiusEnabled: true,
              isRadiusRefreshing: false,
              onLocate: () {},
              onSelectRadiusPreset: (_) {},
              onOpenFilters: () {},
              onOpenCompare: () {},
              onOpenDetails: () {},
              onCloseSelectedCafe: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final roundActionInks = tester
          .widgetList<Ink>(
            find.descendant(
              of: find.byKey(const Key('map-action-rail')),
              matching: find.byType(Ink),
            ),
          )
          .where((ink) => ink.width == 44 && ink.height == 44)
          .toList(growable: false);
      expect(roundActionInks, hasLength(2));
    });

    testWidgets('cafe image carousel supports multiple local photos',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: Center(
            child: CafeImageCarousel(
              imageUrls: const [
                'https://example.com/1.png',
                'https://example.com/2.png',
              ],
              imageProviders: [
                transparentImageProvider,
                transparentImageProvider,
              ],
              height: 160,
              colors: lightColors,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('cafe image carousel shows placeholder for zero photos',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Center(
            child: CafeImageCarousel(
              imageUrls: <String>[],
              height: 160,
              colors: lightColors,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No photos available yet'), findsOneWidget);
    });

    testWidgets('cafe card uses gallery instead of a single photo widget',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: CafeCard(
            cafe: buildTestCafe(
              id: 'cafe-1',
              name: 'Cafe One',
              images: const [
                'https://example.com/1.png',
                'https://example.com/2.png',
              ],
            ),
            isFavorite: false,
            inCompare: false,
            onPress: () {},
            onFavoritePress: () {},
            onComparePress: () {},
            colors: lightColors,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('cafe-card-gallery-cafe-card-cafe-1')),
          findsOneWidget);
      expect(find.byType(CafeImageCarousel), findsOneWidget);
    });

    testWidgets('tapping a cafe card from home opens cafe details first',
        (tester) async {
      final cafes = [
        buildTestCafe(
          id: 'cafe-1',
          name: 'Cafe One',
        ),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(cafes: cafes, currentUser: testUser),
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/cafe/:id',
            builder: (_, state) => CafeDetailScreen(
              cafeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/map',
            builder: (_, __) => MapScreen(
              hasMapsConfigOverride: true,
              imageProviderBuilder: (_) => transparentImageProvider,
              mapLayerBuilder: (
                context,
                cafes,
                selectedCafeId,
                onTapMarker,
                onTapMap,
              ) {
                return ColoredBox(
                  color: Colors.black12,
                  child: Center(
                    child: Text('selected:$selectedCafeId'),
                  ),
                );
              },
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      final cafeCardFinder = find.byKey(const ValueKey('cafe-card-cafe-1'));
      final cafeCard = tester.widget<GestureDetector>(cafeCardFinder);
      cafeCard.onTap?.call();
      await tester.pumpAndSettle();

      expect(find.byType(CafeDetailScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CafeDetailScreen),
          matching: find.text('Cafe One'),
        ),
        findsOneWidget,
      );
      expect(container.read(selectedCafeIdProvider), isNull);
    });

    testWidgets('tapping a favorite cafe opens the matching detail route',
        (tester) async {
      final cafes = [
        buildTestCafe(
          id: 'favorite-detail-cafe',
          name: 'Favorite Detail Cafe',
        ),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          favorites: const ['favorite-detail-cafe'],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/favorites',
        routes: [
          GoRoute(
            path: '/favorites',
            builder: (_, __) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/cafe/:id',
            builder: (_, state) => CafeDetailScreen(
              cafeId: state.pathParameters['id']!,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('favorite-cafe-favorite-detail-cafe')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('favorite-cafe-favorite-detail-cafe')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CafeDetailScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CafeDetailScreen),
          matching: find.text('Favorite Detail Cafe'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('show on the map opens map with the cafe selected',
        (tester) async {
      final cafes = [
        buildTestCafe(
          id: 'cafe-1',
          name: 'Cafe One',
        ).copyWith(coordinates: _testCafeMapCenter),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          currentUser: testUser,
          currentLocation: _testCafeMapCenter,
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
            path: '/map',
            builder: (_, state) => MapScreen(
              preserveInitialSelection:
                  state.queryParameters['focusCafeId']?.isNotEmpty == true,
              hasMapsConfigOverride: true,
              imageProviderBuilder: (_) => transparentImageProvider,
              mapLayerBuilder: (
                context,
                cafes,
                selectedCafeId,
                onTapMarker,
                onTapMap,
              ) {
                return ColoredBox(
                  color: Colors.black12,
                  child: Center(
                    child: Text('selected:$selectedCafeId'),
                  ),
                );
              },
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(CafeDetailScreen)))!;
      await tester.scrollUntilVisible(
        find.text(l10n.cafeDetailOpenOnMap),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final openOnMapAction = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text(l10n.cafeDetailOpenOnMap),
              matching: find.byType(InkWell),
            )
            .first,
      );
      openOnMapAction.onTap!();
      await tester.pumpAndSettle();

      expect(find.byType(MapScreen), findsOneWidget);
      expect(container.read(selectedCafeIdProvider), 'cafe-1');
      expect(find.text('selected:cafe-1'), findsOneWidget);
      expect(find.byKey(const ValueKey('map-selected-sheet-cafe-1')),
          findsOneWidget);
    });

    testWidgets('cafe detail screen shows localized empty hours copy',
        (tester) async {
      final cafes = [
        buildTestCafe(
          id: 'cafe-1',
          name: 'Cafe One',
        ),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(cafes: cafes, currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-1'),
        ),
      );
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(CafeDetailScreen)))!;
      await tester.scrollUntilVisible(
        find.text(l10n.cafeDetailHoursEmpty),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.cafeDetailHoursEmpty), findsOneWidget);
      expect(find.text(l10n.commonClosed.toUpperCase()), findsNothing);
    });

    testWidgets('sponsored cafe card applies premium border treatment',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 360,
                child: CafeCard(
                  cafe: buildTestCafe(
                    id: 'sponsored-1',
                    name: 'Sponsored One',
                  ).copyWith(isFeatured: true),
                  isFavorite: false,
                  inCompare: false,
                  onPress: () {},
                  onFavoritePress: () {},
                  onComparePress: () {},
                  colors: lightColors,
                  sponsoredLabel: 'Sponsored',
                ),
              ),
            ),
          ),
        ),
      );

      final card = tester.widget<GestureDetector>(
        find.byKey(const ValueKey('cafe-card-sponsored-1')),
      );
      final containerWidget = card.child! as Container;
      final decoration = containerWidget.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      expect(border.top.width, 2.4);
      expect(border.top.color, isNot(lightColors.border));
      expect(decoration.color, isNot(lightColors.card));
      expect(decoration.boxShadow, hasLength(2));
      expect(decoration.boxShadow?.first.blurRadius, 24);
    });

    testWidgets('normal cafe card keeps standard border treatment',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 360,
                child: CafeCard(
                  cafe: buildTestCafe(id: 'normal-1', name: 'Normal One'),
                  isFavorite: false,
                  inCompare: false,
                  onPress: () {},
                  onFavoritePress: () {},
                  onComparePress: () {},
                  colors: lightColors,
                ),
              ),
            ),
          ),
        ),
      );

      final card = tester.widget<GestureDetector>(
        find.byKey(const ValueKey('cafe-card-normal-1')),
      );
      final containerWidget = card.child! as Container;
      final decoration = containerWidget.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      expect(border.top.width, 1.0);
      expect(border.top.color, lightColors.border);
    });
  });

  group('navigation consistency', () {
    testWidgets(
        'cafe detail route renders local content before remote enrichment completes',
        (tester) async {
      final remoteDetail = Completer<Cafe?>();
      final localCafe = buildTestCafe(id: 'cafe-1', name: 'Basic Cafe')
          .copyWith(description: '', images: const [], openingHours: const []);
      final enrichedCafe = buildTestCafe(
        id: 'cafe-1',
        name: 'Detailed Cafe',
      ).copyWith(description: 'Freshly enriched detail');
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchCafeDetails: (cafeId, fallback, cancellationToken) async {
          return remoteDetail.future;
        },
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [localCafe],
          currentUser: testUser,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      router.go('/cafe/cafe-1');
      await tester.pump();
      await tester.pump();

      expect(find.byType(CafeDetailScreen), findsOneWidget);
      expect(find.text('Basic Cafe'), findsWidgets);
      expect(container.read(isCafeDetailLoadingProvider('cafe-1')), isTrue);

      remoteDetail.complete(enrichedCafe);
      await tester.pumpAndSettle();

      expect(find.text('Detailed Cafe'), findsWidgets);
      expect(find.text('Freshly enriched detail'), findsOneWidget);
      expect(container.read(isCafeDetailLoadingProvider('cafe-1')), isFalse);
      expect(container.read(cafeDetailErrorProvider('cafe-1')), isNull);
    });

    testWidgets(
        'cafe detail route shows route shell while unresolved cafes load and then fail honestly',
        (tester) async {
      final remoteDetail = Completer<Cafe?>();
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchCafeDetails: (cafeId, fallback, cancellationToken) async {
          return remoteDetail.future;
        },
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentUser: testUser,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      router.go('/cafe/missing-cafe');
      await tester.pump();
      await tester.pump();

      expect(find.byType(CafeDetailScreen), findsOneWidget);
      expect(
          container.read(isCafeDetailLoadingProvider('missing-cafe')), isTrue);

      remoteDetail.complete(null);
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(CafeDetailScreen)))!;
      expect(find.byType(CafeDetailScreen), findsOneWidget);
      expect(find.text(l10n.cafeDetailNotFound), findsOneWidget);
      expect(
          container.read(isCafeDetailLoadingProvider('missing-cafe')), isFalse);
      expect(container.read(cafeByIdProvider('missing-cafe')), isNull);
    });

    testWidgets('cafe detail back falls back to source route without stack',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Cafe One')],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/cafe/cafe-1?source=map',
        routes: [
          GoRoute(
            path: '/explore',
            builder: (_, __) => const Text('Explore Route'),
          ),
          GoRoute(
            path: '/map',
            builder: (_, __) => const Text('Map Route'),
          ),
          GoRoute(
            path: '/favorites',
            builder: (_, __) => const Text('Favorites Route'),
          ),
          GoRoute(
            path: '/cafe/:id',
            builder: (_, state) => CafeDetailScreen(
              cafeId: state.pathParameters['id']!,
              source: state.queryParameters['source'],
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cafe-detail-back-button')));
      await tester.pumpAndSettle();

      expect(find.text('Map Route'), findsOneWidget);
    });

    testWidgets(
        'compare state stays correct across compare, home, explore, and map routes',
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

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(NavigationBar)))!;

      expect(find.byKey(const Key('shell-compare-fab')), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(
                find.byKey(const Key('shell-compare-fab')))
            .backgroundColor,
        const Color(0xFF181512),
      );
      final compareFab = tester.widget<FloatingActionButton>(
        find.byKey(const Key('shell-compare-fab')),
      );
      expect(compareFab.foregroundColor, isNot(Colors.white));
      expect(
        tester
            .widget<FloatingActionButton>(
                find.byKey(const Key('shell-compare-fab')))
            .tooltip,
        l10n.compareSelectedCount(2),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('shell-compare-fab')),
          matching: find.byKey(const Key('shell-compare-fab-count-text')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('shell-compare-fab')),
          matching: find.text(l10n.compareSelectedCount(2)),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('shell-compare-fab')),
          matching: find.byKey(const Key('shell-compare-fab-icon-badge')),
        ),
        findsOneWidget,
      );
      final compareIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('shell-compare-fab-icon-badge')),
          matching: find.byIcon(Icons.compare_arrows_rounded),
        ),
      );
      expect(compareIcon.color, const Color(0xFF181512));
      final compareIconBadge = tester.widget<Container>(
        find.byKey(const Key('shell-compare-fab-icon-badge')),
      );
      final badgeDecoration = compareIconBadge.decoration as BoxDecoration;
      expect(badgeDecoration.color,
          compareFab.foregroundColor?.withValues(alpha: 0.92));
      expect(
        find.descendant(
          of: find.byKey(const Key('shell-compare-fab')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('shell-compare-fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('compare-remove-cafe-2')));
      await tester.pumpAndSettle();

      expect(find.text('Cafe Two'), findsNothing);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-compare-fab')), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(
                find.byKey(const Key('shell-compare-fab')))
            .tooltip,
        l10n.compareSelectedCount(1),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('shell-compare-fab')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.explore_outlined));
      await tester.pumpAndSettle();

      expect(find.text(l10n.cafeCardCompared), findsOneWidget);
      expect(find.text(l10n.cafeCardCompare), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-compare-fab')), findsNothing);

      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-compare-fab')), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(
                find.byKey(const Key('shell-compare-fab')))
            .tooltip,
        l10n.compareSelectedCount(1),
      );
      expect(
        container.read(compareListProvider),
        const ['cafe-1'],
      );
    });

    testWidgets(
        'bottom navigation edge destinations stay inset from the outer container on mobile widths',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cafes = [
        buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      final navRect =
          tester.getRect(find.byKey(const Key('shell-bottom-nav-container')));
      final homeRect = tester.getRect(find.byIcon(Icons.home_rounded));
      final profileRect = tester.getRect(find.byIcon(Icons.person_outline));

      expect(homeRect.left, greaterThan(navRect.left + 8));
      expect(profileRect.right, lessThan(navRect.right - 8));
    });

    testWidgets('reselecting Home tab emits scroll-to-top signal',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Cafe One')],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      final before = container.read(homeScrollToTopSignalProvider);
      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pump();

      expect(container.read(homeScrollToTopSignalProvider), before + 1);
    });

    testWidgets('reselecting Explore tab emits scroll-to-top signal',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'cafe-1', name: 'Cafe One')],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        buildTestRouterApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.explore_outlined));
      await tester.pumpAndSettle();

      final before = container.read(exploreScrollToTopSignalProvider);
      await tester.tap(find.byIcon(Icons.explore_rounded));
      await tester.pump();

      expect(container.read(exploreScrollToTopSignalProvider), before + 1);
      expect(router.routeInformationProvider.value.uri.path, '/explore');
    });
  });
}

class _MapHost extends StatefulWidget {
  const _MapHost({
    required this.childBuilder,
  });

  final Widget Function() childBuilder;

  @override
  State<_MapHost> createState() => _MapHostState();
}

class _MapHostState extends State<_MapHost> {
  bool _showMap = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          key: const Key('toggle-map-host'),
          onPressed: () => setState(() {
            _showMap = !_showMap;
          }),
          child: const Text('Toggle'),
        ),
        Expanded(
          child: _showMap ? widget.childBuilder() : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
