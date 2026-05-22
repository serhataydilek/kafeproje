class InflightRequestRegistry<T> {
  final Map<String, Future<T>> _inflight = <String, Future<T>>{};

  Future<T> run(
    String key,
    Future<T> Function() action,
  ) {
    final existing = _inflight[key];
    if (existing != null) {
      return existing;
    }

    final future = action();
    _inflight[key] = future;
    future.whenComplete(() {
      if (identical(_inflight[key], future)) {
        _inflight.remove(key);
      }
    });
    return future;
  }

  bool contains(String key) => _inflight.containsKey(key);

  void clear() => _inflight.clear();
}
