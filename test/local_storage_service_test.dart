import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kafeproje/models/cafe_cache.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/services/local_storage_service.dart';

import 'test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    await Hive.close();
    tempDir = await Directory.systemTemp.createTemp(
      'kafeproje-local-storage-test-',
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LocalStorageService encryption key selection', () {
    test('reuses a valid key already stored in secure storage', () async {
      final storedKey = Uint8List.fromList(
        List<int>.generate(32, (index) => index, growable: false),
      );
      final store = _FakeSecureKeyValueStore(
        initial: {
          'app_state_encryption_key_v2': base64Encode(storedKey),
        },
      );

      final selectedKey =
          await LocalStorageService.selectEncryptionKeyForTesting(
        keyStore: store,
        canOpenWithKey: (key) async => _matchesKey(key, storedKey),
      );

      expect(_matchesKey(selectedKey, storedKey), isTrue);
      expect(store.writes, isEmpty);
    });

    test('migrates the legacy key into secure storage when needed', () async {
      final store = _FakeSecureKeyValueStore();
      const seed = 'kafeproje_hive_enc_key_v1_pad_32';
      final legacyKey = Uint8List.fromList(
        List<int>.generate(
          32,
          (index) => seed.codeUnitAt(index % seed.length),
          growable: false,
        ),
      );

      final selectedKey =
          await LocalStorageService.selectEncryptionKeyForTesting(
        keyStore: store,
        canOpenWithKey: (key) async => _matchesKey(key, legacyKey),
      );

      expect(_matchesKey(selectedKey, legacyKey), isTrue);
      expect(store.writes.length, 1);
      expect(store.writes.single.key, 'app_state_encryption_key_v2');
    });

    test('generates and stores a fresh random key for new installs', () async {
      final store = _FakeSecureKeyValueStore();

      final selectedKey =
          await LocalStorageService.selectEncryptionKeyForTesting(
        keyStore: store,
        canOpenWithKey: (_) async => false,
      );

      expect(selectedKey.length, 32);
      expect(store.writes.length, 1);
      final persisted = base64Decode(store.writes.single.value);
      expect(_matchesKey(selectedKey, Uint8List.fromList(persisted)), isTrue);
    });
  });

  group('LocalStorageService open', () {
    test('migrates an existing plaintext box into encrypted storage', () async {
      Hive.init(tempDir.path);
      final legacyBox = await Hive.openBox<dynamic>('app_state');
      await legacyBox.put('locale_mode', 'tr');
      await legacyBox.put('favorites:guest', ['cafe-1', 'cafe-2']);
      await legacyBox.close();
      await Hive.close();

      final store = _FakeSecureKeyValueStore();
      final service = await LocalStorageService.open(
        secureKeyStore: store,
        hiveInitializer: () async => Hive.init(tempDir.path),
      );

      expect(await service.loadLocaleMode(), 'tr');
      expect(await service.loadFavorites('guest'), ['cafe-1', 'cafe-2']);
      expect(store.writes, isNotEmpty);

      await Hive.close();
      Hive.init(tempDir.path);
      final persistedKey = Uint8List.fromList(
        base64Decode(store.writes.last.value),
      );
      final reopenedBox = await Hive.openBox<dynamic>(
        'app_state',
        encryptionCipher: HiveAesCipher(persistedKey),
      );
      expect(reopenedBox.get('locale_mode'), 'tr');
      expect(reopenedBox.get('__meta:encrypted_box_v1'), isTrue);
    });

    test('recreates a fresh encrypted box when the stored key is lost',
        () async {
      final originalKey = Uint8List.fromList(
        List<int>.generate(32, (index) => (index * 7) % 256, growable: false),
      );
      Hive.init(tempDir.path);
      final encryptedBox = await Hive.openBox<dynamic>(
        'app_state',
        encryptionCipher: HiveAesCipher(originalKey),
      );
      await encryptedBox.put('locale_mode', 'tr');
      await encryptedBox.close();
      final metadataBox = await Hive.openBox<dynamic>('app_state_meta');
      await metadataBox.put('storage_mode', 'encrypted');
      await metadataBox.close();
      await Hive.close();

      final wrongKey = Uint8List.fromList(
        List<int>.generate(32, (index) => 255 - index, growable: false),
      );
      final store = _FakeSecureKeyValueStore(
        initial: {
          'app_state_encryption_key_v2': base64Encode(wrongKey),
        },
      );

      final service = await LocalStorageService.open(
        secureKeyStore: store,
        hiveInitializer: () async => Hive.init(tempDir.path),
      );

      expect(await service.loadLocaleMode(), isNull);
      expect(store.writes, isNotEmpty);
      final refreshedKey = base64Decode(store.writes.last.value);
      expect(_matchesKey(Uint8List.fromList(refreshedKey), wrongKey), isFalse);
      expect(
          _matchesKey(Uint8List.fromList(refreshedKey), originalKey), isFalse);
    });
  });

  group('LocalStorageService cafe list cache', () {
    test('keeps different cache keys isolated', () async {
      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('app_state');
      final service = LocalStorageService(box);

      final nearbyCafe = buildTestCafe(id: 'nearby-1', name: 'Nearby');
      final districtCafe = buildTestCafe(id: 'district-1', name: 'District');

      await service.saveCafeListCache(
        'nearby:key',
        [nearbyCafe],
        nextPageToken: 'next-nearby',
      );
      await service.saveCafeListCache(
        'district:key',
        [districtCafe],
        nextPageToken: 'next-district',
      );

      final nearbySnapshot = await service.loadCafeListCache('nearby:key');
      final districtSnapshot = await service.loadCafeListCache('district:key');

      expect(nearbySnapshot?.cacheKey, 'nearby:key');
      expect(nearbySnapshot?.cafes.single.id, nearbyCafe.id);
      expect(nearbySnapshot?.nextPageToken, 'next-nearby');
      expect(districtSnapshot?.cacheKey, 'district:key');
      expect(districtSnapshot?.cafes.single.id, districtCafe.id);
      expect(districtSnapshot?.nextPageToken, 'next-district');
    });

    test('resolves cached cafes by id/placeId across persisted list caches',
        () async {
      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('app_state');
      final service = LocalStorageService(box);

      final nearbyCafe = buildTestCafe(id: 'nearby-1', name: 'Nearby One');
      final farCafe = buildTestCafe(id: 'far-1', name: 'Far One')
          .copyWith(placeId: 'place-far-1');

      await service.saveCafeListCache('nearby:key', [nearbyCafe]);
      await service.saveCafeListCache('far:key', [farCafe]);

      final resolved = await service.resolveCachedCafesByIdentifiers([
        'place-far-1',
        'nearby-1',
      ]);

      expect(
        resolved.map((cafe) => cafe.id).toList(growable: false),
        ['far-1', 'nearby-1'],
      );

      final onlyFar = await service.resolveCachedCafesByIdentifiers([
        'place-far-1',
      ]);

      expect(
        onlyFar.map((cafe) => cafe.id).toList(growable: false),
        ['far-1'],
      );
    });

    test('replaceCafeInListCaches only updates matching cached lists',
        () async {
      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('app_state');
      final service = LocalStorageService(box);

      final targetCafe = buildTestCafe(id: 'shared', name: 'Old Name');
      final untouchedCafe = buildTestCafe(id: 'other', name: 'Other Cafe');

      await service.saveCafeListCache('list-a', [targetCafe]);
      await service.saveCafeListCache('list-b', [untouchedCafe]);

      final updatedCafe = buildTestCafe(id: 'shared', name: 'New Name');
      await service.replaceCafeInListCaches(updatedCafe);

      final listA = await service.loadCafeListCache('list-a');
      final listB = await service.loadCafeListCache('list-b');

      expect(listA?.cafes.single.name, 'New Name');
      expect(listB?.cafes.single.name, 'Other Cafe');
    });

    test('persists structured cache metadata alongside cached lists', () async {
      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('app_state');
      final service = LocalStorageService(box);
      final cafe = buildTestCafe(id: 'meta-cafe', name: 'Meta Cafe');
      final cachedAt = DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          );

      await service.saveCafeListCache(
        'meta-key',
        [cafe],
        cachedAt: cachedAt,
      );

      final snapshot = await service.loadCafeListCache('meta-key');

      expect(snapshot, isNotNull);
      expect(snapshot!.metadata.lastUpdated, cachedAt);
      expect(snapshot.metadata.source, CafeCacheDataSource.localCache);
      expect(snapshot.metadata.version, 1);
    });

    test('loads legacy cached lists even when timestamps are missing',
        () async {
      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('app_state');
      final service = LocalStorageService(box);
      final cafe = buildTestCafe(id: 'legacy-cafe', name: 'Legacy Cafe');

      await box.put('cafes:list:v4:legacy-key', {
        'cafes': [cafe.toJson()],
      });

      final snapshot = await service.loadCafeListCache('legacy-key');

      expect(snapshot, isNotNull);
      expect(snapshot!.cafes.single.id, 'legacy-cafe');
      expect(snapshot.metadata.lastUpdated, isNull);
      expect(snapshot.metadata.source, CafeCacheDataSource.unknown);
    });
  });

  group('LocalStorageService filter presets', () {
    test('saves and restores filter presets for a scope', () async {
      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('app_state');
      final service = LocalStorageService(box);
      final now = DateTime.utc(2026, 4, 3, 12, 0);

      final presets = [
        FilterPreset(
          id: 'preset-1',
          name: 'Kadikoy Focus',
          filters: const Filters(district: 'Kadikoy', minRating: 4.0),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await service.saveFilterPresets('explore:test-user', presets);
      final restored = await service.loadFilterPresets('explore:test-user');

      expect(restored, hasLength(1));
      expect(restored.first.id, 'preset-1');
      expect(restored.first.name, 'Kadikoy Focus');
      expect(restored.first.filters.district, 'Kadikoy');
      expect(restored.first.filters.minRating, 4.0);
    });

    test('keeps preset scopes isolated and sorted by recency', () async {
      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('app_state');
      final service = LocalStorageService(box);

      await service.saveFilterPresets('explore:user-a', [
        FilterPreset(
          id: 'older',
          name: 'Older',
          filters: const Filters(district: 'Levent'),
          createdAt: DateTime.utc(2026, 4, 3, 8),
          updatedAt: DateTime.utc(2026, 4, 3, 8),
        ),
        FilterPreset(
          id: 'newer',
          name: 'Newer',
          filters: const Filters(district: 'Kadikoy'),
          createdAt: DateTime.utc(2026, 4, 3, 10),
          updatedAt: DateTime.utc(2026, 4, 3, 10),
        ),
      ]);
      await service.saveFilterPresets('explore:user-b', [
        const FilterPreset(
          id: 'other-scope',
          name: 'Other Scope',
          filters: Filters(district: 'Sisli'),
        ),
      ]);

      final scoped = await service.loadFilterPresets('explore:user-a');
      final otherScoped = await service.loadFilterPresets('explore:user-b');

      expect(scoped.map((preset) => preset.id).toList(growable: false), [
        'newer',
        'older',
      ]);
      expect(otherScoped.single.id, 'other-scope');
    });
  });
}

bool _matchesKey(Uint8List left, Uint8List right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

class _FakeSecureKeyValueStore implements SecureKeyValueStore {
  _FakeSecureKeyValueStore({Map<String, String>? initial})
      : _values = {...?initial};

  final Map<String, String> _values;
  final List<({String key, String value})> writes = [];

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
    writes.add((key: key, value: value));
  }
}
