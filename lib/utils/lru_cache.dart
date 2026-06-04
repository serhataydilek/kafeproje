import 'dart:collection';

class LruCache<K, V> {
  LruCache({
    this.maxSize = 100,
    this.defaultTtl,
    DateTime Function()? clock,
  })  : assert(maxSize > 0),
        _clock = clock ?? DateTime.now;

  final int maxSize;
  final Duration? defaultTtl;
  final DateTime Function() _clock;
  final LinkedHashMap<K, _LruCacheEntry<V>> _entries =
      LinkedHashMap<K, _LruCacheEntry<V>>();

  int get length {
    _purgeExpired();
    return _entries.length;
  }

  bool containsKey(K key) {
    _purgeExpiredKey(key);
    return _entries.containsKey(key);
  }

  Iterable<K> get keys {
    _purgeExpired();
    return _entries.keys;
  }

  V? get(K key) {
    final entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }
    if (_isExpired(entry)) {
      return null;
    }
    _entries[key] = entry;
    return entry.value;
  }

  V? peek(K key) {
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }
    if (_isExpired(entry)) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  void put(K key, V value, {Duration? ttl}) {
    _purgeExpired();
    _entries.remove(key);
    _entries[key] = _LruCacheEntry(
      value: value,
      expiresAt: _resolveExpiry(ttl),
    );
    if (_entries.length > maxSize) {
      _entries.remove(_entries.keys.first);
    }
  }

  V? remove(K key) {
    return _entries.remove(key)?.value;
  }

  Iterable<MapEntry<K, V>> get entries {
    _purgeExpired();
    return _entries.entries
        .map((entry) => MapEntry(entry.key, entry.value.value));
  }

  Iterable<V> get values {
    _purgeExpired();
    return _entries.values.map((entry) => entry.value);
  }

  void clear() {
    _entries.clear();
  }

  DateTime? _resolveExpiry(Duration? ttl) {
    final effectiveTtl = ttl ?? defaultTtl;
    if (effectiveTtl == null) {
      return null;
    }
    return _clock().add(effectiveTtl);
  }

  bool _isExpired(_LruCacheEntry<V> entry) {
    final expiresAt = entry.expiresAt;
    return expiresAt != null && !_clock().isBefore(expiresAt);
  }

  void _purgeExpired() {
    final expiredKeys = <K>[];
    for (final entry in _entries.entries) {
      if (_isExpired(entry.value)) {
        expiredKeys.add(entry.key);
      }
    }
    for (final key in expiredKeys) {
      _entries.remove(key);
    }
  }

  void _purgeExpiredKey(K key) {
    final entry = _entries[key];
    if (entry != null && _isExpired(entry)) {
      _entries.remove(key);
    }
  }
}

class _LruCacheEntry<V> {
  const _LruCacheEntry({
    required this.value,
    required this.expiresAt,
  });

  final V value;
  final DateTime? expiresAt;
}
