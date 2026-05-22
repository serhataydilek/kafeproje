import 'dart:async';

import 'request_cancellation.dart';

Future<T> retryAsync<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
  double backoffMultiplier = 2.0,
  bool Function(Object error)? shouldRetry,
  RequestCancellationToken? cancellationToken,
}) async {
  assert(maxAttempts > 0);
  assert(backoffMultiplier >= 1);

  var delay = initialDelay;
  Object? lastError;
  StackTrace? lastStackTrace;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    cancellationToken?.throwIfCancelled();
    try {
      return await action();
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      final canRetry =
          attempt < maxAttempts && (shouldRetry?.call(error) ?? false);
      if (!canRetry) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      cancellationToken?.throwIfCancelled();
      await Future<void>.delayed(delay);
      cancellationToken?.throwIfCancelled();
      final nextDelayMs =
          (delay.inMilliseconds * backoffMultiplier).round().clamp(1, 60000);
      delay = Duration(milliseconds: nextDelayMs);
    }
  }

  Error.throwWithStackTrace(
    lastError ?? StateError('retryAsync failed without capturing an error.'),
    lastStackTrace ?? StackTrace.current,
  );
}
