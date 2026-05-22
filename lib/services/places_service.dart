import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_cache_config.dart';
import '../constants/error_codes.dart';
import '../constants/network_config.dart';
import '../config/env.dart';
import '../data/fallback_districts.dart';
import '../models/index.dart';
import 'places_query_catalog.dart';
import '../utils/app_logger.dart';
import '../utils/cafe_discovery_debug_report.dart';
import '../utils/cafe_discovery_classifier.dart';
import '../utils/district_utils.dart';
import '../utils/inflight_request_registry.dart';
import '../utils/istanbul_region.dart';
import '../utils/lru_cache.dart';
import '../utils/log_sanitizer.dart';
import '../utils/rate_limiter.dart';
import '../utils/request_cancellation.dart';
import '../utils/retry.dart';
import '../utils/service_error.dart';
import '../utils/text_normalization.dart';

/// Result returned by the Google Places list search endpoint.
class PlacesResult {
  const PlacesResult({
    required this.cafes,
    this.nextPageToken,
    this.warningMessage,
    this.diagnostics,
  });

  final List<Cafe> cafes;
  final String? nextPageToken;
  final String? warningMessage;
  final PlacesFetchDiagnostics? diagnostics;
}

class PlacesFetchDiagnostics {
  const PlacesFetchDiagnostics({
    required this.rawFetchedCount,
    required this.rejectedByClassifierCount,
    required this.rejectedByDedupeCount,
    required this.acceptedUniqueCount,
  });

  final int rawFetchedCount;
  final int rejectedByClassifierCount;
  final int rejectedByDedupeCount;
  final int acceptedUniqueCount;
}

@visibleForTesting
String safePlacesHttpFailureLogMessage(
  http.Response response, {
  required String operationName,
}) {
  return 'PlacesService $operationName error HTTP ${response.statusCode}. '
      'Remote response body omitted.';
}

class _ChainPassStats {
  const _ChainPassStats({
    required this.rawFetchedCount,
    required this.allowedByClassifierCount,
    required this.rejectedByClassifierCount,
    required this.rejectedByDedupeCount,
    required this.deniedReasonCounts,
  });

  final int rawFetchedCount;
  final int allowedByClassifierCount;
  final int rejectedByClassifierCount;
  final int rejectedByDedupeCount;
  final Map<String, int> deniedReasonCounts;
}

class _PhotoLogTracker {
  int rawCandidateCount = 0;
  int imagePayloadCount = 0;
  int sampledCount = 0;
}

enum _PlacesSearchKind {
  nearby,
  text,
}

class _PlacesSearchRequest {
  const _PlacesSearchRequest.nearby({
    required this.label,
    required this.lat,
    required this.lng,
    required this.radius,
  })  : kind = _PlacesSearchKind.nearby,
        textQuery = null,
        locationRestriction = null,
        maxPages = null;

  const _PlacesSearchRequest.text({
    required this.label,
    required this.textQuery,
    this.locationRestriction,
    this.maxPages,
  })  : kind = _PlacesSearchKind.text,
        lat = null,
        lng = null,
        radius = null;

  final _PlacesSearchKind kind;
  final String label;
  final double? lat;
  final double? lng;
  final int? radius;
  final String? textQuery;
  final Map<String, dynamic>? locationRestriction;
  final int? maxPages;
}

/// Abstraction over the remote cafe discovery source.
abstract class PlacesServiceBase {
  bool get supportsExternalPagination;

  /// Fetches cafes from Google Places API with optional location or district filtering.
  ///
  /// **Search Strategy**:
  /// - Coordinates + radius: Nearby search in specified geographic area
  /// - District name: District-specific search using predefined district centers
  /// - Neither: Broad text search across Istanbul using multiple query strings
  ///
  /// **Parameters**:
  /// - [lat]/[lng]: Optional coordinates for nearby search
  /// - [district]: Optional district name (e.g., 'Kadikoy') as coordinates alternative
  /// - [radius]: Search radius in meters for nearby (default: 5000m)
  /// - [pageToken]: Pagination token from previous result
  /// - [seedOnly]: If true, disables caching and returns fresh API data
  ///
  /// **Returns**: [PlacesResult] with cafes and optional next page token.
  /// **API Limits**: Results are limited by Google Places quota and paging.
  Future<PlacesResult> fetchCafes({
    double? lat,
    double? lng,
    String? district,
    int radius = 5000,
    String? pageToken,
    bool seedOnly = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  });

  /// Fetches detailed information for a specific cafe by Google Place ID.
  ///
  /// **Parameters**:
  /// - [placeId]: Unique Google Place ID identifier
  ///
  /// **Returns**: Detailed [Cafe] object or null if not found.
  /// **Caching**: Results are cached locally to avoid duplicate API calls.
  Future<Cafe?> fetchCafeDetails(
    String placeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  });

  Future<PlaceRatingMetadata?> fetchPlaceRatingMetadata(
    String placeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  });
}

class PlaceRatingMetadata {
  const PlaceRatingMetadata({
    required this.placeId,
    this.rating,
    this.reviewCount,
  });

  final String placeId;
  final double? rating;
  final int? reviewCount;
}

/// Google Places API client discovering cafes across Istanbul neighborhoods.
///
/// Uses text searches, chain searches, and district-based nearby searches to
/// broaden coverage while staying within API quota limits.
class PlacesService implements PlacesServiceBase {
  PlacesService({
    http.Client? client,
    Duration requestTimeout = NetworkTimeoutConfig.placesRequestTimeout,
    Iterable<District> Function()? districtCatalogLoader,
    String Function()? cityDisplayNameLoader,
  })  : _client = client ?? http.Client(),
        _requestTimeout = requestTimeout,
        _districtCatalogLoader = districtCatalogLoader ??
            (() => FallbackDistrictCatalog.districtsForCity('istanbul')),
        _cityDisplayNameLoader = cityDisplayNameLoader ?? (() => 'Istanbul');

  static const int _maxNearbyResultCount = RateLimitConfig.maxNearbyResults;
  static const int _textSearchPageSize = RateLimitConfig.textSearchPageSize;
  static const int _maxTextSearchPagesPerQuery =
      RateLimitConfig.maxTextSearchPages;
  static const int _batchSize = RateLimitConfig.processingBatchSize;
  static const int _photoLogSampleLimit = 3;

  final http.Client _client;
  final Duration _requestTimeout;
  final Iterable<District> Function() _districtCatalogLoader;
  final String Function() _cityDisplayNameLoader;
  final InflightRequestRegistry<PlacesResult> _inflightCafeSearches =
      InflightRequestRegistry<PlacesResult>();
  final InflightRequestRegistry<Cafe?> _inflightCafeDetails =
      InflightRequestRegistry<Cafe?>();
  final InflightRequestRegistry<List<Map<String, dynamic>>>
      _inflightNearbyRequests =
      InflightRequestRegistry<List<Map<String, dynamic>>>();
  final InflightRequestRegistry<
          ({List<Map<String, dynamic>> places, String? nextPageToken})>
      _inflightTextPages = InflightRequestRegistry<
          ({List<Map<String, dynamic>> places, String? nextPageToken})>();
  final InflightRequestRegistry<Map<String, dynamic>?> _inflightRawDetails =
      InflightRequestRegistry<Map<String, dynamic>?>();
  final InflightRequestRegistry<PlaceRatingMetadata?> _inflightRatingMetadata =
      InflightRequestRegistry<PlaceRatingMetadata?>();
  final LruCache<String, List<Map<String, dynamic>>> _nearbySearchCache =
      LruCache<String, List<Map<String, dynamic>>>(
    maxSize: RequestTuningConfig.nearbyQueryMemoryEntries,
    defaultTtl: RequestTuningConfig.nearbyQueryMemoryTtl,
  );
  final LruCache<String,
          ({List<Map<String, dynamic>> places, String? nextPageToken})>
      _textSearchCache = LruCache<String,
          ({List<Map<String, dynamic>> places, String? nextPageToken})>(
    maxSize: RequestTuningConfig.textSearchMemoryEntries,
    defaultTtl: RequestTuningConfig.textSearchMemoryTtl,
  );
  final LruCache<String, Map<String, dynamic>> _placeDetailsCache =
      LruCache<String, Map<String, dynamic>>(
    maxSize: RequestTuningConfig.placeDetailsMemoryEntries,
    defaultTtl: RequestTuningConfig.placeDetailsMemoryTtl,
  );
  final RateLimiter _endpointRateLimiter = RateLimiter(
    bucketIntervals: const {
      'nearby_search': RequestTuningConfig.nearbySearchMinInterval,
      'text_search': RequestTuningConfig.textSearchMinInterval,
      'place_details': RequestTuningConfig.placeDetailsMinInterval,
      'photo_fetch': RequestTuningConfig.photoFetchMinInterval,
      'reverse_geocode': RequestTuningConfig.reverseGeocodeMinInterval,
    },
  );

  @override
  bool get supportsExternalPagination => false;

  List<District> get _activeDistricts =>
      resolveDistrictCatalog(districts: _districtCatalogLoader());

  String get _currentCityDisplayName {
    final value = _cityDisplayNameLoader().trim();
    return value.isEmpty ? 'Istanbul' : value;
  }

  @override
  Future<PlacesResult> fetchCafes({
    double? lat,
    double? lng,
    String? district,
    int radius = 5000,
    String? pageToken,
    bool seedOnly = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final requestKey = [
      lat?.toStringAsFixed(5) ?? 'none',
      lng?.toStringAsFixed(5) ?? 'none',
      district?.trim().toLowerCase() ?? 'none',
      radius.toString(),
      pageToken?.trim().isNotEmpty == true ? pageToken!.trim() : 'first',
      seedOnly ? 'seed' : 'full',
      (requestTimeout ?? _requestTimeout).inMilliseconds.toString(),
    ].join('|');

    cancellationToken?.throwIfCancelled();
    return _inflightCafeSearches.run(
      requestKey,
      () => _fetchCafesInternal(
        requestKey: requestKey,
        lat: lat,
        lng: lng,
        district: district,
        radius: radius,
        pageToken: pageToken,
        seedOnly: seedOnly,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      ),
    );
  }

  Future<PlacesResult> _fetchCafesInternal({
    required String requestKey,
    double? lat,
    double? lng,
    String? district,
    int radius = 5000,
    String? pageToken,
    bool seedOnly = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final effectiveTimeout = requestTimeout ?? _requestTimeout;
    final apiKey = Env.optionalGooglePlacesApiKey;
    if (apiKey == null) {
      throw const AppServiceException.unavailable(
        'Google Places API key is missing.',
        errorCode: AppErrorCode.serviceUnavailable,
      );
    }

    final nearbyUrl =
        Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
    final textUrl =
        Uri.parse('https://places.googleapis.com/v1/places:searchText');
    final hasDeviceLocation =
        lat != null && lng != null && isWithinIstanbul(lat, lng);
    final hasDistrictFilter = district != null && district.trim().isNotEmpty;
    final usesDefaultLocation = !hasDeviceLocation && !hasDistrictFilter;
    final warningMessage = usesDefaultLocation
        ? 'Location access is unavailable or outside $_currentCityDisplayName. Showing cafes across $_currentCityDisplayName.'
        : null;

    CafeDiscoveryDebugReportRecorder.instance.beginSession(
      requestKey: requestKey,
      radiusMeters: radius,
      seedOnly: seedOnly,
      radiusPreset: _radiusPresetLabelForRadius(radius),
      district: hasDistrictFilter ? district.trim() : null,
    );

    try {
      final photoLogTracker = kDebugMode ? _PhotoLogTracker() : null;
      final cafesById = <String, Cafe>{};
      final confidenceByCafeId = <String, int>{};
      final rawCountByLabel = <String, int>{};
      final acceptedCountByLabel = <String, int>{};
      final classifierDeniedReasonCounts = <String, int>{};
      var classifierRejectedCount = 0;
      var classifierAllowedCount = 0;
      var dedupeRejectedCount = 0;
      final searchRequests = _buildSearchRequests(
        lat: hasDeviceLocation ? lat : null,
        lng: hasDeviceLocation ? lng : null,
        district: district,
        radius: radius,
        seedOnly: seedOnly,
      );

      // INSTRUMENTATION: Log search strategy
      AppLogger.debug(
        '[PLACES_SEARCH_PLAN] seedOnly=$seedOnly locationMode=${hasDeviceLocation ? "device" : hasDistrictFilter ? "district" : "citywide"} '
        'totalSearches=${searchRequests.length} details="${searchRequests.map((r) => r.label).join(", ")}"',
        key: 'places-search-plan',
        throttle: Duration.zero,
      );

      for (var i = 0; i < searchRequests.length; i += _batchSize) {
        cancellationToken?.throwIfCancelled();
        final batch = searchRequests.skip(i).take(_batchSize).toList();
        final batchResults = await Future.wait(
          batch.map(
            (request) => _fetchPlacesForRequest(
              request,
              apiKey: apiKey,
              nearbyUrl: nearbyUrl,
              textUrl: textUrl,
              requestTimeout: effectiveTimeout,
              cancellationToken: cancellationToken,
            ),
          ),
        );

        for (var batchIndex = 0;
            batchIndex < batchResults.length;
            batchIndex++) {
          final request = batch[batchIndex];
          final places = batchResults[batchIndex];
          rawCountByLabel.update(
            request.label,
            (count) => count + places.length,
            ifAbsent: () => places.length,
          );

          for (final placeMap in places) {
            final sourceQuery = request.textQuery ?? request.label;
            final searchKind =
                request.kind == _PlacesSearchKind.nearby ? 'nearby' : 'text';
            CafeDiscoveryDebugReportRecorder.instance.recordRawCandidate(
              place: placeMap,
              sourceQuery: sourceQuery,
              sourceLabel: request.label,
              searchKind: searchKind,
            );
            _logRawGooglePlacePhotoPayload(
              placeMap,
              source: searchKind,
              label: request.label,
              tracker: photoLogTracker,
            );
            if (placeMap['businessStatus'] != null &&
                placeMap['businessStatus'] != 'OPERATIONAL') {
              continue;
            }
            if (!_hasUsableGoogleLocation(placeMap)) {
              continue;
            }
            final assessment = assessGoogleCafeCandidate(placeMap);
            CafeDiscoveryDebugReportRecorder.instance.recordClassifierDecision(
              place: placeMap,
              assessment: assessment,
              sourceQuery: sourceQuery,
            );
            if (!assessment.isValidCafe) {
              classifierRejectedCount += 1;
              final denyReason = assessment.denyReason ?? 'unspecified';
              classifierDeniedReasonCounts.update(
                denyReason,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
              continue;
            }
            classifierAllowedCount += 1;

            try {
              final cafe = Cafe.fromGooglePlace(
                placeMap,
                maxImageCount: 5,
              );
              final wasDuplicate = cafesById.containsKey(cafe.id);
              cafesById[cafe.id] = cafe;
              if (wasDuplicate) {
                dedupeRejectedCount += 1;
              }
              confidenceByCafeId[cafe.id] = math.max(
                confidenceByCafeId[cafe.id] ?? assessment.score,
                assessment.score,
              );
              acceptedCountByLabel.update(
                request.label,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            } catch (error) {
              AppLogger.warn(
                'PlacesService skipped a malformed place for ${request.label}',
                key: 'places-parse-skip-${normalizeSearchText(request.label)}',
              );
            }
          }
        }
      }

      final localLat = lat;
      final localLng = lng;
      final localRestriction =
          hasDeviceLocation && localLat != null && localLng != null
              ? _buildRectangleLocationRestriction(
                  lat: localLat,
                  lng: localLng,
                  radiusMeters: radius,
                  expansionFactor: 1.2,
                )
              : null;
      final districtRestriction = hasDistrictFilter
          ? _buildDistrictLocationRestriction(district.trim())
          : null;
      if (_shouldRunChainCompletionPass(
        radius: radius,
        discoveredCafeCount: cafesById.length,
        seedOnly: seedOnly,
      )) {
        AppLogger.debug(
          '[PLACES_CHAIN_COMPLETION_START] cafeCount=${cafesById.length} seedOnly=$seedOnly',
          key: 'places-chain-completion-start',
          throttle: Duration.zero,
        );
        final countBefore = cafesById.length;
        final chainStats = await _runChainCompletionPass(
          cafesById,
          confidenceByCafeId: confidenceByCafeId,
          apiKey: apiKey,
          textUrl: textUrl,
          rawCountByLabel: rawCountByLabel,
          acceptedCountByLabel: acceptedCountByLabel,
          district: hasDistrictFilter ? district : null,
          locationRestriction: districtRestriction ?? localRestriction,
          seedOnly: seedOnly,
          requestTimeout: effectiveTimeout,
          cancellationToken: cancellationToken,
          photoLogTracker: photoLogTracker,
        );
        classifierAllowedCount += chainStats.allowedByClassifierCount;
        classifierRejectedCount += chainStats.rejectedByClassifierCount;
        dedupeRejectedCount += chainStats.rejectedByDedupeCount;
        for (final entry in chainStats.deniedReasonCounts.entries) {
          classifierDeniedReasonCounts.update(
            entry.key,
            (count) => count + entry.value,
            ifAbsent: () => entry.value,
          );
        }
        final countAfter = cafesById.length;
        AppLogger.debug(
          '[PLACES_CHAIN_COMPLETION_END] added=${countAfter - countBefore} newTotal=$countAfter chains=${PlacesQueryCatalog.buildChainSearchQueries(cityDisplayName: _currentCityDisplayName, districtDisplayName: hasDistrictFilter ? district : null).length}',
          key: 'places-chain-completion-end',
          throttle: Duration.zero,
        );
      }

      final cafes = cafesById.values.toList(growable: false)
        ..sort((left, right) {
          final confidenceCompare = (confidenceByCafeId[right.id] ?? 0)
              .compareTo(confidenceByCafeId[left.id] ?? 0);
          if (confidenceCompare != 0) {
            return confidenceCompare;
          }
          final reviewCountCompare =
              right.reviewCount.compareTo(left.reviewCount);
          if (reviewCountCompare != 0) {
            return reviewCountCompare;
          }
          final ratingCompare = right.rating.compareTo(left.rating);
          if (ratingCompare != 0) {
            return ratingCompare;
          }
          return left.name.compareTo(right.name);
        });

      AppLogger.debug(
        '[PLACES_FETCH_COMPLETE] totalAPIcalls=${searchRequests.length} '
        'rawResults=${rawCountByLabel.values.fold<int>(0, (sum, count) => sum + count)} '
        'classifierAllowed=$classifierAllowedCount '
        'classifierRejected=$classifierRejectedCount '
        'classifierTopDenyReasons=${_formatTopReasonCounts(classifierDeniedReasonCounts)} '
        'dedupeRejected=$dedupeRejectedCount '
        'dedupedCount=${cafesById.length} '
        'acceptedCafes=${cafes.length} '
        'seedOnly=$seedOnly '
        'breakdown=${searchRequests.map((req) => "${req.label}:${rawCountByLabel[req.label] ?? 0}/${acceptedCountByLabel[req.label] ?? 0}").join(" | ")}',
        key: 'places-fetch-summary',
        throttle: Duration.zero,
      );
      if (photoLogTracker != null) {
        AppLogger.debug(
          '[CAFE_DIAG_PHOTO_FETCH] rawCandidates=${photoLogTracker.rawCandidateCount} imagePayloadCount=${photoLogTracker.imagePayloadCount} sampled=${photoLogTracker.sampledCount}',
          key: 'cafe-diag-photo-fetch-$requestKey',
          throttle: Duration.zero,
        );
      }

      return PlacesResult(
        cafes: cafes,
        warningMessage: warningMessage,
        diagnostics: PlacesFetchDiagnostics(
          rawFetchedCount:
              rawCountByLabel.values.fold<int>(0, (sum, count) => sum + count),
          rejectedByClassifierCount: classifierRejectedCount,
          rejectedByDedupeCount: dedupeRejectedCount,
          acceptedUniqueCount: cafesById.length,
        ),
      );
    } catch (error) {
      AppLogger.error(
        'PlacesService exception during fetchCafes',
        error: error,
        key: 'places-fetch-exception',
      );
      if (error is AppServiceException) {
        rethrow;
      }
      throw AppServiceException(
        message: _describePlacesError(error, 'load cafes'),
        type: classifyServiceError(error),
        cause: error,
      );
    }
  }

  @override
  Future<Cafe?> fetchCafeDetails(
    String placeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final normalizedPlaceId = placeId.trim();
    cancellationToken?.throwIfCancelled();
    return _inflightCafeDetails.run(
      '$normalizedPlaceId|${(requestTimeout ?? _requestTimeout).inMilliseconds}',
      () => _fetchCafeDetailsInternal(
        normalizedPlaceId,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      ),
    );
  }

  Future<Cafe?> _fetchCafeDetailsInternal(
    String placeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final apiKey = Env.optionalGooglePlacesApiKey;
    if (apiKey == null) {
      return null;
    }

    final data = await _fetchPlaceDetailsRaw(
      placeId,
      apiKey: apiKey,
      requestTimeout: requestTimeout ?? _requestTimeout,
      cancellationToken: cancellationToken,
    );
    if (data == null) {
      return null;
    }

    if (data['businessStatus'] != 'OPERATIONAL' ||
        !assessGoogleCafeCandidate(data).isValidCafe ||
        !_hasUsableGoogleLocation(data)) {
      return null;
    }

    return Cafe.fromGooglePlace(
      data,
    );
  }

  @override
  Future<PlaceRatingMetadata?> fetchPlaceRatingMetadata(
    String placeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    final normalizedPlaceId = placeId.trim();
    if (normalizedPlaceId.isEmpty) {
      return Future<PlaceRatingMetadata?>.value(null);
    }
    return _inflightRatingMetadata.run(
      normalizedPlaceId,
      () => _fetchPlaceRatingMetadataInternal(
        normalizedPlaceId,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      ),
    );
  }

  Future<PlaceRatingMetadata?> _fetchPlaceRatingMetadataInternal(
    String placeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final apiKey = Env.optionalGooglePlacesApiKey;
    if (apiKey == null) {
      return null;
    }
    final data = await _fetchPlaceDetailsRaw(
      placeId,
      apiKey: apiKey,
      fieldMask: 'id,rating,userRatingCount',
      requestTimeout: requestTimeout ?? _requestTimeout,
      cancellationToken: cancellationToken,
    );
    if (data == null) {
      return null;
    }
    return PlaceRatingMetadata(
      placeId: data['id'] as String? ?? placeId,
      rating: (data['rating'] as num?)?.toDouble(),
      reviewCount: (data['userRatingCount'] as num?)?.toInt(),
    );
  }

  List<_PlacesSearchRequest> _buildSearchRequests({
    double? lat,
    double? lng,
    String? district,
    required int radius,
    required bool seedOnly,
  }) {
    final normalizedDistrict = district?.trim();
    final effectiveRadius = radius.clamp(600, 8000).toInt();
    final requests = normalizedDistrict != null && normalizedDistrict.isNotEmpty
        ? _buildDistrictModeRequests(
            normalizedDistrict,
            seedOnly: seedOnly,
          )
        : lat != null && lng != null
            ? _buildNearbyModeRequests(
                lat: lat,
                lng: lng,
                radius: effectiveRadius,
                seedOnly: seedOnly,
              )
            : _buildCityWideRequests(seedOnly: seedOnly);

    final dedupedRequests = <String, _PlacesSearchRequest>{};
    for (final request in requests) {
      final key = switch (request.kind) {
        _PlacesSearchKind.nearby =>
          'nearby:${request.lat}:${request.lng}:${request.radius}',
        _PlacesSearchKind.text =>
          'text:${normalizeSearchText(request.textQuery!)}:'
              '${request.maxPages ?? _maxTextSearchPagesPerQuery}:'
              '${request.locationRestriction == null ? 'global' : normalizeSearchText(request.label)}',
      };
      dedupedRequests.putIfAbsent(key, () => request);
    }

    return dedupedRequests.values.toList(growable: false);
  }

  List<_PlacesSearchRequest> _buildCityWideRequests({
    required bool seedOnly,
  }) {
    final maxPages = seedOnly ? 1 : 3;
    final cityQueries = PlacesQueryCatalog.buildCityTextSearchQueries(
      cityDisplayName: _currentCityDisplayName,
      fullSet: !seedOnly,
    );

    return cityQueries
        .map(
          (query) => _PlacesSearchRequest.text(
            label: query,
            textQuery: query,
            maxPages: maxPages,
          ),
        )
        .toList(growable: false);
  }

  Future<_ChainPassStats> _runChainCompletionPass(
    Map<String, Cafe> cafesById, {
    required Map<String, int> confidenceByCafeId,
    required String apiKey,
    required Uri textUrl,
    required Map<String, int> rawCountByLabel,
    required Map<String, int> acceptedCountByLabel,
    required bool seedOnly,
    required Duration requestTimeout,
    required _PhotoLogTracker? photoLogTracker,
    RequestCancellationToken? cancellationToken,
    Map<String, dynamic>? locationRestriction,
    String? district,
  }) async {
    var rawFetchedCount = 0;
    var allowedByClassifierCount = 0;
    var rejectedByClassifierCount = 0;
    var rejectedByDedupeCount = 0;
    final deniedReasonCounts = <String, int>{};
    final queries = PlacesQueryCatalog.buildChainSearchQueries(
      cityDisplayName: _currentCityDisplayName,
      districtDisplayName: district,
    );

    for (final query in queries) {
      cancellationToken?.throwIfCancelled();
      final places = await _fetchTextSearchPlaces(
        url: textUrl,
        apiKey: apiKey,
        textQuery: query,
        locationRestriction: locationRestriction,
        maxPages: seedOnly ? 1 : math.min(2, _maxTextSearchPagesPerQuery),
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );
      rawCountByLabel.update(
        'chain:$query',
        (count) => count + places.length,
        ifAbsent: () => places.length,
      );
      rawFetchedCount += places.length;

      for (final placeMap in places) {
        CafeDiscoveryDebugReportRecorder.instance.recordRawCandidate(
          place: placeMap,
          sourceQuery: query,
          sourceLabel: 'chain:$query',
          searchKind: 'chain',
        );
        _logRawGooglePlacePhotoPayload(
          placeMap,
          source: 'chain',
          label: query,
          tracker: photoLogTracker,
        );
        if (placeMap['businessStatus'] != null &&
            placeMap['businessStatus'] != 'OPERATIONAL') {
          continue;
        }
        final assessment = assessGoogleCafeCandidate(placeMap);
        CafeDiscoveryDebugReportRecorder.instance.recordClassifierDecision(
          place: placeMap,
          assessment: assessment,
          sourceQuery: query,
        );
        if (!_hasUsableGoogleLocation(placeMap) || !assessment.isValidCafe) {
          if (!assessment.isValidCafe) {
            rejectedByClassifierCount += 1;
            final denyReason = assessment.denyReason ?? 'unspecified';
            deniedReasonCounts.update(
              denyReason,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
          continue;
        }
        allowedByClassifierCount += 1;

        try {
          final cafe = Cafe.fromGooglePlace(
            placeMap,
            maxImageCount: 5,
          );
          if (district != null &&
              district.trim().isNotEmpty &&
              !_matchesDistrict(cafe.district, district)) {
            continue;
          }
          final isNewCafe = !cafesById.containsKey(cafe.id);
          if (!isNewCafe) {
            rejectedByDedupeCount += 1;
          }
          cafesById[cafe.id] = cafe;
          confidenceByCafeId[cafe.id] = math.max(
            confidenceByCafeId[cafe.id] ?? assessment.score,
            assessment.score,
          );
          if (isNewCafe) {
            acceptedCountByLabel.update(
              'chain:$query',
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
        } catch (_) {
          AppLogger.warn(
            'PlacesService skipped a malformed chain place for $query',
            key: 'places-chain-parse-skip-${normalizeSearchText(query)}',
          );
        }
      }
    }

    return _ChainPassStats(
      rawFetchedCount: rawFetchedCount,
      allowedByClassifierCount: allowedByClassifierCount,
      rejectedByClassifierCount: rejectedByClassifierCount,
      rejectedByDedupeCount: rejectedByDedupeCount,
      deniedReasonCounts: deniedReasonCounts,
    );
  }

  List<_PlacesSearchRequest> _buildNearbyModeRequests({
    required double lat,
    required double lng,
    required int radius,
    required bool seedOnly,
  }) {
    final localRestriction = _buildRectangleLocationRestriction(
      lat: lat,
      lng: lng,
      radiusMeters: radius,
      expansionFactor: seedOnly ? 1.2 : 1.45,
    );
    final textMaxPages = _nearbyTextMaxPages(
      seedOnly: seedOnly,
      radius: radius,
    );
    final textQueries = seedOnly
        ? const ['cafe', 'coffee shop']
        : radius >= 5000
            ? const [
                'cafe',
                'coffee shop',
                'specialty coffee',
                'kahve',
                'coffee cocktail',
                'cafe cocktail',
              ]
            : const [
                'cafe',
                'coffee shop',
                'specialty coffee',
                'coffee roastery',
                'kahve',
              ];
    final requests = <_PlacesSearchRequest>[
      _PlacesSearchRequest.nearby(
        label: seedOnly ? 'nearby-seed' : 'nearby-active-radius',
        lat: lat,
        lng: lng,
        radius: radius,
      ),
      for (final center in _buildNearbySupplementalCenters(
        lat: lat,
        lng: lng,
        radius: radius,
        seedOnly: seedOnly,
      ))
        _PlacesSearchRequest.nearby(
          label:
              'nearby-${center.lat.toStringAsFixed(4)}-${center.lng.toStringAsFixed(4)}',
          lat: center.lat,
          lng: center.lng,
          radius: _supplementalNearbyRadius(radius),
        ),
      for (final query in textQueries)
        _PlacesSearchRequest.text(
          label: 'nearby:$query',
          textQuery: query,
          locationRestriction: localRestriction,
          maxPages: textMaxPages,
        ),
      if (!seedOnly) ...[
        _PlacesSearchRequest.text(
          label: '${normalizeSearchText(_currentCityDisplayName)}:cafe',
          textQuery: 'cafe in $_currentCityDisplayName',
          maxPages: 1,
        ),
        _PlacesSearchRequest.text(
          label: '${normalizeSearchText(_currentCityDisplayName)}:coffee-shop',
          textQuery: 'coffee shop in $_currentCityDisplayName',
          maxPages: 1,
        ),
      ],
    ];

    return requests;
  }

  List<_PlacesSearchRequest> _buildDistrictModeRequests(
    String district, {
    required bool seedOnly,
  }) {
    final matchedDistrict = matchDistrict(
      district,
      districts: _activeDistricts,
    );
    final locationRestriction = matchedDistrict == null
        ? null
        : _buildDistrictLocationRestriction(matchedDistrict.displayName);
    final textMaxPages = seedOnly ? 1 : 2;

    final nearbyRequests = <_PlacesSearchRequest>[
      if (matchedDistrict != null)
        _PlacesSearchRequest.nearby(
          label: matchedDistrict.displayName,
          lat: matchedDistrict.latitude,
          lng: matchedDistrict.longitude,
          radius: matchedDistrict.searchRadiusMeters ?? 1400,
        ),
      if (matchedDistrict == null)
        _PlacesSearchRequest.text(
          label: '$district cafes',
          textQuery: 'cafe in $district $_currentCityDisplayName',
          maxPages: textMaxPages,
        ),
    ];

    final requests = <_PlacesSearchRequest>[
      ...nearbyRequests,
      _PlacesSearchRequest.text(
        label: '$district cafes',
        textQuery: 'cafe in $district $_currentCityDisplayName',
        locationRestriction: locationRestriction,
        maxPages: textMaxPages,
      ),
      _PlacesSearchRequest.text(
        label: '$district coffee shops',
        textQuery: 'coffee shop in $district $_currentCityDisplayName',
        locationRestriction: locationRestriction,
        maxPages: textMaxPages,
      ),
      if (!seedOnly)
        _PlacesSearchRequest.text(
          label: '$district specialty coffee',
          textQuery: 'specialty coffee in $district $_currentCityDisplayName',
          locationRestriction: locationRestriction,
          maxPages: textMaxPages,
        ),
    ];

    return requests;
  }

  List<({double lat, double lng})> _buildNearbySupplementalCenters({
    required double lat,
    required double lng,
    required int radius,
    required bool seedOnly,
  }) {
    if (seedOnly || radius < 1200) {
      return const <({double lat, double lng})>[];
    }

    final offsetMeters = _supplementalOffsetMeters(radius);
    final includeDiagonalOffsets = _shouldIncludeDiagonalOffsets(radius);
    final offsets = <({double north, double east})>[
      (north: offsetMeters, east: 0),
      (north: -offsetMeters, east: 0),
      (north: 0, east: offsetMeters),
      (north: 0, east: -offsetMeters),
      if (includeDiagonalOffsets) ...[
        (north: offsetMeters * 0.75, east: offsetMeters * 0.75),
        (north: offsetMeters * 0.75, east: -offsetMeters * 0.75),
        (north: -offsetMeters * 0.75, east: offsetMeters * 0.75),
        (north: -offsetMeters * 0.75, east: -offsetMeters * 0.75),
      ],
    ];

    return offsets
        .map(
          (offset) => _offsetCoordinates(
            lat,
            lng,
            northMeters: offset.north,
            eastMeters: offset.east,
          ),
        )
        .where((center) => isWithinIstanbul(center.lat, center.lng))
        .toList(growable: false);
  }

  bool _shouldRunChainCompletionPass({
    required int radius,
    required int discoveredCafeCount,
    required bool seedOnly,
  }) {
    if (seedOnly) {
      return false;
    }
    if (radius >= 4000) {
      final minimumLargeRadiusCoverage =
          switch (RequestTuningConfig.largeRadiusCoverageProfile) {
        LargeRadiusCoverageProfile.conservative => 70,
        LargeRadiusCoverageProfile.balanced => 90,
        LargeRadiusCoverageProfile.aggressive => 110,
      };
      return discoveredCafeCount < minimumLargeRadiusCoverage;
    }
    // Only run if cafe count is REALLY low for smaller radiuses
    final targetCount = radius >= 2000 ? 8 : 5;
    return discoveredCafeCount < targetCount;
  }

  int _supplementalNearbyRadius(int radius) {
    if (radius >= 5000) {
      final factor = switch (RequestTuningConfig.largeRadiusCoverageProfile) {
        LargeRadiusCoverageProfile.conservative => 0.34,
        LargeRadiusCoverageProfile.balanced => 0.42,
        LargeRadiusCoverageProfile.aggressive => 0.50,
      };
      final minRadius =
          switch (RequestTuningConfig.largeRadiusCoverageProfile) {
        LargeRadiusCoverageProfile.conservative => 1200,
        LargeRadiusCoverageProfile.balanced => 1400,
        LargeRadiusCoverageProfile.aggressive => 1600,
      };
      final maxRadius =
          switch (RequestTuningConfig.largeRadiusCoverageProfile) {
        LargeRadiusCoverageProfile.conservative => 1600,
        LargeRadiusCoverageProfile.balanced => 2000,
        LargeRadiusCoverageProfile.aggressive => 2400,
      };
      return (radius * factor).round().clamp(minRadius, maxRadius).toInt();
    }
    return (radius * 0.65).round().clamp(650, 1400).toInt();
  }

  int _nearbyTextMaxPages({
    required bool seedOnly,
    required int radius,
  }) {
    if (seedOnly) {
      return 1;
    }
    if (radius < 5000) {
      return 3;
    }

    return switch (RequestTuningConfig.largeRadiusCoverageProfile) {
      LargeRadiusCoverageProfile.conservative => 2,
      LargeRadiusCoverageProfile.balanced => 4,
      LargeRadiusCoverageProfile.aggressive => 5,
    };
  }

  double _supplementalOffsetMeters(int radius) {
    if (radius >= 5000) {
      final factor = switch (RequestTuningConfig.largeRadiusCoverageProfile) {
        LargeRadiusCoverageProfile.conservative => 0.36,
        LargeRadiusCoverageProfile.balanced => 0.46,
        LargeRadiusCoverageProfile.aggressive => 0.55,
      };
      final minOffset =
          switch (RequestTuningConfig.largeRadiusCoverageProfile) {
        LargeRadiusCoverageProfile.conservative => 1600.0,
        LargeRadiusCoverageProfile.balanced => 1800.0,
        LargeRadiusCoverageProfile.aggressive => 2200.0,
      };
      final maxOffset =
          switch (RequestTuningConfig.largeRadiusCoverageProfile) {
        LargeRadiusCoverageProfile.conservative => 2300.0,
        LargeRadiusCoverageProfile.balanced => 2800.0,
        LargeRadiusCoverageProfile.aggressive => 3200.0,
      };
      return (radius * factor).clamp(minOffset, maxOffset);
    }
    if (radius >= 2200) {
      return 1300.0;
    }
    return 850.0;
  }

  bool _shouldIncludeDiagonalOffsets(int radius) {
    if (radius < 2200) {
      return false;
    }
    if (radius < 5000) {
      return true;
    }

    return switch (RequestTuningConfig.largeRadiusCoverageProfile) {
      LargeRadiusCoverageProfile.conservative => false,
      LargeRadiusCoverageProfile.balanced => true,
      LargeRadiusCoverageProfile.aggressive => true,
    };
  }

  ({double lat, double lng}) _offsetCoordinates(
    double lat,
    double lng, {
    required double northMeters,
    required double eastMeters,
  }) {
    final latOffset = northMeters / 111320.0;
    final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.2, 1.0);
    final lngOffset = eastMeters / (111320.0 * cosLat);
    return (lat: lat + latOffset, lng: lng + lngOffset);
  }

  Map<String, dynamic> _buildCatalogLocationRestriction(
    Iterable<District> districts,
  ) {
    var lowLat = istanbulNortheastLat;
    var lowLng = istanbulNortheastLng;
    var highLat = istanbulSouthwestLat;
    var highLng = istanbulSouthwestLng;

    for (final district in districts) {
      final restriction = districtLocationRestriction(district);
      final rectangle = restriction?['rectangle'] as Map<String, dynamic>?;
      final low = rectangle?['low'] as Map<String, dynamic>?;
      final high = rectangle?['high'] as Map<String, dynamic>?;
      final hasRectangle = low != null && high != null;
      final bounds = hasRectangle
          ? (
              lowLat: (low['latitude'] as num).toDouble(),
              lowLng: (low['longitude'] as num).toDouble(),
              highLat: (high['latitude'] as num).toDouble(),
              highLng: (high['longitude'] as num).toDouble(),
            )
          : _boundsForRadius(
              lat: district.latitude,
              lng: district.longitude,
              radiusMeters: district.searchRadiusMeters ?? 1400,
              expansionFactor: 1.15,
            );
      lowLat = math.min(lowLat, bounds.lowLat);
      lowLng = math.min(lowLng, bounds.lowLng);
      highLat = math.max(highLat, bounds.highLat);
      highLng = math.max(highLng, bounds.highLng);
    }

    if (lowLat > highLat || lowLng > highLng) {
      return _buildCityLocationRestriction();
    }

    return _rectangleRestriction(
      lowLat: lowLat,
      lowLng: lowLng,
      highLat: highLat,
      highLng: highLng,
    );
  }

  Map<String, dynamic> _buildRectangleLocationRestriction({
    required double lat,
    required double lng,
    required int radiusMeters,
    double expansionFactor = 1.0,
  }) {
    final bounds = _boundsForRadius(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      expansionFactor: expansionFactor,
    );
    return _rectangleRestriction(
      lowLat: bounds.lowLat,
      lowLng: bounds.lowLng,
      highLat: bounds.highLat,
      highLng: bounds.highLng,
    );
  }

  ({
    double lowLat,
    double lowLng,
    double highLat,
    double highLng,
  }) _boundsForRadius({
    required double lat,
    required double lng,
    required int radiusMeters,
    double expansionFactor = 1.0,
  }) {
    final expandedRadiusMeters = radiusMeters * expansionFactor;
    final latDelta = expandedRadiusMeters / 111320.0;
    final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.2, 1.0);
    final lngDelta = expandedRadiusMeters / (111320.0 * cosLat);

    return (
      lowLat: math.max(istanbulSouthwestLat, lat - latDelta),
      lowLng: math.max(istanbulSouthwestLng, lng - lngDelta),
      highLat: math.min(istanbulNortheastLat, lat + latDelta),
      highLng: math.min(istanbulNortheastLng, lng + lngDelta),
    );
  }

  Map<String, dynamic> _buildDistrictLocationRestriction(String district) {
    final matchedDistrict =
        matchDistrict(district, districts: _activeDistricts);
    if (matchedDistrict == null) {
      return _buildCityLocationRestriction();
    }

    return districtLocationRestriction(matchedDistrict) ??
        _buildRectangleLocationRestriction(
          lat: matchedDistrict.latitude,
          lng: matchedDistrict.longitude,
          radiusMeters: matchedDistrict.searchRadiusMeters ?? 1400,
          expansionFactor: 1.15,
        );
  }

  Map<String, dynamic> _buildCityLocationRestriction() {
    final districts = _activeDistricts;
    if (districts.isNotEmpty) {
      return _buildCatalogLocationRestriction(districts);
    }

    return _rectangleRestriction(
      lowLat: istanbulSouthwestLat,
      lowLng: istanbulSouthwestLng,
      highLat: istanbulNortheastLat,
      highLng: istanbulNortheastLng,
    );
  }

  Map<String, dynamic> _rectangleRestriction({
    required double lowLat,
    required double lowLng,
    required double highLat,
    required double highLng,
  }) {
    return {
      'rectangle': {
        'low': {
          'latitude': lowLat,
          'longitude': lowLng,
        },
        'high': {
          'latitude': highLat,
          'longitude': highLng,
        },
      },
    };
  }

  Future<List<Map<String, dynamic>>> _fetchPlacesForRequest(
    _PlacesSearchRequest request, {
    required String apiKey,
    required Uri nearbyUrl,
    required Uri textUrl,
    required Duration requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    switch (request.kind) {
      case _PlacesSearchKind.nearby:
        return _fetchNearbyPlaces(
          url: nearbyUrl,
          apiKey: apiKey,
          lat: request.lat!,
          lng: request.lng!,
          radius: request.radius!,
          requestTimeout: requestTimeout,
          cancellationToken: cancellationToken,
        );
      case _PlacesSearchKind.text:
        return _fetchTextSearchPlaces(
          url: textUrl,
          apiKey: apiKey,
          textQuery: request.textQuery!,
          locationRestriction: request.locationRestriction,
          maxPages: request.maxPages ?? _maxTextSearchPagesPerQuery,
          requestTimeout: requestTimeout,
          cancellationToken: cancellationToken,
        );
    }
  }

  Future<Map<String, dynamic>?> _fetchPlaceDetailsRaw(
    String placeId, {
    required String apiKey,
    String fieldMask =
        'id,displayName,rating,userRatingCount,location,shortFormattedAddress,'
            'regularOpeningHours,currentOpeningHours,photos.name,priceLevel,businessStatus,'
            'internationalPhoneNumber,websiteUri,primaryType,types',
    required Duration requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final requestKey =
        '$placeId|${requestTimeout.inMilliseconds.toString()}|$fieldMask';
    final cached = _placeDetailsCache.get(requestKey);
    if (cached != null) {
      return cached;
    }
    if (!_endpointRateLimiter.tryAcquire(
          requestKey,
          bucket: 'place_details',
        ) &&
        cached != null) {
      return cached;
    }

    return _inflightRawDetails.run(
      requestKey,
      () async {
        final url =
            Uri.parse('https://places.googleapis.com/v1/places/$placeId');

        final response = await _sendWithRetry(
          operationName: 'fetchCafeDetails',
          cancellationToken: cancellationToken,
          request: () => _client.get(
            url,
            headers: {
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': fieldMask,
            },
          ).timeout(
            requestTimeout,
            onTimeout: () {
              throw const AppServiceException.timeout(
                'Places details request timed out.',
              );
            },
          ),
        );

        if (response.statusCode != 200) {
          AppLogger.warn(
            safePlacesHttpFailureLogMessage(
              response,
              operationName: 'Details API',
            ),
            key: 'places-details-http-error-${response.statusCode}',
          );
          return null;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _placeDetailsCache.put(requestKey, decoded);
        return decoded;
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchNearbyPlaces({
    required Uri url,
    required String apiKey,
    required double lat,
    required double lng,
    required int radius,
    required Duration requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final requestKey = [
      lat.toStringAsFixed(4),
      lng.toStringAsFixed(4),
      radius.toString(),
      requestTimeout.inMilliseconds.toString(),
    ].join('|');
    final cached = _nearbySearchCache.get(requestKey);
    if (cached != null) {
      AppLogger.debug(
        '[PLACES_CACHE] kind=nearby hit=true key=$requestKey count=${cached.length}',
        key: 'places-cache-nearby',
        throttle: Duration.zero,
      );
      return cached;
    }
    AppLogger.debug(
      '[PLACES_CACHE] kind=nearby hit=false key=$requestKey',
      key: 'places-cache-nearby',
      throttle: Duration.zero,
    );
    if (!_endpointRateLimiter.tryAcquire(
          requestKey,
          bucket: 'nearby_search',
        ) &&
        cached != null) {
      return cached;
    }

    return _inflightNearbyRequests.run(
      requestKey,
      () async {
        final response = await _sendWithRetry(
          operationName: 'fetchNearbyCafes',
          cancellationToken: cancellationToken,
          request: () => _client
              .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask':
                  'places.id,places.displayName,places.rating,places.userRatingCount,'
                      'places.location,places.shortFormattedAddress,'
                      'places.regularOpeningHours,places.currentOpeningHours,'
                      'places.photos.name,'
                      'places.priceLevel,places.businessStatus,'
                      'places.primaryType,places.types',
            },
            body: jsonEncode({
              'includedTypes': ['cafe', 'coffee_shop'],
              'maxResultCount': _maxNearbyResultCount,
              'rankPreference': 'DISTANCE',
              'locationRestriction': {
                'circle': {
                  'center': {
                    'latitude': lat,
                    'longitude': lng,
                  },
                  'radius': radius.toDouble(),
                },
              },
            }),
          )
              .timeout(
            requestTimeout,
            onTimeout: () {
              throw const AppServiceException.timeout(
                'Places nearby search request timed out.',
              );
            },
          ),
        );

        _throwIfPlacesHttpFailure(response, operationName: 'Nearby Search');

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>?;
        final normalized = places == null || places.isEmpty
            ? const <Map<String, dynamic>>[]
            : places.cast<Map<String, dynamic>>();
        _nearbySearchCache.put(requestKey, normalized);
        return normalized;
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTextSearchPlaces({
    required Uri url,
    required String apiKey,
    required String textQuery,
    Map<String, dynamic>? locationRestriction,
    int maxPages = _maxTextSearchPagesPerQuery,
    required Duration requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final places = <Map<String, dynamic>>[];
    String? nextPageToken;

    for (var pageIndex = 0; pageIndex < maxPages; pageIndex++) {
      cancellationToken?.throwIfCancelled();
      if (pageIndex > 0) {
        await Future<void>.delayed(NetworkTimeoutConfig.placesPaginationDelay);
        cancellationToken?.throwIfCancelled();
      }
      late final ({
        List<Map<String, dynamic>> places,
        String? nextPageToken
      }) result;
      try {
        result = await _fetchTextSearchPage(
          url: url,
          apiKey: apiKey,
          textQuery: textQuery,
          pageToken: nextPageToken,
          locationRestriction: locationRestriction,
          requestTimeout: requestTimeout,
          cancellationToken: cancellationToken,
        );
      } catch (error) {
        if (pageIndex == 0) {
          rethrow;
        }
        AppLogger.warn(
          'PlacesService text search pagination stopped early for "$textQuery"',
          key:
              'places-text-search-pagination-${normalizeSearchText(textQuery)}',
        );
        break;
      }
      places.addAll(result.places);
      CafeDiscoveryDebugReportRecorder.instance.recordTextPage(
        textQuery: textQuery,
        pageIndex: pageIndex,
        placesCount: result.places.length,
        hasNextPageToken: result.nextPageToken?.trim().isNotEmpty == true,
      );

      final nextToken = result.nextPageToken?.trim();
      if (nextToken == null || nextToken.isEmpty) {
        break;
      }
      nextPageToken = nextToken;
    }

    return places;
  }

  Future<({List<Map<String, dynamic>> places, String? nextPageToken})>
      _fetchTextSearchPage({
    required Uri url,
    required String apiKey,
    required String textQuery,
    String? pageToken,
    Map<String, dynamic>? locationRestriction,
    required Duration requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final normalizedRestriction = locationRestriction == null
        ? 'global'
        : jsonEncode(locationRestriction);
    final requestKey = [
      normalizeSearchText(textQuery),
      pageToken?.trim().isNotEmpty == true ? pageToken!.trim() : 'first',
      normalizedRestriction,
      requestTimeout.inMilliseconds.toString(),
    ].join('|');
    final cached = _textSearchCache.get(requestKey);
    if (cached != null) {
      AppLogger.debug(
        '[PLACES_CACHE] kind=text hit=true key=$requestKey count=${cached.places.length}',
        key: 'places-cache-text',
        throttle: Duration.zero,
      );
      return cached;
    }
    AppLogger.debug(
      '[PLACES_CACHE] kind=text hit=false key=$requestKey',
      key: 'places-cache-text',
      throttle: Duration.zero,
    );
    if (!_endpointRateLimiter.tryAcquire(
          requestKey,
          bucket: 'text_search',
        ) &&
        cached != null) {
      return cached;
    }

    return _inflightTextPages.run(
      requestKey,
      () async {
        final response = await _sendWithRetry(
          operationName: 'fetchTextCafes',
          cancellationToken: cancellationToken,
          request: () => _client
              .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask':
                  'places.id,places.displayName,places.rating,places.userRatingCount,'
                      'places.location,places.shortFormattedAddress,'
                      'places.regularOpeningHours,places.currentOpeningHours,'
                      'places.photos.name,'
                      'places.priceLevel,places.businessStatus,'
                      'places.primaryType,places.types,nextPageToken',
            },
            body: jsonEncode({
              'textQuery': textQuery,
              'pageSize': _textSearchPageSize,
              if (pageToken != null && pageToken.isNotEmpty)
                'pageToken': pageToken,
              'strictTypeFiltering': false,
              'locationRestriction':
                  locationRestriction ?? _buildCityLocationRestriction(),
            }),
          )
              .timeout(
            requestTimeout,
            onTimeout: () {
              throw const AppServiceException.timeout(
                'Places text search request timed out.',
              );
            },
          ),
        );

        _throwIfPlacesHttpFailure(response, operationName: 'Text Search');

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>?;
        final result = (
          places: places == null
              ? const <Map<String, dynamic>>[]
              : places.cast<Map<String, dynamic>>(),
          nextPageToken: data['nextPageToken'] as String?,
        );
        _textSearchCache.put(requestKey, result);
        return result;
      },
    );
  }

  void _throwIfPlacesHttpFailure(
    http.Response response, {
    required String operationName,
  }) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      AppLogger.warn(
        'PlacesService: Authentication Error (${response.statusCode}). '
        'Check your API key.',
        key: 'places-auth-error-${response.statusCode}',
      );
      throw const AppServiceException.auth(
        'Invalid Google Places API key.',
        errorCode: AppErrorCode.serviceUnavailable,
      );
    }

    if (response.statusCode == 429) {
      AppLogger.warn(
        'PlacesService: Rate limit exceeded.',
        key: 'places-rate-limit',
      );
      throw const AppServiceException.rateLimit(
        'Places API rate limit exceeded.',
        errorCode: AppErrorCode.serviceUnavailable,
      );
    }

    if (response.statusCode != 200) {
      AppLogger.warn(
        safePlacesHttpFailureLogMessage(
          response,
          operationName: operationName,
        ),
        key: 'places-http-error-${response.statusCode}',
      );
      throw AppServiceException.unavailable(
        'Places API error: HTTP ${response.statusCode}',
        errorCode: AppErrorCode.serviceUnavailable,
      );
    }
  }

  Future<http.Response> _sendWithRetry({
    required String operationName,
    required Future<http.Response> Function() request,
    RequestCancellationToken? cancellationToken,
  }) async {
    return retryAsync(
      () async {
        cancellationToken?.throwIfCancelled();
        final response = await request();
        if (_shouldRetryStatusCode(response.statusCode)) {
          if (response.statusCode == 429) {
            throw AppServiceException.rateLimit(
              'retryable_http_${response.statusCode}',
              errorCode: AppErrorCode.serviceUnavailable,
            );
          }
          throw AppServiceException.unavailable(
            'retryable_http_${response.statusCode}',
            errorCode: AppErrorCode.serviceUnavailable,
          );
        }
        return response;
      },
      maxAttempts: RateLimitConfig.maxRequestAttempts,
      initialDelay: NetworkTimeoutConfig.placesRetryInitialDelay,
      backoffMultiplier: NetworkTimeoutConfig.placesRetryBackoffMultiplier,
      shouldRetry: (error) {
        final retryable = _isRetryableError(error);
        if (retryable) {
          AppLogger.warn(
            'PlacesService.$operationName retrying after $error',
            key: '$operationName-retry-${error.toString()}',
          );
        }
        return retryable;
      },
      cancellationToken: cancellationToken,
    );
  }

  bool _shouldRetryStatusCode(int statusCode) {
    return statusCode == 429 || statusCode >= 500;
  }

  bool _isRetryableError(Object error) {
    if (error is TimeoutException ||
        (error is AppServiceException &&
            error.type == ServiceErrorType.timeout)) {
      return true;
    }
    if (error is AppServiceException &&
        error.type == ServiceErrorType.cancelled) {
      return false;
    }

    final text = error.toString().toLowerCase();
    if (text.contains('retryable_http_429') ||
        RegExp(r'retryable_http_5\d{2}').hasMatch(text)) {
      return true;
    }
    return text.contains('socket') ||
        text.contains('timeout') ||
        text.contains('network') ||
        text.contains('connection');
  }

  String _describePlacesError(Object error, String action) {
    switch (classifyServiceError(error)) {
      case ServiceErrorType.cancelled:
        return 'The request to $action was cancelled.';
      case ServiceErrorType.rateLimit:
        return 'Google Places is rate limiting requests right now.';
      case ServiceErrorType.timeout:
        return 'Google Places timed out while trying to $action.';
      case ServiceErrorType.network:
        return 'A network error occurred while trying to $action.';
      case ServiceErrorType.auth:
      case ServiceErrorType.unavailable:
        return 'Google Places configuration is unavailable.';
      case ServiceErrorType.parse:
        return 'Google Places returned unexpected data while trying to $action.';
      case ServiceErrorType.validation:
      case ServiceErrorType.conflict:
      case ServiceErrorType.notFound:
      case ServiceErrorType.unknown:
        return 'Unable to $action from Google Places.';
    }
  }

  void dispose() {
    _inflightCafeSearches.clear();
    _inflightCafeDetails.clear();
    _inflightNearbyRequests.clear();
    _inflightTextPages.clear();
    _inflightRawDetails.clear();
    _nearbySearchCache.clear();
    _textSearchCache.clear();
    _placeDetailsCache.clear();
    _endpointRateLimiter.dispose();
    _client.close();
  }

  bool _hasUsableGoogleLocation(Map<String, dynamic> place) {
    final location = place['location'];
    if (location is! Map<String, dynamic>) {
      return false;
    }

    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      return false;
    }

    return lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        isWithinIstanbul(lat, lng);
  }

  bool _matchesDistrict(String cafeDistrict, String selectedDistrict) {
    return districtMatches(
      cafeDistrict,
      selectedDistrict,
      districts: _activeDistricts,
    );
  }

  void _logRawGooglePlacePhotoPayload(
    Map<String, dynamic> place, {
    required String source,
    required String label,
    _PhotoLogTracker? tracker,
  }) {
    final id = (place['id'] as String?)?.trim() ?? 'unknown';
    final displayName =
        (place['displayName'] as Map<String, dynamic>?)?['text'] as String? ??
            'unknown';
    final photoPayload = place['photos'];
    if (!kDebugMode && tracker == null) {
      return;
    }

    final rawImageInputs = <String, Object?>{
      'photos': photoPayload,
      'photo_urls': place['photo_urls'],
      'photoUrl': place['photoUrl'],
      'image_url': place['image_url'],
      'image_urls': place['image_urls'],
      'media': place['media'],
    };
    final imageCount = rawImageInputs.values.fold<int>(
      0,
      (count, value) => count + _estimatePhotoPayloadCount(value),
    );
    if (tracker != null) {
      tracker.rawCandidateCount += 1;
      if (imageCount > 0) {
        tracker.imagePayloadCount += 1;
      }
    }
    if (!kDebugMode || imageCount == 0) {
      return;
    }

    if (tracker != null && tracker.sampledCount >= _photoLogSampleLimit) {
      return;
    }

    final rawImageFields = <String, Object?>{
      'photos': _previewForLog(photoPayload),
      'photo_urls': _previewForLog(place['photo_urls']),
      'photoUrl': _previewForLog(place['photoUrl']),
      'image_url': _previewForLog(place['image_url']),
      'image_urls': _previewForLog(place['image_urls']),
      'media': _previewForLog(place['media']),
    };

    AppLogger.debug(
      '[CAFE_DIAG_PHOTO_RAW_GOOGLE] source=$source label="$label" id=$id name="$displayName" imageCount=$imageCount raw=$rawImageFields',
      key: 'cafe-diag-photo-raw-google-$source-$id',
      throttle: Duration.zero,
    );
    if (tracker != null) {
      tracker.sampledCount += 1;
    }
  }

  Object? _previewForLog(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return redactUrlForLog(value);
    }
    if (value is List) {
      return value.take(2).map(_previewForLog).toList(growable: false);
    }
    if (value is Map) {
      final entries = value.entries.take(6);
      return <String, Object?>{
        for (final entry in entries)
          entry.key.toString(): _previewForLog(entry.value),
      };
    }
    return value;
  }

  int _estimatePhotoPayloadCount(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is String) {
      return value.trim().isEmpty ? 0 : 1;
    }
    if (value is List) {
      var count = 0;
      for (final item in value) {
        count += _estimatePhotoPayloadCount(item);
      }
      return count;
    }
    if (value is Map) {
      return value.isEmpty ? 0 : 1;
    }
    return 1;
  }

  String _formatTopReasonCounts(Map<String, int> counts, {int limit = 4}) {
    if (counts.isEmpty) {
      return 'none';
    }
    final sorted = counts.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));
    return sorted
        .take(limit)
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
  }

  String _radiusPresetLabelForRadius(int radiusMeters) {
    if (radiusMeters >= 4000) {
      return 'large';
    }
    if (radiusMeters >= 2000) {
      return 'medium';
    }
    return 'small';
  }
}
