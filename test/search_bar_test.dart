import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/theme/app_theme.dart';
import 'package:kafeproje/widgets/ui/search_bar.dart';

void main() {
  testWidgets('clear action appears for active input and resets value', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    String latestValue = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchBar(
            controller: controller,
            colors: lightColors,
            hintText: 'Search',
            onChanged: (value) => latestValue = value,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.enterText(find.byType(TextField), 'espresso');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(controller.text, isEmpty);
    expect(latestValue, isEmpty);
  });

  testWidgets('filter action and active-count badge render as expected', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    var filterTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchBar(
            controller: controller,
            colors: lightColors,
            hintText: 'Search',
            activeFilterCount: 3,
            filterButtonKey: const Key('search-filter'),
            onFilterTap: () => filterTapped = true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-filter')));
    await tester.pumpAndSettle();

    expect(filterTapped, isTrue);
  });
}
