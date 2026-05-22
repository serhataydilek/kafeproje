import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/retry.dart';
import 'package:kafeproje/utils/request_cancellation.dart';
import 'package:kafeproje/utils/service_error.dart';

void main() {
  group('retryAsync', () {
    test('retries transient failures until success', () async {
      var attempts = 0;

      final result = await retryAsync(
        () async {
          attempts++;
          if (attempts < 3) {
            throw Exception('transient');
          }
          return 'ok';
        },
        maxAttempts: 3,
        initialDelay: Duration.zero,
        shouldRetry: (_) => true,
      );

      expect(result, 'ok');
      expect(attempts, 3);
    });

    test('rethrows immediately when shouldRetry returns false', () async {
      var attempts = 0;

      await expectLater(
        () => retryAsync<int>(
          () async {
            attempts++;
            throw StateError('permanent');
          },
          maxAttempts: 3,
          initialDelay: Duration.zero,
          shouldRetry: (_) => false,
        ),
        throwsA(isA<StateError>()),
      );

      expect(attempts, 1);
    });

    test('stops retrying after maxAttempts', () async {
      var attempts = 0;

      await expectLater(
        () => retryAsync<int>(
          () async {
            attempts++;
            throw Exception('still failing');
          },
          maxAttempts: 2,
          initialDelay: Duration.zero,
          shouldRetry: (_) => true,
        ),
        throwsException,
      );

      expect(attempts, 2);
    });

    test('stops immediately when the request is cancelled', () async {
      final controller = RequestCancellationController();
      var attempts = 0;

      await expectLater(
        () => retryAsync<int>(
          () async {
            attempts++;
            controller.cancel('superseded');
            controller.token.throwIfCancelled();
            return 1;
          },
          maxAttempts: 3,
          initialDelay: Duration.zero,
          shouldRetry: (_) => true,
          cancellationToken: controller.token,
        ),
        throwsA(
          isA<AppServiceException>().having(
            (error) => error.type,
            'type',
            ServiceErrorType.cancelled,
          ),
        ),
      );

      expect(attempts, 1);
    });
  });
}
