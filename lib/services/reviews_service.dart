import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/error_codes.dart';
import '../constants/network_config.dart';
import '../models/review.dart';
import '../models/service_result.dart';
import '../utils/app_logger.dart';
import '../utils/input_validation.dart';
import '../utils/review_moderation.dart';
import '../utils/service_error.dart';

/// Supabase service for cafe review operations (fetch, submit, update, delete).
class ReviewsService {
  ReviewsService(
    this._client, {
    Duration requestTimeout = NetworkTimeoutConfig.reviewsRequestTimeout,
    Future<List<Map<String, dynamic>>> Function(
      String cafeId, {
      required int page,
      required int pageSize,
    })? reviewRowsLoader,
  })  : _requestTimeout = requestTimeout,
        _reviewRowsLoader = reviewRowsLoader;

  static const _reviewColumns =
      'id, cafe_id, user_id, rating, wifi_quality, noise_level, '
      'study_friendliness, seating_comfort, socket_availability, '
      'smoking_policy, content, created_at';
  static const _reviewColumnsWithProfile =
      '$_reviewColumns, profiles!cafe_reviews_user_id_fkey(username, avatar_url)';
  static const int _maxReviewLength = 2000;
  static const Duration _submissionCooldown = Duration(seconds: 30);

  final SupabaseClient _client;
  final Duration _requestTimeout;
  final Future<List<Map<String, dynamic>>> Function(
    String cafeId, {
    required int page,
    required int pageSize,
  })? _reviewRowsLoader;
  final Map<String, DateTime> _lastSubmissionTimeByUser = {};
  final Map<String, Future<ServiceResult<ReviewPage>>> _inflightReviewPages =
      {};

  Future<ServiceResult<ReviewPage>> fetchReviews(
    String cafeId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    final requestKey = '$cafeId|$page|$pageSize';
    final inflight = _inflightReviewPages[requestKey];
    if (inflight != null) {
      return inflight;
    }

    final future = _fetchReviewsInternal(
      cafeId,
      page: page,
      pageSize: pageSize,
    );
    _inflightReviewPages[requestKey] = future;
    return future.whenComplete(() {
      _inflightReviewPages.remove(requestKey);
    });
  }

  Future<ServiceResult<ReviewPage>> _fetchReviewsInternal(
    String cafeId, {
    required int page,
    required int pageSize,
  }) async {
    try {
      final rows = await _fetchReviewRows(
        cafeId,
        page: page,
        pageSize: pageSize,
      );
      final reviews =
          rows.map(CafeReview.fromSupabaseRow).toList(growable: false);

      return ServiceResult.success(
        data: ReviewPage(
          reviews: reviews,
          hasMore: reviews.length == pageSize,
        ),
      );
    } catch (error) {
      AppLogger.error(
        'ReviewsService.fetchReviews failed for cafeId=$cafeId',
        error: error,
        key: 'reviews-fetch-failed-$cafeId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForFetchError(error),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<ReviewMutationResult>> submitReview({
    required String cafeId,
    String? userId,
    required int rating,
    int? wifiQuality,
    int? noiseLevel,
    int? studyFriendliness,
    int? seatingComfort,
    String? socketAvailability,
    String? smokingPolicy,
    String? content,
    bool bypassSubmissionCooldown = false,
  }) async {
    if (rating < 1 || rating > 5) {
      return ServiceResult.failure(
        errorCode: AppErrorCode.ratingOutOfRange,
        errorType: ServiceErrorType.validation,
      );
    }

    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      return ServiceResult.failure(
        errorCode: AppErrorCode.reviewAuthRequired,
        errorType: ServiceErrorType.auth,
      );
    }

    final effectiveUserId = authUser.id;
    if (userId != null &&
        userId.trim().isNotEmpty &&
        userId.trim() != effectiveUserId) {
      AppLogger.warn(
        'ReviewsService.submitReview ignored mismatched userId=$userId for authUser=$effectiveUserId',
        key: 'reviews-submit-user-mismatch-$cafeId',
      );
    }

    final normalizedContent = _normalizeContent(content);
    if (normalizedContent != null &&
        normalizedContent.length > _maxReviewLength) {
      return ServiceResult.failure(
        errorCode: AppErrorCode.reviewTextTooLong,
        errorType: ServiceErrorType.validation,
      );
    }

    final moderation = moderateReviewText(normalizedContent);
    if (moderation.isBlocked) {
      return ServiceResult.failure(
        errorCode: AppErrorCode.reviewProfanityBlocked,
        errorType: ServiceErrorType.validation,
      );
    }

    final insertPayload = <String, dynamic>{
      'cafe_id': cafeId,
      'user_id': effectiveUserId,
      'rating': rating,
      if (wifiQuality != null) 'wifi_quality': wifiQuality,
      if (noiseLevel != null) 'noise_level': noiseLevel,
      if (studyFriendliness != null) 'study_friendliness': studyFriendliness,
      if (seatingComfort != null) 'seating_comfort': seatingComfort,
      if (_normalizeOptionalText(socketAvailability) != null)
        'socket_availability': _normalizeOptionalText(socketAvailability),
      if (_normalizeSmokingPolicy(smokingPolicy) != null)
        'smoking_policy': _normalizeSmokingPolicy(smokingPolicy),
      'content': _normalizeContent(moderation.sanitizedText),
    };
    final updatePayload = <String, dynamic>{
      'rating': rating,
      if (wifiQuality != null) 'wifi_quality': wifiQuality,
      if (noiseLevel != null) 'noise_level': noiseLevel,
      if (studyFriendliness != null) 'study_friendliness': studyFriendliness,
      if (seatingComfort != null) 'seating_comfort': seatingComfort,
      if (_normalizeOptionalText(socketAvailability) != null)
        'socket_availability': _normalizeOptionalText(socketAvailability),
      if (_normalizeSmokingPolicy(smokingPolicy) != null)
        'smoking_policy': _normalizeSmokingPolicy(smokingPolicy),
      'content': _normalizeContent(moderation.sanitizedText),
    };

    try {
      final existingReview = await _findExistingReview(cafeId, effectiveUserId);
      final existingContent = _normalizeReviewTextForComparison(
        existingReview?.content,
      );
      final nextContent =
          _normalizeReviewTextForComparison(moderation.sanitizedText);
      if (existingContent != null &&
          nextContent != null &&
          existingContent == nextContent) {
        return ServiceResult.failure(
          errorCode: AppErrorCode.reviewDuplicateText,
          errorType: ServiceErrorType.conflict,
        );
      }

      final now = DateTime.now().toUtc();
      final lastSubmissionAt = _lastSubmissionTimeByUser[effectiveUserId];
      if (!bypassSubmissionCooldown &&
          lastSubmissionAt != null &&
          now.difference(lastSubmissionAt) < _submissionCooldown) {
        return ServiceResult.failure(
          errorCode: AppErrorCode.reviewSubmissionRateLimited,
          errorType: ServiceErrorType.validation,
        );
      }

      final existingReviewId = existingReview?.id;
      final didUpdateExisting = existingReviewId != null;

      final completedAt = DateTime.now().toUtc();
      final response = didUpdateExisting
          ? await _updateReview(existingReviewId, updatePayload)
          : await _insertReview(insertPayload);

      final review = CafeReview.fromSupabaseRow(response);
      if (!bypassSubmissionCooldown) {
        _lastSubmissionTimeByUser[effectiveUserId] = completedAt;
      }

      return ServiceResult.success(
        data: ReviewMutationResult(
          review: review,
          didUpdateExisting: didUpdateExisting,
        ),
      );
    } catch (error) {
      if (_isUniqueReviewConflict(error)) {
        AppLogger.warn(
          'ReviewsService.submitReview hit unique conflict for cafeId=$cafeId, retrying as update',
          key: 'reviews-submit-conflict-$cafeId',
        );

        try {
          final existingReviewAfterConflict = await _findExistingReview(
            cafeId,
            effectiveUserId,
          );
          if (existingReviewAfterConflict != null) {
            final response = await _updateReview(
              existingReviewAfterConflict.id,
              updatePayload,
            );
            final review = CafeReview.fromSupabaseRow(response);
            if (!bypassSubmissionCooldown) {
              _lastSubmissionTimeByUser[effectiveUserId] =
                  DateTime.now().toUtc();
            }
            return ServiceResult.success(
              data: ReviewMutationResult(
                review: review,
                didUpdateExisting: true,
              ),
            );
          }
        } catch (retryError) {
          AppLogger.error(
            'ReviewsService.submitReview retry update failed for cafeId=$cafeId',
            error: retryError,
            key: 'reviews-submit-conflict-retry-$cafeId',
          );
        }
      }

      AppLogger.error(
        'ReviewsService.submitReview failed for cafeId=$cafeId',
        error: error,
        key: 'reviews-submit-failed-$cafeId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForMutationError(error),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<ServiceResult<CafeReview>> addReview({
    required String cafeId,
    required String userId,
    required int rating,
    int? wifiQuality,
    int? noiseLevel,
    int? studyFriendliness,
    int? seatingComfort,
    String? socketAvailability,
    String? smokingPolicy,
    String? content,
  }) async {
    final result = await submitReview(
      cafeId: cafeId,
      userId: userId,
      rating: rating,
      wifiQuality: wifiQuality,
      noiseLevel: noiseLevel,
      studyFriendliness: studyFriendliness,
      seatingComfort: seatingComfort,
      socketAvailability: socketAvailability,
      smokingPolicy: smokingPolicy,
      content: content,
    );

    if (!result.ok || result.data == null) {
      return ServiceResult.failure(
        message: result.message,
        error: result.error,
        errorCode: result.errorCode,
        errorType: result.errorType,
      );
    }

    return ServiceResult.success(
      data: result.data!.review,
      message: result.data!.didUpdateExisting ? 'updated' : 'created',
    );
  }

  Future<ServiceResult<void>> deleteReview(
    String reviewId, {
    required String userId,
    bool isAdmin = false,
  }) async {
    if (userId.trim().isEmpty) {
      return ServiceResult.failure(
        errorCode: AppErrorCode.reviewAuthRequired,
        errorType: ServiceErrorType.auth,
      );
    }

    final authorization = await _authorizeReviewMutation(
      reviewId: reviewId,
      userId: userId,
      isAdmin: isAdmin,
    );
    if (!authorization.ok) {
      return authorization;
    }

    try {
      await _withReviewTimeout(
        _client.from('cafe_reviews').delete().eq('id', reviewId),
      );
      return ServiceResult.success();
    } catch (error) {
      AppLogger.error(
        'ReviewsService.deleteReview failed for reviewId=$reviewId',
        error: error,
        key: 'reviews-delete-failed-$reviewId',
      );
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForDeleteError(error),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReviewRows(
    String cafeId, {
    required int page,
    required int pageSize,
  }) async {
    final overrideLoader = _reviewRowsLoader;
    if (overrideLoader != null) {
      return overrideLoader(cafeId, page: page, pageSize: pageSize);
    }
    final from = page * pageSize;
    final to = from + pageSize - 1;
    try {
      final response = await _client
          .from('cafe_reviews')
          .select(_reviewColumnsWithProfile)
          .eq('cafe_id', cafeId)
          .range(from, to)
          .order('created_at', ascending: false)
          .timeout(NetworkTimeoutConfig.reviewsRequestTimeout);

      return _castRows(response);
    } catch (error) {
      if (!_shouldFallbackWithoutProfiles(error)) {
        rethrow;
      }

      AppLogger.warn(
        'ReviewsService.fetchReviews falling back to base review rows for cafeId=$cafeId because profile enrichment failed',
        key: 'reviews-fetch-fallback-$cafeId',
      );

      final response = await _client
          .from('cafe_reviews')
          .select(_reviewColumns)
          .eq('cafe_id', cafeId)
          .range(from, to)
          .order('created_at', ascending: false)
          .timeout(NetworkTimeoutConfig.reviewsRequestTimeout);

      return _castRows(response);
    }
  }

  Future<Map<String, dynamic>> _insertReview(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client
        .from('cafe_reviews')
        .insert(payload)
        .select(_reviewColumns)
        .single()
        .timeout(NetworkTimeoutConfig.reviewsRequestTimeout);

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> _updateReview(
    String reviewId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client
        .from('cafe_reviews')
        .update(payload)
        .eq('id', reviewId)
        .select(_reviewColumns)
        .single()
        .timeout(NetworkTimeoutConfig.reviewsRequestTimeout);

    return Map<String, dynamic>.from(response);
  }

  Future<({String id, String userId, String? content})?> _findExistingReview(
    String cafeId,
    String userId,
  ) async {
    final response = await _client
        .from('cafe_reviews')
        .select('id, user_id, content')
        .eq('cafe_id', cafeId)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .timeout(NetworkTimeoutConfig.reviewsRequestTimeout);

    final rows = _castRows(response);
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final reviewId = row['id'] as String?;
    final reviewUserId = row['user_id'] as String?;
    if (reviewId == null || reviewUserId == null) {
      return null;
    }

    return (
      id: reviewId,
      userId: reviewUserId,
      content: row['content'] as String?,
    );
  }

  Future<ServiceResult<void>> _authorizeReviewMutation({
    required String reviewId,
    required String userId,
    required bool isAdmin,
  }) async {
    try {
      final response = await _client
          .from('cafe_reviews')
          .select('user_id')
          .eq('id', reviewId)
          .maybeSingle()
          .timeout(NetworkTimeoutConfig.reviewsRequestTimeout);

      if (response == null) {
        return ServiceResult.failure(
          errorCode: AppErrorCode.recordNotFound,
          errorType: ServiceErrorType.notFound,
        );
      }

      final ownerId = response['user_id'] as String?;
      if (!isAdmin && ownerId != userId) {
        return ServiceResult.failure(
          errorCode: AppErrorCode.notReviewOwner,
          errorType: ServiceErrorType.auth,
        );
      }

      return ServiceResult.success();
    } catch (error) {
      return ServiceResult.failure(
        message: error.toString(),
        errorCode: _errorCodeForDeleteError(error),
        error: error,
        errorType: classifyServiceError(error),
      );
    }
  }

  List<Map<String, dynamic>> _castRows(dynamic response) {
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  bool _shouldFallbackWithoutProfiles(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('profiles') ||
        message.contains('cafe_reviews_user_id_fkey') ||
        message.contains('relationship') ||
        message.contains('row-level security') ||
        message.contains('permission denied');
  }

  bool _isUniqueReviewConflict(Object error) {
    if (error is PostgrestException && error.code == '23505') {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('duplicate') ||
        message.contains('unique') ||
        message.contains('23505');
  }

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _normalizeSmokingPolicy(String? value) {
    final normalized = _normalizeOptionalText(value);
    if (normalized == null) {
      return null;
    }
    if (normalized == 'mixed') {
      return 'outdoor_only';
    }
    return normalized;
  }

  String? _normalizeContent(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return sanitizeInput(trimmed);
  }

  String? _normalizeReviewTextForComparison(String? value) {
    final normalized = _normalizeContent(value);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  AppErrorCode _errorCodeForFetchError(Object error) {
    switch (classifyServiceError(error)) {
      case ServiceErrorType.cancelled:
        return AppErrorCode.reviewLoadFailed;
      case ServiceErrorType.network:
        return AppErrorCode.networkError;
      case ServiceErrorType.rateLimit:
        return AppErrorCode.reviewLoadFailed;
      case ServiceErrorType.timeout:
        return AppErrorCode.requestTimedOut;
      case ServiceErrorType.auth:
      case ServiceErrorType.validation:
      case ServiceErrorType.conflict:
      case ServiceErrorType.notFound:
      case ServiceErrorType.parse:
      case ServiceErrorType.unavailable:
      case ServiceErrorType.unknown:
        break;
    }

    if (error is PostgrestException) {
      if (error.code == '42501' ||
          error.message.toLowerCase().contains('row-level security')) {
        return AppErrorCode.permissionDenied;
      }
    }

    return AppErrorCode.reviewLoadFailed;
  }

  AppErrorCode _errorCodeForMutationError(Object error) {
    switch (classifyServiceError(error)) {
      case ServiceErrorType.cancelled:
        return AppErrorCode.reviewSubmitFailed;
      case ServiceErrorType.network:
        return AppErrorCode.networkError;
      case ServiceErrorType.rateLimit:
        return AppErrorCode.reviewSubmissionRateLimited;
      case ServiceErrorType.timeout:
        return AppErrorCode.requestTimedOut;
      case ServiceErrorType.auth:
      case ServiceErrorType.validation:
      case ServiceErrorType.conflict:
      case ServiceErrorType.notFound:
      case ServiceErrorType.parse:
      case ServiceErrorType.unavailable:
      case ServiceErrorType.unknown:
        break;
    }

    if (error is PostgrestException) {
      final message = error.message.toLowerCase();

      if (error.code == '42501' || message.contains('row-level security')) {
        return AppErrorCode.permissionDenied;
      }
      if (error.code == '23503' || message.contains('foreign key')) {
        return AppErrorCode.reviewProfileMissing;
      }
      if (error.code == '23505' || message.contains('duplicate')) {
        return AppErrorCode.reviewDuplicateText;
      }
      if (error.code == '23514' || message.contains('check constraint')) {
        if (message.contains('rating')) {
          return AppErrorCode.ratingOutOfRange;
        }
        return AppErrorCode.validationFailed;
      }
      if (error.code == '23502' || message.contains('null value')) {
        return AppErrorCode.reviewFieldMissing;
      }
    }

    return AppErrorCode.reviewSubmitFailed;
  }

  AppErrorCode _errorCodeForDeleteError(Object error) {
    switch (classifyServiceError(error)) {
      case ServiceErrorType.cancelled:
        return AppErrorCode.reviewDeleteFailed;
      case ServiceErrorType.network:
        return AppErrorCode.networkError;
      case ServiceErrorType.rateLimit:
        return AppErrorCode.reviewDeleteFailed;
      case ServiceErrorType.timeout:
        return AppErrorCode.requestTimedOut;
      case ServiceErrorType.auth:
      case ServiceErrorType.validation:
      case ServiceErrorType.conflict:
      case ServiceErrorType.notFound:
      case ServiceErrorType.parse:
      case ServiceErrorType.unavailable:
      case ServiceErrorType.unknown:
        break;
    }

    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (error.code == '42501' || message.contains('row-level security')) {
        return AppErrorCode.permissionDenied;
      }
    }

    return AppErrorCode.reviewDeleteFailed;
  }

  Future<T> _withReviewTimeout<T>(Future<T> request) {
    return request.timeout(_requestTimeout);
  }
}
