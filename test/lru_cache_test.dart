import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/lru_cache.dart';

void main() {
  group('LruCache', () {
    test('evicts the least recently used entry', () {
      final cache = LruCache<String, int>(maxSize: 2);

      cache.put('a', 1);
      cache.put('b', 2);
      expect(cache.keys, orderedEquals(['a', 'b']));

      expect(cache.get('a'), 1);
      cache.put('c', 3);

      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('c'), isTrue);
      expect(cache.keys, orderedEquals(['a', 'c']));
      expect(cache.length, 2);
    });

    test('updating an existing key refreshes recency without growing size', () {
      final cache = LruCache<String, int>(maxSize: 2);

      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('a', 10);
      cache.put('c', 3);

      expect(cache.get('a'), 10);
      expect(cache.containsKey('b'), isFalse);
      expect(cache.keys, orderedEquals(['c', 'a']));
      expect(cache.length, 2);
    });

    test('clear removes all entries', () {
      final cache = LruCache<String, int>(maxSize: 2);

      cache.put('a', 1);
      cache.put('b', 2);
      cache.clear();

      expect(cache.length, 0);
      expect(cache.keys, isEmpty);
      expect(cache.values, isEmpty);
    });

    test('expired entries are evicted on access', () {
      var now = DateTime.utc(2026, 3, 29, 12);
      final cache = LruCache<String, int>(
        maxSize: 2,
        defaultTtl: const Duration(minutes: 5),
        clock: () => now,
      );

      cache.put('a', 1);
      expect(cache.get('a'), 1);

      now = now.add(const Duration(minutes: 6));

      expect(cache.get('a'), isNull);
      expect(cache.containsKey('a'), isFalse);
      expect(cache.length, 0);
    });
  });
}
