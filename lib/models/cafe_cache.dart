import 'index.dart';

enum CafeCacheDataSource {
  unknown,
  localCache,
  googlePlaces,
  supabase,
}

class CafeCacheMetadata {
  const CafeCacheMetadata({
    this.lastUpdated,
    this.source = CafeCacheDataSource.unknown,
    this.version = 1,
  });

  final DateTime? lastUpdated;
  final CafeCacheDataSource source;
  final int version;

  bool get hasKnownTimestamp => lastUpdated != null;
}

class CafeListCacheSnapshot {
  CafeListCacheSnapshot({
    required this.cafes,
    required this.cacheKey,
    CafeCacheMetadata? metadata,
    DateTime? lastUpdated,
    this.nextPageToken,
  }) : metadata = metadata ??
            CafeCacheMetadata(
              lastUpdated: lastUpdated,
            );

  final List<Cafe> cafes;
  final String cacheKey;
  final CafeCacheMetadata metadata;
  final String? nextPageToken;

  DateTime? get lastUpdated => metadata.lastUpdated;
  DateTime? get cachedAt => metadata.lastUpdated;
}

class CafeDetailCacheSnapshot {
  CafeDetailCacheSnapshot({
    required this.cafe,
    CafeCacheMetadata? metadata,
    DateTime? lastUpdated,
  }) : metadata = metadata ??
            CafeCacheMetadata(
              lastUpdated: lastUpdated,
            );

  final Cafe cafe;
  final CafeCacheMetadata metadata;

  DateTime? get lastUpdated => metadata.lastUpdated;
  DateTime? get cachedAt => metadata.lastUpdated;
}

class MapViewCacheSnapshot {
  const MapViewCacheSnapshot({
    required this.lat,
    required this.lng,
    required this.zoom,
    this.selectedCafeId,
    required this.cachedAt,
  });

  final double lat;
  final double lng;
  final double zoom;
  final String? selectedCafeId;
  final DateTime cachedAt;
}
