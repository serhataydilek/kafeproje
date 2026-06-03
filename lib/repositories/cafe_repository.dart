import 'dart:async';

import '../constants/app_cache_config.dart';
import '../models/cafe_cache.dart';
import '../models/index.dart';
import '../models/service_result.dart';
import '../services/connectivity_service.dart';
import '../services/local_storage_service.dart';
import '../services/places_service.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';
import '../utils/cafe_branching.dart';
import '../utils/cafe_discovery_debug_report.dart';
import '../utils/cafe_cache_keys.dart';
import '../utils/cafe_cache_policy.dart';
import '../utils/cafe_discovery_classifier.dart';
import '../utils/cafe_media.dart';
import '../utils/district_utils.dart';
import '../utils/filter_sort.dart';
import '../utils/inflight_request_registry.dart';
import '../utils/log_sanitizer.dart';
import '../utils/lru_cache.dart';
import '../utils/request_cancellation.dart';
import '../utils/rate_limiter.dart';
import '../utils/service_error.dart';
import '../utils/text_normalization.dart';
import 'cafe_merge_policy.dart';

class CafeRepositoryResult {
  const CafeRepositoryResult({
    this.ok = true,
    required this.cafes,
    required this.usedRemote,
    this.warningMessage,
    this.nextPageToken,
    this.errorMessage,
    this.errorType = ServiceErrorType.unknown,
    this.diagnostics,
  });

  const CafeRepositoryResult.failure({
    this.cafes = const <Cafe>[],
    this.usedRemote = false,
    this.warningMessage,
    this.nextPageToken,
    this.errorMessage,
    this.errorType = ServiceErrorType.unknown,
    this.diagnostics,
  }) : ok = false;

  final bool ok;
  final List<Cafe> cafes;
  final bool usedRemote;
  final String? warningMessage;
  final String? nextPageToken;
  final String? errorMessage;
  final ServiceErrorType errorType;
  final CafeDiscoveryDiagnostics? diagnostics;
}

class CafeDiscoveryDiagnostics {
  const CafeDiscoveryDiagnostics({
    required this.rawFetchedCount,
    required this.rejectedByClassifierCount,
    required this.rejectedByDedupeCount,
    required this.finalMergedCount,
    required this.finalPublicCount,
    required this.fromRemote,
  });

  final int rawFetchedCount;
  final int rejectedByClassifierCount;
  final int rejectedByDedupeCount;
  final int finalMergedCount;
  final int finalPublicCount;
  final bool fromRemote;
}

/// Repository-owned local source of truth for cafe cache and remote merges.
///
/// Widgets must observe `cafeProvider`; this repository is intentionally
/// non-reactive and only manages cached snapshots plus remote fetch behavior.
class CafeRepository {
  CafeRepository(
    this._service, [
    this._cafeOverlaySource,
    this._storage,
    this._connectivityService,
  ]);

  final PlacesServiceBase? _service;
  final CafeOverlaySource? _cafeOverlaySource;
  final LocalStorageService? _storage;
  final ConnectivityService? _connectivityService;
  final LruCache<String, CafeListCacheSnapshot> _memoryCafeListCache =
      LruCache<String, CafeListCacheSnapshot>(
    maxSize: CafeCachePolicy.memoryListEntryLimit,
    defaultTtl: CafeCachePolicy.memoryListTtl,
  );
  final LruCache<String, Cafe> _memoryCafeDetails = LruCache<String, Cafe>(
    maxSize: CafeCachePolicy.memoryDetailEntryLimit,
    defaultTtl: CafeCachePolicy.detailFreshTtl,
  );
  final LruCache<String, List<({String district, int count})>>
      _memoryPopularDistrictCounts =
      LruCache<String, List<({String district, int count})>>(
    maxSize: 12,
    defaultTtl: const Duration(minutes: 10),
  );
  final InflightRequestRegistry<CafeRepositoryResult> _inflightCafeRequests =
      InflightRequestRegistry<CafeRepositoryResult>();
  final InflightRequestRegistry<Cafe?> _inflightCafeDetails =
      InflightRequestRegistry<Cafe?>();
  final InflightRequestRegistry<List<({String district, int count})>>
      _inflightPopularDistrictCounts =
      InflightRequestRegistry<List<({String district, int count})>>();
  final RateLimiter _rateLimiter = RateLimiter(
    bucketIntervals: const {
      'nearby_search': RequestTuningConfig.nearbySearchMinInterval,
      'place_details': RequestTuningConfig.placeDetailsMinInterval,
    },
  );

  bool get isRemoteEnabled => _service != null;
  bool get supportsLoadMorePagination =>
      _service?.supportsExternalPagination ?? true;
  bool get _isOnline => _connectivityService?.currentlyOnline ?? true;
  Future<void> clearCache() async {
    _memoryCafeListCache.clear();
    _memoryCafeDetails.clear();
    _memoryPopularDistrictCounts.clear();
    if (_storage != null) {
      await _storage!.clearCafeCache();
    }
  }

  Future<int> removeCafeFromCache(Iterable<String> rawIds) async {
    final ids =
        rawIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return 0;
    }

    var removed = 0;
    for (final id in ids) {
      final existing = _memoryCafeDetails.get(id);
      if (existing != null) {
        _memoryCafeDetails.remove(id);
        removed += 1;
      }
      await _storage?.invalidateCafeDetailCache(id);
    }

    for (final entry in _memoryCafeDetails.entries.toList()) {
      final cafe = entry.value;
      if (ids.any((id) => _cafeMatchesIdentifier(cafe, id))) {
        _memoryCafeDetails.remove(entry.key);
        removed += 1;
      }
    }

    _memoryCafeListCache.clear();
    _memoryPopularDistrictCounts.clear();
    await _storage?.clearCafeListCaches();
    return removed;
  }

  /// Evicts only the in-memory list cache without touching disk or detail caches.
  /// Use after a single cafe is mutated to avoid serving stale list data while
  /// preserving the disk cache and other cached data.
  void evictCafeListCache() {
    _memoryCafeListCache.clear();
    _memoryPopularDistrictCounts.clear();
  }

  /// Keeps already-seen cafes resolvable by id/place id even after the active
  /// radius-owned discovery list is replaced.
  void rememberCafes(Iterable<Cafe> cafes) {
    for (final cafe in cafes) {
      _rememberCafe(cafe);
    }
  }

  Future<List<Cafe>> getCafesByIds(
    List<String> cafeIds, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final normalizedIds = <String>[];
    final seen = <String>{};
    for (final rawId in cafeIds) {
      final id = rawId.trim();
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      normalizedIds.add(id);
    }
    if (normalizedIds.isEmpty) {
      return const <Cafe>[];
    }

    final byRequestedId = <String, Cafe>{};
    for (final id in normalizedIds) {
      final cached = _findCachedCafeByIdentifier(id);
      if (cached == null) {
        continue;
      }
      byRequestedId[id] = cached;
    }

    final missing = normalizedIds
        .where((id) => !byRequestedId.containsKey(id))
        .toList(growable: false);

    if (missing.isNotEmpty && _storage != null) {
      final cached = await _storage!.resolveCachedCafesByIdentifiers(missing);
      for (final cafe in cached) {
        _rememberCafe(cafe);
        _assignCafeToRequestedIds(cafe, normalizedIds, byRequestedId);
      }
    }

    final unresolvedAfterCache = normalizedIds
        .where((id) => !byRequestedId.containsKey(id))
        .toList(growable: false);

    if (unresolvedAfterCache.isNotEmpty) {
      final queryService = _cafeOverlaySource;
      if (queryService != null) {
        final result = await queryService.fetchCafesByIds(
          unresolvedAfterCache,
          includeDeleted: includeDeleted,
          requestTimeout: requestTimeout,
          cancellationToken: cancellationToken,
        );

        if (result.ok) {
          for (final cafe in result.data ?? const <Cafe>[]) {
            _rememberCafe(cafe);
            _assignCafeToRequestedIds(cafe, normalizedIds, byRequestedId);
          }
        }

        final stillMissing = normalizedIds
            .where((id) => !byRequestedId.containsKey(id))
            .toList(growable: false);
        if (stillMissing.isNotEmpty) {
          final placeResult = await queryService.fetchCafesByPlaceIds(
            stillMissing,
            includeDeleted: includeDeleted,
            requestTimeout: requestTimeout,
            cancellationToken: cancellationToken,
          );

          if (placeResult.ok) {
            for (final cafe in placeResult.data ?? const <Cafe>[]) {
              _rememberCafe(cafe);
              _assignCafeToRequestedIds(cafe, normalizedIds, byRequestedId);
            }
          }
        }
      }
    }

    final ordered = <Cafe>[];
    final emitted = <String>{};
    for (final id in normalizedIds) {
      final cafe = byRequestedId[id];
      if (cafe == null) {
        continue;
      }
      final canonical = CafeMergePolicy.canonicalIdentityFor(cafe);
      if (!emitted.add(canonical)) {
        continue;
      }
      if (!includeDeleted && _isPublicCafe(cafe) == false) {
        continue;
      }
      ordered.add(cafe);
    }
    return ordered;
  }

  /// Text search is a Supabase overlay lookup, not a Google discovery owner.
  ///
  /// The caller should use this only to hydrate local results when a user has
  /// an explicit search query and the current discovery corpus has no matches.
  Future<CafeRepositoryResult> searchCafesByName(
    String query, {
    int limit = 20,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const CafeRepositoryResult(cafes: <Cafe>[], usedRemote: false);
    }

    final queryService = _cafeOverlaySource;
    if (queryService == null) {
      return const CafeRepositoryResult.failure(
        errorMessage: 'Cafe search service is unavailable.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    final requestKey =
        'supabase-name-search:${normalizeSearchText(normalizedQuery)}:$limit';
    return _deduplicate(
      _inflightCafeRequests,
      requestKey,
      () async {
        final result = await queryService.searchCafesByName(
          normalizedQuery,
          limit: limit,
        );
        if (!result.ok) {
          return CafeRepositoryResult.failure(
            errorMessage: result.message,
            errorType: result.errorType,
          );
        }

        cancellationToken?.throwIfCancelled();
        final cafes = (result.data ?? const <Cafe>[])
            .where(_isPublicCafe)
            .toList(growable: false);
        _indexCafes(cafes);
        return CafeRepositoryResult(
          cafes: applySharedBrandPricing(cafes),
          usedRemote: true,
        );
      },
      (error, stackTrace) => AppLogger.error(
        'CafeRepository.searchCafesByName failed for $requestKey',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-search-name-$requestKey',
      ),
    );
  }

  Future<List<Cafe>> fetchFeaturedCafes({
    int limit = 40,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final queryService = _cafeOverlaySource;
    if (queryService == null) {
      return const <Cafe>[];
    }

    final result = await queryService.fetchActiveFeaturedCafes(
      limit: limit,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
    if (!result.ok) {
      AppLogger.warn(
        'CafeRepository: active featured Supabase fetch failed. errorType=${result.errorType} errorCode=${result.errorCode}',
        key: 'cafe-featured-fetch-failed',
      );
      throw AppServiceException(
        message: result.message ?? 'Unable to load featured cafes.',
        type: result.errorType,
        errorCode: result.errorCode,
        cause: result.error,
      );
    }

    final incoming = result.data ?? const <Cafe>[];
    final activeCount = incoming.where((cafe) => cafe.isActiveFeatured).length;
    final publicCount = incoming.where(_isPublicFeaturedCafe).length;
    AppLogger.debug(
      '[FEATURED_REPO] incoming=${incoming.length} active=$activeCount public=$publicCount',
      key: 'featured-repo-count',
      throttle: Duration.zero,
    );

    final cafes = incoming.where(_isPublicFeaturedCafe).toList(growable: false)
      ..sort((left, right) {
        final priority =
            left.featuredPriority.compareTo(right.featuredPriority);
        if (priority != 0) {
          return priority;
        }

        final rating = right.effectiveRating.compareTo(left.effectiveRating);
        if (rating != 0) {
          return rating;
        }

        final name =
            left.name.toLowerCase().compareTo(right.name.toLowerCase());
        if (name != 0) {
          return name;
        }

        return left.id.compareTo(right.id);
      });

    _indexCafes(cafes);
    final pricedCafes = applySharedBrandPricing(cafes);
    _logFeaturedImageDiagnostics(pricedCafes);
    return List<Cafe>.unmodifiable(pricedCafes);
  }

  void _logFeaturedImageDiagnostics(List<Cafe> cafes) {
    if (!kVerboseCafeDiagnostics) {
      return;
    }
    for (final cafe in cafes.take(5)) {
      final resolvedUrl = cafe.photoUrls
          .map((url) => resolveCafeImageUrl(
                url,
                maxWidthPx: CafeImageVariant.listThumbnail.requestWidthPx,
              ))
          .whereType<String>()
          .firstOrNull;
      final hasSupabaseImages = cafe.photoUrls.isNotEmpty;
      final hasPlaceId = cafe.placeId?.trim().isNotEmpty == true;
      final imageSource = resolvedUrl == null
          ? 'placeholder'
          : hasSupabaseImages
              ? 'Supabase'
              : hasPlaceId
                  ? 'Google fallback'
                  : 'placeholder';
      AppLogger.debug(
        '[FEATURED_IMAGE_DIAG] id=${cafe.id} name=${cafe.name} google_place_id=${cafe.placeId ?? ''} images=${cafe.photoUrls.length} ${summarizeUrlForLog(resolvedUrl, presenceLabel: 'resolvedImageUrl')} imageSource=$imageSource',
        key: 'featured-image-diag-${cafe.id}',
        throttle: Duration.zero,
      );
    }
  }

  Future<List<Cafe>> hydrateFeaturedGoogleRatingMetadata(
    Iterable<Cafe> featuredCafes, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final places = _service;
    final overlay = _cafeOverlaySource;
    if (places == null) {
      return const <Cafe>[];
    }

    final candidates = featuredCafes.where((cafe) {
      final placeId = cafe.placeId?.trim();
      return cafe.isActiveFeatured &&
          placeId != null &&
          placeId.isNotEmpty &&
          (cafe.googleRating == null ||
              cafe.googleReviewCount == null ||
              _needsFeaturedImageRefresh(cafe));
    }).toList(growable: false);
    if (candidates.isEmpty) {
      return const <Cafe>[];
    }

    final updated = <Cafe>[];
    for (final cafe in candidates.take(3)) {
      cancellationToken?.throwIfCancelled();
      final placeId = cafe.placeId!.trim();
      final needsImageRefresh = _needsFeaturedImageRefresh(cafe);
      try {
        if (needsImageRefresh && kVerboseCafeDiagnostics) {
          AppLogger.debug(
            '[FEATURED_IMAGE_REFRESH_START] cafeId=${cafe.id} name="${cafe.name}" googlePlaceIdPresent=true reason=no_usable_candidates',
            key: 'featured-image-refresh-start-${cafe.id}',
            throttle: Duration.zero,
          );
        }
        if (kVerboseCafeDiagnostics) {
          AppLogger.debug(
            '[SPONSORED_RATING_HYDRATE] placeIdPresent=true result=start',
            key: 'sponsored-rating-hydrate-start-${cafe.id}',
            throttle: Duration.zero,
          );
        }

        final bool fetchDetails = needsImageRefresh || cafe.images.isEmpty;
        double? rating;
        int? reviewCount;
        Cafe? googleCafe;
        List<String> freshImageCandidates = const <String>[];

        if (fetchDetails) {
          googleCafe = await places.fetchCafeDetails(
            placeId,
            requestTimeout: requestTimeout,
            cancellationToken: cancellationToken,
          );
          rating = googleCafe?.googleRating;
          reviewCount = googleCafe?.googleReviewCount;
          if (googleCafe != null && needsImageRefresh) {
            freshImageCandidates = _freshFeaturedImageCandidates(
              googleCafe: googleCafe,
              featuredCafe: cafe,
            );
          }
        } else {
          final metadata = await places.fetchPlaceRatingMetadata(
            placeId,
            requestTimeout: requestTimeout,
            cancellationToken: cancellationToken,
          );
          rating = metadata?.rating;
          reviewCount = metadata?.reviewCount;
        }

        if (rating == null &&
            reviewCount == null &&
            (googleCafe == null || googleCafe.images.isEmpty) &&
            freshImageCandidates.isEmpty) {
          if (needsImageRefresh) {
            _logFeaturedImageRefreshResult(
              cafe: cafe,
              placeId: placeId,
              freshCandidates: freshImageCandidates,
              success: false,
              errorType: 'empty',
            );
          }
          if (kVerboseCafeDiagnostics) {
            AppLogger.debug(
              '[SPONSORED_RATING_HYDRATE] placeIdPresent=true result=failure',
              key: 'sponsored-rating-hydrate-empty-${cafe.id}',
              throttle: Duration.zero,
            );
          }
          continue;
        }

        final syncedAt = DateTime.now().toUtc().toIso8601String();
        unawaited(
          overlay?.updateGoogleRatingMetadata(
                cafeId: cafe.id,
                googlePlaceId: placeId,
                googleRating: rating,
                googleReviewCount: reviewCount,
                externalLastSyncedAt: syncedAt,
                requestTimeout: requestTimeout,
              ) ??
              Future<ServiceResult<void>>.value(
                ServiceResult.success(data: null),
              ),
        );

        Cafe updatedCafe;
        if (googleCafe != null && freshImageCandidates.isNotEmpty) {
          updatedCafe = _mergeFeaturedGoogleDetails(
            featuredCafe: cafe,
            googleCafe: googleCafe,
            freshImageCandidates: freshImageCandidates,
            syncedAt: syncedAt,
          );
        } else if (googleCafe != null) {
          updatedCafe = CafeMergePolicy.mergeCafeSources(
            googlePlaceCafe: googleCafe,
            supabaseCafe: cafe,
          );
        } else {
          final googleData = (cafe.googlePlaceData ??
                  GooglePlaceData(
                      googlePlaceId: placeId, usesAppDefaults: true))
              .copyWith(
            googlePlaceId: placeId,
            googleRating: rating,
            googleReviewCount: reviewCount,
            lastSyncedAt: syncedAt,
          );
          updatedCafe = cafe.copyWith(googlePlaceData: () => googleData);
        }

        updated.add(updatedCafe);
        if (needsImageRefresh) {
          _logFeaturedImageRefreshResult(
            cafe: cafe,
            placeId: placeId,
            freshCandidates: freshImageCandidates,
            success: freshImageCandidates.isNotEmpty,
            errorType: freshImageCandidates.isEmpty ? 'empty' : null,
          );
        }
        if (kVerboseCafeDiagnostics) {
          AppLogger.debug(
            '[SPONSORED_RATING_HYDRATE] placeIdPresent=true result=success photosCount=${updatedCafe.images.length}',
            key: 'sponsored-rating-hydrate-success-${cafe.id}',
            throttle: Duration.zero,
          );
        }
      } catch (error) {
        if (needsImageRefresh) {
          _logFeaturedImageRefreshResult(
            cafe: cafe,
            placeId: placeId,
            freshCandidates: const <String>[],
            success: false,
            errorType: classifyServiceError(error).name,
          );
        }
        if (kVerboseCafeDiagnostics) {
          AppLogger.debug(
            '[SPONSORED_RATING_HYDRATE] placeIdPresent=true result=failure error=$error',
            key: 'sponsored-rating-hydrate-failure-${cafe.id}',
            throttle: Duration.zero,
          );
        }
      }
    }
    if (updated.isNotEmpty) {
      _indexCafes(updated);
    }
    return List<Cafe>.unmodifiable(updated);
  }

  bool _needsFeaturedImageRefresh(Cafe cafe) {
    if (cafe.photoUrls.isEmpty) {
      return true;
    }
    return !_hasUsableFeaturedDisplayImage(cafe.photoUrls);
  }

  bool _hasUsableFeaturedDisplayImage(List<String> urls) {
    for (final url in urls) {
      final normalized = resolveCafeImageUrl(url);
      if (normalized == null || isKnownFailedCafeImageUrl(normalized)) {
        continue;
      }
      if (!isGeneratedPlacesMediaImageUrl(normalized)) {
        return true;
      }
    }
    return false;
  }

  List<String> _freshFeaturedImageCandidates({
    required Cafe googleCafe,
    required Cafe featuredCafe,
  }) {
    final staleCandidates = featuredCafe.photoUrls
        .map(resolveCafeImageUrl)
        .whereType<String>()
        .toSet();
    final fresh = <String>[];
    final seen = <String>{};
    for (final image in googleCafe.photoUrls) {
      final normalized = resolveCafeImageUrl(image);
      if (normalized == null ||
          isKnownFailedCafeImageUrl(normalized) ||
          staleCandidates.contains(normalized) ||
          !seen.add(normalized)) {
        continue;
      }
      fresh.add(normalized);
      if (fresh.length >= 8) {
        break;
      }
    }
    return List<String>.unmodifiable(fresh);
  }

  Cafe _mergeFeaturedGoogleDetails({
    required Cafe featuredCafe,
    required Cafe googleCafe,
    required List<String> freshImageCandidates,
    required String syncedAt,
  }) {
    final existingGoogleData = featuredCafe.googlePlaceData ??
        GooglePlaceData(
          googlePlaceId: featuredCafe.placeId,
          usesAppDefaults: true,
        );
    final googleData = existingGoogleData.copyWith(
      googlePlaceId: featuredCafe.placeId ?? googleCafe.placeId,
      googleRating: googleCafe.googleRating,
      googleReviewCount: googleCafe.googleReviewCount,
      googleOpenNow: googleCafe.googlePlaceData?.googleOpenNow,
      formattedAddress:
          googleCafe.googlePlaceData?.formattedAddress ?? googleCafe.address,
      lastSyncedAt: syncedAt,
      hasPriceLevel: googleCafe.hasPriceLevel,
      usesAppDefaults: true,
      sourceTypes: <String>{
        ...existingGoogleData.sourceTypes,
        ...googleCafe.googlePlaceData?.sourceTypes ?? const <String>[],
        'featured_image_refresh',
      }.toList(growable: false),
    );

    return featuredCafe.copyWith(
      images: freshImageCandidates,
      googlePlaceData: () => googleData,
    );
  }

  void _logFeaturedImageRefreshResult({
    required Cafe cafe,
    required String placeId,
    required List<String> freshCandidates,
    required bool success,
    String? errorType,
  }) {
    if (!kVerboseCafeDiagnostics) {
      return;
    }
    final first = freshCandidates.isEmpty ? null : freshCandidates.first;
    AppLogger.debug(
      '[FEATURED_IMAGE_REFRESH_RESULT] cafeId=${cafe.id} googlePlaceId=$placeId success=$success freshCandidateCount=${freshCandidates.length} firstHost=${_urlHostForFeaturedRefresh(first)} firstPathShape=${_urlPathShapeForFeaturedRefresh(first)} source=google_place_details errorType=${errorType ?? ''}',
      key: 'featured-image-refresh-result-${cafe.id}',
      throttle: Duration.zero,
    );
  }

  String _urlHostForFeaturedRefresh(String? url) {
    final parsed = url == null ? null : Uri.tryParse(url);
    return parsed?.host.isNotEmpty == true ? parsed!.host : 'none';
  }

  String _urlPathShapeForFeaturedRefresh(String? url) {
    final parsed = url == null ? null : Uri.tryParse(url);
    if (parsed == null || parsed.pathSegments.isEmpty) {
      return 'none';
    }
    return parsed.pathSegments.map((segment) {
      if (segment.startsWith('ChIJ') ||
          segment.length > 18 ||
          RegExp(r'^[A-Za-z0-9_-]{12,}$').hasMatch(segment)) {
        return '*';
      }
      return segment;
    }).join('/');
  }

  Future<List<({String district, int count})>> fetchPopularDistrictCounts({
    Filters filters = Filters.empty,
    Iterable<District> districts = const <District>[],
  }) async {
    final queryService = _cafeOverlaySource;
    if (queryService == null) {
      return const <({String district, int count})>[];
    }

    final summaryFilters = _popularDistrictSummaryFilters(filters);
    final cacheKey = _popularDistrictCountsCacheKey(summaryFilters, districts);
    final cached = _memoryPopularDistrictCounts.get(cacheKey);
    if (cached != null) {
      return cached;
    }

    return _inflightPopularDistrictCounts.run(
      cacheKey,
      () async {
        final result = await queryService.fetchDiscoverableCafes(limit: 2000);
        if (!result.ok || result.data == null) {
          return cached ?? const <({String district, int count})>[];
        }

        final publicCafes =
            result.data!.where(_isPublicCafe).toList(growable: false);
        final filteredCafes = applyFilters(
          publicCafes,
          summaryFilters,
          districts: districts,
        );

        final districtCounts = <String, int>{};
        for (final cafe in filteredCafes) {
          final district = canonicalDistrictName(
            cafe.district,
            districts: districts,
          );
          if (district == null || district.isEmpty) {
            continue;
          }
          districtCounts.update(
            district,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }

        final orderedDistricts = districtDisplayNames(districts);
        final counts = orderedDistricts
            .where((district) => (districtCounts[district] ?? 0) > 0)
            .map(
              (district) => (
                district: district,
                count: districtCounts[district]!,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final countOrder = right.count.compareTo(left.count);
            if (countOrder != 0) {
              return countOrder;
            }
            return orderedDistricts
                .indexOf(left.district)
                .compareTo(orderedDistricts.indexOf(right.district));
          });

        _memoryPopularDistrictCounts.put(cacheKey, counts);
        return counts;
      },
    );
  }

  Future<CafeRepositoryResult> forceRefresh() async {
    await clearCache();
    return fetchCafes();
  }

  Future<CafeListCacheSnapshot?> loadCachedCafeList({
    required String cacheKey,
  }) async {
    final memorySnapshot = _memoryCafeListCache.get(cacheKey);
    if (memorySnapshot != null) {
      if (CafeCachePolicy.isExpiredList(memorySnapshot.cachedAt)) {
        _memoryCafeListCache.remove(cacheKey);
        return null;
      }
      return _normalizeSnapshot(memorySnapshot);
    }

    final storage = _storage;
    if (storage == null) {
      return null;
    }

    final snapshot = await storage.loadCafeListCache(cacheKey);
    if (snapshot == null) {
      return null;
    }

    final normalizedSnapshot = _normalizeSnapshot(snapshot);
    final filteredCafes =
        _filterPublicCafes(normalizedSnapshot.cafes, surface: 'cache');

    final validatedSnapshot = CafeListCacheSnapshot(
      cafes: filteredCafes,
      cacheKey: normalizedSnapshot.cacheKey,
      metadata: normalizedSnapshot.metadata,
      nextPageToken: normalizedSnapshot.nextPageToken,
    );

    _memoryCafeListCache.put(cacheKey, validatedSnapshot);
    _indexCafes(filteredCafes);
    return validatedSnapshot;
  }

  Future<Cafe?> loadCachedCafeDetail(
    String cafeId, {
    List<Cafe> fallback = const [],
  }) async {
    final memoryCafe = _memoryCafeDetails.get(cafeId);
    if (memoryCafe != null) {
      return memoryCafe;
    }

    if (_storage == null) {
      return _fallbackCafe(cafeId, fallback);
    }

    final detailSnapshot = await _storage!.loadCafeDetailCache(cafeId);
    if (detailSnapshot != null) {
      _rememberCafe(detailSnapshot.cafe);
      return detailSnapshot.cafe;
    }

    return _fallbackCafe(cafeId, fallback);
  }

  Future<void> saveCafeListSnapshot(
    String cacheKey,
    List<Cafe> cafes, {
    String? nextPageToken,
  }) async {
    final snapshot = CafeListCacheSnapshot(
      cafes: List<Cafe>.unmodifiable(cafes),
      cacheKey: cacheKey,
      metadata: CafeCacheMetadata(
        lastUpdated: DateTime.now().toUtc(),
        source: CafeCacheDataSource.localCache,
      ),
      nextPageToken: _normalizeNextPageToken(nextPageToken),
    );
    _memoryCafeListCache.put(cacheKey, snapshot);
    _indexCafes(cafes);
    await _storage?.saveCafeListCache(
      cacheKey,
      cafes,
      nextPageToken: nextPageToken,
      cachedAt: snapshot.cachedAt,
    );
  }

  Future<T> _deduplicate<T>(
    InflightRequestRegistry<T> registry,
    String key,
    Future<T> Function() action,
    void Function(Object error, StackTrace stackTrace) onErrorLog,
  ) {
    return registry.run(
      key,
      () async {
        try {
          return await action();
        } catch (error, stackTrace) {
          onErrorLog(error, stackTrace);
          rethrow;
        }
      },
    );
  }

  Future<CafeRepositoryResult> fetchDiscoverableCafes({
    String? pageToken,
    double? lat,
    double? lng,
    String? district,
    int radius = 5000,
    bool seedOnly = false,
    bool bypassRateLimit = false,
    String? discoveryCacheKey,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final normalizedPageToken = pageToken?.trim();
    final cacheKey = discoveryCacheKey ??
        CafeCacheKeys.discovery(
          center: lat == null || lng == null
              ? null
              : Coordinates(lat: lat, lng: lng),
          radiusMeters: radius,
          district: district,
        );
    if (!_isOnline) {
      final cachedSnapshot = normalizedPageToken == null
          ? await loadCachedCafeList(cacheKey: cacheKey)
          : null;
      if (cachedSnapshot != null && normalizedPageToken == null) {
        AppLogger.debug(
          '[CAFE_DIAG_CACHE] cacheKey=$cacheKey source=offline hit=true count=${cachedSnapshot.cafes.length}',
          key: 'cafe-diag-cache',
          throttle: Duration.zero,
        );
        return CafeRepositoryResult(
          cafes: cachedSnapshot.cafes,
          usedRemote: false,
          warningMessage: 'Offline - showing cached data',
          nextPageToken: _normalizeNextPageToken(cachedSnapshot.nextPageToken),
        );
      }
      AppLogger.debug(
        '[CAFE_DIAG_CACHE] cacheKey=$cacheKey source=offline hit=false count=0',
        key: 'cafe-diag-cache',
        throttle: Duration.zero,
      );
      return const CafeRepositoryResult.failure(
        errorMessage: 'Offline and no cached cafes are available.',
        warningMessage: 'Offline - showing cached data',
        errorType: ServiceErrorType.network,
      );
    }

    final requestKey = CafeCacheKeys.request(
      cacheKey,
      pageToken: normalizedPageToken,
    );
    AppLogger.debug(
      '[CAFE_DIAG_REPOSITORY_REQUEST] cacheKey=$cacheKey requestKey=$requestKey district=${district ?? 'none'} radius=$radius seedOnly=$seedOnly',
      key: 'cafe-diag-repository-request',
      throttle: Duration.zero,
    );

    if (!bypassRateLimit &&
        !_inflightCafeRequests.contains(requestKey) &&
        !_rateLimiter.tryAcquire(
          requestKey,
          bucket: 'nearby_search',
        )) {
      final cachedSnapshot = normalizedPageToken == null
          ? await loadCachedCafeList(cacheKey: cacheKey)
          : null;
      if (cachedSnapshot != null) {
        AppLogger.debug(
          '[CAFE_DIAG_CACHE] cacheKey=$cacheKey source=ratelimit hit=true count=${cachedSnapshot.cafes.length}',
          key: 'cafe-diag-cache',
          throttle: Duration.zero,
        );
        return CafeRepositoryResult(
          cafes: cachedSnapshot.cafes,
          usedRemote: false,
          warningMessage: 'Using recently cached cafes.',
          nextPageToken: _normalizeNextPageToken(cachedSnapshot.nextPageToken),
        );
      }
      AppLogger.debug(
        '[CAFE_DIAG_CACHE] cacheKey=$cacheKey source=ratelimit hit=false count=0',
        key: 'cafe-diag-cache',
        throttle: Duration.zero,
      );
    }

    cancellationToken?.throwIfCancelled();
    return _deduplicate(
      _inflightCafeRequests,
      requestKey,
      () => _fetchCafesRemote(
        pageToken: normalizedPageToken,
        lat: lat,
        lng: lng,
        district: district,
        radius: radius,
        seedOnly: seedOnly,
        discoveryCacheKey: cacheKey,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      ),
      (error, stackTrace) => AppLogger.error(
        'CafeRepository.fetchCafes failed for $requestKey',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-list-fetch-$requestKey',
      ),
    );
  }

  Future<CafeRepositoryResult> fetchCafes({
    String? pageToken,
    double? lat,
    double? lng,
    String? district,
    int radius = 5000,
    bool seedOnly = false,
    bool bypassRateLimit = false,
    String? discoveryCacheKey,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    return fetchDiscoverableCafes(
      pageToken: pageToken,
      lat: lat,
      lng: lng,
      district: district,
      radius: radius,
      seedOnly: seedOnly,
      bypassRateLimit: bypassRateLimit,
      discoveryCacheKey: discoveryCacheKey,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
  }

  Future<CafeRepositoryResult> _fetchCafesRemote({
    String? pageToken,
    double? lat,
    double? lng,
    String? district,
    int radius = 5000,
    bool seedOnly = false,
    required String discoveryCacheKey,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final service = _service;
    if (service == null) {
      return const CafeRepositoryResult.failure(
        errorMessage: 'Google Places connection not available.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    try {
      final requestStopwatch = Stopwatch()..start();
      cancellationToken?.throwIfCancelled();
      final result = await service.fetchCafes(
        pageToken: pageToken,
        lat: lat,
        lng: lng,
        district: district,
        radius: radius,
        seedOnly: seedOnly,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );
      cancellationToken?.throwIfCancelled();
      AppLogger.debug(
        '[CAFE_DIAG_API] cacheKey=$discoveryCacheKey freshApiCount=${result.cafes.length} seedOnly=$seedOnly elapsedMs=${requestStopwatch.elapsedMilliseconds}',
        key: 'cafe-diag-api',
        throttle: Duration.zero,
      );
      final mergedCandidates = await _mergeGoogleAndSupabase(
        result.cafes,
        district: district,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );
      CafeDiscoveryDebugReportRecorder.instance
          .recordMergedCandidates(mergedCandidates);
      final mergedCafes =
          mergedCandidates.where(_isPublicCafe).toList(growable: false);
      final sourceDiagnostics = result.diagnostics;
      final diagnostics = CafeDiscoveryDiagnostics(
        rawFetchedCount:
            sourceDiagnostics?.rawFetchedCount ?? result.cafes.length,
        rejectedByClassifierCount:
            sourceDiagnostics?.rejectedByClassifierCount ?? 0,
        rejectedByDedupeCount: sourceDiagnostics?.rejectedByDedupeCount ?? 0,
        finalMergedCount: mergedCandidates.length,
        finalPublicCount: mergedCafes.length,
        fromRemote: true,
      );
      AppLogger.debug(
        '[CAFE_DIAG_MERGE] cacheKey=$discoveryCacheKey preFilterCount=${mergedCandidates.length} mergedCount=${mergedCafes.length} seedOnly=$seedOnly elapsedMs=${requestStopwatch.elapsedMilliseconds}',
        key: 'cafe-diag-merge',
        throttle: Duration.zero,
      );

      if (pageToken == null && !seedOnly) {
        await saveCafeListSnapshot(
          discoveryCacheKey,
          mergedCafes,
          nextPageToken: _normalizeNextPageToken(result.nextPageToken),
        );
      } else {
        _indexCafes(mergedCafes);
      }

      return CafeRepositoryResult(
        cafes: mergedCafes,
        usedRemote: true,
        warningMessage: result.warningMessage,
        nextPageToken: _normalizeNextPageToken(result.nextPageToken),
        diagnostics: diagnostics,
      );
    } catch (error) {
      return CafeRepositoryResult.failure(
        errorMessage: _describeRemoteError(error, 'load cafes'),
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<Cafe?> fetchCafeDetails(
    String cafeId, {
    List<Cafe> fallback = const [],
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final requestKey =
        '$cafeId|${(requestTimeout ?? Duration.zero).inMilliseconds}';
    final cached = await loadCachedCafeDetail(cafeId, fallback: fallback);
    if (!_isOnline) {
      return cached;
    }

    if (!_inflightCafeDetails.contains(requestKey) &&
        !_rateLimiter.tryAcquire(
          cafeId,
          bucket: 'place_details',
        ) &&
        cached != null) {
      return cached;
    }

    cancellationToken?.throwIfCancelled();
    return _deduplicate(
      _inflightCafeDetails,
      requestKey,
      () => _fetchCafeDetailsInternal(
        cafeId,
        cached: cached,
        fallback: fallback,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      ),
      (error, stackTrace) => AppLogger.error(
        'CafeRepository.fetchCafeDetails request failed for $cafeId',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-details-request-$cafeId',
      ),
    );
  }

  Future<Cafe?> fetchCafeById(
    String cafeId, {
    List<Cafe> fallback = const [],
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    return fetchCafeDetails(
      cafeId,
      fallback: fallback,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
  }

  Future<Cafe?> _fetchCafeDetailsInternal(
    String cafeId, {
    Cafe? cached,
    List<Cafe> fallback = const [],
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final fallbackCafe = cached ?? _fallbackCafe(cafeId, fallback);
    final supabaseCafe = await _loadSupabaseCafe(
      cafeId,
      placeId: fallbackCafe?.placeId,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
    if (supabaseCafe != null && supabaseCafe.isDeleted) {
      AppLogger.debug(
        '[DETAIL_DELETED_GUARD] cafeId=$cafeId reason=is_deleted_or_deleted_at',
        key: 'detail-deleted-guard-$cafeId',
        throttle: Duration.zero,
      );
      await removeCafeFromCache(<String>[
        cafeId,
        supabaseCafe.id,
        if (supabaseCafe.placeId?.trim().isNotEmpty == true)
          supabaseCafe.placeId!.trim(),
      ]);
      return null;
    }
    final service = _service;
    Cafe? googleCafe;
    if (service != null) {
      try {
        final placeIdToFetch =
            _resolveCafePlaceId(cafeId, cached: cached, fallback: supabaseCafe);
        final cafe = await service.fetchCafeDetails(
          placeIdToFetch,
          requestTimeout: requestTimeout,
          cancellationToken: cancellationToken,
        );
        googleCafe = cafe;
      } catch (error, stackTrace) {
        AppLogger.error(
          'CafeRepository.fetchCafeDetails failed for $cafeId',
          error: error,
          stackTrace: stackTrace,
          key: 'cafe-details-fetch-$cafeId',
        );
      }
    }

    final mergedCafe = googleCafe == null && supabaseCafe == null
        ? null
        : CafeMergePolicy.mergeCafeSources(
            googlePlaceCafe: googleCafe,
            supabaseCafe: supabaseCafe,
          );
    if (mergedCafe != null) {
      _rememberCafe(mergedCafe);
      await _storage?.saveCafeDetailCache(mergedCafe);
      await _mergeCafeIntoListSnapshot(mergedCafe);
      return mergedCafe;
    }

    return cached ?? supabaseCafe;
  }

  Future<List<Cafe>> _mergeGoogleAndSupabase(
    List<Cafe> googleCafes, {
    String? district,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final queryService = _cafeOverlaySource;
    if (queryService == null) {
      return applySharedBrandPricing(
        _filterPublicCafes(googleCafes, surface: 'merge'),
      );
    }

    final shouldFetchDiscoverableBaseline =
        district != null || googleCafes.isEmpty || _cafeOverlaySource != null;
    final includeDiscoverableBaseline =
        district != null && district.trim().isNotEmpty;
    var discoverableRows = const <Cafe>[];
    var activeFeaturedRows = const <Cafe>[];
    var discoverableFetchFailed = false;
    if (shouldFetchDiscoverableBaseline) {
      final discoverableResult = await queryService.fetchDiscoverableCafes(
        district: district,
        limit: district == null ? 240 : 1200,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );
      if (discoverableResult.ok) {
        discoverableRows = discoverableResult.data ?? const <Cafe>[];
      } else {
        discoverableFetchFailed = true;
      }
    }
    final featuredResult = await queryService.fetchActiveFeaturedCafes(
      limit: 40,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
    if (featuredResult.ok) {
      activeFeaturedRows = featuredResult.data ?? const <Cafe>[];
    } else {
      AppLogger.warn(
        'CafeRepository: active featured Supabase fetch failed during merge.',
        key: 'cafe-merge-featured-supabase-failed',
      );
    }

    if (discoverableFetchFailed) {
      AppLogger.warn(
        'CafeRepository: discoverable Supabase fetch failed during merge baseline.',
        key: 'cafe-merge-discoverable-supabase-failed',
      );
    }

    AppLogger.debug(
      '[CAFE_DIAG_SUPABASE] stage=discoverable-baseline district=${district ?? '-'} count=${discoverableRows.length} requested=$shouldFetchDiscoverableBaseline',
      key: 'cafe-diag-supabase-discoverable',
      throttle: Duration.zero,
    );
    CafeDiscoveryDebugReportRecorder.instance
        .recordSupabaseCount(count: discoverableRows.length);

    if (googleCafes.isEmpty) {
      final publicRows = _filterPublicCafes(discoverableRows, surface: 'merge');
      return applySharedBrandPricing(publicRows);
    }

    final placeIds = googleCafes
        .map((cafe) => cafe.placeId?.trim())
        .whereType<String>()
        .where((placeId) => placeId.isNotEmpty)
        .toSet();
    if (placeIds.isEmpty) {
      final mergedWithoutOverlay =
          CafeMergePolicy.mergeGooglePlacesWithSupabase(
        googleCafes,
        _mergeSupabaseRowsByIdentity(
          includeDiscoverableBaseline ? discoverableRows : const <Cafe>[],
          _featuredRowsWithinGoogleDiscovery(
            activeFeaturedRows,
            googleCafes,
            const <Cafe>[],
          ),
        ),
      );
      return applySharedBrandPricing(
        _filterPublicCafes(mergedWithoutOverlay, surface: 'merge'),
      );
    }

    final result = await queryService.fetchCafesByPlaceIds(
      placeIds,
      includeDeleted: true,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
    if (!result.ok) {
      AppLogger.warn(
        'CafeRepository: Supabase overlay fetch failed during cafe merge.',
        key: 'cafe-merge-supabase-overlay-failed',
      );
      final mergedWithoutOverlay =
          CafeMergePolicy.mergeGooglePlacesWithSupabase(
        googleCafes,
        _mergeSupabaseRowsByIdentity(
          includeDiscoverableBaseline ? discoverableRows : const <Cafe>[],
          _featuredRowsWithinGoogleDiscovery(
            activeFeaturedRows,
            googleCafes,
            const <Cafe>[],
          ),
        ),
      );
      return applySharedBrandPricing(
        _filterPublicCafes(mergedWithoutOverlay, surface: 'merge'),
      );
    }

    final overlayRows = result.data ?? const <Cafe>[];
    final featuredDiscoveryRows = _featuredRowsWithinGoogleDiscovery(
      activeFeaturedRows,
      googleCafes,
      overlayRows,
    );
    final combinedSupabaseByIdentity = <String, Cafe>{
      if (includeDiscoverableBaseline)
        for (final cafe in discoverableRows)
          CafeMergePolicy.canonicalIdentityFor(cafe): cafe,
      for (final cafe in featuredDiscoveryRows)
        CafeMergePolicy.canonicalIdentityFor(cafe): cafe,
    };
    for (final cafe in overlayRows) {
      combinedSupabaseByIdentity[CafeMergePolicy.canonicalIdentityFor(cafe)] =
          cafe;
    }
    final overlayIdentities = {
      for (final cafe in overlayRows)
        CafeMergePolicy.canonicalIdentityFor(cafe),
    };
    final featuredDiscoveryIdentities = {
      for (final cafe in featuredDiscoveryRows)
        CafeMergePolicy.canonicalIdentityFor(cafe),
    };
    final discoverableBaselineIdentities = {
      if (includeDiscoverableBaseline)
        for (final cafe in discoverableRows)
          CafeMergePolicy.canonicalIdentityFor(cafe),
    };
    final combinedSupabaseRows = combinedSupabaseByIdentity.values
        .where((cafe) =>
            overlayIdentities
                .contains(CafeMergePolicy.canonicalIdentityFor(cafe)) ||
            discoverableBaselineIdentities
                .contains(CafeMergePolicy.canonicalIdentityFor(cafe)) ||
            featuredDiscoveryIdentities
                .contains(CafeMergePolicy.canonicalIdentityFor(cafe)))
        .toList(growable: false);

    AppLogger.debug(
      '[CAFE_DIAG_SUPABASE] stage=overlay placeIdCount=${placeIds.length} overlayCount=${overlayRows.length} combinedCount=${combinedSupabaseRows.length}',
      key: 'cafe-diag-supabase-overlay',
      throttle: Duration.zero,
    );
    CafeDiscoveryDebugReportRecorder.instance
        .recordSupabaseCount(count: combinedSupabaseRows.length);

    _logRepositoryPhotoMergeSnapshot(
      stage: 'before-merge',
      googleCafes: googleCafes,
      supabaseCafes: combinedSupabaseRows,
      mergedCafes: const <Cafe>[],
    );
    final blockedIdentifiers = _buildBlockedIdentifierSet(overlayRows);
    final filteredGoogleCafes = <Cafe>[];
    final blockedGoogleCafes = <Cafe>[];
    var blockedGoogleCount = 0;
    for (final cafe in googleCafes) {
      if (_isBlockedGoogleCafe(cafe, blockedIdentifiers)) {
        blockedGoogleCount += 1;
        blockedGoogleCafes.add(cafe);
        continue;
      }
      filteredGoogleCafes.add(cafe);
    }
    AppLogger.debug(
      '[CAFE_DIAG_DELETE_BLOCK] blockedRows=${blockedIdentifiers.rowCount} blockedPlaceIds=${blockedIdentifiers.placeIds.length} rejectedGoogle=$blockedGoogleCount',
      key: 'cafe-diag-delete-block',
      throttle: Duration.zero,
    );
    CafeDiscoveryDebugReportRecorder.instance
        .recordDeletedOverlayRemoval(blockedGoogleCafes);

    final merged = CafeMergePolicy.mergeGooglePlacesWithSupabase(
      filteredGoogleCafes,
      combinedSupabaseRows,
    );
    _logRepositoryPhotoMergeSnapshot(
      stage: 'after-policy-merge',
      googleCafes: filteredGoogleCafes,
      supabaseCafes: combinedSupabaseRows,
      mergedCafes: merged,
    );

    _logRepositoryPhotoMergeSnapshot(
      stage: 'final-merged',
      googleCafes: filteredGoogleCafes,
      supabaseCafes: combinedSupabaseRows,
      mergedCafes: merged,
    );

    return applySharedBrandPricing(
        _filterPublicCafes(merged, surface: 'merge'));
  }

  List<Cafe> _mergeSupabaseRowsByIdentity(
    Iterable<Cafe> primaryRows,
    Iterable<Cafe> featuredRows,
  ) {
    final byIdentity = <String, Cafe>{
      for (final cafe in primaryRows)
        CafeMergePolicy.canonicalIdentityFor(cafe): cafe,
    };
    for (final cafe in featuredRows) {
      byIdentity[CafeMergePolicy.canonicalIdentityFor(cafe)] = cafe;
    }
    return byIdentity.values.toList(growable: false);
  }

  List<Cafe> _featuredRowsWithinGoogleDiscovery(
    Iterable<Cafe> featuredRows,
    Iterable<Cafe> googleCafes,
    Iterable<Cafe> overlayRows,
  ) {
    final discoveredPlaceIds = <String>{};
    final discoveredIdentities = <String>{};

    void addDiscovered(Cafe cafe) {
      discoveredIdentities.add(CafeMergePolicy.canonicalIdentityFor(cafe));
      final placeId = cafe.placeId?.trim();
      if (placeId != null && placeId.isNotEmpty) {
        discoveredPlaceIds.add(placeId);
      }
    }

    for (final cafe in googleCafes) {
      addDiscovered(cafe);
    }
    for (final cafe in overlayRows) {
      addDiscovered(cafe);
    }

    return featuredRows.where((cafe) {
      final placeId = cafe.placeId?.trim();
      if (placeId != null &&
          placeId.isNotEmpty &&
          discoveredPlaceIds.contains(placeId)) {
        return true;
      }
      return discoveredIdentities
          .contains(CafeMergePolicy.canonicalIdentityFor(cafe));
    }).toList(growable: false);
  }

  void _logRepositoryPhotoMergeSnapshot({
    required String stage,
    required List<Cafe> googleCafes,
    required List<Cafe> supabaseCafes,
    required List<Cafe> mergedCafes,
  }) {
    final googleByIdentity = <String, Cafe>{
      for (final cafe in googleCafes)
        CafeMergePolicy.canonicalIdentityFor(cafe): cafe,
    };
    final supabaseByIdentity = <String, Cafe>{
      for (final cafe in supabaseCafes)
        CafeMergePolicy.canonicalIdentityFor(cafe): cafe,
    };

    var lostPhotoCount = 0;
    final lostPhotoSamples = <String>[];
    for (final cafe in mergedCafes) {
      final identity = CafeMergePolicy.canonicalIdentityFor(cafe);
      final googleCount = googleByIdentity[identity]?.photoUrls.length ?? 0;
      final supabaseCount = supabaseByIdentity[identity]?.photoUrls.length ?? 0;
      final beforeBest =
          googleCount > supabaseCount ? googleCount : supabaseCount;
      final afterCount = cafe.photoUrls.length;
      if (beforeBest > 0 && afterCount == 0) {
        lostPhotoCount += 1;
        if (lostPhotoSamples.length < 8) {
          lostPhotoSamples.add('${cafe.id}:before=$beforeBest->after=0');
        }
      }
    }

    final sample = mergedCafes
        .take(8)
        .map((cafe) => '${cafe.id}:${cafe.photoUrls.length}')
        .join(',');
    AppLogger.debug(
      '[CAFE_DIAG_PHOTO_MERGE] stage=$stage sourceGoogle=${googleCafes.length} sourceSupabase=${supabaseCafes.length} merged=${mergedCafes.length} '
      'googleWithPhotos=${googleCafes.where((c) => c.photoUrls.isNotEmpty).length} '
      'supabaseWithPhotos=${supabaseCafes.where((c) => c.photoUrls.isNotEmpty).length} '
      'mergedWithPhotos=${mergedCafes.where((c) => c.photoUrls.isNotEmpty).length} '
      'lostFromNonEmpty=$lostPhotoCount lostSamples=${lostPhotoSamples.join('|')} sample=$sample',
      key: 'cafe-diag-photo-merge-$stage',
      throttle: Duration.zero,
    );
  }

  _BlockedCafeIdentifiers _buildBlockedIdentifierSet(List<Cafe> overlays) {
    final placeIds = <String>{};
    final canonicalIds = <String>{};
    final fallbackKeys = <String>{};
    var blockedRows = 0;

    for (final cafe in overlays) {
      if (!isCafeBlockedFromPublic(cafe)) {
        continue;
      }
      blockedRows += 1;

      final placeId = cafe.placeId?.trim();
      if (placeId != null && placeId.isNotEmpty) {
        placeIds.add(placeId);
      }

      canonicalIds.add(CafeMergePolicy.canonicalIdentityFor(cafe));
      final fallbackKey = _fallbackCafeBlockKey(cafe);
      if (fallbackKey != null) {
        fallbackKeys.add(fallbackKey);
      }
    }

    return _BlockedCafeIdentifiers(
      placeIds: placeIds,
      canonicalIds: canonicalIds,
      fallbackKeys: fallbackKeys,
      rowCount: blockedRows,
    );
  }

  bool _isBlockedGoogleCafe(
    Cafe cafe,
    _BlockedCafeIdentifiers blocked,
  ) {
    final placeId = cafe.placeId?.trim();
    if (placeId != null &&
        placeId.isNotEmpty &&
        blocked.placeIds.contains(placeId)) {
      AppLogger.debug(
        '[MERGE_DELETED_PLACE_GUARD] googlePlaceId=${placeId.length > 20 ? '${placeId.substring(0, 20)}…' : placeId} skipped=true reason=blocked_place_id',
        key: 'merge-deleted-place-guard-$placeId',
        throttle: Duration.zero,
      );
      return true;
    }

    if (blocked.canonicalIds
        .contains(CafeMergePolicy.canonicalIdentityFor(cafe))) {
      AppLogger.debug(
        '[MERGE_DELETED_PLACE_GUARD] googlePlaceId=${placeId ?? cafe.id} skipped=true reason=blocked_canonical_id',
        key: 'merge-deleted-place-guard-canonical-${cafe.id}',
        throttle: Duration.zero,
      );
      return true;
    }

    final fallbackKey = _fallbackCafeBlockKey(cafe);
    if (fallbackKey != null && blocked.fallbackKeys.contains(fallbackKey)) {
      AppLogger.debug(
        '[MERGE_DELETED_PLACE_GUARD] googlePlaceId=${placeId ?? cafe.id} skipped=true reason=blocked_fallback_key',
        key: 'merge-deleted-place-guard-fallback-${cafe.id}',
        throttle: Duration.zero,
      );
      return true;
    }
    return false;
  }

  String? _fallbackCafeBlockKey(Cafe cafe) {
    final normalizedName = normalizeSearchText(cafe.name);
    if (normalizedName.isEmpty) {
      return null;
    }

    final lat = cafe.coordinates.lat;
    final lng = cafe.coordinates.lng;
    if (!lat.isFinite || !lng.isFinite) {
      return null;
    }
    return '$normalizedName|${lat.toStringAsFixed(4)}|${lng.toStringAsFixed(4)}';
  }

  Cafe? _findCachedCafeByIdentifier(String id) {
    final direct = _memoryCafeDetails.get(id);
    if (direct != null) {
      return direct;
    }

    for (final entry in _memoryCafeDetails.entries) {
      final cafe = entry.value;
      if (_cafeMatchesIdentifier(cafe, id)) {
        return cafe;
      }
    }

    for (final snapshotEntry in _memoryCafeListCache.entries) {
      for (final cafe in snapshotEntry.value.cafes) {
        if (_cafeMatchesIdentifier(cafe, id)) {
          return cafe;
        }
      }
    }

    return null;
  }

  void _assignCafeToRequestedIds(
    Cafe cafe,
    List<String> normalizedIds,
    Map<String, Cafe> byRequestedId,
  ) {
    for (final id in normalizedIds) {
      if (_cafeMatchesIdentifier(cafe, id)) {
        byRequestedId[id] = cafe;
      }
    }
  }

  bool _cafeMatchesIdentifier(Cafe cafe, String id) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      return false;
    }
    final placeId = cafe.placeId?.trim();
    final googlePlaceId = cafe.googlePlaceData?.googlePlaceId?.trim();
    return cafe.id == normalizedId ||
        placeId == normalizedId ||
        googlePlaceId == normalizedId;
  }

  Future<Cafe?> _loadSupabaseCafe(
    String cafeId, {
    String? placeId,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final queryService = _cafeOverlaySource;
    if (queryService == null) {
      return null;
    }

    final normalizedPlaceId = placeId?.trim();
    if (normalizedPlaceId != null && normalizedPlaceId.isNotEmpty) {
      final deletedPlaceResult = await queryService.fetchCafesByPlaceIds(
        <String>[normalizedPlaceId],
        includeDeleted: true,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );
      if (deletedPlaceResult.ok) {
        for (final cafe in deletedPlaceResult.data ?? const <Cafe>[]) {
          if (cafe.placeId?.trim() == normalizedPlaceId && cafe.isDeleted) {
            return cafe;
          }
        }
      }

      final placeResult = await queryService.fetchCafesByPlaceIds(
        <String>[normalizedPlaceId],
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );
      if (placeResult.ok) {
        for (final cafe in placeResult.data ?? const <Cafe>[]) {
          if (cafe.placeId?.trim() == normalizedPlaceId) {
            return cafe;
          }
        }
      }
    }

    final deletedIdResult = await queryService.fetchCafesByIds(
      <String>[cafeId],
      includeDeleted: true,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
    if (deletedIdResult.ok) {
      for (final cafe in deletedIdResult.data ?? const <Cafe>[]) {
        if ((cafe.id == cafeId || cafe.placeId == cafeId) && cafe.isDeleted) {
          return cafe;
        }
      }
    }

    final detailResult = await queryService.fetchCafeById(
      cafeId,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
    if (!detailResult.ok) {
      return null;
    }
    return detailResult.data;
  }

  String _resolveCafePlaceId(
    String cafeId, {
    Cafe? cached,
    Cafe? fallback,
  }) {
    final knownPlaceId = cached?.placeId?.trim() ?? fallback?.placeId?.trim();
    if (knownPlaceId != null && knownPlaceId.isNotEmpty) {
      return knownPlaceId;
    }
    return cafeId;
  }

  Filters _popularDistrictSummaryFilters(Filters filters) {
    return Filters(
      category: filters.category,
      minRating: filters.minRating,
      priceLevel: filters.priceLevel,
      wifiQuality: filters.wifiQuality,
      outletAvailability: filters.outletAvailability,
      quietnessLevel: filters.quietnessLevel,
      outdoorSeating: filters.outdoorSeating,
      petFriendly: filters.petFriendly,
      studyFriendly: filters.studyFriendly,
      openNow: filters.openNow,
      smokingPolicy: filters.smokingPolicy,
    );
  }

  String _popularDistrictCountsCacheKey(
    Filters filters,
    Iterable<District> districts,
  ) {
    final districtKey = districts
        .where((district) => district.isActive)
        .map((district) => district.id)
        .join('|');
    return [
      filters.category?.value ?? 'any-category',
      filters.minRating?.toStringAsFixed(1) ?? 'any-rating',
      filters.priceLevel?.value ?? 'any-price',
      filters.wifiQuality?.value ?? 'any-wifi',
      filters.outletAvailability?.value ?? 'any-outlet',
      filters.quietnessLevel?.value ?? 'any-quiet',
      filters.outdoorSeating?.toString() ?? 'any-outdoor',
      filters.petFriendly?.toString() ?? 'any-pet',
      filters.studyFriendly?.toString() ?? 'any-study',
      filters.openNow?.toString() ?? 'any-open',
      filters.smokingPolicy?.value ?? 'any-smoking',
      districtKey,
    ].join('|');
  }

  bool _isPublicCafe(Cafe cafe) {
    return isStrictlyValidCafe(cafe);
  }

  List<Cafe> _filterPublicCafes(
    Iterable<Cafe> cafes, {
    required String surface,
  }) {
    var scriptDropped = 0;
    final filtered = <Cafe>[];
    for (final cafe in cafes) {
      if (!_isPublicCafe(cafe)) {
        if (isPublicDiscoveryScriptBlockedCafe(cafe)) {
          scriptDropped += 1;
        }
        continue;
      }
      filtered.add(cafe);
    }
    if (scriptDropped > 0) {
      AppLogger.debug(
        '[CAFE_PUBLIC_FILTER] reason=arabic_script_name surface=$surface dropped=$scriptDropped',
        key: 'cafe-public-filter-$surface',
        throttle: Duration.zero,
      );
    }
    return filtered;
  }

  bool _isPublicFeaturedCafe(Cafe cafe) {
    // Featured feed is a curated Supabase-owned source. Keep it independent
    // from the general discovery classifier so sparse admin-curated rows are
    // not dropped just because they are outside Google/discovery hydration.
    return cafe.isFeatured &&
        !isCafeBlockedFromPublic(cafe) &&
        (isStrictlyValidCafe(cafe) || !assessCafeVenue(cafe).isHardBlocked);
  }

  void _indexCafes(List<Cafe> cafes) {
    for (final cafe in cafes) {
      _rememberCafe(cafe);
    }
  }

  void _rememberCafe(Cafe cafe) {
    _memoryCafeDetails.put(cafe.id, cafe);
  }

  CafeListCacheSnapshot _normalizeSnapshot(CafeListCacheSnapshot snapshot) {
    final normalizedToken = _normalizeNextPageToken(snapshot.nextPageToken);
    if (normalizedToken == snapshot.nextPageToken) {
      return snapshot;
    }
    return CafeListCacheSnapshot(
      cafes: snapshot.cafes,
      cacheKey: snapshot.cacheKey,
      metadata: snapshot.metadata,
      nextPageToken: normalizedToken,
    );
  }

  String? _normalizeNextPageToken(String? token) {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (!supportsLoadMorePagination) {
      return null;
    }
    return trimmed;
  }

  Cafe? _fallbackCafe(String cafeId, List<Cafe> fallback) {
    for (final cafe in fallback) {
      if (cafe.id == cafeId) {
        return cafe;
      }
    }
    return null;
  }

  Future<void> _mergeCafeIntoListSnapshot(Cafe cafe) async {
    final updatedEntries = <String, CafeListCacheSnapshot>{};
    for (final entry in _memoryCafeListCache.entries.toList(growable: false)) {
      final snapshot = entry.value;
      final hasMatch = snapshot.cafes.any(
        (current) =>
            CafeMergePolicy.canonicalIdentityFor(current) ==
            CafeMergePolicy.canonicalIdentityFor(cafe),
      );
      if (!hasMatch) {
        continue;
      }

      final updatedSnapshot = CafeListCacheSnapshot(
        cafes: List<Cafe>.unmodifiable([
          for (final current in snapshot.cafes)
            if (CafeMergePolicy.canonicalIdentityFor(current) ==
                CafeMergePolicy.canonicalIdentityFor(cafe))
              _mergeCafeForCache(current: current, incoming: cafe)
            else
              current,
        ]),
        cacheKey: snapshot.cacheKey,
        metadata: CafeCacheMetadata(
          lastUpdated: DateTime.now().toUtc(),
          source: CafeCacheDataSource.localCache,
          version: snapshot.metadata.version,
        ),
        nextPageToken: snapshot.nextPageToken,
      );
      updatedEntries[entry.key] = updatedSnapshot;
    }

    for (final entry in updatedEntries.entries) {
      _memoryCafeListCache.put(entry.key, entry.value);
      await _storage?.saveCafeListCache(
        entry.key,
        entry.value.cafes,
        nextPageToken: entry.value.nextPageToken,
        cachedAt: entry.value.cachedAt,
      );
    }

    await _storage?.replaceCafeInListCaches(cafe);
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
        '[CAFE_DIAG_PHOTO] source=repository-merge preserveExisting=true cafe=${current.id} current=${normalizedCurrentImages.length} incomingRaw=${incoming.photoUrls.length} incomingNormalized=${normalizedIncomingImages.length}',
        key: 'cafe-diag-photo-repository-merge-${current.id}',
        throttle: Duration.zero,
      );
    } else {
      AppLogger.debug(
        '[CAFE_DIAG_PHOTO] source=repository-merge preserveExisting=false cafe=${current.id} current=${normalizedCurrentImages.length} incomingRaw=${incoming.photoUrls.length} incomingNormalized=${normalizedIncomingImages.length}',
        key: 'cafe-diag-photo-repository-merge-${current.id}',
        throttle: Duration.zero,
      );
    }
    final mergedImages = shouldPreserveCurrentImages
        ? normalizedCurrentImages
        : normalizedIncomingImages;
    final mergedDescription = incoming.description.trim().isNotEmpty
        ? incoming.description
        : current.description;
    final mergedOpeningHours = incoming.openingHours.isNotEmpty
        ? incoming.openingHours
        : current.openingHours;

    return incoming.copyWith(
      images: mergedImages,
      description: mergedDescription,
      openingHours: mergedOpeningHours,
      phoneNumber: (incoming.phoneNumber?.trim().isNotEmpty ?? false)
          ? incoming.phoneNumber
          : current.phoneNumber,
      websiteUri: (incoming.websiteUri?.trim().isNotEmpty ?? false)
          ? incoming.websiteUri
          : current.websiteUri,
    );
  }

  String _describeRemoteError(Object error, String action) {
    switch (classifyServiceError(error)) {
      case ServiceErrorType.cancelled:
        return 'The request to $action was cancelled.';
      case ServiceErrorType.rateLimit:
        return 'Cafe services are rate limiting requests right now.';
      case ServiceErrorType.timeout:
        return 'Request timed out while trying to $action.';
      case ServiceErrorType.network:
        return 'Network error while trying to $action.';
      case ServiceErrorType.auth:
      case ServiceErrorType.unavailable:
        return 'Remote cafe service is unavailable right now.';
      case ServiceErrorType.parse:
        return 'Received an unexpected cafe response while trying to $action.';
      case ServiceErrorType.validation:
      case ServiceErrorType.conflict:
      case ServiceErrorType.notFound:
      case ServiceErrorType.unknown:
        return 'Failed to $action right now.';
    }
  }

  void dispose() {
    _inflightCafeRequests.clear();
    _inflightCafeDetails.clear();
    _memoryCafeDetails.clear();
    _memoryCafeListCache.clear();
    _rateLimiter.dispose();
  }
}

class _BlockedCafeIdentifiers {
  const _BlockedCafeIdentifiers({
    required this.placeIds,
    required this.canonicalIds,
    required this.fallbackKeys,
    required this.rowCount,
  });

  final Set<String> placeIds;
  final Set<String> canonicalIds;
  final Set<String> fallbackKeys;
  final int rowCount;
}
