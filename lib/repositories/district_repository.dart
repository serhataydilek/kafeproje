import '../data/fallback_districts.dart';
import '../models/district.dart';
import '../services/districts_service.dart';
import '../services/local_storage_service.dart';

class DistrictRepository {
  DistrictRepository({
    DistrictsService? remoteService,
    LocalStorageService? storage,
  })  : _remoteService = remoteService,
        _storage = storage;

  static const Duration defaultRefreshInterval = Duration(hours: 12);

  final DistrictsService? _remoteService;
  final LocalStorageService? _storage;
  final Map<String, DistrictCacheSnapshot> _memoryCache = {};
  final Map<String, Future<DistrictCacheSnapshot?>> _inflightRefresh = {};

  Future<DistrictCacheSnapshot?> loadCachedDistricts({
    required String city,
  }) async {
    final normalizedCity = city.trim().toLowerCase();
    final memorySnapshot = _memoryCache[normalizedCity];
    if (memorySnapshot != null) {
      return memorySnapshot;
    }

    final storageSnapshot = await _storage?.loadDistrictCache(normalizedCity);
    if (storageSnapshot == null) {
      return null;
    }

    _memoryCache[normalizedCity] = storageSnapshot;
    return storageSnapshot;
  }

  List<District> loadFallbackDistricts({
    required String city,
  }) {
    return FallbackDistrictCatalog.districtsForCity(city);
  }

  Future<DistrictCacheSnapshot?> refreshDistricts({
    required String city,
  }) {
    final normalizedCity = city.trim().toLowerCase();
    final inflight = _inflightRefresh[normalizedCity];
    if (inflight != null) {
      return inflight;
    }

    final future = _refreshDistrictsInternal(normalizedCity);
    _inflightRefresh[normalizedCity] = future;
    return future.whenComplete(() {
      _inflightRefresh.remove(normalizedCity);
    });
  }

  bool shouldRefresh(
    DistrictCacheSnapshot? snapshot, {
    Duration maxAge = defaultRefreshInterval,
  }) {
    if (snapshot == null) {
      return true;
    }
    return DateTime.now().toUtc().difference(snapshot.lastUpdated.toUtc()) >
        maxAge;
  }

  Future<DistrictCacheSnapshot?> _refreshDistrictsInternal(String city) async {
    final remoteService = _remoteService;
    if (remoteService == null) {
      return null;
    }

    final districts = await remoteService.fetchActiveDistricts(city: city);
    if (districts.isEmpty) {
      return null;
    }

    final snapshot = DistrictCacheSnapshot(
      city: city,
      districts: List<District>.unmodifiable(districts),
      lastUpdated: DateTime.now().toUtc(),
    );
    _memoryCache[city] = snapshot;
    await _storage?.saveDistrictCache(snapshot);
    return snapshot;
  }
}
