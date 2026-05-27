import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/error_codes.dart';
import '../constants/network_config.dart';
import '../models/index.dart';
import '../models/service_result.dart';
import '../utils/app_logger.dart';
import '../utils/cafe_media.dart';
import '../utils/district_utils.dart';
import '../utils/inflight_request_registry.dart';
import '../utils/input_validation.dart';
import '../utils/request_cancellation.dart';
import '../utils/retry.dart';
import '../utils/service_error.dart';
import '../utils/text_normalization.dart';

class AvatarUploadResult {
  const AvatarUploadResult({
    required this.publicUrl,
    required this.path,
  });

  final String publicUrl;
  final String path;
}

class CafeOwnerInviteResult {
  const CafeOwnerInviteResult({
    required this.owner,
    required this.cafe,
    required this.invited,
  });

  final UserProfile owner;
  final Cafe cafe;
  final bool invited;
}

class AdminCafePage {
  const AdminCafePage({
    required this.cafes,
    required this.hasMore,
    required this.offset,
    required this.limit,
  });

  final List<Cafe> cafes;
  final bool hasMore;
  final int offset;
  final int limit;

  int get nextOffset => offset + cafes.length;
}

class SecurityReadinessReport {
  const SecurityReadinessReport({
    required this.isReady,
    required this.checkAvailable,
    required this.rlsEnabled,
    required this.hasAdminInsertPolicy,
    required this.hasAdminUpdatePolicy,
    required this.message,
    this.failureType,
    this.isConfigurationFailure = false,
  });

  factory SecurityReadinessReport.notConfigured() {
    return const SecurityReadinessReport(
      isReady: true,
      checkAvailable: true,
      rlsEnabled: true,
      hasAdminInsertPolicy: true,
      hasAdminUpdatePolicy: true,
      message: 'Supabase not configured for this environment.',
      failureType: null,
    );
  }

  final bool isReady;
  final bool checkAvailable;
  final bool rlsEnabled;
  final bool hasAdminInsertPolicy;
  final bool hasAdminUpdatePolicy;
  final String message;
  final ServiceErrorType? failureType;
  final bool isConfigurationFailure;

  bool get isTransientProbeFailure {
    if (isReady) {
      return false;
    }

    final type = failureType;
    if (type == null) {
      return false;
    }

    final transientFailureType =
        type == ServiceErrorType.cancelled || type.isTransient;
    return !checkAvailable && !isConfigurationFailure && transientFailureType;
  }

  bool get shouldShowRuntimeWarning => !isReady && !isTransientProbeFailure;

  bool get blocksAdminMutations => !isReady && !isTransientProbeFailure;
}

class SecurityReadinessService {
  SecurityReadinessService(
    this._client, {
    Future<dynamic> Function()? readinessProbe,
  }) : _readinessProbe = readinessProbe;

  final SupabaseClient _client;
  final Future<dynamic> Function()? _readinessProbe;

  Future<SecurityReadinessReport> verifyCafeRlsReadiness() async {
    try {
      final raw = _readinessProbe != null
          ? await _readinessProbe!()
          : await _client
              .rpc('app_security_readiness')
              .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      final payload = _readinessPayloadFrom(raw);

      final rlsEnabled = _readBool(payload, 'rls_enabled') ?? false;
      final hasAdminInsertPolicy =
          _readBool(payload, 'has_admin_insert_policy') ?? false;
      final hasAdminUpdatePolicy =
          _readBool(payload, 'has_admin_update_policy') ?? false;
      final isReady = _readBool(payload, 'is_ready') ??
          (rlsEnabled && hasAdminInsertPolicy && hasAdminUpdatePolicy);
      final message = (payload['message'] as String?)?.trim();

      return SecurityReadinessReport(
        isReady: isReady,
        checkAvailable: true,
        rlsEnabled: rlsEnabled,
        hasAdminInsertPolicy: hasAdminInsertPolicy,
        hasAdminUpdatePolicy: hasAdminUpdatePolicy,
        message: (message != null && message.isNotEmpty)
            ? message
            : (isReady
                ? 'Security readiness check passed.'
                : 'Security readiness check failed: RLS/policy requirements are missing.'),
      );
    } catch (error, stackTrace) {
      if (_isMissingReadinessRpc(error)) {
        return const SecurityReadinessReport(
          isReady: false,
          checkAvailable: false,
          rlsEnabled: false,
          hasAdminInsertPolicy: false,
          hasAdminUpdatePolicy: false,
          message:
              'Missing app_security_readiness() database function. Apply Supabase security readiness migration.',
          failureType: ServiceErrorType.unavailable,
          isConfigurationFailure: true,
        );
      }

      final failureType = classifyServiceError(error);
      final isConfigurationFailure = _isReadinessConfigurationFailure(error);
      final message = _readinessFailureMessage(error, failureType);

      AppLogger.error(
        'SecurityReadinessService.verifyCafeRlsReadiness failed',
        error: error,
        stackTrace: stackTrace,
        key: 'security-readiness-check-failed',
      );

      return SecurityReadinessReport(
        isReady: false,
        checkAvailable: false,
        rlsEnabled: false,
        hasAdminInsertPolicy: false,
        hasAdminUpdatePolicy: false,
        message: message,
        failureType: failureType,
        isConfigurationFailure: isConfigurationFailure,
      );
    }
  }

  static Map<String, dynamic> _readinessPayloadFrom(Object? raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is List && raw.length == 1 && raw.single is Map) {
      return Map<String, dynamic>.from(raw.single as Map);
    }
    throw const AppServiceException.parse(
      'Unexpected security readiness payload shape.',
      errorCode: AppErrorCode.parseFailed,
    );
  }

  static bool _isMissingReadinessRpc(Object error) {
    if (error is! PostgrestException) {
      return false;
    }

    final code = error.code?.trim().toLowerCase();
    final message =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return code == 'pgrst202' ||
        code == '42883' ||
        (message.contains('app_security_readiness') &&
            message.contains('does not exist'));
  }

  static bool _isReadinessConfigurationFailure(Object error) {
    if (error is! PostgrestException) {
      return false;
    }

    final dbCode = error.code?.trim().toUpperCase();
    return dbCode == '42501' || dbCode == '42P01' || dbCode == '42703';
  }

  static String _readinessFailureMessage(
    Object error,
    ServiceErrorType failureType,
  ) {
    if (error is PostgrestException) {
      final dbCode = error.code?.trim().toUpperCase();
      if (dbCode == '42501') {
        return 'Security readiness check failed: readiness probe permission denied by Supabase (Postgres 42501).';
      }
      if (dbCode == '42P01' || dbCode == '42703') {
        return 'Security readiness check failed: readiness probe hit a database schema mismatch ($dbCode).';
      }
      if (dbCode != null && dbCode.isNotEmpty) {
        return 'Security readiness check failed: Supabase runtime error while executing readiness probe ($dbCode).';
      }
    }

    switch (failureType) {
      case ServiceErrorType.timeout:
        return 'Security readiness check failed: request to Supabase timed out.';
      case ServiceErrorType.network:
        return 'Security readiness check failed: cannot reach Supabase due to network/connectivity issues.';
      case ServiceErrorType.auth:
        return 'Security readiness check failed: authorization/session error while running readiness probe.';
      case ServiceErrorType.rateLimit:
      case ServiceErrorType.unavailable:
        return 'Security readiness check failed: Supabase service is temporarily unavailable.';
      case ServiceErrorType.cancelled:
        return 'Security readiness check failed: readiness request was cancelled.';
      default:
        return 'Security readiness check failed: runtime exception while executing readiness probe.';
    }
  }

  static bool? _readBool(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == 't' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == 'f' || normalized == '0') {
        return false;
      }
    }
    if (value is num) {
      return value != 0;
    }
    return null;
  }
}

abstract class CafeOverlaySource {
  Future<ServiceResult<List<Cafe>>> fetchDiscoverableCafes({
    String? district,
    int limit,
    int offset,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  });

  Future<ServiceResult<List<Cafe>>> fetchActiveFeaturedCafes({
    String? district,
    int limit,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  });

  Future<ServiceResult<List<Cafe>>> fetchCafes();

  Future<ServiceResult<List<Cafe>>> fetchCafesByIds(
    Iterable<String> ids, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  });

  Future<ServiceResult<List<Cafe>>> searchCafesByName(
    String query, {
    int limit = 20,
    bool includeDeleted = false,
  });

  Future<ServiceResult<List<Cafe>>> fetchCafesByPlaceIds(
    Iterable<String> placeIds, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  });

  Future<ServiceResult<Cafe?>> fetchCafeDetails(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  });

  Future<ServiceResult<Cafe?>> fetchCafeById(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  });

  Future<ServiceResult<void>> updateGoogleRatingMetadata({
    required String cafeId,
    required String googlePlaceId,
    double? googleRating,
    int? googleReviewCount,
    String? externalLastSyncedAt,
    Duration? requestTimeout,
  });
}

typedef CafeListRowsLoader = Future<List<Map<String, dynamic>>> Function();
typedef CafeRowsByPlaceIdsLoader = Future<List<Map<String, dynamic>>> Function(
  List<String> placeIds, {
  required Duration requestTimeout,
  RequestCancellationToken? cancellationToken,
});
typedef CafeDetailRowLoader = Future<Map<String, dynamic>?> Function(
  String cafeId, {
  required Duration requestTimeout,
  RequestCancellationToken? cancellationToken,
});
typedef CafeInsertRowLoader = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);
typedef CafeUpdateRowLoader = Future<Map<String, dynamic>> Function(
  String cafeId,
  Map<String, dynamic> payload,
);
typedef CafeSoftDeleteLookupLoader = Future<Map<String, dynamic>?> Function(
  String cafeId,
  String? candidatePlaceId,
);
typedef CafeSoftDeleteUpdateLoader = Future<Map<String, dynamic>?> Function(
  String cafeId,
  Map<String, dynamic> payload,
);
typedef CafeTombstoneLoader = Future<Map<String, dynamic>?> Function(
  String googlePlaceId,
  Map<String, dynamic> payload,
);

class CafeQueryService implements CafeOverlaySource {
  CafeQueryService(
    this._client, {
    CafeListRowsLoader? cafesLoader,
    CafeRowsByPlaceIdsLoader? cafesByPlaceIdsLoader,
    CafeDetailRowLoader? cafeDetailLoader,
  })  : _cafesLoader = cafesLoader,
        _cafesByPlaceIdsLoader = cafesByPlaceIdsLoader,
        _cafeDetailLoader = cafeDetailLoader;

  final SupabaseClient _client;
  final CafeListRowsLoader? _cafesLoader;
  final CafeRowsByPlaceIdsLoader? _cafesByPlaceIdsLoader;
  final CafeDetailRowLoader? _cafeDetailLoader;
  final InflightRequestRegistry<ServiceResult<List<Cafe>>> _inflightPlaceIds =
      InflightRequestRegistry<ServiceResult<List<Cafe>>>();
  final InflightRequestRegistry<ServiceResult<Cafe?>> _inflightDetails =
      InflightRequestRegistry<ServiceResult<Cafe?>>();

  /// Lightweight columns fetched for the list view.
  ///
  /// Includes image URLs so list surfaces (cards/map/favorites) can render
  /// without requiring detail fetches.
  static const _listColumns =
      'id,name,category,district,neighborhood,address,rating,review_count,'
      'price_level,wifi_quality,outlet_availability,quietness_level,'
      'study_friendly,pet_friendly,outdoor_seating,smoking_policy,'
      'is_deleted,google_place_id,google_uses_app_defaults,'
      'coordinates,phone_number,website_uri,tags,images,favorite_count,'
      'owner_approval_status,is_featured';

  static const _overlayColumns = '$_listColumns,deleted_at';
  static const _featuredColumns =
      'id,name,district,neighborhood,address,formatted_address,category,'
      'rating,review_count,google_rating,google_review_count,price_level,'
      'description,tags,images,opening_hours,menu_highlights,wifi_quality,'
      'outlet_availability,quietness_level,study_friendly,pet_friendly,'
      'outdoor_seating,smoking_policy,coordinates,phone_number,website_uri,'
      'owner_approval_status,google_place_id,google_uses_app_defaults,'
      'is_deleted,favorite_count,'
      'deleted_at,deleted_by,is_featured,featured_priority,featured_until,'
      'featured_label';
  static const _adminColumns = '*';

  @override
  Future<ServiceResult<List<Cafe>>> fetchDiscoverableCafes({
    String? district,
    int limit = 800,
    int offset = 0,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final safeLimit = limit.clamp(1, 2000);
    final safeOffset = offset < 0 ? 0 : offset;
    final effectiveTimeout =
        requestTimeout ?? NetworkTimeoutConfig.supabaseDataRequestTimeout;
    final normalizedDistrict = district?.trim();
    final districtTerms = _districtSearchTerms(normalizedDistrict);

    final loader = _cafesLoader;
    if (loader != null) {
      try {
        final rows = await loader();
        final cafes = rows
            .map(Cafe.fromSupabaseRow)
            .where((cafe) => cafe.isVisibleInPublic)
            .where((cafe) => _matchesDistrictTerms(cafe, districtTerms))
            .skip(safeOffset)
            .take(safeLimit)
            .toList(growable: false);
        return ServiceResult.success(data: cafes);
      } catch (error, stackTrace) {
        AppLogger.error(
          'CafeQueryService.fetchDiscoverableCafes loader failed',
          error: error,
          stackTrace: stackTrace,
          key: 'cafe-query-fetch-discoverable-loader',
        );
      }
    }

    try {
      final response = await retryAsync(
        () async {
          AppLogger.debug(
            '[FEATURED_FETCH] requested=true limit=$safeLimit',
            key: 'featured-fetch-requested',
            throttle: Duration.zero,
          );
          var query = _client
              .from('cafes')
              .select(_listColumns)
              .or('is_deleted.is.null,is_deleted.eq.false')
              .isFilter('deleted_at', null);

          if (districtTerms.isNotEmpty) {
            query = query.or(_buildDistrictOrFilter(districtTerms));
          }

          return _withDataTimeout(
            query
                .order('rating', ascending: false)
                .order('name', ascending: true)
                .range(safeOffset, safeOffset + safeLimit - 1),
            timeout: effectiveTimeout,
          );
        },
        shouldRetry: _shouldRetrySupabaseError,
        cancellationToken: cancellationToken,
      );

      cancellationToken?.throwIfCancelled();

      _logRawSupabasePhotoRows(
        source: 'remote-discoverable',
        rows: response as List,
      );

      final cafes = (response)
          .map(Cafe.fromSupabaseRow)
          .where((cafe) => _matchesDistrictTerms(cafe, districtTerms))
          .toList(growable: false);
      _logPhotoFlow(source: 'remote-discoverable', cafes: cafes);

      return ServiceResult.success(data: cafes);
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeQueryService.fetchDiscoverableCafes failed',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-query-fetch-discoverable',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeListFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchActiveFeaturedCafes({
    String? district,
    int limit = 40,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final safeLimit = limit.clamp(1, 200);
    final effectiveTimeout =
        requestTimeout ?? NetworkTimeoutConfig.supabaseDataRequestTimeout;
    final districtTerms = _districtSearchTerms(district);

    AppLogger.debug(
      '[FEATURED_QUERY] phase=start limit=$safeLimit district=${district ?? '-'}',
      key: 'featured-query-start',
      throttle: Duration.zero,
    );

    final loader = _cafesLoader;
    if (loader != null) {
      try {
        final cafes = (await loader())
            .map(Cafe.fromSupabaseRow)
            .where((cafe) => cafe.isFeatured && cafe.isVisibleInPublic)
            .where((cafe) => _matchesDistrictTerms(cafe, districtTerms))
            .toList(growable: false)
          ..sort(_compareFeaturedCafes);
        AppLogger.debug(
          '[FEATURED_QUERY] phase=loader rows=${cafes.length}',
          key: 'featured-query-loader',
          throttle: Duration.zero,
        );
        return ServiceResult.success(
          data: cafes.take(safeLimit).toList(growable: false),
        );
      } catch (error, stackTrace) {
        AppLogger.error(
          'CafeQueryService.fetchActiveFeaturedCafes loader failed',
          error: error,
          stackTrace: stackTrace,
          key: 'cafe-query-fetch-featured-loader',
        );
      }
    }

    try {
      final response = await retryAsync(
        () async {
          var query = _client
              .from('cafes')
              .select(_featuredColumns)
              .eq('is_featured', true)
              .isFilter('deleted_at', null)
              .or('is_deleted.is.null,is_deleted.eq.false');

          if (districtTerms.isNotEmpty) {
            query = query.or(_buildDistrictOrFilter(districtTerms));
          }

          return _withDataTimeout(
            query
                .order('featured_priority', ascending: true)
                .order('name', ascending: true)
                .limit(safeLimit),
            timeout: effectiveTimeout,
          );
        },
        shouldRetry: _shouldRetrySupabaseError,
        cancellationToken: cancellationToken,
      );

      cancellationToken?.throwIfCancelled();

      final rows = (response as List)
          .map((row) => row as Map<String, dynamic>)
          .toList(growable: false);

      AppLogger.debug(
        '[FEATURED_QUERY] phase=success rows=${rows.length}',
        key: 'featured-query-success',
        throttle: Duration.zero,
      );

      _logFeaturedRawImageShape(rows: rows);

      _logRawSupabasePhotoRows(
        source: 'remote-active-featured',
        rows: rows,
      );

      final mappedCafes =
          rows.map(Cafe.fromSupabaseRow).toList(growable: false);
      final activeCafes = mappedCafes
          .where((cafe) => cafe.isFeatured && cafe.isVisibleInPublic)
          .toList(growable: false);
      final districtCafes = activeCafes
          .where((cafe) => _matchesDistrictTerms(cafe, districtTerms))
          .toList(growable: false)
        ..sort(_compareFeaturedCafes);

      AppLogger.debug(
        '[FEATURED_QUERY] phase=map mapped=${mappedCafes.length} active=${activeCafes.length} district=${districtCafes.length}',
        key: 'featured-query-map',
        throttle: Duration.zero,
      );
      _logPhotoFlow(source: 'remote-active-featured', cafes: districtCafes);
      return ServiceResult.success(data: districtCafes);
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeQueryService.fetchActiveFeaturedCafes failed',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-query-fetch-featured',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeListFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  int _compareFeaturedCafes(Cafe left, Cafe right) {
    final priority = left.featuredPriority.compareTo(right.featuredPriority);
    if (priority != 0) {
      return priority;
    }

    final rating = right.effectiveRating.compareTo(left.effectiveRating);
    if (rating != 0) {
      return rating;
    }

    final name = left.name.toLowerCase().compareTo(right.name.toLowerCase());
    if (name != 0) {
      return name;
    }

    return left.id.compareTo(right.id);
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafes() async {
    final loader = _cafesLoader;
    if (loader != null) {
      try {
        final rows = await loader();
        final cafes = rows.map(Cafe.fromSupabaseRow).toList(growable: false);
        return ServiceResult.success(data: cafes);
      } catch (error, stackTrace) {
        AppLogger.error(
          'CafeQueryService.fetchCafes fallback loader failed',
          error: error,
          stackTrace: stackTrace,
          key: 'cafe-query-fetch-list-loader',
        );
        return ServiceResult.failure(
          message: error.toString(),
          errorCode: _errorCodeForSupabaseError(
            error,
            fallback: AppErrorCode.cafeListFailed,
          ),
          error: error,
          errorType: classifyServiceError(error),
        );
      }
    }

    final result = await fetchDiscoverableCafes(limit: 2000);
    if (!result.ok) {
      return result;
    }
    return ServiceResult.success(data: result.data ?? const <Cafe>[]);
  }

  Future<ServiceResult<AdminCafePage>> fetchAdminCafes({
    String searchQuery = '',
    String district = 'all',
    String status = 'all',
    int limit = 60,
    int offset = 0,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final safeLimit = limit.clamp(1, 200);
    final safeOffset = offset < 0 ? 0 : offset;
    final effectiveTimeout =
        requestTimeout ?? NetworkTimeoutConfig.supabaseDataRequestTimeout;
    final districtTerms = _districtSearchTerms(district);

    try {
      final response = await retryAsync(
        () async {
          var query = _client.from('cafes').select(_adminColumns);

          final normalizedSearch =
              searchQuery.trim().replaceAll('%', '').replaceAll('_', '');
          if (normalizedSearch.isNotEmpty) {
            query = query.ilike('name', '%$normalizedSearch%');
          }

          if (districtTerms.isNotEmpty) {
            query = query.or(_buildDistrictOrFilter(districtTerms));
          }

          switch (status.trim()) {
            case 'visible':
              query = query
                  .or('is_deleted.eq.false,is_deleted.is.null')
                  .isFilter('deleted_at', null);
              break;
            case 'hidden':
              query = query.isFilter('deleted_at', null);
              break;
            case 'deleted':
              query = query.or('is_deleted.eq.true,deleted_at.not.is.null');
              break;
            case 'all':
            default:
              break;
          }

          return _withDataTimeout(
            query
                .order('name', ascending: true)
                .range(safeOffset, safeOffset + safeLimit),
            timeout: effectiveTimeout,
          );
        },
        shouldRetry: _shouldRetrySupabaseError,
        cancellationToken: cancellationToken,
      );

      cancellationToken?.throwIfCancelled();
      final rows = (response as List)
          .map((row) => row as Map<String, dynamic>)
          .toList(growable: false);
      final hasMore = rows.length > safeLimit;
      final pageRows = hasMore ? rows.take(safeLimit).toList() : rows;
      _logRawSupabasePhotoRows(
        source: 'remote-admin-page',
        rows: pageRows,
      );
      final cafes = pageRows
          .map(Cafe.fromSupabaseRow)
          .where((cafe) => _matchesDistrictTerms(cafe, districtTerms))
          .toList(growable: false);
      AppLogger.debug(
        '[ADMIN_CAFE_LIST_SOURCE] source=adminSupabase count=${cafes.length} featuredOnly=false',
        key: 'admin-cafe-list-source-service',
        throttle: Duration.zero,
      );
      AppLogger.debug(
        '[ADMIN_CAFE_LIST_FILTER] deletedExcluded=0 featuredFilterApplied=false',
        key: 'admin-cafe-list-filter-service',
        throttle: Duration.zero,
      );
      _logPhotoFlow(source: 'remote-admin-page', cafes: cafes);

      return ServiceResult.success(
        data: AdminCafePage(
          cafes: cafes,
          hasMore: hasMore,
          offset: safeOffset,
          limit: safeLimit,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeQueryService.fetchAdminCafes failed',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-query-fetch-admin-page',
      );
      final fallback = await _fallbackAdminCafePage(
        searchQuery: searchQuery,
        district: district,
        status: status,
        limit: safeLimit,
        offset: safeOffset,
      );
      if (fallback != null) {
        return ServiceResult.success(data: fallback);
      }
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeListFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<AdminCafePage?> _fallbackAdminCafePage({
    required String searchQuery,
    required String district,
    required String status,
    required int limit,
    required int offset,
  }) async {
    final listResult = await _fetchAllCafesForAdminFallback();
    if (!listResult.ok || listResult.data == null) {
      return null;
    }

    var cafes = listResult.data!;
    final normalizedSearch = searchQuery.trim();
    if (normalizedSearch.isNotEmpty) {
      cafes = cafes
          .where((cafe) =>
              normalizeSearchText(cafe.name)
                  .contains(normalizeSearchText(normalizedSearch)) ||
              normalizeSearchText(cafe.address)
                  .contains(normalizeSearchText(normalizedSearch)) ||
              normalizeSearchText(cafe.placeId ?? '')
                  .contains(normalizeSearchText(normalizedSearch)))
          .toList(growable: false);
    }

    final districtTerms = _districtSearchTerms(district);
    if (districtTerms.isNotEmpty) {
      cafes = cafes
          .where((cafe) => _matchesDistrictTerms(cafe, districtTerms))
          .toList(growable: false);
    }

    switch (status.trim()) {
      case 'visible':
        cafes = cafes
            .where((cafe) => cafe.isVisibleInPublic)
            .toList(growable: false);
        break;
      case 'hidden':
        cafes = cafes
            .where((cafe) => !cafe.isDeleted && !cafe.isVisibleInPublic)
            .toList(growable: false);
        break;
      case 'deleted':
        cafes = cafes.where((cafe) => cafe.isDeleted).toList(growable: false);
        break;
      case 'all':
      default:
        break;
    }

    final page = cafes.skip(offset).take(limit).toList(growable: false);
    final hasMore = offset + page.length < cafes.length;
    return AdminCafePage(
      cafes: page,
      hasMore: hasMore,
      offset: offset,
      limit: limit,
    );
  }

  Future<ServiceResult<List<Cafe>>> _fetchAllCafesForAdminFallback({
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final effectiveTimeout =
        requestTimeout ?? NetworkTimeoutConfig.supabaseDataRequestTimeout;
    const pageSize = 400;
    const maxRows = 4000;
    final rows = <Map<String, dynamic>>[];

    try {
      var offset = 0;
      while (offset < maxRows) {
        final pageResponse = await retryAsync(
          () async {
            final query = _client
                .from('cafes')
                .select(_adminColumns)
                .order('name', ascending: true)
                .range(offset, offset + pageSize - 1);
            return _withDataTimeout(query, timeout: effectiveTimeout);
          },
          shouldRetry: _shouldRetrySupabaseError,
          cancellationToken: cancellationToken,
        );

        cancellationToken?.throwIfCancelled();
        final pageRows = (pageResponse as List)
            .map((row) => row as Map<String, dynamic>)
            .toList(growable: false);
        if (pageRows.isEmpty) {
          break;
        }

        rows.addAll(pageRows);
        if (pageRows.length < pageSize) {
          break;
        }

        offset += pageSize;
      }

      final cafes = rows.map(Cafe.fromSupabaseRow).toList(growable: false);
      return ServiceResult.success(data: cafes);
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeQueryService._fetchAllCafesForAdminFallback failed',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-query-fetch-all-admin-fallback',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeListFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  List<String> _districtSearchTerms(String? district) {
    final normalizedDistrict = district?.trim() ?? '';
    if (normalizedDistrict.isEmpty || normalizedDistrict == 'all') {
      return const <String>[];
    }

    final matchedDistrict = matchDistrict(normalizedDistrict);
    final terms = <String>{
      normalizedDistrict,
      if (matchedDistrict != null) matchedDistrict.displayName,
      if (matchedDistrict != null) matchedDistrict.name,
      if (matchedDistrict != null) ...matchedDistrict.searchTerms,
    };

    final deduped = <String>[];
    final normalizedSeen = <String>{};
    for (final term in terms) {
      final sanitized = term
          .trim()
          .replaceAll('%', '')
          .replaceAll('_', '')
          .replaceAll(',', ' ');
      if (sanitized.isEmpty) {
        continue;
      }

      final normalized = normalizeSearchText(sanitized);
      if (normalized.isEmpty || !normalizedSeen.add(normalized)) {
        continue;
      }
      deduped.add(sanitized);
    }

    deduped.sort((left, right) => right.length.compareTo(left.length));
    return deduped.take(8).toList(growable: false);
  }

  bool _matchesDistrictTerms(Cafe cafe, List<String> terms) {
    if (terms.isEmpty) {
      return true;
    }
    for (final term in terms) {
      if (districtMatches(cafe.district, term)) {
        return true;
      }
    }
    return false;
  }

  String _buildDistrictOrFilter(List<String> terms) {
    return terms.map((term) => 'district.ilike.%$term%').join(',');
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafesByPlaceIds(
    Iterable<String> placeIds, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final normalizedPlaceIds = placeIds
        .map((placeId) => placeId.trim())
        .where((placeId) => placeId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedPlaceIds.isEmpty) {
      return ServiceResult.success(data: <Cafe>[]);
    }

    final effectiveTimeout =
        requestTimeout ?? NetworkTimeoutConfig.supabaseDataRequestTimeout;
    final requestKey =
        '${normalizedPlaceIds.join('|')}|includeDeleted=$includeDeleted';
    cancellationToken?.throwIfCancelled();
    return _inflightPlaceIds.run(
      '$requestKey|${effectiveTimeout.inMilliseconds}',
      () async {
        try {
          final response = await retryAsync(
            () async {
              final loader = _cafesByPlaceIdsLoader;
              if (loader != null) {
                return loader(
                  normalizedPlaceIds,
                  requestTimeout: effectiveTimeout,
                  cancellationToken: cancellationToken,
                );
              }
              var query = _client
                  .from('cafes')
                  .select(_overlayColumns)
                  .inFilter('google_place_id', normalizedPlaceIds);
              if (!includeDeleted) {
                query = query
                    .or('is_deleted.is.null,is_deleted.eq.false')
                    .isFilter('deleted_at', null);
              }
              return _withDataTimeout(
                query,
                timeout: effectiveTimeout,
              );
            },
            shouldRetry: _shouldRetrySupabaseError,
            cancellationToken: cancellationToken,
          );

          cancellationToken?.throwIfCancelled();
          _logRawSupabasePhotoRows(
            source: 'remote-overlay',
            rows: response as List,
          );
          final cafes = (response as List)
              .map((row) => Cafe.fromSupabaseRow(row as Map<String, dynamic>))
              .toList(growable: false);
          AppLogger.debug(
            '[CAFE_DIAG_DB_OVERLAY] placeIdCount=${normalizedPlaceIds.length} includeDeleted=$includeDeleted rawDbCount=${(response as List).length} mappedCount=${cafes.length}',
            key: 'cafe-diag-db-overlay',
            throttle: Duration.zero,
          );
          _logPhotoFlow(source: 'remote-overlay', cafes: cafes);

          return ServiceResult.success(data: cafes);
        } catch (error, stackTrace) {
          AppLogger.error(
            'CafeQueryService.fetchCafesByPlaceIds failed',
            error: error,
            stackTrace: stackTrace,
            key: 'cafe-query-fetch-place-ids',
          );
          return ServiceResult.failure(
            message: error.toString(),
            errorCode: _errorCodeForSupabaseError(
              error,
              fallback: AppErrorCode.cafeListFailed,
            ),
            error: error,
            errorType: classifyServiceError(error),
          );
        }
      },
    );
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafesByIds(
    Iterable<String> ids, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return ServiceResult.success(data: const <Cafe>[]);
    }

    final effectiveTimeout =
        requestTimeout ?? NetworkTimeoutConfig.supabaseDataRequestTimeout;

    try {
      final byId = await retryAsync(
        () async {
          var query = _client
              .from('cafes')
              .select(_overlayColumns)
              .inFilter('id', normalizedIds);
          if (!includeDeleted) {
            query = query
                .or('is_deleted.is.null,is_deleted.eq.false')
                .isFilter('deleted_at', null);
          }
          return _withDataTimeout(query, timeout: effectiveTimeout);
        },
        shouldRetry: _shouldRetrySupabaseError,
        cancellationToken: cancellationToken,
      );

      cancellationToken?.throwIfCancelled();
      _logRawSupabasePhotoRows(
        source: 'remote-by-ids:id-query',
        rows: byId as List,
      );
      final byPlaceId = await retryAsync(
        () async {
          var query = _client
              .from('cafes')
              .select(_overlayColumns)
              .inFilter('google_place_id', normalizedIds);
          if (!includeDeleted) {
            query = query
                .or('is_deleted.is.null,is_deleted.eq.false')
                .isFilter('deleted_at', null);
          }
          return _withDataTimeout(query, timeout: effectiveTimeout);
        },
        shouldRetry: _shouldRetrySupabaseError,
        cancellationToken: cancellationToken,
      );

      cancellationToken?.throwIfCancelled();
      _logRawSupabasePhotoRows(
        source: 'remote-by-ids:place-query',
        rows: byPlaceId as List,
      );
      final mergedRows = <String, Cafe>{};
      for (final row in [...(byId as List), ...(byPlaceId as List)]) {
        final cafe = Cafe.fromSupabaseRow(row as Map<String, dynamic>);
        mergedRows[cafe.canonicalIdentityKey] = cafe;
      }

      final cafes = mergedRows.values.toList(growable: false);
      _logPhotoFlow(source: 'remote-by-ids', cafes: cafes);
      return ServiceResult.success(data: cafes);
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeQueryService.fetchCafesByIds failed',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-query-fetch-by-ids',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeListFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  @override
  Future<ServiceResult<Cafe?>> fetchCafeById(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final effectiveTimeout =
        requestTimeout ?? NetworkTimeoutConfig.supabaseDataRequestTimeout;
    cancellationToken?.throwIfCancelled();
    return _inflightDetails.run(
      '$cafeId|${effectiveTimeout.inMilliseconds}',
      () async {
        try {
          final response = await retryAsync(
            () async {
              final loader = _cafeDetailLoader;
              if (loader != null) {
                return loader(
                  cafeId,
                  requestTimeout: effectiveTimeout,
                  cancellationToken: cancellationToken,
                );
              }
              // Primary lookup by UUID id.
              final byId = await _withDataTimeout(
                _client
                    .from('cafes')
                    .select('*')
                    .eq('id', cafeId)
                    .maybeSingle(),
                timeout: effectiveTimeout,
              );
              if (byId != null) return byId;

              // Fallback: look up by google_place_id for API-origin cafes.
              return _withDataTimeout(
                _client
                    .from('cafes')
                    .select('*')
                    .eq('google_place_id', cafeId)
                    .isFilter('deleted_at', null)
                    .or('is_deleted.is.null,is_deleted.eq.false')
                    .maybeSingle(),
                timeout: effectiveTimeout,
              );
            },
            shouldRetry: _shouldRetrySupabaseError,
            cancellationToken: cancellationToken,
          );

          cancellationToken?.throwIfCancelled();
          if (response == null) {
            return ServiceResult<Cafe?>.success(data: null);
          }

          _logRawSupabasePhotoRow(
            source: 'remote-detail',
            row: response,
          );

          final cafe = Cafe.fromSupabaseRow(response);
          _logPhotoFlow(source: 'remote-detail', cafes: <Cafe>[cafe]);
          // Do not return deleted cafes.
          if (cafe.isDeleted) {
            return ServiceResult<Cafe?>.success(data: null);
          }

          return ServiceResult.success(data: cafe);
        } catch (error, stackTrace) {
          AppLogger.error(
            'CafeQueryService.fetchCafeById failed for cafeId=$cafeId',
            error: error,
            stackTrace: stackTrace,
            key: 'cafe-query-fetch-detail-$cafeId',
          );

          final fallbackList = await _fetchAllCafesForAdminFallback(
            requestTimeout: effectiveTimeout,
            cancellationToken: cancellationToken,
          );
          if (fallbackList.ok && fallbackList.data != null) {
            for (final cafe in fallbackList.data!) {
              if (cafe.id == cafeId || cafe.placeId == cafeId) {
                if (cafe.isDeleted) {
                  return ServiceResult<Cafe?>.success(data: null);
                }
                return ServiceResult.success(data: cafe);
              }
            }
            return ServiceResult<Cafe?>.success(data: null);
          }

          return ServiceResult.failure(
            message: error.toString(),
            errorCode: _errorCodeForSupabaseError(
              error,
              fallback: AppErrorCode.cafeDetailFailed,
            ),
            error: error,
            errorType: classifyServiceError(error),
          );
        }
      },
    );
  }

  @override
  Future<ServiceResult<Cafe?>> fetchCafeDetails(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    return fetchCafeById(
      cafeId,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
  }

  @override
  Future<ServiceResult<List<Cafe>>> searchCafesByName(
    String query, {
    int limit = 20,
    bool includeDeleted = false,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return ServiceResult.success(data: const <Cafe>[]);
    }

    final safePattern = normalizedQuery.replaceAll('%', '').replaceAll('_', '');
    try {
      var request = _client
          .from('cafes')
          .select(_listColumns)
          .ilike('name', '%$safePattern%');
      if (!includeDeleted) {
        request = request
            .or('is_deleted.is.null,is_deleted.eq.false')
            .isFilter('deleted_at', null);
      }

      final orderedRequest =
          request.order('rating', ascending: false).limit(limit.clamp(1, 200));

      final response = await _withDataTimeout(orderedRequest);
      _logRawSupabasePhotoRows(
        source: 'remote-search',
        rows: response as List,
      );
      final cafes = (response as List)
          .map((row) => Cafe.fromSupabaseRow(row as Map<String, dynamic>))
          .toList(growable: false);
      _logPhotoFlow(source: 'remote-search', cafes: cafes);
      return ServiceResult.success(data: cafes);
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeQueryService.searchCafesByName failed query=$normalizedQuery',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-query-search-by-name',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeListFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  void _logPhotoFlow({
    required String source,
    required List<Cafe> cafes,
  }) {
    if (cafes.isEmpty) {
      AppLogger.debug(
        '[CAFE_DIAG_PHOTO] source=$source cafes=0',
        key: 'cafe-diag-photo-$source',
        throttle: Duration.zero,
      );
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

  void _logRawSupabasePhotoRows({
    required String source,
    required List rows,
  }) {
    if (!kVerboseCafeDiagnostics) {
      return;
    }
    if (rows.isEmpty) {
      AppLogger.debug(
        '[CAFE_DIAG_PHOTO_RAW_SUPABASE] source=$source rows=0',
        key: 'cafe-diag-photo-raw-supabase-$source',
        throttle: Duration.zero,
      );
      return;
    }

    final candidate = rows.whereType<Map<String, dynamic>>().firstWhere(
          _rowHasImagePayload,
          orElse: () => rows.firstWhere((_) => true) as Map<String, dynamic>,
        );
    _logRawSupabasePhotoRow(source: source, row: candidate);
  }

  void _logFeaturedRawImageShape({
    required List<Map<String, dynamic>> rows,
  }) {
    if (!kDebugMode) {
      return;
    }
    for (final row in rows) {
      final id = (row['id'] as String?)?.trim() ?? 'unknown';
      final name = (row['name'] as String?)?.trim() ?? 'unknown';
      final placeIdPresent =
          (row['google_place_id'] as String?)?.trim().isNotEmpty == true;
      final rawImages = row['images'];
      final rawPhotoUrls = row['photo_urls'];
      final rawImagesCount = _rawImageCount(rawImages);
      final hasPhotoUrlsField = row.containsKey('photo_urls');
      final rawPhotoUrlsCount =
          hasPhotoUrlsField ? _rawImageCount(rawPhotoUrls) : null;
      final samples = _rawImageSamples(rawImages, maxSamples: 3);
      final sampleSegments = <String>[];
      for (var index = 0; index < samples.length; index += 1) {
        final sample = samples[index];
        final shape = _rawImageShapeDiagnostics(sample);
        sampleSegments.add('sample$index=$shape');
      }
      final samplePayload =
          sampleSegments.isEmpty ? 'samples=0' : sampleSegments.join(' ');

      AppLogger.debug(
        '[FEATURED_RAW_IMAGE_SHAPE_DIAG] cafeId=$id cafeName="$name" googlePlaceIdPresent=$placeIdPresent rawImagesCount=$rawImagesCount rawPhotoUrlsCount=${rawPhotoUrlsCount ?? 'n/a'} $samplePayload',
        key: 'featured-raw-image-shape-$id',
        throttle: Duration.zero,
      );
    }
  }

  int _rawImageCount(Object? raw) {
    if (raw == null) {
      return 0;
    }
    if (raw is List) {
      return raw.length;
    }
    if (raw is String) {
      return raw.trim().isEmpty ? 0 : 1;
    }
    if (raw is Map) {
      return raw.isEmpty ? 0 : 1;
    }
    return 1;
  }

  List<String> _rawImageSamples(Object? raw, {int maxSamples = 3}) {
    final samples = <String>[];

    void addSample(Object? value) {
      if (samples.length >= maxSamples || value == null) {
        return;
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          samples.add(trimmed);
        }
        return;
      }
      if (value is List) {
        for (final entry in value) {
          addSample(entry);
          if (samples.length >= maxSamples) {
            return;
          }
        }
        return;
      }
      if (value is Map) {
        for (final entry in value.values) {
          addSample(entry);
          if (samples.length >= maxSamples) {
            return;
          }
        }
      }
    }

    addSample(raw);
    return samples;
  }

  String _rawImageShapeDiagnostics(String raw) {
    final trimmed = raw.trim();
    final startsWithPlacesSlash = trimmed.startsWith('places/') ||
        trimmed.startsWith('/v1/places/') ||
        trimmed.startsWith('v1/places/');
    final containsPhotosSegment =
        trimmed.contains('/photos/') || trimmed.contains('photos/');
    final containsMediaSuffix = trimmed.endsWith('/media');

    final uri = Uri.tryParse(trimmed);
    final hasScheme = uri?.hasScheme == true;
    final host = uri?.host.toLowerCase() ?? 'none';
    final pathShape = hasScheme
        ? googlePhotoUrlDiagnosticsForLog(trimmed)
        : 'host=none pathShape=none hasMediaSuffix=$containsMediaSuffix hasMaxWidthPx=false hasMaxHeightPx=false usesPhotoApiKey=false usesFallbackPlacesKey=false';

    String valueType = 'unknown';
    if (hasScheme && (uri?.scheme == 'http' || uri?.scheme == 'https')) {
      if (trimmed.contains('storage/v1/object/public/')) {
        valueType = 'storage_url';
      } else {
        valueType = 'full_url';
      }
    } else if (startsWithPlacesSlash ||
        normalizeGooglePhotoName(trimmed) != null) {
      valueType = 'places_photo_name';
    } else if (_looksLikeLegacyPhotoReference(trimmed)) {
      valueType = 'legacy_photo_reference';
    }

    return 'valueType=$valueType host=$host $pathShape startsWithPlacesSlash=$startsWithPlacesSlash containsPhotosSegment=$containsPhotosSegment containsMediaSuffix=$containsMediaSuffix';
  }

  bool _looksLikeLegacyPhotoReference(String raw) {
    if (raw.contains('://') || raw.contains('/') || raw.contains('.')) {
      return false;
    }
    if (raw.contains(RegExp(r'\s'))) {
      return false;
    }
    return raw.length >= 20;
  }

  void _logRawSupabasePhotoRow({
    required String source,
    required Map<String, dynamic> row,
  }) {
    final id = (row['id'] as String?)?.trim() ?? 'unknown';
    final name = (row['name'] as String?)?.trim() ?? 'unknown';
    final fieldPresence = <String, bool>{
      'images': _hasPhotoPayload(row['images']),
      'photo_urls': _hasPhotoPayload(row['photo_urls']),
      'photoUrl': _hasPhotoPayload(row['photoUrl']),
      'image_url': _hasPhotoPayload(row['image_url']),
      'image_urls': _hasPhotoPayload(row['image_urls']),
      'photos': _hasPhotoPayload(row['photos']),
      'media': _hasPhotoPayload(row['media']),
      'google_photo_reference': _hasPhotoPayload(row['google_photo_reference']),
      'google_photo_references':
          _hasPhotoPayload(row['google_photo_references']),
    };
    final presentFields = fieldPresence.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList(growable: false);
    AppLogger.debug(
      '[CAFE_DIAG_PHOTO_RAW_SUPABASE] source=$source id=$id name="$name" presentFieldCount=${presentFields.length}/${fieldPresence.length} presentFields=$presentFields',
      key: 'cafe-diag-photo-raw-supabase-$source-$id',
      throttle: Duration.zero,
    );
  }

  bool _rowHasImagePayload(Map<String, dynamic> row) {
    for (final key in const [
      'images',
      'photo_urls',
      'photoUrl',
      'image_url',
      'image_urls',
      'photos',
      'media',
      'google_photo_reference',
      'google_photo_references',
    ]) {
      if (_hasPhotoPayload(row[key])) {
        return true;
      }
    }
    return false;
  }

  bool _hasPhotoPayload(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is List) {
      return value.any(_hasPhotoPayload);
    }
    if (value is Map) {
      return value.values.any(_hasPhotoPayload);
    }
    return true;
  }

  @override
  Future<ServiceResult<void>> updateGoogleRatingMetadata({
    required String cafeId,
    required String googlePlaceId,
    double? googleRating,
    int? googleReviewCount,
    String? externalLastSyncedAt,
    Duration? requestTimeout,
  }) async {
    final normalizedCafeId = cafeId.trim();
    final normalizedPlaceId = googlePlaceId.trim();
    if (normalizedCafeId.isEmpty || normalizedPlaceId.isEmpty) {
      return ServiceResult.failure(
        message: 'Cafe id and Google place id are required.',
        errorType: ServiceErrorType.validation,
      );
    }
    final payload = <String, dynamic>{
      'google_rating': googleRating,
      'google_review_count': googleReviewCount,
      'external_last_synced_at':
          externalLastSyncedAt ?? DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await _client
          .from('cafes')
          .update(payload)
          .eq('id', normalizedCafeId)
          .eq('google_place_id', normalizedPlaceId)
          .timeout(
            requestTimeout ?? NetworkTimeoutConfig.supabaseDataRequestTimeout,
          );
      return ServiceResult.success(data: null);
    } catch (error) {
      return ServiceResult.failure(
        message: 'Unable to update Google rating metadata.',
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }
}

class CafeCommandService {
  CafeCommandService(
    this._client, {
    CafeUpdateRowLoader? updateCafeLoader,
    CafeInsertRowLoader? addCafeLoader,
    CafeSoftDeleteLookupLoader? softDeleteLookupLoader,
    CafeSoftDeleteUpdateLoader? softDeleteUpdateLoader,
    CafeTombstoneLoader? tombstoneLoader,
  })  : _updateCafeLoader = updateCafeLoader,
        _addCafeLoader = addCafeLoader,
        _softDeleteLookupLoader = softDeleteLookupLoader,
        _softDeleteUpdateLoader = softDeleteUpdateLoader,
        _tombstoneLoader = tombstoneLoader;

  final SupabaseClient _client;
  final CafeUpdateRowLoader? _updateCafeLoader;
  final CafeInsertRowLoader? _addCafeLoader;
  final CafeSoftDeleteLookupLoader? _softDeleteLookupLoader;
  final CafeSoftDeleteUpdateLoader? _softDeleteUpdateLoader;
  final CafeTombstoneLoader? _tombstoneLoader;
  final Set<String> _pendingDestructiveTargetLocks = <String>{};

  static bool _looksLikeGooglePlaceId(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty || _looksLikeUuid(normalized)) {
      return false;
    }
    return normalized.startsWith('ChI') ||
        (normalized.length >= 20 &&
            RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(normalized));
  }

  static bool _looksLikeUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id.trim());
  }

  String _destructiveLockKey(
    String cafeId,
    String? placeId,
  ) {
    final normalizedPlaceId = placeId?.trim();
    if (normalizedPlaceId != null && normalizedPlaceId.isNotEmpty) {
      return 'place:${normalizedPlaceId.toLowerCase()}';
    }
    if (_looksLikeGooglePlaceId(cafeId)) {
      return 'place:${cafeId.toLowerCase()}';
    }
    return 'id:${cafeId.toLowerCase()}';
  }

  bool _acquireDestructiveTargetLock(String lockKey) {
    return _pendingDestructiveTargetLocks.add(lockKey);
  }

  void _releaseDestructiveTargetLock(String lockKey) {
    _pendingDestructiveTargetLocks.remove(lockKey);
  }

  Future<Map<String, dynamic>?> _lookupSoftDeleteTarget(
    String normalizedCafeId,
    String? candidatePlaceId,
  ) async {
    if (_softDeleteLookupLoader != null) {
      return _softDeleteLookupLoader!(normalizedCafeId, candidatePlaceId);
    }

    var existingRow = await _client
        .from('cafes')
        .select('id,google_place_id,name,is_deleted,deleted_at,is_featured')
        .eq('id', normalizedCafeId)
        .maybeSingle()
        .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

    if (existingRow == null && candidatePlaceId != null) {
      existingRow = await _client
          .from('cafes')
          .select('id,google_place_id,name,is_deleted,deleted_at,is_featured')
          .eq('google_place_id', candidatePlaceId)
          .limit(1)
          .maybeSingle()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
    }

    if (existingRow == null &&
        candidatePlaceId == null &&
        !_looksLikeUuid(normalizedCafeId)) {
      existingRow = await _client
          .from('cafes')
          .select('id,google_place_id,name,is_deleted,deleted_at,is_featured')
          .eq('google_place_id', normalizedCafeId)
          .limit(1)
          .maybeSingle()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
    }

    return existingRow;
  }

  Future<Map<String, dynamic>?> _runSoftDeleteUpdate(
    String resolvedRowId,
    Map<String, dynamic> payload,
    String? resolvedPlaceId,
  ) async {
    if (_softDeleteUpdateLoader != null) {
      // Test-injected loader: return null to signal zero rows (caller decides
      // whether to tombstone or fail — same semantics as the real Supabase path).
      return _softDeleteUpdateLoader!(resolvedRowId, payload);
    }

    AppLogger.debug(
      '[ADMIN_DELETE_OPERATION] operation=SOFT_UPDATE physicalDelete=false table=cafes filter=id.eq.$resolvedRowId payloadKeys=${payload.keys.join(",")}',
      key: 'admin-delete-operation-id-$resolvedRowId',
      throttle: Duration.zero,
    );
    final rowsById = await _client
        .from('cafes')
        .update(payload)
        .eq('id', resolvedRowId)
        .select('*')
        .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

    final rows = <Map<String, dynamic>>[
      for (final row in rowsById) Map<String, dynamic>.from(row as Map),
    ];

    final normalizedPlaceId = resolvedPlaceId?.trim();
    if (normalizedPlaceId != null && normalizedPlaceId.isNotEmpty) {
      AppLogger.debug(
        '[ADMIN_DELETE_OPERATION] operation=SOFT_UPDATE physicalDelete=false table=cafes filter=google_place_id.eq.$normalizedPlaceId payloadKeys=${payload.keys.join(",")}',
        key: 'admin-delete-operation-place-$resolvedRowId',
        throttle: Duration.zero,
      );
      final rowsByPlaceId = await _client
          .from('cafes')
          .update(payload)
          .eq('google_place_id', normalizedPlaceId)
          .select('*')
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      final seenIds = rows
          .map((row) => (row['id'] as String?)?.trim())
          .whereType<String>()
          .toSet();
      for (final row in rowsByPlaceId) {
        final mapped = Map<String, dynamic>.from(row as Map);
        final id = (mapped['id'] as String?)?.trim();
        if (id == null || seenIds.add(id)) {
          rows.add(mapped);
        }
      }
    }

    AppLogger.debug(
      '[ADMIN_DELETE_UPDATE] operation=SOFT_UPDATE table=cafes targetType=${normalizedPlaceId == null || normalizedPlaceId.isEmpty ? 'id' : 'both'} returnedRows=${rows.length}',
      key: 'admin-delete-update-$resolvedRowId',
      throttle: Duration.zero,
    );

    if (rows.isEmpty) {
      // Caller decides whether to tombstone or fail — return null to signal
      // zero rows without throwing so the tombstone path can run.
      return null;
    }
    return rows.first;
  }

  /// Builds a stable, persistent tombstone id from a Google place id.
  ///
  /// Replaces all characters outside [A-Za-z0-9_-] with underscores and
  /// prefixes with `deleted-google-`. This avoids Dart's hashCode (which is
  /// not stable across processes or platforms).
  static String _buildTombstoneId(String googlePlaceId) {
    final sanitized = googlePlaceId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return 'deleted-google-$sanitized';
  }

  /// Inserts or updates a minimal deleted overlay row for a Google-only cafe
  /// that has no matching Supabase row. The tombstone prevents Google Places
  /// merge from resurrecting the venue.
  Future<Map<String, dynamic>?> _writeTombstoneRecord(
    String googlePlaceId, {
    String? displayName,
    String? deletedBy,
  }) async {
    final tombstoneId = _buildTombstoneId(googlePlaceId);
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'id': tombstoneId,
      'google_place_id': googlePlaceId,
      'name': (displayName?.trim().isNotEmpty == true)
          ? displayName!.trim()
          : googlePlaceId,
      'is_deleted': true,
      'deleted_at': now,
      'is_featured': false,
      'category': 'normal_cafe',
      'tags': <String>[],
      'images': <String>[],
      'opening_hours': <Map<String, dynamic>>[],
      'menu_highlights': <String>[],
    };
    if (deletedBy != null && deletedBy.trim().isNotEmpty) {
      payload['deleted_by'] = deletedBy.trim();
    }

    if (_tombstoneLoader != null) {
      return _tombstoneLoader!(googlePlaceId, payload);
    }

    // Check whether a row already exists by google_place_id.
    final existingRow = await _client
        .from('cafes')
        .select('id,google_place_id,is_deleted')
        .eq('google_place_id', googlePlaceId)
        .limit(1)
        .maybeSingle()
        .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

    if (existingRow != null) {
      // Row exists — soft-delete it in-place.
      final existingId = (existingRow['id'] as String?)?.trim() ?? tombstoneId;
      AppLogger.debug(
        '[ADMIN_DELETE_TOMBSTONE] action=update_existing googlePlaceId=${_shortId(googlePlaceId)} existingId=${_shortId(existingId)}',
        key: 'admin-delete-tombstone-update-${_shortId(googlePlaceId)}',
        throttle: Duration.zero,
      );
      final updatePayload = <String, dynamic>{
        'is_deleted': true,
        'deleted_at': now,
        'is_featured': false,
      };
      if (deletedBy != null && deletedBy.trim().isNotEmpty) {
        updatePayload['deleted_by'] = deletedBy.trim();
      }
      final updated = await _client
          .from('cafes')
          .update(updatePayload)
          .eq('id', existingId)
          .select('*')
          .limit(1)
          .maybeSingle()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return updated;
    }

    // No existing row — insert a fresh tombstone.
    AppLogger.debug(
      '[ADMIN_DELETE_TOMBSTONE] action=insert googlePlaceId=${_shortId(googlePlaceId)} tombstoneId=${_shortId(tombstoneId)}',
      key: 'admin-delete-tombstone-insert-${_shortId(googlePlaceId)}',
      throttle: Duration.zero,
    );
    final inserted = await _client
        .from('cafes')
        .insert(payload)
        .select('*')
        .single()
        .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
    return inserted;
  }

  static String _shortId(String id) {
    return id.length > 20 ? '${id.substring(0, 20)}…' : id;
  }

  Future<ServiceResult<Cafe>> softDeleteCafe({
    required String cafeId,
    String? externalPlaceId,
    String? deletedBy,
  }) async {
    final normalizedCafeId = cafeId.trim();
    final normalizedExternalPlaceId = externalPlaceId?.trim();
    final candidatePlaceId = (normalizedExternalPlaceId != null &&
            normalizedExternalPlaceId.isNotEmpty)
        ? normalizedExternalPlaceId
        : (_looksLikeGooglePlaceId(normalizedCafeId) ? normalizedCafeId : null);
    final lockKey = _destructiveLockKey(normalizedCafeId, candidatePlaceId);
    AppLogger.debug(
      '[ADMIN_DELETE_SERVICE_ENTER] method=CafeCommandService.softDeleteCafe operation=SOFT_UPDATE physicalDelete=false selectedId=$normalizedCafeId selectedGooglePlaceId=${candidatePlaceId ?? ''}',
      key: 'admin-delete-service-enter-$normalizedCafeId',
      throttle: Duration.zero,
    );
    AppLogger.debug(
      '[ADMIN_DELETE_SUPABASE_SERVICE_ENTER] method=SupabaseService.softDeleteCafe delegate=CafeCommandService.softDeleteCafe operation=SOFT_UPDATE physicalDelete=false selectedId=$normalizedCafeId selectedGooglePlaceId=${candidatePlaceId ?? ''}',
      key: 'admin-delete-supabase-service-enter-$normalizedCafeId',
      throttle: Duration.zero,
    );

    if (!_acquireDestructiveTargetLock(lockKey)) {
      return ServiceResult.failure(
        message: 'Delete already in progress for this cafe.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }

    try {
      final existingRow = await _lookupSoftDeleteTarget(
        normalizedCafeId,
        candidatePlaceId,
      );

      final dbRowExists = existingRow != null;

      if (!dbRowExists) {
        // No Supabase row found.
        AppLogger.debug(
          '[ADMIN_DELETE_ZERO_ROW] id=${_shortId(normalizedCafeId)} googlePlaceIdPresent=${candidatePlaceId != null}',
          key: 'admin-delete-zero-row-$normalizedCafeId',
          throttle: Duration.zero,
        );
        if (candidatePlaceId != null) {
          // Google-only cafe — insert tombstone to block future merge.
          return await _tombstoneAndReturn(
            googlePlaceId: candidatePlaceId,
            deletedBy: deletedBy,
          );
        }
        return ServiceResult.failure(
          message: 'Cannot delete: missing stable id/place_id',
          errorCode: AppErrorCode.recordNotFound,
          errorType: ServiceErrorType.notFound,
        );
      }

      final resolvedExistingRow = existingRow;

      final resolvedRowId = (resolvedExistingRow['id'] as String?)?.trim();
      if (resolvedRowId == null || resolvedRowId.isEmpty) {
        return ServiceResult.failure(
          message: 'Resolved cafe row id is missing.',
          errorCode: AppErrorCode.parseFailed,
          errorType: ServiceErrorType.parse,
        );
      }

      final resolvedPlaceId =
          (resolvedExistingRow['google_place_id'] as String?)?.trim();
      final displayName = (resolvedExistingRow['name'] as String?)?.trim();
      final payload = <String, dynamic>{
        'is_deleted': true,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'is_featured': false,
      };
      if (deletedBy != null && deletedBy.trim().isNotEmpty) {
        payload['deleted_by'] = deletedBy.trim();
      }

      final targetType = (resolvedPlaceId != null && resolvedPlaceId.isNotEmpty)
          ? 'both'
          : (candidatePlaceId != null ? 'google_place_id' : 'id');
      AppLogger.debug(
        '[ADMIN_DELETE_TARGET_TYPE] selected=$targetType id=$resolvedRowId hasGooglePlaceId=${resolvedPlaceId != null && resolvedPlaceId.isNotEmpty}',
        key: 'admin-delete-target-type-$normalizedCafeId',
        throttle: Duration.zero,
      );

      final response =
          await _runSoftDeleteUpdate(resolvedRowId, payload, resolvedPlaceId);

      if (response == null) {
        // Update returned zero rows despite finding a row earlier. This can
        // happen with concurrent deletes or RLS conflicts. Attempt a tombstone
        // if a google_place_id is available; otherwise fail clearly.
        final effectivePlaceId = resolvedPlaceId ?? candidatePlaceId;
        AppLogger.debug(
          '[ADMIN_DELETE_ZERO_ROW] id=${_shortId(resolvedRowId)} googlePlaceIdPresent=${effectivePlaceId != null} fallback=tombstone',
          key: 'admin-delete-zero-row-update-$resolvedRowId',
          throttle: Duration.zero,
        );
        if (effectivePlaceId != null) {
          return await _tombstoneAndReturn(
            googlePlaceId: effectivePlaceId,
            displayName: displayName,
            deletedBy: deletedBy,
          );
        }
        return ServiceResult.failure(
          message: _safeSoftDeleteFailureMessage(ServiceErrorType.notFound),
          errorCode: AppErrorCode.recordNotFound,
          errorType: ServiceErrorType.notFound,
        );
      }

      AppLogger.debug(
        '[ADMIN_DELETE_RESULT] mode=soft_update ok=true id=${_shortId(resolvedRowId)}',
        key: 'admin-delete-result-$resolvedRowId',
        throttle: Duration.zero,
      );
      return ServiceResult.success(data: Cafe.fromSupabaseRow(response));
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeCommandService.softDeleteCafe failed for cafeId=$normalizedCafeId placeId=${candidatePlaceId ?? ''} cause=${_sanitizedSoftDeleteCause(error)}',
        stackTrace: stackTrace,
        key: 'cafe-command-soft-delete-$normalizedCafeId',
      );
      final errorType = classifyServiceError(error);
      return ServiceResult.failure(
        message: _safeSoftDeleteFailureMessage(errorType),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeUpdateFailed,
        ),
        error: error,
        errorType: errorType,
      );
    } finally {
      _releaseDestructiveTargetLock(lockKey);
    }
  }

  Future<ServiceResult<Cafe>> _tombstoneAndReturn({
    required String googlePlaceId,
    String? displayName,
    String? deletedBy,
  }) async {
    try {
      final tombstoneRow = await _writeTombstoneRecord(
        googlePlaceId,
        displayName: displayName,
        deletedBy: deletedBy,
      );
      AppLogger.debug(
        '[ADMIN_DELETE_TOMBSTONE] action=insert_or_upsert googlePlaceId=${_shortId(googlePlaceId)} result=${tombstoneRow != null ? 'success' : 'failure'}',
        key: 'admin-delete-tombstone-result-${_shortId(googlePlaceId)}',
        throttle: Duration.zero,
      );
      if (tombstoneRow != null) {
        AppLogger.debug(
          '[ADMIN_DELETE_RESULT] mode=tombstone ok=true googlePlaceId=${_shortId(googlePlaceId)}',
          key: 'admin-delete-result-tombstone-${_shortId(googlePlaceId)}',
          throttle: Duration.zero,
        );
        return ServiceResult.success(data: Cafe.fromSupabaseRow(tombstoneRow));
      }
      AppLogger.debug(
        '[ADMIN_DELETE_RESULT] mode=tombstone ok=false googlePlaceId=${_shortId(googlePlaceId)}',
        key: 'admin-delete-result-tombstone-fail-${_shortId(googlePlaceId)}',
        throttle: Duration.zero,
      );
      return ServiceResult.failure(
        message: _safeSoftDeleteFailureMessage(ServiceErrorType.notFound),
        errorCode: AppErrorCode.recordNotFound,
        errorType: ServiceErrorType.notFound,
      );
    } catch (tombstoneError, tombstoneTrace) {
      AppLogger.error(
        'CafeCommandService tombstone failed for googlePlaceId=${_shortId(googlePlaceId)}',
        error: tombstoneError,
        stackTrace: tombstoneTrace,
        key: 'cafe-command-tombstone-${_shortId(googlePlaceId)}',
      );
      final errorType = classifyServiceError(tombstoneError);
      return ServiceResult.failure(
        message: _safeSoftDeleteFailureMessage(errorType),
        errorCode: _errorCodeForSupabaseError(
          tombstoneError,
          fallback: AppErrorCode.cafeUpdateFailed,
        ),
        error: tombstoneError,
        errorType: errorType,
      );
    }
  }

  static String _safeSoftDeleteFailureMessage(ServiceErrorType errorType) {
    return switch (errorType) {
      ServiceErrorType.auth =>
        'Admin privileges are required to delete this cafe.',
      ServiceErrorType.validation =>
        'Cafe id or place id is required to delete this cafe.',
      ServiceErrorType.notFound =>
        'Delete target could not be resolved. Use an exact cafe id or place id.',
      ServiceErrorType.timeout ||
      ServiceErrorType.network =>
        'Cafe could not be deleted because the network request failed. Please try again.',
      ServiceErrorType.unavailable =>
        'Cafe admin service is unavailable. Please try again.',
      _ => 'Cafe could not be deleted. Please try again.',
    };
  }

  static String _sanitizedSoftDeleteCause(Object error) {
    if (error is PostgrestException) {
      final code = error.code?.trim();
      return 'postgrest:${code == null || code.isEmpty ? 'unknown' : code}';
    }
    return classifyServiceError(error).name;
  }

  Future<ServiceResult<Cafe>> updateCafeByAdmin(
    String cafeId,
    CafeAdminUpdateInput input,
  ) async {
    final payload = input.toRow();
    payload['google_uses_app_defaults'] = false;
    final validationCode = _validateCafePayload(payload);
    if (validationCode != null) {
      return ServiceResult.failure(
        errorCode: validationCode,
        errorType: ServiceErrorType.validation,
      );
    }

    try {
      final response = await ((_updateCafeLoader != null)
              ? _updateCafeLoader!(cafeId, payload)
              : () async {
                  final normalizedCafeId = cafeId.trim();

                  Map<String, dynamic>? existingRow = await _client
                      .from('cafes')
                      .select('id,google_place_id')
                      .eq('id', normalizedCafeId)
                      .maybeSingle()
                      .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

                  existingRow ??= await _client
                      .from('cafes')
                      .select('id,google_place_id')
                      .eq('google_place_id', normalizedCafeId)
                      .limit(1)
                      .maybeSingle()
                      .timeout(
                        NetworkTimeoutConfig.supabaseDataRequestTimeout,
                      );

                  final resolvedRowId = (existingRow?['id'] as String?)?.trim();
                  if (resolvedRowId == null || resolvedRowId.isEmpty) {
                    if (_looksLikeGooglePlaceId(normalizedCafeId)) {
                      final insertPayload = Map<String, dynamic>.from(payload)
                        ..['id'] = const Uuid().v4()
                        ..['google_place_id'] = normalizedCafeId
                        ..['google_uses_app_defaults'] = false
                        ..['owner_approval_status'] = 'approved'
                        ..['is_deleted'] = false;

                      insertPayload.putIfAbsent('neighborhood', () => '');

                      return _client
                          .from('cafes')
                          .insert(insertPayload)
                          .select('*')
                          .single();
                    }

                    throw const AppServiceException.notFound(
                      'Cafe row not found for update.',
                      errorCode: AppErrorCode.recordNotFound,
                    );
                  }

                  return _client
                      .from('cafes')
                      .update(payload)
                      .eq('id', resolvedRowId)
                      .select('*')
                      .single();
                }())
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      return ServiceResult.success(data: Cafe.fromSupabaseRow(response));
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeCommandService.updateCafeByAdmin failed for cafeId=$cafeId',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-command-update-$cafeId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeUpdateFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<Cafe>> updateCafe(
    String cafeId,
    CafeAdminUpdateInput input,
  ) {
    return updateCafeByAdmin(cafeId, input);
  }

  Future<ServiceResult<Cafe>> updateCafeByOwner(
    String cafeId,
    CafeAdminUpdateInput input,
  ) async {
    final payload = input.toRow()
      ..removeWhere(
        (key, _) => !CafeAdminUpdateInput.ownerEditableColumns.contains(key),
      );
    final validationCode = _validateCafePayload(payload);
    if (validationCode != null) {
      return ServiceResult.failure(
        errorCode: validationCode,
        errorType: ServiceErrorType.validation,
      );
    }

    try {
      final row = await _client
          .rpc(
            'owner_update_cafe',
            params: <String, dynamic>{
              'p_cafe_id': cafeId.trim(),
              'p_updates': payload,
            },
          )
          .single()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return ServiceResult.success(data: Cafe.fromSupabaseRow(row));
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeCommandService.updateCafeByOwner failed for cafeId=$cafeId',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-command-owner-update-$cafeId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeUpdateFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<Cafe>> restoreCafe({
    required String cafeId,
  }) async {
    final normalizedCafeId = cafeId.trim();
    final lockKey = _destructiveLockKey(normalizedCafeId, null);
    if (normalizedCafeId.isEmpty) {
      return ServiceResult.failure(
        message: 'Cafe id is required for restore.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }

    if (!_acquireDestructiveTargetLock(lockKey)) {
      return ServiceResult.failure(
        message: 'Restore already in progress for this cafe.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }

    try {
      Map<String, dynamic>? existingRow = await _client
          .from('cafes')
          .select('id,google_place_id,is_deleted,owner_approval_status')
          .eq('id', normalizedCafeId)
          .maybeSingle()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      if (existingRow == null && _looksLikeGooglePlaceId(normalizedCafeId)) {
        existingRow = await _client
            .from('cafes')
            .select('id,google_place_id,is_deleted,owner_approval_status')
            .eq('google_place_id', normalizedCafeId)
            .maybeSingle()
            .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      }

      final resolvedRowId = (existingRow?['id'] as String?)?.trim();
      if (resolvedRowId == null || resolvedRowId.isEmpty) {
        return ServiceResult.failure(
          message: 'Cafe row not found for restore.',
          errorCode: AppErrorCode.recordNotFound,
          errorType: ServiceErrorType.notFound,
        );
      }

      final response = await _client
          .from('cafes')
          .update(<String, dynamic>{
            'is_deleted': false,
            'deleted_at': null,
            'deleted_by': null,
            'owner_approval_status': 'approved',
            'google_uses_app_defaults': false,
          })
          .eq('id', resolvedRowId)
          .select('*')
          .single()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      return ServiceResult.success(data: Cafe.fromSupabaseRow(response));
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeCommandService.restoreCafe failed for cafeId=$normalizedCafeId',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-command-restore-$normalizedCafeId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeUpdateFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    } finally {
      _releaseDestructiveTargetLock(lockKey);
    }
  }

  Future<ServiceResult<Cafe>> addCafe(CafeAdminUpdateInput input) async {
    final payload = input.toRow();
    payload['id'] ??= const Uuid().v4();
    payload['google_uses_app_defaults'] = false;
    final validationCode = _validateCafePayload(payload);
    if (validationCode != null) {
      return ServiceResult.failure(
        errorCode: validationCode,
        errorType: ServiceErrorType.validation,
      );
    }

    payload['neighborhood'] ??= '';
    final googlePlaceId = (payload['google_place_id'] as String?)?.trim();

    try {
      if (_addCafeLoader == null &&
          googlePlaceId != null &&
          googlePlaceId.isNotEmpty) {
        final existing = await _client
            .from('cafes')
            .select('*')
            .eq('google_place_id', googlePlaceId)
            .maybeSingle()
            .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
        if (existing != null) {
          return ServiceResult.failure(
            message: 'Cafe already exists for this Google Place ID.',
            errorCode: AppErrorCode.dataConflict,
            errorType: ServiceErrorType.conflict,
          );
        }
      }

      final response = await ((_addCafeLoader != null)
              ? _addCafeLoader!(payload)
              : _client.from('cafes').insert(payload).select('*').single())
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      return ServiceResult.success(data: Cafe.fromSupabaseRow(response));
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeCommandService.addCafe failed',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-command-add',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeAddFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  /// Creates or updates a cafe row identified by its Google Place ID.
  ///
  /// This is the entry point for editing API-fetched cafes: if no local row
  /// exists for [placeId], one is inserted automatically (upsert). Existing
  /// rows are updated via the google_place_id unique index.
  Future<ServiceResult<Cafe>> upsertCafeByPlaceId(
    String placeId,
    CafeAdminUpdateInput input,
  ) async {
    final payload = input.toRow();
    payload['google_place_id'] = placeId;
    payload['google_uses_app_defaults'] = false;

    // Ensure the row has at minimum a name so it passes the NOT NULL constraint.
    payload.putIfAbsent('name', () => '');
    payload.putIfAbsent('neighborhood', () => '');

    try {
      final response = await _client
          .from('cafes')
          .upsert(
            payload,
            onConflict: 'google_place_id',
            ignoreDuplicates: false,
          )
          .select('*')
          .single()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      return ServiceResult.success(data: Cafe.fromSupabaseRow(response));
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeCommandService.upsertCafeByPlaceId failed for placeId=$placeId',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-command-upsert-$placeId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.cafeUpdateFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  AppErrorCode? _validateCafePayload(Map<String, dynamic> payload) {
    final name = payload['name'] as String?;
    final neighborhood = payload['neighborhood'] as String?;
    final address = payload['address'] as String?;
    final description = payload['description'] as String?;

    if (name == null || name.trim().isEmpty) {
      return AppErrorCode.cafeNameRequired;
    }
    if (validateRequiredText(name, 'Cafe name') != null) {
      return AppErrorCode.cafeNameInvalid;
    }
    if (neighborhood != null &&
        validateRequiredText(neighborhood, 'Neighborhood') != null) {
      return AppErrorCode.neighborhoodInvalid;
    }
    if (address != null && validateRequiredText(address, 'Address') != null) {
      return AppErrorCode.addressInvalid;
    }
    if (description != null &&
        description.trim().isNotEmpty &&
        validateRequiredText(description, 'Description') != null) {
      return AppErrorCode.descriptionInvalid;
    }

    final images = payload['images'];
    if (images is List) {
      final imageUrls = images.whereType<String>().toList(growable: false);
      if (hasUntrustedAdminImageHosts(imageUrls)) {
        return AppErrorCode.validationFailed;
      }
    }

    return null;
  }
}

@Deprecated('Use CafeQueryService and CafeCommandService instead.')
class CafesService {
  CafesService(SupabaseClient client)
      : query = CafeQueryService(client),
        command = CafeCommandService(client);

  final CafeQueryService query;
  final CafeCommandService command;

  Future<ServiceResult<List<Cafe>>> fetchDiscoverableCafes({
    String? district,
    int limit = 800,
    int offset = 0,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) =>
      query.fetchDiscoverableCafes(
        district: district,
        limit: limit,
        offset: offset,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );

  Future<ServiceResult<List<Cafe>>> fetchActiveFeaturedCafes({
    String? district,
    int limit = 40,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) =>
      query.fetchActiveFeaturedCafes(
        district: district,
        limit: limit,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );

  Future<ServiceResult<List<Cafe>>> fetchCafes() => query.fetchCafes();

  Future<ServiceResult<Cafe?>> fetchCafeById(String cafeId) =>
      query.fetchCafeById(cafeId);

  Future<ServiceResult<void>> updateGoogleRatingMetadata({
    required String cafeId,
    required String googlePlaceId,
    double? googleRating,
    int? googleReviewCount,
    String? externalLastSyncedAt,
    Duration? requestTimeout,
  }) =>
      query.updateGoogleRatingMetadata(
        cafeId: cafeId,
        googlePlaceId: googlePlaceId,
        googleRating: googleRating,
        googleReviewCount: googleReviewCount,
        externalLastSyncedAt: externalLastSyncedAt,
        requestTimeout: requestTimeout,
      );

  Future<ServiceResult<Cafe?>> fetchCafeDetails(String cafeId) =>
      query.fetchCafeDetails(cafeId);

  Future<ServiceResult<Cafe>> updateCafe(
    String cafeId,
    CafeAdminUpdateInput input,
  ) =>
      command.updateCafe(cafeId, input);

  Future<ServiceResult<Cafe>> updateCafeByAdmin(
    String cafeId,
    CafeAdminUpdateInput input,
  ) =>
      command.updateCafeByAdmin(cafeId, input);

  Future<ServiceResult<Cafe>> updateCafeByOwner(
    String cafeId,
    CafeAdminUpdateInput input,
  ) =>
      command.updateCafeByOwner(cafeId, input);

  Future<ServiceResult<Cafe>> restoreCafe({required String cafeId}) =>
      command.restoreCafe(cafeId: cafeId);

  Future<ServiceResult<Cafe>> addCafe(CafeAdminUpdateInput input) =>
      command.addCafe(input);
}

class CafeOwnerClaimsService {
  CafeOwnerClaimsService(this._client);

  final SupabaseClient _client;

  Future<ServiceResult<List<CafeOwnerClaim>>> fetchClaimsForUser(
    String userId,
  ) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return ServiceResult.failure(
        message: 'User id is required.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }

    try {
      final rows = await _client
          .from('cafe_owner_claims')
          .select('*')
          .eq('user_id', normalizedUserId)
          .order('created_at', ascending: false)
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return ServiceResult.success(
        data: rows
            .map((row) => CafeOwnerClaim.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ))
            .toList(growable: false),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeOwnerClaimsService.fetchClaimsForUser failed',
        error: error,
        stackTrace: stackTrace,
        key: 'owner-claims-user-$normalizedUserId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<List<CafeOwnerClaim>>> fetchPendingClaims() async {
    try {
      final rows = await _client
          .from('cafe_owner_claims')
          .select('*')
          .eq('status', CafeOwnerClaimStatus.pending.value)
          .order('created_at', ascending: true)
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return ServiceResult.success(
        data: rows
            .map((row) => CafeOwnerClaim.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ))
            .toList(growable: false),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeOwnerClaimsService.fetchPendingClaims failed',
        error: error,
        stackTrace: stackTrace,
        key: 'owner-claims-pending',
      );
      return ServiceResult.failure(
        message: error.toString(),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<CafeOwnerClaim>> createClaim({
    required String userId,
    required String cafeId,
    required String businessName,
    String? businessEmail,
    String? evidenceUrl,
    String? phone,
    String? note,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedCafeId = cafeId.trim();
    final normalizedBusinessName = sanitizeInput(businessName);
    if (normalizedUserId.isEmpty ||
        normalizedCafeId.isEmpty ||
        normalizedBusinessName.isEmpty) {
      return ServiceResult.failure(
        message: 'User, cafe, and business name are required.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }

    try {
      final existing = await _client
          .from('cafe_owner_claims')
          .select('*')
          .eq('user_id', normalizedUserId)
          .eq('cafe_id', normalizedCafeId)
          .eq('status', CafeOwnerClaimStatus.pending.value)
          .limit(1)
          .maybeSingle()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      if (existing != null) {
        return ServiceResult.failure(
          message: 'A pending ownership claim already exists for this cafe.',
          errorCode: AppErrorCode.validationFailed,
          errorType: ServiceErrorType.conflict,
        );
      }

      final row = await _client
          .from('cafe_owner_claims')
          .insert(<String, dynamic>{
            'id': const Uuid().v4(),
            'user_id': normalizedUserId,
            'cafe_id': normalizedCafeId,
            'business_name': normalizedBusinessName,
            'business_email': _nullableSanitized(businessEmail),
            'business_phone': _nullableSanitized(phone),
            'evidence_url': _nullableSanitized(evidenceUrl),
            'message': _nullableSanitized(note),
            'phone': _nullableSanitized(phone),
            'note': _nullableSanitized(note),
            'status': CafeOwnerClaimStatus.pending.value,
          })
          .select('*')
          .single()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return ServiceResult.success(
        data: CafeOwnerClaim.fromJson(Map<String, dynamic>.from(row)),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeOwnerClaimsService.createClaim failed',
        error: error,
        stackTrace: stackTrace,
        key: 'owner-claim-create-$normalizedCafeId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<CafeOwnerClaim>> approveClaim({
    required String claimId,
    required String reviewedBy,
  }) {
    return _reviewClaim(
      claimId: claimId,
      reviewedBy: reviewedBy,
      nextStatus: CafeOwnerClaimStatus.approved,
    );
  }

  Future<ServiceResult<CafeOwnerClaim>> rejectClaim({
    required String claimId,
    required String reviewedBy,
    String? reason,
  }) {
    return _reviewClaim(
      claimId: claimId,
      reviewedBy: reviewedBy,
      nextStatus: CafeOwnerClaimStatus.rejected,
      reason: reason,
    );
  }

  Future<ServiceResult<CafeOwnerClaim>> _reviewClaim({
    required String claimId,
    required String reviewedBy,
    required CafeOwnerClaimStatus nextStatus,
    String? reason,
  }) async {
    final normalizedClaimId = claimId.trim();
    final normalizedReviewer = reviewedBy.trim();
    if (normalizedClaimId.isEmpty || normalizedReviewer.isEmpty) {
      return ServiceResult.failure(
        message: 'Claim id and reviewer id are required.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }

    try {
      final reviewedRow = await _client
          .rpc(
            nextStatus == CafeOwnerClaimStatus.approved
                ? 'admin_approve_cafe_owner_claim'
                : 'admin_reject_cafe_owner_claim',
            params: <String, dynamic>{
              'p_claim_id': normalizedClaimId,
              if (nextStatus == CafeOwnerClaimStatus.rejected)
                'p_reason': _nullableSanitized(reason),
            },
          )
          .single()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      return ServiceResult.success(
        data: CafeOwnerClaim.fromJson(Map<String, dynamic>.from(reviewedRow)),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeOwnerClaimsService._reviewClaim failed',
        error: error,
        stackTrace: stackTrace,
        key: 'owner-claim-review-$normalizedClaimId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }
}

class CafeOwnerInviteService {
  CafeOwnerInviteService(this._client);

  final SupabaseClient _client;

  Future<ServiceResult<CafeOwnerInviteResult>> inviteAndAssign({
    required String cafeId,
    required String email,
    String? firstName,
    String? lastName,
    String? fullName,
  }) async {
    final normalizedCafeId = cafeId.trim();
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedCafeId.isEmpty || normalizedEmail.isEmpty) {
      return ServiceResult.failure(
        message: 'Cafe id and owner email are required.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }

    try {
      final response = await _client.functions
          .invoke(
            'invite-cafe-owner',
            body: <String, dynamic>{
              'cafe_id': normalizedCafeId,
              'email': normalizedEmail,
              if (firstName?.trim().isNotEmpty == true)
                'first_name': sanitizeInput(firstName!),
              if (lastName?.trim().isNotEmpty == true)
                'last_name': sanitizeInput(lastName!),
              if (fullName?.trim().isNotEmpty == true)
                'full_name': sanitizeInput(fullName!),
            },
          )
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      final payload = response.data;
      if (payload is! Map) {
        return ServiceResult.failure(
          message: 'Unexpected cafe owner invite response.',
          errorCode: AppErrorCode.parseFailed,
          errorType: ServiceErrorType.parse,
        );
      }
      final ownerPayload = payload['owner'];
      final cafePayload = payload['cafe'];
      if (ownerPayload is! Map || cafePayload is! Map) {
        return ServiceResult.failure(
          message: 'Cafe owner invite response is missing owner or cafe data.',
          errorCode: AppErrorCode.parseFailed,
          errorType: ServiceErrorType.parse,
        );
      }

      return ServiceResult.success(
        data: CafeOwnerInviteResult(
          owner: UserProfile.fromJson(
            Map<String, dynamic>.from(ownerPayload),
          ),
          cafe: Cafe.fromSupabaseRow(
            Map<String, dynamic>.from(cafePayload),
          ),
          invited: payload['invited'] == true,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'CafeOwnerInviteService.inviteAndAssign failed for cafeId=$cafeId',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-owner-invite-$cafeId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.validationFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }
}

String? _nullableSanitized(String? value) {
  final normalized = sanitizeInput(value ?? '');
  return normalized.isEmpty ? null : normalized;
}

const int kMaxAvatarUploadBytes = 5 * 1024 * 1024;
const Set<String> kAllowedAvatarExtensions = <String>{
  'png',
  'jpg',
  'jpeg',
  'webp',
};

typedef AvatarBinaryUploader = Future<void> Function({
  required String path,
  required Uint8List bytes,
  required FileOptions fileOptions,
});

class ProfilesService {
  ProfilesService(
    this._client, {
    AvatarBinaryUploader? avatarBinaryUploader,
  }) : _avatarBinaryUploader = avatarBinaryUploader;

  final SupabaseClient _client;
  final AvatarBinaryUploader? _avatarBinaryUploader;
  static const avatarBucket = 'avatars';

  static const _columnsFull =
      'id,username,first_name,last_name,full_name,email,role,created_at,avatar_url';
  static const _columnsSafe =
      'id,username,first_name,last_name,full_name,email,role,created_at';

  Future<ProfileRole> getProfileRoleByEmail(String email) async {
    final normalizedEmail = normalizeEmail(email);
    try {
      final data = await _client
          .from('profiles')
          .select('role')
          .ilike('email', normalizedEmail)
          .single()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return ProfileRole.fromString(data['role'] as String?);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'ProfilesService.getProfileRoleByEmail falling back to user role',
        key: 'profile-role-fallback',
        throttle: const Duration(seconds: 2),
      );
      AppLogger.debug(
        'ProfilesService.getProfileRoleByEmail failed type=${classifyServiceError(error)}',
        key: 'profile-role-debug',
      );
      AppLogger.error(
        'ProfilesService.getProfileRoleByEmail failed',
        error: error,
        stackTrace: stackTrace,
        key: 'profile-role',
      );
      return ProfileRole.user;
    }
  }

  Future<void> createProfileIfMissing({
    required String id,
    required String username,
    required String firstName,
    required String lastName,
    required String fullName,
    required String email,
  }) async {
    final normalizedEmail = normalizeEmail(email);

    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('email', normalizedEmail)
          .maybeSingle()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      if (existing != null) {
        return;
      }

      await _client.from('profiles').insert({
        'id': id,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'full_name': fullName,
        'email': normalizedEmail,
        'role': 'user',
      }).timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
    } catch (error, stackTrace) {
      if (error.toString().contains('duplicate')) {
        return;
      }
      AppLogger.error(
        'ProfilesService.createProfileIfMissing failed for userId=$id',
        error: error,
        stackTrace: stackTrace,
        key: 'profile-create-$id',
      );
      rethrow;
    }
  }

  Future<ServiceResult<List<UserProfile>>> fetchProfiles() async {
    try {
      List<dynamic> data;
      try {
        data = await _client
            .from('profiles')
            .select(_columnsFull)
            .order('created_at', ascending: false)
            .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      } catch (error) {
        if (error.toString().contains('avatar_url')) {
          data = await _client
              .from('profiles')
              .select(_columnsSafe)
              .order('created_at', ascending: false)
              .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
        } else {
          rethrow;
        }
      }

      final profiles = await Future.wait(
        data.map(
          (row) => _resolveProfileAvatar(
            UserProfile.fromJson(row as Map<String, dynamic>),
          ),
        ),
      );

      return ServiceResult.success(data: profiles);
    } catch (error, stackTrace) {
      AppLogger.error(
        'ProfilesService.fetchProfiles failed',
        error: error,
        stackTrace: stackTrace,
        key: 'profile-list',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.profileListFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<void>> updateProfileRole(
    String userId,
    ProfileRole newRole,
  ) async {
    final roleStr = newRole.value;

    try {
      await _client
          .from('profiles')
          .update({'role': roleStr})
          .eq('id', userId)
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      final verify = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

      if (verify['role'] != roleStr) {
        return ServiceResult<void>.failure(
          errorCode: AppErrorCode.roleChangeFailed,
          errorType: ServiceErrorType.auth,
        );
      }

      return ServiceResult<void>.success();
    } catch (error, stackTrace) {
      AppLogger.error(
        'ProfilesService.updateProfileRole failed for userId=$userId',
        error: error,
        stackTrace: stackTrace,
        key: 'profile-role-update-$userId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.roleChangeFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<void>> updateProfile(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    final username = fields['username'] as String?;
    if (username != null &&
        (username.length < kUsernameMinLength ||
            username.length > kUsernameMaxLength ||
            !isValidUsername(username))) {
      return ServiceResult<void>.failure(
        errorCode: AppErrorCode.usernameInvalid,
        errorType: ServiceErrorType.validation,
      );
    }

    try {
      await _client
          .from('profiles')
          .update(fields)
          .eq('id', userId)
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return ServiceResult<void>.success();
    } catch (error, stackTrace) {
      final message = error.toString();
      AppLogger.error(
        'ProfilesService.updateProfile failed for userId=$userId',
        error: error,
        stackTrace: stackTrace,
        key: 'profile-update-$userId',
      );
      if (message.contains('duplicate') && message.contains('username')) {
        return ServiceResult.failure(
          message: message,
          errorCode: AppErrorCode.usernameTaken,
          error: error,
          errorType: ServiceErrorType.conflict,
        );
      }
      return ServiceResult.failure(
        message: message,
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.profileUpdateFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<AvatarUploadResult>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final sanitizedExtension = _normalizeAvatarExtension(fileExtension);
    final validationFailure = _validateAvatarUploadInput(
      userId: userId,
      bytes: bytes,
      normalizedExtension: sanitizedExtension,
    );
    if (validationFailure != null) {
      return validationFailure;
    }
    final path =
        'profiles/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$sanitizedExtension';
    final fileOptions = FileOptions(
      upsert: true,
      contentType: _avatarContentTypeForExtension(sanitizedExtension),
    );

    try {
      final uploader = _avatarBinaryUploader;
      if (uploader != null) {
        await uploader(path: path, bytes: bytes, fileOptions: fileOptions)
            .timeout(NetworkTimeoutConfig.uploadRequestTimeout);
      } else {
        await _client.storage
            .from(avatarBucket)
            .uploadBinary(path, bytes, fileOptions: fileOptions)
            .timeout(NetworkTimeoutConfig.uploadRequestTimeout);
      }

      final publicUrl = _client.storage.from(avatarBucket).getPublicUrl(path);
      return ServiceResult.success(
        data: AvatarUploadResult(publicUrl: publicUrl, path: path),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'ProfilesService.uploadAvatar failed for userId=$userId',
        error: error,
        stackTrace: stackTrace,
        key: 'avatar-upload-$userId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.avatarUploadFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<void> deleteAvatarByPublicUrl(String? publicUrl) async {
    final objectPath = extractAvatarObjectPath(publicUrl);
    if (objectPath == null) {
      return;
    }

    try {
      await _client.storage.from(avatarBucket).remove([objectPath]).timeout(
          NetworkTimeoutConfig.supabaseDataRequestTimeout);
    } catch (error, stackTrace) {
      AppLogger.error(
        'ProfilesService.deleteAvatarByPublicUrl failed',
        error: error,
        stackTrace: stackTrace,
        key: 'avatar-delete-$objectPath',
      );
    }
  }

  String? extractAvatarObjectPath(String? publicUrl) {
    final trimmed = publicUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return null;
    }

    final segments = uri.pathSegments;
    final publicIndex = segments.indexOf('public');
    final signedIndex = segments.indexOf('sign');
    final anchorIndex = publicIndex >= 0 ? publicIndex : signedIndex;
    if (anchorIndex == -1 || anchorIndex + 1 >= segments.length) {
      return null;
    }

    final bucket = segments[anchorIndex + 1];
    if (bucket != avatarBucket || anchorIndex + 2 >= segments.length) {
      return null;
    }

    return segments.sublist(anchorIndex + 2).join('/');
  }

  Future<String?> resolveAvatarUrl(String? storedValue) async {
    final trimmed = storedValue?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final objectPath = extractAvatarObjectPath(trimmed);
    if (objectPath == null) {
      return trimmed;
    }

    try {
      return await _client.storage
          .from(avatarBucket)
          .createSignedUrl(objectPath, 60 * 60 * 24 * 7)
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
    } catch (_) {
      try {
        return _client.storage.from(avatarBucket).getPublicUrl(objectPath);
      } catch (error, stackTrace) {
        AppLogger.error(
          'ProfilesService.resolveAvatarUrl failed for $objectPath',
          error: error,
          stackTrace: stackTrace,
          key: 'avatar-resolve-$objectPath',
        );
        return trimmed;
      }
    }
  }

  Future<String?> findEmailByUsername(String username) async {
    final result = await findEmailByUsernameResult(username);
    return result.data;
  }

  Future<ServiceResult<String?>> findEmailByUsernameResult(
    String username,
  ) async {
    try {
      final data = await _client
          .from('profiles')
          .select('email')
          .eq('username', normalizeUsername(username))
          .maybeSingle()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return ServiceResult.success(data: data?['email'] as String?);
    } catch (error, stackTrace) {
      AppLogger.error(
        'ProfilesService.findEmailByUsername failed',
        error: error,
        stackTrace: stackTrace,
        key: 'find-email-${normalizeUsername(username)}',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.profileLoadFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<UserProfile?>> fetchProfileById(String userId) async {
    try {
      Map<String, dynamic> data;
      try {
        data = await _client
            .from('profiles')
            .select(_columnsFull)
            .eq('id', userId)
            .single()
            .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      } catch (error) {
        if (error.toString().contains('avatar_url') ||
            classifyServiceError(error).isTransient ||
            classifyServiceError(error) == ServiceErrorType.parse ||
            classifyServiceError(error) == ServiceErrorType.unknown) {
          AppLogger.debug(
            'ProfilesService.fetchProfileById retrying with safe columns type=${classifyServiceError(error)}',
            key: 'profile-load-safe-retry',
          );
          data = await _client
              .from('profiles')
              .select(_columnsSafe)
              .eq('id', userId)
              .single()
              .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
        } else {
          rethrow;
        }
      }
      final profile = await _resolveProfileAvatar(UserProfile.fromJson(data));
      return ServiceResult.success(data: profile);
    } catch (error, stackTrace) {
      AppLogger.error(
        'ProfilesService.fetchProfileById failed for userId=$userId',
        error: error,
        stackTrace: stackTrace,
        key: 'profile-load-$userId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForSupabaseError(
          error,
          fallback: AppErrorCode.profileLoadFailed,
        ),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<UserProfile> _resolveProfileAvatar(UserProfile profile) async {
    final resolvedAvatarUrl = await resolveAvatarUrl(profile.avatarUrl);
    if (resolvedAvatarUrl == profile.avatarUrl) {
      return profile;
    }
    return profile.copyWith(avatarUrl: resolvedAvatarUrl);
  }
}

Future<T> _withDataTimeout<T>(
  Future<T> request, {
  Duration timeout = NetworkTimeoutConfig.supabaseDataRequestTimeout,
}) {
  return request.timeout(timeout);
}

bool _shouldRetrySupabaseError(Object error) {
  return classifyServiceError(error).isTransient;
}

AppErrorCode _errorCodeForSupabaseError(
  Object error, {
  required AppErrorCode fallback,
}) {
  switch (classifyServiceError(error)) {
    case ServiceErrorType.auth:
      return AppErrorCode.permissionDenied;
    case ServiceErrorType.cancelled:
      return fallback;
    case ServiceErrorType.timeout:
      return AppErrorCode.requestTimedOut;
    case ServiceErrorType.network:
      return AppErrorCode.networkError;
    case ServiceErrorType.rateLimit:
      return AppErrorCode.serviceUnavailable;
    case ServiceErrorType.conflict:
      return AppErrorCode.dataConflict;
    case ServiceErrorType.validation:
      return AppErrorCode.validationFailed;
    case ServiceErrorType.notFound:
      return AppErrorCode.recordNotFound;
    case ServiceErrorType.parse:
      return AppErrorCode.parseFailed;
    case ServiceErrorType.unavailable:
      return AppErrorCode.serviceUnavailable;
    case ServiceErrorType.unknown:
      return fallback;
  }
}

String _normalizeAvatarExtension(String extension) {
  return extension.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), '');
}

ServiceResult<AvatarUploadResult>? _validateAvatarUploadInput({
  required String userId,
  required Uint8List bytes,
  required String normalizedExtension,
}) {
  if (userId.trim().isEmpty) {
    return ServiceResult<AvatarUploadResult>.failure(
      message: 'Unable to upload avatar right now. Please sign in again.',
      errorCode: AppErrorCode.validationFailed,
      errorType: ServiceErrorType.validation,
    );
  }

  if (bytes.isEmpty) {
    return ServiceResult<AvatarUploadResult>.failure(
      message: 'Avatar image is empty.',
      errorCode: AppErrorCode.avatarEmpty,
      errorType: ServiceErrorType.validation,
    );
  }

  if (bytes.lengthInBytes > kMaxAvatarUploadBytes) {
    final maxSizeMb =
        (kMaxAvatarUploadBytes / (1024 * 1024)).toStringAsFixed(0);
    return ServiceResult<AvatarUploadResult>.failure(
      message:
          'Avatar image is too large. Maximum allowed size is $maxSizeMb MB.',
      errorCode: AppErrorCode.validationFailed,
      errorType: ServiceErrorType.validation,
    );
  }

  if (!kAllowedAvatarExtensions.contains(normalizedExtension)) {
    return ServiceResult<AvatarUploadResult>.failure(
      message:
          'Unsupported avatar file type. Allowed types: png, jpg, jpeg, webp.',
      errorCode: AppErrorCode.validationFailed,
      errorType: ServiceErrorType.validation,
    );
  }

  if (!_matchesAvatarSignature(bytes, normalizedExtension)) {
    return ServiceResult<AvatarUploadResult>.failure(
      message: 'Avatar image content is invalid for the selected file type.',
      errorCode: AppErrorCode.validationFailed,
      errorType: ServiceErrorType.validation,
    );
  }

  return null;
}

bool _matchesAvatarSignature(Uint8List bytes, String normalizedExtension) {
  switch (normalizedExtension) {
    case 'png':
      return bytes.lengthInBytes >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0D &&
          bytes[5] == 0x0A &&
          bytes[6] == 0x1A &&
          bytes[7] == 0x0A;
    case 'jpg':
    case 'jpeg':
      return bytes.lengthInBytes >= 3 &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xD8 &&
          bytes[2] == 0xFF;
    case 'webp':
      return bytes.lengthInBytes >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50;
    default:
      return false;
  }
}

String _avatarContentTypeForExtension(String extension) {
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}
