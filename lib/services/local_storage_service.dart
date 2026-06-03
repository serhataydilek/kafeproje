import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/cafe_cache.dart';
import '../models/index.dart';
import '../models/offline_queue_entry.dart';
import '../repositories/cafe_merge_policy.dart';
import '../utils/app_logger.dart';
import '../utils/cafe_media.dart';
import '../utils/cafe_cache_policy.dart';

/// Local data persistence using Hive with encryption for offline-first support.
///
/// **What It Stores**:
/// - Favorites: User's saved favorite cafe IDs
/// - Compare list: Cafes selected for comparison
/// - Locale preference: User's selected language (Turkish/English)
/// - Cafe cache: Full cafe data with metadata (addresses, ratings, etc.)
/// - Map view state: Last viewed map position and zoom
///
/// **Caching Strategy**:
/// - Cafe list cache: 24-hour TTL (refreshed daily)
/// - Cafe detail cache: Indefinite (refreshed on user request)
/// - Map view cache: 7-day TTL (preserved across sessions)
/// - Max detail entries: 36 cafes (LRU eviction if exceeded)
///
/// **Security**:
/// - Uses secure storage for encryption key
/// - Hive box encrypted with AES to protect cached user data
/// - Legacy plaintext boxes are migrated into encrypted storage
/// - Lost/invalid keys are recovered by recreating the encrypted box
///
/// **Offline Support**:
/// Available in offline mode for cached data (favorites, app state, cached
/// cafe listings). Downloads trigger refresh when connection is restored.
///
/// **Example**:
/// ```dart
/// final storage = await LocalStorageService.open();
///
/// await storage.saveCafeListCache(
///   'nearby:example',
///   cafes,
///   nextPageToken: 'page_2',
///   cachedAt: DateTime.now(),
/// );
/// ```
class LocalStorageService {
  /// Creates a local storage service wrapping a Hive encrypted box.
  LocalStorageService(this._box);

  static const _boxName = 'app_state';
  static const _metadataBoxName = 'app_state_meta';
  static const _encryptionKeyStorageKey = 'app_state_encryption_key_v2';
  static const _encryptionSentinelKey = '__meta:encrypted_box_v1';
  static const _storageModeKey = 'storage_mode';
  static const _encryptedStorageMode = 'encrypted';
  static const _favoritesPrefix = 'favorites:';
  static const _comparePrefix = 'compare:';
  static const _preferencesPrefix = 'preferences:';
  static const _filterPresetsPrefix = 'filter_presets:v1:';
  static const _localeModeKey = 'locale_mode';
  static const _cafeDiscoveryStateKey = 'cafes:discovery:v1';
  static const _districtCachePrefix = 'districts:config:v1:';
  static const _cafeListCachePrefix = 'cafes:list:v4:';
  static const _cafeDetailPrefix = 'cafes:detail:v3:';
  static const int _cafeCacheMetadataVersion = 1;
  static const _mapViewCacheKey = 'map:view:v1';
  static const _offlineQueueKey = 'offline:queue:v1';
  static const _offlineDeadLetterKey = 'offline:dead:v1';
  static const Duration _mapViewCacheMaxAge = Duration(days: 7);
  static const List<String> _legacyCafeListCacheKeys = [
    'cafes:list:v1',
    'cafes:list:v2',
    'cafes:list:v3',
  ];
  static const List<String> _legacyCafeDetailPrefixes = [
    'cafes:detail:',
    'cafes:detail:v2:',
  ];
  final Box<dynamic> _box;

  /// Legacy key kept only so existing installs can migrate to secure storage.
  static Uint8List _legacyEncryptionKey() {
    const seed = 'kafeproje_hive_enc_key_v1_pad_32';
    final bytes = Uint8List(32);
    final seedBytes = seed.codeUnits;
    for (var i = 0; i < 32; i++) {
      bytes[i] = seedBytes[i % seedBytes.length];
    }
    return bytes;
  }

  static Uint8List _generateEncryptionKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256), growable: false),
    );
  }

  static Future<LocalStorageService> open({
    SecureKeyValueStore? secureKeyStore,
    EncryptedHiveBoxOpener? boxOpener,
    PlainHiveBoxOpener? plainBoxOpener,
    HiveBoxResetter? boxResetter,
    HiveInitializer? hiveInitializer,
  }) async {
    await (hiveInitializer ?? Hive.initFlutter)();

    final keyStore = secureKeyStore ?? const FlutterSecureKeyValueStore();
    final openEncryptedBox = boxOpener ?? _openEncryptedHiveBox;
    final openPlainBox = plainBoxOpener ?? _openPlainHiveBox;
    final resetBox = boxResetter ?? _resetHiveBox;
    final boxPreviouslyExisted = await Hive.boxExists(_boxName);
    final hasEncryptedStorageMarker = await _hasEncryptedStorageMarker();

    final storedKey = await _readStoredEncryptionKey(keyStore);
    if (storedKey != null) {
      final box = await _tryOpenEncryptedBox(
        openEncryptedBox,
        storedKey,
        boxPreviouslyExisted: boxPreviouslyExisted,
      );
      if (box != null) {
        final service = LocalStorageService(box);
        await service._cleanupStorageFootprint();
        await _markEncryptedStorage();
        return service;
      }
    }

    Map<String, dynamic>? plaintextSnapshot;
    if (!hasEncryptedStorageMarker && boxPreviouslyExisted) {
      plaintextSnapshot = await _readPlaintextSnapshot(openPlainBox);
      if (plaintextSnapshot != null) {
        final newKey = _generateEncryptionKey();
        await _persistEncryptionKey(keyStore, newKey);
        final box = await _openFreshEncryptedBox(
          encryptionKey: newKey,
          openBox: openEncryptedBox,
          resetBox: resetBox,
          plaintextSnapshot: plaintextSnapshot,
        );
        final service = LocalStorageService(box);
        await service._cleanupStorageFootprint();
        await _markEncryptedStorage();
        return service;
      }
    }

    if (storedKey == null) {
      final legacyKey = _legacyEncryptionKey();
      final legacyBox = await _tryOpenEncryptedBox(
        openEncryptedBox,
        legacyKey,
        boxPreviouslyExisted: boxPreviouslyExisted,
      );
      if (legacyBox != null) {
        await _persistEncryptionKey(keyStore, legacyKey);
        final service = LocalStorageService(legacyBox);
        await service._cleanupStorageFootprint();
        await _markEncryptedStorage();
        return service;
      }
    }

    final newKey = _generateEncryptionKey();
    await _persistEncryptionKey(keyStore, newKey);

    final box = await _openFreshEncryptedBox(
      encryptionKey: newKey,
      openBox: openEncryptedBox,
      resetBox: resetBox,
      plaintextSnapshot: plaintextSnapshot,
    );
    final service = LocalStorageService(box);
    await service._cleanupStorageFootprint();
    await _markEncryptedStorage();
    return service;
  }

  static Future<Box<dynamic>> _openEncryptedHiveBox(Uint8List encryptionKey) {
    final cipher = HiveAesCipher(encryptionKey);
    return Hive.isBoxOpen(_boxName)
        ? Future<Box<dynamic>>.value(Hive.box<dynamic>(_boxName))
        : Hive.openBox<dynamic>(_boxName, encryptionCipher: cipher);
  }

  static Future<Box<dynamic>> _openPlainHiveBox() {
    return Hive.isBoxOpen(_boxName)
        ? Future<Box<dynamic>>.value(Hive.box<dynamic>(_boxName))
        : Hive.openBox<dynamic>(_boxName);
  }

  static Future<Box<dynamic>?> _tryOpenEncryptedBox(
    EncryptedHiveBoxOpener openBox,
    Uint8List encryptionKey, {
    required bool boxPreviouslyExisted,
  }) async {
    try {
      final box = await openBox(encryptionKey);
      if (!_looksLikeValidEncryptedBox(box, boxPreviouslyExisted)) {
        await box.close();
        await _closeBoxIfOpen();
        return null;
      }
      await _ensureEncryptionSentinel(box);
      return box;
    } catch (_) {
      await _closeBoxIfOpen();
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _readPlaintextSnapshot(
    PlainHiveBoxOpener openBox,
  ) async {
    if (!await Hive.boxExists(_boxName)) {
      return null;
    }

    try {
      final box = await openBox();
      final snapshot = <String, dynamic>{};
      for (final key in box.keys) {
        snapshot[key.toString()] = box.get(key);
      }
      await box.close();
      return snapshot;
    } catch (_) {
      await _closeBoxIfOpen();
      return null;
    }
  }

  static Future<Box<dynamic>> _openFreshEncryptedBox({
    required Uint8List encryptionKey,
    required EncryptedHiveBoxOpener openBox,
    required HiveBoxResetter resetBox,
    Map<String, dynamic>? plaintextSnapshot,
  }) async {
    if (plaintextSnapshot != null) {
      await resetBox();
    }

    try {
      final box = await openBox(encryptionKey);
      if (plaintextSnapshot != null && plaintextSnapshot.isNotEmpty) {
        await box.putAll(plaintextSnapshot);
      }
      await _ensureEncryptionSentinel(box);
      return box;
    } catch (_) {
      await resetBox();
      final box = await openBox(encryptionKey);
      if (plaintextSnapshot != null && plaintextSnapshot.isNotEmpty) {
        await box.putAll(plaintextSnapshot);
      }
      await _ensureEncryptionSentinel(box);
      return box;
    }
  }

  static bool _looksLikeValidEncryptedBox(
    Box<dynamic> box,
    bool boxPreviouslyExisted,
  ) {
    if (!boxPreviouslyExisted) {
      return true;
    }
    if (box.get(_encryptionSentinelKey) == true) {
      return true;
    }
    return box.keys.any((key) => key != _encryptionSentinelKey);
  }

  static Future<void> _ensureEncryptionSentinel(Box<dynamic> box) async {
    if (box.get(_encryptionSentinelKey) == true) {
      return;
    }
    await box.put(_encryptionSentinelKey, true);
  }

  static Future<void> _closeBoxIfOpen() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return;
    }
    await Hive.box<dynamic>(_boxName).close();
  }

  static Future<void> _resetHiveBox() async {
    await _closeBoxIfOpen();
    if (await Hive.boxExists(_boxName)) {
      await Hive.deleteBoxFromDisk(_boxName);
    }
  }

  static Future<bool> _hasEncryptedStorageMarker() async {
    final wasOpen = Hive.isBoxOpen(_metadataBoxName);
    if (!wasOpen && !await Hive.boxExists(_metadataBoxName)) {
      return false;
    }

    final box = wasOpen
        ? Hive.box<dynamic>(_metadataBoxName)
        : await Hive.openBox<dynamic>(_metadataBoxName);
    final mode = box.get(_storageModeKey) as String?;
    if (!wasOpen) {
      await box.close();
    }
    return mode == _encryptedStorageMode;
  }

  static Future<void> _markEncryptedStorage() async {
    final wasOpen = Hive.isBoxOpen(_metadataBoxName);
    final box = wasOpen
        ? Hive.box<dynamic>(_metadataBoxName)
        : await Hive.openBox<dynamic>(_metadataBoxName);
    await box.put(_storageModeKey, _encryptedStorageMode);
    if (!wasOpen) {
      await box.close();
    }
  }

  static Future<Uint8List?> _readStoredEncryptionKey(
    SecureKeyValueStore keyStore,
  ) async {
    final encoded = await keyStore.read(_encryptionKeyStorageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = base64Decode(encoded);
      if (decoded.length != 32) {
        return null;
      }
      return Uint8List.fromList(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _persistEncryptionKey(
    SecureKeyValueStore keyStore,
    Uint8List encryptionKey,
  ) {
    return keyStore.write(
      _encryptionKeyStorageKey,
      base64Encode(encryptionKey),
    );
  }

  @visibleForTesting
  static Future<Uint8List> selectEncryptionKeyForTesting({
    required SecureKeyValueStore keyStore,
    required Future<bool> Function(Uint8List encryptionKey) canOpenWithKey,
  }) {
    return _selectEncryptionKey(
      keyStore: keyStore,
      canOpenWithKey: canOpenWithKey,
    );
  }

  static Future<Uint8List> _selectEncryptionKey({
    required SecureKeyValueStore keyStore,
    required Future<bool> Function(Uint8List encryptionKey) canOpenWithKey,
  }) async {
    final storedKey = await _readStoredEncryptionKey(keyStore);
    if (storedKey != null && await canOpenWithKey(storedKey)) {
      return storedKey;
    }

    final legacyKey = _legacyEncryptionKey();
    if (await canOpenWithKey(legacyKey)) {
      await _persistEncryptionKey(keyStore, legacyKey);
      return legacyKey;
    }

    final newKey = _generateEncryptionKey();
    await _persistEncryptionKey(keyStore, newKey);
    return newKey;
  }

  /// Remove all cached cafe data (list + detail caches).
  Future<void> clearCafeCache() async {
    await clearCafeListCaches();
    final keysToDelete = _box.keys
        .where((key) => key is String && key.startsWith(_cafeDetailPrefix))
        .toList();
    for (final key in keysToDelete) {
      await _box.delete(key);
    }
  }

  String _favoritesKey(String scope) => '$_favoritesPrefix$scope';
  String _compareKey(String scope) => '$_comparePrefix$scope';
  String _preferencesKey(String scope) => '$_preferencesPrefix$scope';
  String _filterPresetsKey(String scope) => '$_filterPresetsPrefix$scope';
  String _districtCacheKey(String city) => '$_districtCachePrefix$city';
  String _cafeListKey(String cacheKey) => '$_cafeListCachePrefix$cacheKey';
  String _cafeDetailKey(String cafeId) => '$_cafeDetailPrefix$cafeId';

  Future<List<String>> loadFavorites(String scope) async {
    final raw = _box.get(_favoritesKey(scope));
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  Future<void> saveFavorites(String scope, List<String> favorites) async {
    await _box.put(_favoritesKey(scope), favorites);
  }

  Future<List<String>> loadCompareList(String scope) async {
    final raw = _box.get(_compareKey(scope));
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  Future<void> saveCompareList(String scope, List<String> compareList) async {
    await _box.put(_compareKey(scope), compareList);
  }

  Future<List<PreferenceKey>> loadPreferences(String scope) async {
    final raw = _box.get(_preferencesKey(scope));
    if (raw is! List) {
      return const <PreferenceKey>[];
    }

    return raw
        .whereType<String>()
        .map(PreferenceKeyExtension.fromString)
        .toList(growable: false);
  }

  Future<void> savePreferences(
    String scope,
    List<PreferenceKey> preferences,
  ) async {
    await _box.put(
      _preferencesKey(scope),
      preferences.map((item) => item.value).toList(growable: false),
    );
  }

  Future<List<FilterPreset>> loadFilterPresets(String scope) async {
    final raw = _box.get(_filterPresetsKey(scope));
    if (raw is! List) {
      return const <FilterPreset>[];
    }

    final presets = <FilterPreset>[];
    for (final item in raw) {
      final map = _asStringKeyedMap(item);
      if (map == null) {
        continue;
      }
      final preset = FilterPreset.fromJson(map);
      if (preset.id.isEmpty || preset.name.isEmpty) {
        continue;
      }
      presets.add(preset);
    }

    presets.sort((left, right) {
      final leftUpdated = left.updatedAt ?? left.createdAt;
      final rightUpdated = right.updatedAt ?? right.createdAt;
      if (leftUpdated == null && rightUpdated == null) {
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      }
      if (leftUpdated == null) {
        return 1;
      }
      if (rightUpdated == null) {
        return -1;
      }
      return rightUpdated.compareTo(leftUpdated);
    });

    return presets;
  }

  Future<void> saveFilterPresets(
    String scope,
    List<FilterPreset> presets,
  ) async {
    await _box.put(
      _filterPresetsKey(scope),
      presets.map((preset) => preset.toJson()).toList(growable: false),
    );
  }

  Future<String?> loadLocaleMode() async {
    final raw = _box.get(_localeModeKey);
    return raw is String ? raw : null;
  }

  Future<void> saveLocaleMode(String mode) async {
    await _box.put(_localeModeKey, mode);
  }

  Future<Filters> loadCafeFilters() async {
    final map = _asStringKeyedMap(_box.get(_cafeDiscoveryStateKey));
    return _decodeFilters(map?['filters']);
  }

  Future<int?> loadCafeRadiusMeters() async {
    final map = _asStringKeyedMap(_box.get(_cafeDiscoveryStateKey));
    return (map?['radiusMeters'] as num?)?.toInt();
  }

  Future<void> saveCafeDiscoveryState({
    required Filters filters,
    required int radiusMeters,
  }) async {
    await _box.put(_cafeDiscoveryStateKey, {
      'filters': _encodeFilters(filters),
      'radiusMeters': radiusMeters,
    });
  }

  Future<DistrictCacheSnapshot?> loadDistrictCache(String city) async {
    final map = _asStringKeyedMap(_box.get(_districtCacheKey(city)));
    if (map == null) {
      return null;
    }

    final districtsRaw = map['districts'];
    final lastUpdated = _parseDateTime(map['lastUpdated']);
    if (districtsRaw is! List || lastUpdated == null) {
      await _box.delete(_districtCacheKey(city));
      return null;
    }

    final districts = <District>[];
    for (final item in districtsRaw) {
      final districtMap = _asStringKeyedMap(item);
      if (districtMap == null) {
        await _box.delete(_districtCacheKey(city));
        return null;
      }
      districts.add(District.fromJson(districtMap));
    }

    return DistrictCacheSnapshot(
      city: city,
      districts: List<District>.unmodifiable(districts),
      lastUpdated: lastUpdated,
    );
  }

  Future<void> saveDistrictCache(DistrictCacheSnapshot snapshot) async {
    await _box.put(_districtCacheKey(snapshot.city), {
      'districts': snapshot.districts
          .map((district) => district.toJson())
          .toList(growable: false),
      'lastUpdated': snapshot.lastUpdated.toUtc().toIso8601String(),
    });
  }

  Future<CafeListCacheSnapshot?> loadCafeListCache(String cacheKey) async {
    final storageKey = _cafeListKey(cacheKey);
    final map = _asStringKeyedMap(_box.get(storageKey));
    if (map == null) {
      return null;
    }

    final cafes = _decodeCafeList(map['cafes']);
    final metadata = _decodeCafeCacheMetadata(map);
    if (cafes == null) {
      await _box.delete(storageKey);
      return null;
    }

    if (_isExpiredList(metadata.lastUpdated)) {
      await _box.delete(storageKey);
      return null;
    }

    final nextPageTokenRaw = map['nextPageToken'];
    _logPhotoFlow(source: 'cache-list', cafes: cafes);
    return CafeListCacheSnapshot(
      cafes: cafes,
      cacheKey: cacheKey,
      metadata: metadata,
      nextPageToken: nextPageTokenRaw is String && nextPageTokenRaw.isNotEmpty
          ? nextPageTokenRaw
          : null,
    );
  }

  /// Resolves cafes by [identifiers] from persisted list/detail caches.
  ///
  /// This is used by favorites/compare flows when requested cafes are outside
  /// the currently visible discovery corpus.
  Future<List<Cafe>> resolveCachedCafesByIdentifiers(
    Iterable<String> identifiers,
  ) async {
    final orderedIds = <String>[];
    final seenIds = <String>{};
    for (final rawId in identifiers) {
      final id = rawId.trim();
      if (id.isEmpty || !seenIds.add(id)) {
        continue;
      }
      orderedIds.add(id);
    }

    if (orderedIds.isEmpty) {
      return const <Cafe>[];
    }

    final byIdentifier = <String, Cafe>{};

    void indexCafe(Cafe cafe) {
      if (orderedIds.contains(cafe.id)) {
        byIdentifier[cafe.id] = cafe;
      }

      final placeId = cafe.placeId?.trim();
      if (placeId != null &&
          placeId.isNotEmpty &&
          orderedIds.contains(placeId)) {
        byIdentifier[placeId] = cafe;
      }
    }

    var unresolved =
        orderedIds.where((id) => !byIdentifier.containsKey(id)).toSet();

    for (final id in orderedIds) {
      final detailSnapshot = await loadCafeDetailCache(id);
      if (detailSnapshot == null) {
        continue;
      }
      indexCafe(detailSnapshot.cafe);
    }

    unresolved =
        orderedIds.where((id) => !byIdentifier.containsKey(id)).toSet();

    if (unresolved.isNotEmpty) {
      final listCacheKeys = _box.keys
          .whereType<String>()
          .where((key) => key.startsWith(_cafeListCachePrefix))
          .toList(growable: false);

      for (final key in listCacheKeys) {
        final map = _asStringKeyedMap(_box.get(key));
        if (map == null) {
          await _box.delete(key);
          continue;
        }

        final cafes = _decodeCafeList(map['cafes']);
        final metadata = _decodeCafeCacheMetadata(map);
        if (cafes == null || _isExpiredList(metadata.lastUpdated)) {
          await _box.delete(key);
          continue;
        }

        for (final cafe in cafes) {
          final matchesId = unresolved.contains(cafe.id);
          final placeId = cafe.placeId?.trim();
          final matchesPlaceId =
              placeId != null && unresolved.contains(placeId);
          if (!matchesId && !matchesPlaceId) {
            continue;
          }
          indexCafe(cafe);
        }

        unresolved =
            orderedIds.where((id) => !byIdentifier.containsKey(id)).toSet();
        if (unresolved.isEmpty) {
          break;
        }
      }
    }

    if (unresolved.isNotEmpty) {
      final detailCacheKeys = _box.keys
          .whereType<String>()
          .where((key) => key.startsWith(_cafeDetailPrefix))
          .toList(growable: false);

      for (final key in detailCacheKeys) {
        final map = _asStringKeyedMap(_box.get(key));
        if (map == null) {
          continue;
        }

        final metadata = _decodeCafeCacheMetadata(map);
        if (_isExpiredDetail(metadata.lastUpdated)) {
          await _box.delete(key);
          continue;
        }

        final cafeMap = _asStringKeyedMap(map['cafe']);
        if (cafeMap == null) {
          continue;
        }

        final cafe = Cafe.fromSupabaseRow(cafeMap);
        final placeId = cafe.placeId?.trim();
        final matchesId = unresolved.contains(cafe.id);
        final matchesPlaceId = placeId != null && unresolved.contains(placeId);
        if (!matchesId && !matchesPlaceId) {
          continue;
        }

        indexCafe(cafe);
        unresolved =
            orderedIds.where((id) => !byIdentifier.containsKey(id)).toSet();
        if (unresolved.isEmpty) {
          break;
        }
      }
    }

    final ordered = <Cafe>[];
    final emittedCanonical = <String>{};
    for (final id in orderedIds) {
      final cafe = byIdentifier[id];
      if (cafe == null) {
        continue;
      }

      final canonical = CafeMergePolicy.canonicalIdentityFor(cafe);
      if (!emittedCanonical.add(canonical)) {
        continue;
      }
      ordered.add(cafe);
    }

    return List<Cafe>.unmodifiable(ordered);
  }

  Future<void> saveCafeListCache(
    String cacheKey,
    List<Cafe> cafes, {
    String? nextPageToken,
    DateTime? cachedAt,
  }) async {
    final lastUpdated = (cachedAt ?? DateTime.now().toUtc()).toUtc();
    final metadata = _encodeCafeCacheMetadata(
      CafeCacheMetadata(
        lastUpdated: lastUpdated,
        source: CafeCacheDataSource.localCache,
        version: _cafeCacheMetadataVersion,
      ),
    );
    await _box.put(_cafeListKey(cacheKey), {
      'cafes': cafes.map((cafe) => cafe.toJson()).toList(growable: false),
      'cachedAt': lastUpdated.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'metadata': metadata,
      'nextPageToken': nextPageToken,
    });
    await _pruneCafeListCache();
    await _pruneCafeDetailCache();
  }

  Future<void> clearCafeListCaches() async {
    final keysToDelete = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(_cafeListCachePrefix))
        .toList(growable: false);
    for (final key in keysToDelete) {
      await _box.delete(key);
    }
  }

  Future<void> invalidateCafeDetailCache(String cafeId) async {
    await _box.delete(_cafeDetailKey(cafeId));
  }

  Future<void> replaceCafeInListCaches(Cafe cafe) async {
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(_cafeListCachePrefix))
        .toList(growable: false);

    for (final key in keys) {
      final map = _asStringKeyedMap(_box.get(key));
      if (map == null) {
        await _box.delete(key);
        continue;
      }

      final cafes = _decodeCafeList(map['cafes']);
      final metadata = _decodeCafeCacheMetadata(map);
      if (cafes == null || _isExpiredList(metadata.lastUpdated)) {
        await _box.delete(key);
        continue;
      }

      var didReplace = false;
      final updatedCafes = [
        for (final current in cafes)
          if (CafeMergePolicy.canonicalIdentityFor(current) ==
              CafeMergePolicy.canonicalIdentityFor(cafe))
            () {
              didReplace = true;
              return _mergeCafeForCache(current: current, incoming: cafe);
            }()
          else
            current,
      ];
      if (!didReplace) {
        continue;
      }

      await _box.put(key, {
        'cafes':
            updatedCafes.map((item) => item.toJson()).toList(growable: false),
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
        'metadata': _encodeCafeCacheMetadata(
          CafeCacheMetadata(
            lastUpdated: DateTime.now().toUtc(),
            source: CafeCacheDataSource.localCache,
            version: _cafeCacheMetadataVersion,
          ),
        ),
        'nextPageToken': map['nextPageToken'],
      });
    }

    await _pruneCafeListCache();
  }

  Cafe _mergeCafeForCache({
    required Cafe current,
    required Cafe incoming,
  }) {
    final normalizedCurrentImages = normalizeCafeImageUrls(current.photoUrls);
    final normalizedIncomingImages = normalizeCafeImageUrls(incoming.photoUrls);
    final shouldPreserveCurrentImages =
        normalizedIncomingImages.isEmpty && normalizedCurrentImages.isNotEmpty;
    if (shouldPreserveCurrentImages) {
      AppLogger.debug(
        '[CAFE_DIAG_PHOTO] source=cache-merge preserveExisting=true cafe=${current.id} current=${normalizedCurrentImages.length} incomingRaw=${incoming.photoUrls.length} incomingNormalized=${normalizedIncomingImages.length}',
        key: 'cafe-diag-photo-cache-merge-${current.id}',
        throttle: Duration.zero,
      );
    }

    return incoming.copyWith(
      images: shouldPreserveCurrentImages
          ? normalizedCurrentImages
          : normalizedIncomingImages,
      description: incoming.description.trim().isNotEmpty
          ? incoming.description
          : current.description,
      openingHours: incoming.openingHours.isNotEmpty
          ? incoming.openingHours
          : current.openingHours,
      phoneNumber: (incoming.phoneNumber?.trim().isNotEmpty ?? false)
          ? incoming.phoneNumber
          : current.phoneNumber,
      websiteUri: (incoming.websiteUri?.trim().isNotEmpty ?? false)
          ? incoming.websiteUri
          : current.websiteUri,
    );
  }

  Future<CafeDetailCacheSnapshot?> loadCafeDetailCache(String cafeId) async {
    final cacheKey = _cafeDetailKey(cafeId);
    final map = _asStringKeyedMap(_box.get(cacheKey));
    if (map == null) {
      return null;
    }

    final cafeMap = _asStringKeyedMap(map['cafe']);
    final metadata = _decodeCafeCacheMetadata(map);
    if (cafeMap == null) {
      return null;
    }

    if (_isExpiredDetail(metadata.lastUpdated)) {
      await _box.delete(cacheKey);
      return null;
    }

    final cafe = Cafe.fromSupabaseRow(cafeMap);
    _logPhotoFlow(source: 'cache-detail', cafes: <Cafe>[cafe]);
    return CafeDetailCacheSnapshot(
      cafe: cafe,
      metadata: metadata,
    );
  }

  Future<void> saveCafeDetailCache(
    Cafe cafe, {
    DateTime? cachedAt,
  }) async {
    final lastUpdated = (cachedAt ?? DateTime.now().toUtc()).toUtc();
    await _box.put(_cafeDetailKey(cafe.id), {
      'cafe': cafe.toJson(),
      'cachedAt': lastUpdated.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'metadata': _encodeCafeCacheMetadata(
        CafeCacheMetadata(
          lastUpdated: lastUpdated,
          source: CafeCacheDataSource.localCache,
          version: _cafeCacheMetadataVersion,
        ),
      ),
    });
    await _pruneCafeDetailCache();
  }

  Future<MapViewCacheSnapshot?> loadMapViewCache() async {
    final map = _asStringKeyedMap(_box.get(_mapViewCacheKey));
    if (map == null) {
      return null;
    }

    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    final zoom = (map['zoom'] as num?)?.toDouble();
    final cachedAt = _parseDateTime(map['cachedAt']);
    if (lat == null || lng == null || zoom == null || cachedAt == null) {
      return null;
    }

    final selectedCafeId = map['selectedCafeId'] as String?;
    if (DateTime.now().toUtc().difference(cachedAt.toUtc()) >
        _mapViewCacheMaxAge) {
      await _box.delete(_mapViewCacheKey);
      return null;
    }
    return MapViewCacheSnapshot(
      lat: lat,
      lng: lng,
      zoom: zoom,
      selectedCafeId: selectedCafeId,
      cachedAt: cachedAt,
    );
  }

  Future<void> saveMapViewCache({
    required double lat,
    required double lng,
    required double zoom,
    String? selectedCafeId,
    DateTime? cachedAt,
  }) async {
    await _box.put(_mapViewCacheKey, {
      'lat': lat,
      'lng': lng,
      'zoom': zoom,
      'selectedCafeId': selectedCafeId,
      'cachedAt': (cachedAt ?? DateTime.now().toUtc()).toIso8601String(),
    });
  }

  Future<List<OfflineQueueEntry>> loadOfflineQueue() async {
    return _decodeOfflineQueueEntries(_box.get(_offlineQueueKey));
  }

  Future<void> saveOfflineQueue(List<OfflineQueueEntry> entries) async {
    await _box.put(
      _offlineQueueKey,
      entries.map((entry) => entry.toJson()).toList(growable: false),
    );
  }

  Future<List<OfflineQueueEntry>> loadOfflineDeadLetters() async {
    return _decodeOfflineQueueEntries(_box.get(_offlineDeadLetterKey));
  }

  Future<void> saveOfflineDeadLetters(List<OfflineQueueEntry> entries) async {
    await _box.put(
      _offlineDeadLetterKey,
      entries.map((entry) => entry.toJson()).toList(growable: false),
    );
  }

  Map<String, dynamic>? _asStringKeyedMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }

    return raw.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  List<Cafe>? _decodeCafeList(Object? raw) {
    if (raw is! List) {
      return null;
    }

    final cafes = <Cafe>[];
    for (final item in raw) {
      final map = _asStringKeyedMap(item);
      if (map == null) {
        return null;
      }
      cafes.add(Cafe.fromSupabaseRow(map));
    }
    return cafes;
  }

  void _logPhotoFlow({
    required String source,
    required List<Cafe> cafes,
  }) {
    if (cafes.isEmpty || !kVerboseCafeDiagnostics) {
      return;
    }
    final sample = cafes
        .take(12)
        .map((cafe) => '${cafe.id}:${cafe.photoUrls.length}')
        .join(',');
    AppLogger.debug(
      '[CAFE_DIAG_PHOTO] source=$source cafes=${cafes.length} sample=$sample',
      key: 'cafe-diag-photo-$source',
      throttle: Duration.zero,
    );
  }

  List<OfflineQueueEntry> _decodeOfflineQueueEntries(Object? raw) {
    if (raw is! List) {
      return <OfflineQueueEntry>[];
    }

    final entries = <OfflineQueueEntry>[];
    for (final item in raw) {
      final map = _asStringKeyedMap(item);
      if (map == null) {
        continue;
      }
      entries.add(OfflineQueueEntry.fromJson(map));
    }
    return entries;
  }

  Map<String, dynamic> _encodeFilters(Filters filters) {
    final data = <String, dynamic>{};
    if (filters.category != null) {
      data['category'] = filters.category!.value;
    }
    final selectedDistricts = filters.effectiveDistricts
        .map((district) => district.trim())
        .where((district) => district.isNotEmpty)
        .toList(growable: false);
    if (selectedDistricts.isNotEmpty) {
      data['selectedDistricts'] = selectedDistricts;
      if (selectedDistricts.length == 1) {
        data['district'] = selectedDistricts.single;
      }
    }
    if (filters.neighborhood?.trim().isNotEmpty == true) {
      data['neighborhood'] = filters.neighborhood!.trim();
    }
    if (filters.minRating != null) {
      data['minRating'] = filters.minRating;
    }
    if (filters.priceLevel != null) {
      data['priceLevel'] = filters.priceLevel!.value;
    }
    if (filters.wifiQuality != null) {
      data['wifiQuality'] = filters.wifiQuality!.value;
    }
    if (filters.outletAvailability != null) {
      data['outletAvailability'] = filters.outletAvailability!.value;
    }
    if (filters.quietnessLevel != null) {
      data['quietnessLevel'] = filters.quietnessLevel!.value;
    }
    if (filters.outdoorSeating != null) {
      data['outdoorSeating'] = filters.outdoorSeating;
    }
    if (filters.petFriendly != null) {
      data['petFriendly'] = filters.petFriendly;
    }
    if (filters.studyFriendly != null) {
      data['studyFriendly'] = filters.studyFriendly;
    }
    if (filters.openNow != null) {
      data['openNow'] = filters.openNow;
    }
    if (filters.smokingPolicy != null) {
      data['smokingPolicy'] = filters.smokingPolicy!.value;
    }
    if (filters.searchQuery?.trim().isNotEmpty == true) {
      data['searchQuery'] = filters.searchQuery!.trim();
    }
    return data;
  }

  Filters _decodeFilters(Object? raw) {
    final map = _asStringKeyedMap(raw);
    if (map == null) {
      return Filters.empty;
    }

    return Filters(
      category: _trimmedString(map['category']) == null
          ? null
          : CafeCategoryExtension.fromString(_trimmedString(map['category'])!),
      district: _trimmedString(map['district']),
      selectedDistricts: _decodeDistrictSet(
        map['selectedDistricts'] ?? map['districts'],
        legacyDistrict: _trimmedString(map['district']),
      ),
      neighborhood: _trimmedString(map['neighborhood']),
      minRating: (map['minRating'] as num?)?.toDouble(),
      priceLevel: _trimmedString(map['priceLevel']) == null
          ? null
          : PriceLevelExtension.fromString(_trimmedString(map['priceLevel'])!),
      wifiQuality: _trimmedString(map['wifiQuality']) == null
          ? null
          : WifiQualityExtension.fromString(
              _trimmedString(map['wifiQuality'])!),
      outletAvailability: _trimmedString(map['outletAvailability']) == null
          ? null
          : OutletAvailabilityExtension.fromString(
              _trimmedString(map['outletAvailability'])!,
            ),
      quietnessLevel: _trimmedString(map['quietnessLevel']) == null
          ? null
          : QuietnessLevelExtension.fromString(
              _trimmedString(map['quietnessLevel'])!,
            ),
      outdoorSeating: map['outdoorSeating'] as bool?,
      petFriendly: map['petFriendly'] as bool?,
      studyFriendly: map['studyFriendly'] as bool?,
      openNow: map['openNow'] as bool?,
      smokingPolicy: _trimmedString(map['smokingPolicy']) == null
          ? null
          : SmokingPolicyExtension.fromString(
              _trimmedString(map['smokingPolicy'])!,
            ),
      searchQuery: _trimmedString(map['searchQuery']),
    );
  }

  Set<String> _decodeDistrictSet(
    Object? raw, {
    String? legacyDistrict,
  }) {
    final districts = <String>{};
    if (raw is List) {
      for (final item in raw) {
        final value = item is String ? item.trim() : '';
        if (value.isNotEmpty) {
          districts.add(value);
        }
      }
    }
    if (districts.isEmpty && legacyDistrict?.trim().isNotEmpty == true) {
      districts.add(legacyDistrict!.trim());
    }
    return Set<String>.unmodifiable(districts);
  }

  DateTime? _parseDateTime(Object? raw) {
    if (raw is! String) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  String? _trimmedString(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isExpiredList(DateTime? cachedAt) {
    return CafeCachePolicy.isExpiredList(cachedAt);
  }

  bool _isExpiredDetail(DateTime? cachedAt) {
    return CafeCachePolicy.isExpiredDetail(cachedAt);
  }

  Future<void> _cleanupStorageFootprint() async {
    for (final key in _legacyCafeListCacheKeys) {
      await _box.delete(key);
    }

    final legacyDetailKeys = _box.keys
        .whereType<String>()
        .where(
          (key) =>
              _legacyCafeDetailPrefixes.any(key.startsWith) &&
              !key.startsWith(_cafeDetailPrefix),
        )
        .toList(growable: false);
    for (final key in legacyDetailKeys) {
      await _box.delete(key);
    }

    final detailKeys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(_cafeDetailPrefix))
        .toList(growable: false);
    for (final key in detailKeys) {
      final map = _asStringKeyedMap(_box.get(key));
      final cachedAt = _decodeCafeCacheMetadata(map).lastUpdated;
      if (_isExpiredDetail(cachedAt)) {
        await _box.delete(key);
      }
    }

    final listKeys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(_cafeListCachePrefix))
        .toList(growable: false);
    for (final key in listKeys) {
      final map = _asStringKeyedMap(_box.get(key));
      final cachedAt = _decodeCafeCacheMetadata(map).lastUpdated;
      if (_isExpiredList(cachedAt)) {
        await _box.delete(key);
      }
    }

    final mapView = _asStringKeyedMap(_box.get(_mapViewCacheKey));
    final mapCachedAt = _parseDateTime(mapView?['cachedAt']);
    if (mapCachedAt != null &&
        DateTime.now().toUtc().difference(mapCachedAt.toUtc()) >
            _mapViewCacheMaxAge) {
      await _box.delete(_mapViewCacheKey);
    }

    await _pruneCafeListCache();
    await _pruneCafeDetailCache();
  }

  Future<void> _pruneCafeListCache() async {
    final entries = <({String key, DateTime cachedAt})>[];

    for (final key in _box.keys.whereType<String>()) {
      if (!key.startsWith(_cafeListCachePrefix)) {
        continue;
      }
      final map = _asStringKeyedMap(_box.get(key));
      final cachedAt = _decodeCafeCacheMetadata(map).lastUpdated;
      if (_isExpiredList(cachedAt)) {
        await _box.delete(key);
        continue;
      }
      if (cachedAt != null) {
        entries.add((key: key, cachedAt: cachedAt));
      }
    }

    if (entries.length <= CafeCachePolicy.persistentListEntryLimit) {
      return;
    }

    entries.sort((left, right) => left.cachedAt.compareTo(right.cachedAt));
    final overflow = entries.length - CafeCachePolicy.persistentListEntryLimit;
    for (final entry in entries.take(overflow)) {
      await _box.delete(entry.key);
    }
  }

  Future<void> _pruneCafeDetailCache() async {
    final entries = <({String key, DateTime cachedAt})>[];

    for (final key in _box.keys.whereType<String>()) {
      if (!key.startsWith(_cafeDetailPrefix)) {
        continue;
      }
      final map = _asStringKeyedMap(_box.get(key));
      final cachedAt = _decodeCafeCacheMetadata(map).lastUpdated;
      if (cachedAt != null) {
        entries.add((key: key, cachedAt: cachedAt));
      }
    }

    if (entries.length <= CafeCachePolicy.persistentDetailEntryLimit) {
      return;
    }

    // Evict the stalest cached detail entries first so frequently viewed cafes
    // stay warm, giving us a simple timestamp-based LRU-like policy.
    entries.sort((left, right) => left.cachedAt.compareTo(right.cachedAt));
    final overflow =
        entries.length - CafeCachePolicy.persistentDetailEntryLimit;
    for (final entry in entries.take(overflow)) {
      await _box.delete(entry.key);
    }
  }

  CafeCacheMetadata _decodeCafeCacheMetadata(Map<String, dynamic>? map) {
    final metadataMap = _asStringKeyedMap(map?['metadata']);
    final lastUpdated = _parseDateTime(metadataMap?['lastUpdated']) ??
        _parseDateTime(map?['lastUpdated']) ??
        _parseDateTime(map?['cachedAt']);
    final sourceRaw = _trimmedString(metadataMap?['source']) ??
        _trimmedString(map?['source']);
    final version =
        (metadataMap?['version'] as num?)?.toInt() ?? _cafeCacheMetadataVersion;

    return CafeCacheMetadata(
      lastUpdated: lastUpdated,
      source: switch (sourceRaw) {
        'local_cache' => CafeCacheDataSource.localCache,
        'google_places' => CafeCacheDataSource.googlePlaces,
        'supabase' => CafeCacheDataSource.supabase,
        _ => CafeCacheDataSource.unknown,
      },
      version: version,
    );
  }

  Map<String, dynamic> _encodeCafeCacheMetadata(CafeCacheMetadata metadata) {
    return <String, dynamic>{
      'lastUpdated': metadata.lastUpdated?.toUtc().toIso8601String(),
      'source': switch (metadata.source) {
        CafeCacheDataSource.localCache => 'local_cache',
        CafeCacheDataSource.googlePlaces => 'google_places',
        CafeCacheDataSource.supabase => 'supabase',
        CafeCacheDataSource.unknown => 'unknown',
      },
      'version': metadata.version,
    };
  }
}

typedef EncryptedHiveBoxOpener = Future<Box<dynamic>> Function(
  Uint8List encryptionKey,
);
typedef PlainHiveBoxOpener = Future<Box<dynamic>> Function();
typedef HiveBoxResetter = Future<void> Function();
typedef HiveInitializer = Future<void> Function();

abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }
}
