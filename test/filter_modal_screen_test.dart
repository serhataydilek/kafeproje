import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/screens/filter_modal_screen.dart';

import 'test_helpers.dart';

void main() {
  group('Filter modal', () {
    testWidgets(
      'shows localized labels and resets clearly',
      (tester) async {
        final container = createTestContainer(
          state: buildTestAppShellState(
            filters: const Filters(district: 'Levent'),
          ),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const FilterModalScreen(scope: FilterModalScope.explore),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('filters-back-button')), findsOneWidget);
        expect(find.byKey(const Key('filters-apply-button')), findsOneWidget);
        expect(find.text('Cafe'), findsOneWidget);
        expect(find.text('Cafe lounge'), findsOneWidget);
        expect(find.text('Rating 3.0+'), findsOneWidget);
        expect(find.text('Rating 4.5+'), findsOneWidget);

        final resetButtonFinder = find.byKey(const Key('filters-reset-button'));
        expect(resetButtonFinder, findsOneWidget);
        expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);

        final resetButton = tester.widget<OutlinedButton>(resetButtonFinder);
        expect(resetButton.onPressed, isNotNull);

        await tester.tap(resetButtonFinder);
        await tester.pumpAndSettle();

        expect(find.text('Apply (1 filters)'), findsNothing);
        expect(find.text('Apply'), findsOneWidget);

        final applyButton = tester.widget<FilledButton>(
          find.byKey(const Key('filters-apply-button')),
        );
        expect(applyButton.onPressed, isNotNull);
      },
    );

    testWidgets('saves a named preset from current filter draft',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          filters: const Filters(district: 'Levent'),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const FilterModalScreen(scope: FilterModalScope.explore),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('filter-preset-name-input')),
        'Levent Focus',
      );
      await tester.tap(find.byKey(const Key('filter-preset-save-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter-preset-row-0')), findsOneWidget);
    });

    testWidgets('applies a preset and updates explore filter state',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          filters: const Filters(district: 'Levent'),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const FilterModalScreen(scope: FilterModalScope.explore),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('filter-preset-name-input')),
        'Levent Focus',
      );
      await tester.tap(find.byKey(const Key('filter-preset-save-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filters-reset-button')));
      await tester.pumpAndSettle();

      expect(container.read(exploreFiltersProvider).district, 'Levent');

      await tester.tap(find.byKey(const Key('filter-preset-apply-0')));
      await tester.pumpAndSettle();

      final filters = container.read(exploreFiltersProvider);
      expect(filters.district, 'Levent');
      expect(filters.activeCount, greaterThan(0));
    });

    testWidgets('overwrites existing preset by name and updates payload',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          filters: const Filters(district: 'Levent'),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const FilterModalScreen(scope: FilterModalScope.explore),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('filter-preset-name-input')),
        'Focus',
      );
      await tester.tap(find.byKey(const Key('filter-preset-save-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cafe lounge').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('filter-preset-name-input')),
        'Focus',
      );
      await tester.tap(find.byKey(const Key('filter-preset-save-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter-preset-row-0')), findsOneWidget);
      expect(find.byKey(const Key('filter-preset-row-1')), findsNothing);

      await tester.tap(find.byKey(const Key('filters-reset-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-preset-apply-0')));
      await tester.pumpAndSettle();

      final filters = container.read(exploreFiltersProvider);
      expect(filters.district, 'Levent');
      expect(filters.category, CafeCategory.cafeLounge);
    });

    testWidgets('deletes a saved preset', (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          filters: const Filters(district: 'Levent'),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const FilterModalScreen(scope: FilterModalScope.explore),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('filter-preset-name-input')),
        'Delete Me',
      );
      await tester.tap(find.byKey(const Key('filter-preset-save-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter-preset-row-0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter-preset-delete-0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter-preset-row-0')), findsNothing);
    });

    testWidgets('resetting filters does not remove saved presets',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          filters: const Filters(district: 'Levent'),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const FilterModalScreen(scope: FilterModalScope.explore),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('filter-preset-name-input')),
        'Keep Me',
      );
      await tester.tap(find.byKey(const Key('filter-preset-save-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filters-reset-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter-preset-row-0')), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('prevents invalid preset naming and empty preset saves',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          filters: const Filters(district: 'Levent'),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const FilterModalScreen(scope: FilterModalScope.explore),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter-preset-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Preset name cannot be empty.'), findsOneWidget);
      expect(find.byKey(const Key('filter-preset-row-0')), findsNothing);

      await tester.tap(find.byKey(const Key('filters-reset-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('filter-preset-name-input')),
        'Empty Draft',
      );
      await tester.tap(find.byKey(const Key('filter-preset-save-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Add at least one filter before saving a preset.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('filter-preset-row-0')), findsNothing);
    });
  });
}
