import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    testWidgets('only runs the latest scheduled callback', (tester) async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      var callCount = 0;
      var latestValue = '';

      debouncer(() {
        callCount++;
        latestValue = 'first';
      });
      await tester.pump(const Duration(milliseconds: 60));

      debouncer(() {
        callCount++;
        latestValue = 'second';
      });

      await tester.pump(const Duration(milliseconds: 99));
      expect(callCount, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(callCount, 1);
      expect(latestValue, 'second');

      debouncer.dispose();
    });

    testWidgets('dispose cancels any pending callback', (tester) async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var callCount = 0;

      debouncer(() => callCount++);
      debouncer.dispose();

      await tester.pump(const Duration(milliseconds: 60));
      expect(callCount, 0);
    });
  });
}
