import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/screens/explore_screen.dart';
import 'package:kafeproje/utils/filter_sort.dart';

import 'test_helpers.dart';

void main() {
  group('nearest sorting', () {
    test(
        'sortCafes orders by real distance and sends placeholder coordinates last',
        () {
      const userLocation = Coordinates(lat: 41.0, lng: 29.0);
      final cafes = [
        buildTestCafe(
          id: 'far-cafe',
          name: 'Far Cafe',
        ).copyWith(
          coordinates: const Coordinates(lat: 41.12, lng: 29.12),
        ),
        buildTestCafe(
          id: 'unknown-cafe',
          name: 'Unknown Cafe',
        ).copyWith(
          coordinates: const Coordinates(lat: 41.0082, lng: 28.9784),
        ),
        buildTestCafe(
          id: 'near-cafe',
          name: 'Near Cafe',
        ).copyWith(
          coordinates: const Coordinates(lat: 41.002, lng: 29.001),
        ),
      ];

      final sorted = sortCafes(cafes, SortOption.nearest, userLocation);

      expect(sorted.map((cafe) => cafe.id).toList(), [
        'near-cafe',
        'far-cafe',
        'unknown-cafe',
      ]);
    });

    testWidgets('explore screen applies nearest ordering to the rendered list',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const userLocation = Coordinates(lat: 41.0, lng: 29.0);
      final cafes = [
        buildTestCafe(
          id: 'far-cafe',
          name: 'Far Cafe',
        ).copyWith(
          coordinates: const Coordinates(lat: 41.12, lng: 29.12),
        ),
        buildTestCafe(
          id: 'near-cafe',
          name: 'Near Cafe',
        ).copyWith(
          coordinates: const Coordinates(lat: 41.002, lng: 29.001),
        ),
        buildTestCafe(
          id: 'unknown-cafe',
          name: 'Unknown Cafe',
        ).copyWith(
          coordinates: const Coordinates(lat: 41.0082, lng: 28.9784),
        ),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          currentLocation: userLocation,
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ExploreScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nearest'));
      await tester.pumpAndSettle();

      final nearRect = tester.getRect(
        find.byKey(const ValueKey('explore-cafe-near-cafe')),
      );
      final farRect = tester.getRect(
        find.byKey(const ValueKey('explore-cafe-far-cafe')),
      );
      final resultsScrollable = find.byType(Scrollable).last;
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('explore-cafe-unknown-cafe')),
        resultsScrollable,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final unknownRect = tester.getRect(
        find.byKey(const ValueKey('explore-cafe-unknown-cafe')),
      );

      expect(nearRect.top, lessThan(farRect.top));
      expect(unknownRect.top, greaterThanOrEqualTo(0));
    });
  });
}
