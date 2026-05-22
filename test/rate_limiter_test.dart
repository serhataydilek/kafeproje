import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    test('acquire throttles repeated calls within the interval', () {
      final limiter =
          RateLimiter(minInterval: const Duration(milliseconds: 50));

      expect(limiter.tryAcquire('fetch'), isTrue);
      expect(limiter.tryAcquire('fetch'), isFalse);
    });

    test('release allows immediate retry after a failure', () {
      final limiter = RateLimiter(minInterval: const Duration(seconds: 1));

      expect(limiter.tryAcquire('fetch'), isTrue);
      limiter.release('fetch');
      expect(limiter.tryAcquire('fetch'), isTrue);
    });

    test('reset clears all throttled keys', () {
      final limiter = RateLimiter(minInterval: const Duration(seconds: 1));

      expect(limiter.tryAcquire('a'), isTrue);
      expect(limiter.tryAcquire('b'), isTrue);
      expect(limiter.tryAcquire('a'), isFalse);

      limiter.reset();

      expect(limiter.tryAcquire('a'), isTrue);
      expect(limiter.tryAcquire('b'), isTrue);
    });

    test('acquire succeeds again after the minimum interval passes', () async {
      final limiter =
          RateLimiter(minInterval: const Duration(milliseconds: 10));

      expect(limiter.tryAcquire('fetch'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(limiter.tryAcquire('fetch'), isTrue);
    });
  });
}
