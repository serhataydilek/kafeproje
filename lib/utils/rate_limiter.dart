class RateLimiter {
  RateLimiter({
    this.minInterval = const Duration(seconds: 2),
    Map<String, Duration>? bucketIntervals,
    DateTime Function()? clock,
  })  : _bucketIntervals = Map.unmodifiable(bucketIntervals ?? const {}),
        _clock = clock ?? DateTime.now;

  final Duration minInterval;
  final Map<String, Duration> _bucketIntervals;
  final DateTime Function() _clock;
  final Map<String, DateTime> _lastCallAt = {};

  bool tryAcquire(
    String key, {
    String? bucket,
    Duration? minIntervalOverride,
  }) {
    final now = _clock();
    final namespacedKey = bucket == null ? key : '$bucket::$key';
    final effectiveInterval =
        minIntervalOverride ?? (bucket == null ? null : _bucketIntervals[bucket]) ?? minInterval;
    final lastCall = _lastCallAt[namespacedKey];
    if (lastCall != null && now.difference(lastCall) < effectiveInterval) {
      return false;
    }
    _lastCallAt[namespacedKey] = now;
    return true;
  }

  void release(String key, {String? bucket}) {
    _lastCallAt.remove(bucket == null ? key : '$bucket::$key');
  }

  void reset() {
    _lastCallAt.clear();
  }

  void dispose() {
    reset();
  }
}
