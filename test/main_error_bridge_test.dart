import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/main.dart';

void main() {
  group('buildPlatformErrorBridgeHandler', () {
    test('returns handled when an existing handler already handled error', () {
      var forwarded = false;
      final handler = buildPlatformErrorBridgeHandler(
        existingHandler: (_, __) => true,
        onUnhandledError: (_, __) {
          forwarded = true;
        },
      );

      final handled = handler(Exception('boom'), StackTrace.current);

      expect(handled, isTrue);
      expect(forwarded, isFalse);
    });

    test('forwards unhandled errors and marks them handled', () {
      var forwarded = false;
      final handler = buildPlatformErrorBridgeHandler(
        existingHandler: (_, __) => false,
        onUnhandledError: (_, __) {
          forwarded = true;
        },
      );

      final handled = handler(Exception('boom'), StackTrace.current);

      expect(handled, isTrue);
      expect(forwarded, isTrue);
    });

    test('forwards errors when no existing handler is installed', () {
      var forwarded = false;
      final handler = buildPlatformErrorBridgeHandler(
        onUnhandledError: (_, __) {
          forwarded = true;
        },
      );

      final handled = handler(Exception('boom'), StackTrace.current);

      expect(handled, isTrue);
      expect(forwarded, isTrue);
    });
  });
}
