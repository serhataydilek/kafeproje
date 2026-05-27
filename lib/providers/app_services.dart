part of 'app_core_providers.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  if (kReleaseMode) {
    return FirebaseAnalyticsService();
  }
  return const DebugAnalyticsService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!Env.hasSupabaseConfig) {
    return null;
  }
  return Supabase.instance.client;
});

final cafeQueryServiceProvider = Provider<CafeQueryService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return CafeQueryService(client);
});

final cafeCommandServiceProvider = Provider<CafeCommandService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return CafeCommandService(client);
});

final cafeOwnerClaimsServiceProvider = Provider<CafeOwnerClaimsService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return CafeOwnerClaimsService(client);
});

final cafeOwnerInviteServiceProvider = Provider<CafeOwnerInviteService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return CafeOwnerInviteService(client);
});

final securityReadinessServiceProvider =
    Provider<SecurityReadinessService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return SecurityReadinessService(client);
});

final securityReadinessProvider =
    FutureProvider<SecurityReadinessReport>((ref) async {
  final service = ref.watch(securityReadinessServiceProvider);
  if (service == null) {
    return SecurityReadinessReport.notConfigured();
  }
  return service.verifyCafeRlsReadiness();
});

/// Profile CRUD and avatar operations for the authenticated user/admin.
final profilesServiceProvider = Provider<ProfilesService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return ProfilesService(client);
});

/// Reviews operations for cafes.
final reviewsServiceProvider = Provider<ReviewsService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return ReviewsService(client);
});

/// Supabase-backed favorites — source of truth with Hive as offline cache.
final favoritesServiceProvider = Provider<FavoritesService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return FavoritesService(client);
});

class FavoritesSyncGateway {
  const FavoritesSyncGateway(this._service);

  final FavoritesService? _service;

  Future<bool> syncFavorite({
    required String userId,
    required String cafeId,
    required bool isAdding,
  }) async {
    final service = _service;
    if (service == null) {
      return true;
    }
    return isAdding
        ? service.addFavorite(userId, cafeId)
        : service.removeFavorite(userId, cafeId);
  }
}

final favoritesSyncGatewayProvider = Provider<FavoritesSyncGateway>((ref) {
  return FavoritesSyncGateway(ref.watch(favoritesServiceProvider));
});

final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  final service = OfflineQueueService(
    storage: ref.watch(localStorageServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    reviewsService: ref.watch(reviewsServiceProvider),
    profilesService: ref.watch(profilesServiceProvider),
    favoritesService: ref.watch(favoritesServiceProvider),
  );
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

class PaginatedCafeReviewsState {
  const PaginatedCafeReviewsState({
    this.status = const async_result.AsyncLoading<List<CafeReview>>(
      previous: <CafeReview>[],
    ),
    this.hasMore = true,
    this.isLoadingMore = false,
    this.loadMoreErrorCode,
  });

  final async_result.AsyncResult<List<CafeReview>> status;
  final bool hasMore;
  final bool isLoadingMore;
  final AppErrorCode? loadMoreErrorCode;

  List<CafeReview> get reviews => switch (status) {
        async_result.AsyncData<List<CafeReview>>(value: final value) => value,
        async_result.AsyncLoading<List<CafeReview>>(previous: final previous) =>
          previous ?? const <CafeReview>[],
        async_result.AsyncError<List<CafeReview>>(previous: final previous) =>
          previous ?? const <CafeReview>[],
      };

  PaginatedCafeReviewsState copyWith({
    async_result.AsyncResult<List<CafeReview>>? status,
    bool? hasMore,
    bool? isLoadingMore,
    AppErrorCode? Function()? loadMoreErrorCode,
  }) {
    return PaginatedCafeReviewsState(
      status: status ?? this.status,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreErrorCode: loadMoreErrorCode != null
          ? loadMoreErrorCode()
          : this.loadMoreErrorCode,
    );
  }
}

final paginatedCafeReviewsProvider = StateNotifierProvider.autoDispose
    .family<CafeReviewsController, PaginatedCafeReviewsState, String>((
  ref,
  cafeId,
) {
  return CafeReviewsController(ref, cafeId);
});

final currentUserOwnerClaimsProvider =
    FutureProvider.autoDispose<List<CafeOwnerClaim>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const <CafeOwnerClaim>[];
  }
  final service = ref.watch(cafeOwnerClaimsServiceProvider);
  if (service == null) {
    throw const AppServiceException.unavailable(
      'Ownership claim service is unavailable.',
      errorCode: AppErrorCode.serviceUnavailable,
    );
  }
  final result = await service.fetchClaimsForUser(user.id);
  if (!result.ok) {
    throw AppServiceException(
      message: result.message ?? 'Unable to load ownership claims.',
      type: result.errorType,
      errorCode: result.errorCode,
      cause: result.error,
    );
  }
  return result.data ?? const <CafeOwnerClaim>[];
});

final cafeOwnerClaimForCafeProvider =
    Provider.autoDispose.family<CafeOwnerClaim?, String>((ref, cafeId) {
  final normalizedCafeId = cafeId.trim();
  final claims = ref.watch(currentUserOwnerClaimsProvider).valueOrNull ??
      const <CafeOwnerClaim>[];
  return claims.where((claim) => claim.cafeId == normalizedCafeId).firstOrNull;
});

final pendingCafeOwnerClaimsProvider =
    FutureProvider.autoDispose<List<CafeOwnerClaim>>((ref) async {
  final service = ref.watch(cafeOwnerClaimsServiceProvider);
  if (service == null) {
    throw const AppServiceException.unavailable(
      'Ownership claim service is unavailable.',
      errorCode: AppErrorCode.serviceUnavailable,
    );
  }
  final result = await service.fetchPendingClaims();
  if (!result.ok) {
    throw AppServiceException(
      message: result.message ?? 'Unable to load pending ownership claims.',
      type: result.errorType,
      errorCode: result.errorCode,
      cause: result.error,
    );
  }
  return result.data ?? const <CafeOwnerClaim>[];
});

final canManageCafeProvider =
    Provider.autoDispose.family<bool, Cafe>((ref, cafe) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return false;
  }
  if (ref.watch(isAdminProvider)) {
    return true;
  }
  if (user.role != ProfileRole.cafeOwner) {
    return false;
  }
  final ownerId = cafe.ownerUserId?.trim();
  return ownerId != null && ownerId.isNotEmpty && ownerId == user.id;
});

final cafeOwnerInviteControllerProvider = StateNotifierProvider.autoDispose<
    CafeOwnerInviteController, async_result.AsyncResult<void>>((ref) {
  return CafeOwnerInviteController(ref);
});

class CafeOwnerInviteController
    extends StateNotifier<async_result.AsyncResult<void>> {
  CafeOwnerInviteController(this._ref)
      : super(const async_result.AsyncData(null));

  final Ref _ref;

  Future<ServiceResult<CafeOwnerInviteResult>> inviteAndAssign({
    required String cafeId,
    required String email,
    String? firstName,
    String? lastName,
    String? fullName,
  }) async {
    if (!_ref.read(isAdminProvider)) {
      return ServiceResult.failure(
        message: 'Admin privileges are required to invite cafe owners.',
        errorCode: AppErrorCode.permissionDenied,
        errorType: ServiceErrorType.auth,
      );
    }

    final service = _ref.read(cafeOwnerInviteServiceProvider);
    if (service == null) {
      return ServiceResult.failure(
        message: 'Cafe owner invite service is unavailable.',
        errorCode: AppErrorCode.serviceUnavailable,
        errorType: ServiceErrorType.unavailable,
      );
    }

    state = const async_result.AsyncLoading();
    final result = await service.inviteAndAssign(
      cafeId: cafeId,
      email: email,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
    );
    state = result.ok
        ? const async_result.AsyncData(null)
        : async_result.AsyncError<void>(
            result.errorCode ?? AppErrorCode.validationFailed,
            debugMessage: result.message,
            originalError: result.error,
          );
    if (result.ok && result.data != null) {
      _ref.read(cafeProvider.notifier).upsertCafe(result.data!.cafe);
      try {
        _ref.invalidate(adminCafeDetailsProvider(cafeId));
        _ref.invalidate(adminUsersProvider);
        await _ref.read(adminCafeListControllerProvider.notifier).refresh();
        await _ref.read(cafeRepositoryProvider).clearCache();
      } catch (error, stackTrace) {
        AppLogger.error(
          'Cafe owner invite succeeded but follow-up refresh failed',
          error: error,
          stackTrace: stackTrace,
          key: 'cafe-owner-invite-refresh-$cafeId',
        );
      }
    }
    return result;
  }

  Future<ServiceResult<Cafe>> unassignOwner(String cafeId) async {
    if (!_ref.read(isAdminProvider)) {
      return ServiceResult.failure(
        message: 'Admin privileges are required to unassign cafe owners.',
        errorCode: AppErrorCode.permissionDenied,
        errorType: ServiceErrorType.auth,
      );
    }

    final mutation = _ref.read(cafeAdminMutationControllerProvider.notifier);
    state = const async_result.AsyncLoading();
    final result = await mutation.updateCafe(
      cafeId,
      const CafeAdminUpdateInput(ownerUserId: ''),
    );
    state = result.ok
        ? const async_result.AsyncData(null)
        : async_result.AsyncError<void>(
            result.errorCode ?? AppErrorCode.cafeUpdateFailed,
            debugMessage: result.message,
            originalError: result.error,
          );
    if (result.ok) {
      try {
        _ref.invalidate(adminCafeDetailsProvider(cafeId));
        await _ref.read(cafeRepositoryProvider).clearCache();
      } catch (error, stackTrace) {
        AppLogger.error(
          'Cafe owner unassign succeeded but follow-up refresh failed',
          error: error,
          stackTrace: stackTrace,
          key: 'cafe-owner-unassign-refresh-$cafeId',
        );
      }
    }
    return result;
  }
}

final cafeOwnerClaimControllerProvider = StateNotifierProvider.autoDispose<
    CafeOwnerClaimController, async_result.AsyncResult<void>>((ref) {
  return CafeOwnerClaimController(ref);
});

class CafeOwnerClaimController
    extends StateNotifier<async_result.AsyncResult<void>> {
  CafeOwnerClaimController(this._ref)
      : super(const async_result.AsyncData(null));

  final Ref _ref;

  Future<ServiceResult<CafeOwnerClaim>> createClaim({
    required String cafeId,
    required String businessName,
    String? businessEmail,
    String? evidenceUrl,
    String? phone,
    String? note,
  }) async {
    final user = _ref.read(currentUserProvider);
    final service = _ref.read(cafeOwnerClaimsServiceProvider);
    if (user == null) {
      return ServiceResult.failure(
        message: 'Please sign in to claim this cafe.',
        errorCode: AppErrorCode.permissionDenied,
        errorType: ServiceErrorType.auth,
      );
    }
    if (service == null) {
      return ServiceResult.failure(
        message: 'Ownership claim service is unavailable.',
        errorCode: AppErrorCode.serviceUnavailable,
        errorType: ServiceErrorType.unavailable,
      );
    }
    final existing = _ref.read(cafeOwnerClaimForCafeProvider(cafeId));
    if (existing?.isPending == true) {
      return ServiceResult.failure(
        message: 'A pending ownership claim already exists for this cafe.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.conflict,
      );
    }

    state = const async_result.AsyncLoading();
    final result = await service.createClaim(
      userId: user.id,
      cafeId: cafeId,
      businessName: businessName,
      businessEmail: businessEmail,
      evidenceUrl: evidenceUrl,
      phone: phone,
      note: note,
    );
    state = result.ok
        ? const async_result.AsyncData(null)
        : async_result.AsyncError<void>(
            result.errorCode ?? AppErrorCode.validationFailed,
            debugMessage: result.message,
            originalError: result.error,
          );
    if (result.ok) {
      _ref.invalidate(currentUserOwnerClaimsProvider);
      _ref.invalidate(cafeOwnerClaimForCafeProvider(cafeId));
    }
    return result;
  }
}

final cafeOwnerClaimAdminControllerProvider = StateNotifierProvider.autoDispose<
    CafeOwnerClaimAdminController, async_result.AsyncResult<void>>((ref) {
  return CafeOwnerClaimAdminController(ref);
});

class CafeOwnerClaimAdminController
    extends StateNotifier<async_result.AsyncResult<void>> {
  CafeOwnerClaimAdminController(this._ref)
      : super(const async_result.AsyncData(null));

  final Ref _ref;

  Future<ServiceResult<CafeOwnerClaim>> approve(String claimId) {
    return _review(claimId, approve: true);
  }

  Future<ServiceResult<CafeOwnerClaim>> reject(String claimId) {
    return _review(claimId, approve: false);
  }

  Future<ServiceResult<CafeOwnerClaim>> _review(
    String claimId, {
    required bool approve,
  }) async {
    final user = _ref.read(currentUserProvider);
    final service = _ref.read(cafeOwnerClaimsServiceProvider);
    if (user == null || !_ref.read(isAdminProvider)) {
      return ServiceResult.failure(
        message: 'Admin privileges are required to review claims.',
        errorCode: AppErrorCode.permissionDenied,
        errorType: ServiceErrorType.auth,
      );
    }
    if (service == null) {
      return ServiceResult.failure(
        message: 'Ownership claim service is unavailable.',
        errorCode: AppErrorCode.serviceUnavailable,
        errorType: ServiceErrorType.unavailable,
      );
    }
    state = const async_result.AsyncLoading();
    final result = approve
        ? await service.approveClaim(claimId: claimId, reviewedBy: user.id)
        : await service.rejectClaim(claimId: claimId, reviewedBy: user.id);
    state = result.ok
        ? const async_result.AsyncData(null)
        : async_result.AsyncError<void>(
            result.errorCode ?? AppErrorCode.validationFailed,
            debugMessage: result.message,
            originalError: result.error,
          );
    if (result.ok) {
      _ref.invalidate(pendingCafeOwnerClaimsProvider);
      _ref.invalidate(currentUserOwnerClaimsProvider);
      _ref.invalidate(adminCafeListControllerProvider);
      await _ref.read(adminCafeListControllerProvider.notifier).refresh();
      await _ref.read(cafeRepositoryProvider).clearCache();
    }
    return result;
  }
}

class CafeReviewsController extends StateNotifier<PaginatedCafeReviewsState> {
  CafeReviewsController(this._ref, this._cafeId)
      : super(const PaginatedCafeReviewsState()) {
    unawaited(refresh());
  }

  static const int _pageSize = 20;

  final Ref _ref;
  final String _cafeId;
  int _page = 0;

  Future<void> refresh() async {
    final service = _ref.read(reviewsServiceProvider);
    if (service == null) {
      state = state.copyWith(
        status: const async_result.AsyncError<List<CafeReview>>(
          AppErrorCode.serviceUnavailable,
          previous: <CafeReview>[],
        ),
        hasMore: false,
        loadMoreErrorCode: () => null,
      );
      return;
    }

    state = state.copyWith(
      status: async_result.AsyncLoading<List<CafeReview>>(
        previous: state.reviews,
      ),
      isLoadingMore: false,
      loadMoreErrorCode: () => null,
    );

    final result = await service.fetchReviews(
      _cafeId,
      page: 0,
      pageSize: _pageSize,
    );
    if (!result.ok || result.data == null) {
      state = state.copyWith(
        status: async_result.AsyncError<List<CafeReview>>(
          result.errorCode ?? AppErrorCode.reviewLoadFailed,
          debugMessage: result.message,
          originalError: result.error,
          previous: state.reviews,
        ),
        hasMore: false,
      );
      return;
    }

    _page = 1;
    state = state.copyWith(
      status: async_result.AsyncData<List<CafeReview>>(result.data!.reviews),
      hasMore: result.data!.hasMore,
      isLoadingMore: false,
      loadMoreErrorCode: () => null,
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) {
      return;
    }

    final service = _ref.read(reviewsServiceProvider);
    if (service == null) {
      state = state.copyWith(
        loadMoreErrorCode: () => AppErrorCode.serviceUnavailable,
      );
      return;
    }

    state = state.copyWith(
      isLoadingMore: true,
      loadMoreErrorCode: () => null,
    );

    final result = await service.fetchReviews(
      _cafeId,
      page: _page,
      pageSize: _pageSize,
    );
    if (!result.ok || result.data == null) {
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorCode: () =>
            result.errorCode ?? AppErrorCode.reviewLoadFailed,
      );
      return;
    }

    _page += 1;
    state = state.copyWith(
      status: async_result.AsyncData<List<CafeReview>>([
        ...state.reviews,
        ...result.data!.reviews,
      ]),
      hasMore: result.data!.hasMore,
      isLoadingMore: false,
      loadMoreErrorCode: () => null,
    );
  }
}

final currentUserCafeReviewProvider =
    Provider.autoDispose.family<CafeReview?, String>((
  ref,
  cafeId,
) {
  final currentUser = ref.watch(currentUserProvider);
  final reviews = ref.watch(paginatedCafeReviewsProvider(cafeId)).reviews;
  if (currentUser == null) {
    return null;
  }

  for (final review in reviews) {
    if (review.userId == currentUser.id) {
      return review;
    }
  }

  return null;
});

class CafeReviewSummary {
  const CafeReviewSummary({
    required this.rating,
    required this.reviewCount,
    required this.usesLiveReviews,
  });

  final double rating;
  final int reviewCount;
  final bool usesLiveReviews;
}

final cafeReviewSummaryProvider =
    Provider.autoDispose.family<CafeReviewSummary, String>((
  ref,
  cafeId,
) {
  final cafe = ref.watch(cafeByIdProvider(cafeId));
  final reviews = ref.watch(paginatedCafeReviewsProvider(cafeId)).reviews;

  if (reviews.isNotEmpty) {
    final total = reviews.fold<int>(0, (sum, review) => sum + review.rating);
    return CafeReviewSummary(
      rating: total / reviews.length,
      reviewCount: reviews.length,
      usesLiveReviews: true,
    );
  }

  return CafeReviewSummary(
    rating: cafe?.appRating ?? 0,
    reviewCount: cafe?.appReviewCount ?? 0,
    usesLiveReviews: false,
  );
});

final reviewSubmissionControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewSubmissionController, async_result.AsyncResult<void>, String>(
        (
  ref,
  cafeId,
) {
  return ReviewSubmissionController(ref, cafeId);
});

class ReviewSubmissionController
    extends StateNotifier<async_result.AsyncResult<void>> {
  ReviewSubmissionController(this._ref, this._cafeId)
      : super(const async_result.AsyncData(null));

  final Ref _ref;
  final String _cafeId;

  void resetState() {
    if (!mounted) {
      return;
    }
    state = const async_result.AsyncData(null);
  }

  Future<ServiceResult<ReviewMutationResult>> submitReview({
    String? userId,
    required int rating,
    int? wifiQuality,
    int? noiseLevel,
    int? studyFriendliness,
    int? seatingComfort,
    String? socketAvailability,
    String? smokingPolicy,
    String? content,
  }) async {
    if (state is async_result.AsyncLoading<void>) {
      AppLogger.warn(
        'ReviewSubmissionController ignored duplicate submit for cafeId=$_cafeId',
        key: 'review-submit-duplicate-$_cafeId',
      );
      return ServiceResult.failure(
        message: 'Review submission is already in progress.',
        errorType: ServiceErrorType.validation,
      );
    }

    final connectivity = _ref.read(connectivityServiceProvider);
    final offlineSync = _ref.read(offlineSyncProvider.notifier);
    final service = _ref.read(reviewsServiceProvider);
    if (service == null) {
      return ServiceResult.failure(
        message: 'Review service is unavailable.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    state = const async_result.AsyncLoading();

    try {
      Future<void> enqueueOfflineSubmission() {
        return offlineSync.enqueueReviewSubmission({
          'cafeId': _cafeId,
          'userId': userId,
          'rating': rating,
          'wifiQuality': wifiQuality,
          'noiseLevel': noiseLevel,
          'studyFriendliness': studyFriendliness,
          'seatingComfort': seatingComfort,
          'socketAvailability': socketAvailability,
          'smokingPolicy': smokingPolicy,
          'content': content,
        });
      }

      if (!connectivity.currentlyOnline) {
        await enqueueOfflineSubmission();
        state = const async_result.AsyncData(null);
        _ref.read(analyticsServiceProvider).trackReviewSubmitted(_cafeId);
        return ServiceResult.success(
          message: ServiceResultMessages.offlineQueued,
        );
      }

      final result = await service.submitReview(
        cafeId: _cafeId,
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

      if (!result.ok) {
        if (result.errorType.isTransient) {
          await enqueueOfflineSubmission();
          state = const async_result.AsyncData(null);
          _ref.read(analyticsServiceProvider).trackReviewSubmitted(_cafeId);
          return ServiceResult.success(
            message: ServiceResultMessages.offlineQueued,
          );
        }

        AppLogger.warn(
          'ReviewSubmissionController failed for cafeId=$_cafeId message=${result.message ?? 'n/a'}',
          key: 'review-submit-failed-$_cafeId',
        );
        state = async_result.AsyncError<void>(
          result.errorCode ?? AppErrorCode.reviewSubmitFailed,
          debugMessage: result.message,
          originalError: result.error,
        );
        return result;
      }

      try {
        await _ref
            .read(paginatedCafeReviewsProvider(_cafeId).notifier)
            .refresh();
      } catch (error) {
        AppLogger.error(
          'ReviewSubmissionController refresh failed for cafeId=$_cafeId',
          error: error,
          key: 'review-submit-refresh-failed-$_cafeId',
        );
      }

      state = const async_result.AsyncData(null);
      _ref.read(analyticsServiceProvider).trackReviewSubmitted(_cafeId);
      return result;
    } catch (e) {
      state = async_result.AsyncError<void>(
        AppErrorCode.reviewSubmitFailed,
        originalError: e,
      );
      return ServiceResult.failure(message: e.toString());
    }
  }
}

final reviewDeletionControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewDeletionController, async_result.AsyncResult<void>, String>((
  ref,
  cafeId,
) {
  return ReviewDeletionController(ref, cafeId);
});

class ReviewDeletionController
    extends StateNotifier<async_result.AsyncResult<void>> {
  ReviewDeletionController(this._ref, this._cafeId)
      : super(const async_result.AsyncData(null));

  final Ref _ref;
  final String _cafeId;
  final Set<String> _pendingReviewIds = <String>{};

  Future<ServiceResult<void>> deleteReview({
    required String reviewId,
    required String userId,
    required bool isAdmin,
  }) async {
    if (!_pendingReviewIds.add(reviewId)) {
      return ServiceResult.failure(
        message: 'Review deletion is already in progress.',
        errorType: ServiceErrorType.validation,
      );
    }

    final service = _ref.read(reviewsServiceProvider);
    if (service == null) {
      _pendingReviewIds.remove(reviewId);
      return ServiceResult.failure(
        message: 'Review service is unavailable.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    state = const async_result.AsyncLoading();
    final result = await service.deleteReview(
      reviewId,
      userId: userId,
      isAdmin: isAdmin,
    );

    if (result.ok) {
      _ref.read(analyticsServiceProvider).trackReviewDeleted(_cafeId);
      try {
        await _ref
            .read(paginatedCafeReviewsProvider(_cafeId).notifier)
            .refresh();
      } finally {
        state = const async_result.AsyncData(null);
      }
    } else {
      state = async_result.AsyncError<void>(
        result.errorCode ?? AppErrorCode.reviewDeleteFailed,
        debugMessage: result.message,
        originalError: result.error,
      );
    }

    _pendingReviewIds.remove(reviewId);
    if (state is async_result.AsyncLoading<void>) {
      state = const async_result.AsyncData(null);
    }
    return result;
  }
}

final adminUsersProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  final service = ref.watch(profilesServiceProvider);
  if (service == null) {
    throw StateError('Profile service is unavailable.');
  }

  final result = await service.fetchProfiles();
  if (!result.ok) {
    throw StateError(result.message ?? 'User list could not be loaded.');
  }
  return result.data ?? const <UserProfile>[];
});

class AdminCafeListState {
  const AdminCafeListState({
    this.cafes = const <Cafe>[],
    this.searchQuery = '',
    this.districtFilter = 'all',
    this.statusFilter = 'all',
    this.offset = 0,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
  });

  final List<Cafe> cafes;
  final String searchQuery;
  final String districtFilter;
  final String statusFilter;
  final int offset;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  AdminCafeListState copyWith({
    List<Cafe>? cafes,
    String? searchQuery,
    String? districtFilter,
    String? statusFilter,
    int? offset,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? Function()? errorMessage,
  }) {
    return AdminCafeListState(
      cafes: cafes ?? this.cafes,
      searchQuery: searchQuery ?? this.searchQuery,
      districtFilter: districtFilter ?? this.districtFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      offset: offset ?? this.offset,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

final adminCafeListControllerProvider = StateNotifierProvider.autoDispose<
    AdminCafeListController, AdminCafeListState>((ref) {
  final controller = AdminCafeListController(ref);
  unawaited(controller.refresh());
  return controller;
});

final adminCafesProvider = Provider.autoDispose<List<Cafe>>((ref) {
  return ref.watch(
    adminCafeListControllerProvider.select((state) => state.cafes),
  );
});

final adminDiscoveredCafesProvider = Provider.autoDispose<List<Cafe>>((ref) {
  final savedCafes = ref.watch(adminCafesProvider);
  final cacheCafes = ref.watch(cafesProvider);
  final homeCafes = ref.watch(homeCafesProvider);
  final mapCafes = ref.watch(mapFilteredCafesProvider);
  final featuredCafes = ref.watch(featuredCafesProvider);
  final searchCafes = ref.watch(exploreCafeResultsProvider);

  final merged = _mergeDiscoveredCafeSources(
    cache: cacheCafes,
    home: homeCafes,
    map: mapCafes,
    featured: featuredCafes,
    search: searchCafes,
  );
  final filtered = _filterUnsavedDiscoveredCafes(
    discovered: merged,
    saved: savedCafes,
  );
  final excludedSaved = merged.length - filtered.length;
  AppLogger.debug(
    '[ADMIN_CAFES_DIAG] savedCount=${savedCafes.length}',
    key: 'admin-cafes-diag-saved',
    throttle: Duration.zero,
  );
  AppLogger.debug(
    '[ADMIN_CAFES_DIAG] discoveredSource cache=${cacheCafes.length} home=${homeCafes.length} map=${mapCafes.length} featured=${featuredCafes.length} search=${searchCafes.length} merged=${merged.length} excludedSaved=$excludedSaved final=${filtered.length}',
    key: 'admin-cafes-diag-discovered',
    throttle: Duration.zero,
  );
  return filtered;
});

List<Cafe> _mergeDiscoveredCafeSources({
  required List<Cafe> cache,
  required List<Cafe> home,
  required List<Cafe> map,
  required List<Cafe> featured,
  required List<Cafe> search,
}) {
  final byKey = <String, Cafe>{};
  final sources = <List<Cafe>>[cache, home, map, featured, search];
  for (final list in sources) {
    for (final cafe in list) {
      final keys = _discoveredCafeIdentityKeys(cafe);
      if (keys.isEmpty) {
        continue;
      }
      final dedupeKey = keys.firstWhere(
        (key) => key.startsWith('place:'),
        orElse: () => keys.first,
      );
      final existing = byKey[dedupeKey];
      if (existing == null ||
          cafe.photoUrls.length > existing.photoUrls.length) {
        byKey[dedupeKey] = cafe;
      }
    }
  }
  return List<Cafe>.unmodifiable(byKey.values);
}

List<Cafe> _filterUnsavedDiscoveredCafes({
  required List<Cafe> discovered,
  required List<Cafe> saved,
}) {
  final savedKeys = <String>{};
  for (final cafe in saved) {
    savedKeys.addAll(_discoveredCafeIdentityKeys(cafe));
  }

  final byKey = <String, Cafe>{};
  for (final cafe in discovered) {
    final placeId = cafe.placeId?.trim();
    if (placeId == null || placeId.isEmpty) {
      continue;
    }
    final keys = _discoveredCafeIdentityKeys(cafe);
    if (keys.any(savedKeys.contains)) {
      continue;
    }
    final dedupeKey = keys.firstWhere(
      (key) => key.startsWith('place:'),
      orElse: () => keys.first,
    );
    byKey.putIfAbsent(dedupeKey, () => cafe);
  }

  return List<Cafe>.unmodifiable(byKey.values);
}

Set<String> _discoveredCafeIdentityKeys(Cafe cafe) {
  final keys = <String>{
    'id:${cafe.id.trim()}',
    'canonical:${cafe.canonicalIdentityKey.trim()}',
    'fallback:${normalizeSearchText(cafe.name)}|${normalizeSearchText(cafe.address)}',
  };
  final placeId = cafe.placeId?.trim();
  if (placeId != null && placeId.isNotEmpty) {
    keys.add('place:$placeId');
  }
  keys.removeWhere((key) => key.endsWith(':') || key.trim().isEmpty);
  return keys;
}

class AdminCafeListController extends StateNotifier<AdminCafeListState> {
  AdminCafeListController(this._ref) : super(const AdminCafeListState());

  static const int _pageSize = 60;
  static const Duration _filterDebounceDuration = Duration(milliseconds: 300);

  final Ref _ref;
  Timer? _filterDebounceTimer;
  Completer<void>? _debouncedLoadCompleter;
  RequestCancellationController? _activeAdminListRequest;
  int _adminListRequestVersion = 0;

  Future<void> refresh() async {
    _cancelPendingDebouncedLoad();
    await _loadPage(reset: true);
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    await _loadPage(reset: false);
  }

  Future<void> setSearchQuery(String query) async {
    final normalized = query.trim();
    if (normalized == state.searchQuery) {
      return;
    }
    state = state.copyWith(searchQuery: normalized);
    await _scheduleDebouncedRefresh();
  }

  Future<void> setDistrictFilter(String district) async {
    final normalized = district.trim().isEmpty ? 'all' : district.trim();
    if (normalized == state.districtFilter) {
      return;
    }
    state = state.copyWith(districtFilter: normalized);
    await _scheduleDebouncedRefresh();
  }

  Future<void> setStatusFilter(String status) async {
    final normalized = status.trim().isEmpty ? 'all' : status.trim();
    if (normalized == state.statusFilter) {
      return;
    }
    state = state.copyWith(statusFilter: normalized);
    await _scheduleDebouncedRefresh();
  }

  Future<void> _scheduleDebouncedRefresh() {
    _filterDebounceTimer?.cancel();
    final previousCompleter = _debouncedLoadCompleter;
    if (previousCompleter != null && !previousCompleter.isCompleted) {
      previousCompleter.complete();
    }

    final completer = Completer<void>();
    _debouncedLoadCompleter = completer;
    _filterDebounceTimer = Timer(_filterDebounceDuration, () {
      final activeCompleter = _debouncedLoadCompleter;
      _debouncedLoadCompleter = null;
      _filterDebounceTimer = null;
      _loadPage(reset: true).whenComplete(() {
        if (activeCompleter != null && !activeCompleter.isCompleted) {
          activeCompleter.complete();
        }
      });
    });
    return completer.future;
  }

  void _cancelPendingDebouncedLoad() {
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = null;
    final completer = _debouncedLoadCompleter;
    _debouncedLoadCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _loadPage({required bool reset}) async {
    final service = _ref.read(cafeQueryServiceProvider);
    if (service == null) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        hasMore: false,
        errorMessage: () => 'Cafe query service is unavailable.',
      );
      return;
    }

    final requestVersion = ++_adminListRequestVersion;
    _activeAdminListRequest?.cancel(
      'Superseded by a newer admin cafe list request.',
    );
    final requestController = RequestCancellationController(
      defaultReason: 'Admin cafe list request was cancelled.',
    );
    _activeAdminListRequest = requestController;
    final requestOffset = reset ? 0 : state.offset;
    final requestSearchQuery = state.searchQuery;
    final requestDistrict = state.districtFilter;
    final requestStatus = state.statusFilter;
    state = state.copyWith(
      isLoading: reset,
      isLoadingMore: !reset,
      errorMessage: () => null,
    );

    final result = await service.fetchAdminCafes(
      searchQuery: requestSearchQuery,
      district: requestDistrict,
      status: requestStatus,
      limit: _pageSize,
      offset: requestOffset,
      cancellationToken: requestController.token,
    );

    if (!_isCurrentAdminListRequest(requestVersion, requestController)) {
      return;
    }

    if (!result.ok || result.data == null) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: () => result.message ?? 'Cafe list could not be loaded.',
      );
      if (identical(_activeAdminListRequest, requestController)) {
        _activeAdminListRequest = null;
      }
      return;
    }

    final page = result.data!;
    final mergedCafes = reset
        ? page.cafes
        : _mergeAdminCafePages(
            state.cafes,
            page.cafes,
          );
    final nextCafes = _dedupeAdminCafeRows(mergedCafes);
    final googleDiscoveredCount = _ref.read(cafeProvider).cafes.length;
    final deletedExcluded = page.cafes.where((cafe) => cafe.isDeleted).length;
    AppLogger.debug(
      '[ADMIN_CAFE_LIST_SOURCE] source=adminSupabase count=${page.cafes.length} featuredOnly=false',
      key: 'admin-cafe-list-source',
      throttle: Duration.zero,
    );
    AppLogger.debug(
      '[ADMIN_CAFE_LIST_FILTER] deletedExcluded=$deletedExcluded featuredFilterApplied=false',
      key: 'admin-cafe-list-filter',
      throttle: Duration.zero,
    );
    AppLogger.debug(
      '[ADMIN_CAFE_LIST_COUNT_EXPLAIN] supabaseActive=${nextCafes.length} googleDiscovered=$googleDiscoveredCount rendered=${nextCafes.length} mode=supabaseOnly',
      key: 'admin-cafe-list-count-explain',
      throttle: Duration.zero,
    );

    state = state.copyWith(
      cafes: nextCafes,
      offset: reset ? page.cafes.length : state.offset + page.cafes.length,
      hasMore: page.hasMore,
      isLoading: false,
      isLoadingMore: false,
      errorMessage: () => null,
    );
    if (identical(_activeAdminListRequest, requestController)) {
      _activeAdminListRequest = null;
    }
  }

  bool _isCurrentAdminListRequest(
    int requestVersion,
    RequestCancellationController requestController,
  ) {
    return mounted &&
        requestVersion == _adminListRequestVersion &&
        identical(_activeAdminListRequest, requestController) &&
        !requestController.isCancelled;
  }

  List<Cafe> _mergeAdminCafePages(List<Cafe> current, List<Cafe> incoming) {
    if (incoming.isEmpty) {
      return current;
    }

    final byIdentity = <String, Cafe>{
      for (final cafe in current) cafe.canonicalIdentityKey: cafe,
    };
    for (final cafe in incoming) {
      byIdentity[cafe.canonicalIdentityKey] = cafe;
    }
    return byIdentity.values.toList(growable: false);
  }

  List<Cafe> _dedupeAdminCafeRows(List<Cafe> cafes) {
    if (cafes.length < 2) {
      return cafes;
    }
    final byIdentity = <String, Cafe>{};
    var duplicateKeys = 0;
    for (final cafe in cafes) {
      final key = _adminCafeIdentityKey(cafe);
      if (byIdentity.containsKey(key)) {
        duplicateKeys += 1;
        AppLogger.warn(
          '[ADMIN_DUPLICATE_ROW_WARNING] name=${_safeAdminCafeName(cafe.name)} ids=${_safeAdminCafeId(cafe.id)} reason=${cafe.placeId?.trim().isNotEmpty == true ? 'same_place' : 'name_location_fallback'}',
          key: 'admin-duplicate-row-${key.hashCode.abs()}',
        );
      }
      byIdentity[key] = cafe;
    }
    if (duplicateKeys > 0) {
      AppLogger.debug(
        '[CAFE_IDENTITY_DEDUPE] surface=admin before=${cafes.length} after=${byIdentity.length} duplicateKeys=$duplicateKeys',
        key: 'admin-cafe-dedupe',
        throttle: Duration.zero,
      );
    }
    return byIdentity.values.toList(growable: false);
  }

  int removeCafesByIdentity(Iterable<String> rawIds) {
    final ids =
        rawIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return 0;
    }

    bool matches(Cafe cafe) =>
        _adminCafeRemovalIdentityKeys(cafe).any(ids.contains);
    final before = state.cafes.length;
    final next =
        state.cafes.where((cafe) => !matches(cafe)).toList(growable: false);
    if (next.length == before) {
      return 0;
    }
    state = state.copyWith(
      cafes: next,
      offset: next.length,
      hasMore: state.hasMore && next.isNotEmpty,
    );
    return before - next.length;
  }

  String _adminCafeIdentityKey(Cafe cafe) {
    final placeId = cafe.placeId?.trim();
    if (placeId != null && placeId.isNotEmpty) {
      return 'place:$placeId';
    }
    final normalizedDistrict = normalizeSearchText(cafe.district);
    final normalizedNeighborhood = normalizeSearchText(cafe.neighborhood);
    final normalizedAddress = normalizeSearchText(cafe.address);
    if (normalizedDistrict.isEmpty &&
        normalizedNeighborhood.isEmpty &&
        normalizedAddress.isEmpty) {
      return cafe.canonicalIdentityKey.trim();
    }
    return 'fallback:${normalizeSearchText(cafe.name)}|${normalizeSearchText(cafe.district)}|${normalizeSearchText(cafe.neighborhood)}|${normalizeSearchText(cafe.address)}';
  }

  Set<String> _adminCafeRemovalIdentityKeys(Cafe cafe) {
    final keys = <String>{
      cafe.id.trim(),
      cafe.canonicalIdentityKey.trim(),
      _adminCafeIdentityKey(cafe),
    };
    final placeId = cafe.placeId?.trim();
    if (placeId != null && placeId.isNotEmpty) {
      keys.add(placeId);
    }
    keys.removeWhere((key) => key.isEmpty);
    return keys;
  }

  String _safeAdminCafeName(String name) {
    final normalized = normalizeSearchText(name);
    if (normalized.length <= 40) {
      return normalized;
    }
    return normalized.substring(0, 40);
  }

  String _safeAdminCafeId(String id) {
    return id.length <= 12 ? id : id.substring(0, 12);
  }

  @override
  void dispose() {
    _filterDebounceTimer?.cancel();
    _activeAdminListRequest?.cancel('Admin cafe list controller disposed.');
    super.dispose();
  }
}

final adminCafeDetailsProvider =
    FutureProvider.autoDispose.family<Cafe?, String>((ref, rawCafeId) async {
  final cafeId = rawCafeId.trim();
  if (cafeId.isEmpty) {
    return null;
  }

  final service = ref.watch(cafeQueryServiceProvider);
  final fallbackCafe =
      ref.read(adminCafeListControllerProvider).cafes.where((cafe) {
            return cafe.id == cafeId || cafe.placeId == cafeId;
          }).firstOrNull ??
          ref.read(cafesProvider).where((cafe) {
            return cafe.id == cafeId || cafe.placeId == cafeId;
          }).firstOrNull ??
          ref.read(cafeByIdProvider(cafeId));
  if (fallbackCafe != null && fallbackCafe.isDeleted) {
    AppLogger.debug(
      '[DETAIL_DELETED_GUARD] cafeId=$cafeId reason=is_deleted_or_deleted_at',
      key: 'admin-detail-deleted-guard-$cafeId',
      throttle: Duration.zero,
    );
    return null;
  }
  if (service == null) {
    return fallbackCafe;
  }

  final detail = await service.fetchCafeById(cafeId);
  if (detail.ok && detail.data != null) {
    if (detail.data!.isDeleted) {
      AppLogger.debug(
        '[DETAIL_DELETED_GUARD] cafeId=$cafeId reason=is_deleted_or_deleted_at',
        key: 'admin-detail-remote-deleted-guard-$cafeId',
        throttle: Duration.zero,
      );
      return null;
    }
    return detail.data;
  }

  if (cafeId.startsWith('ChI')) {
    final byPlaceId = await service.fetchCafesByPlaceIds(<String>{cafeId});
    if (byPlaceId.ok) {
      for (final cafe in byPlaceId.data ?? const <Cafe>[]) {
        if (cafe.placeId?.trim() == cafeId) {
          return cafe;
        }
      }
    }
  }

  return fallbackCafe;
});

final cafeAdminMutationControllerProvider = StateNotifierProvider.autoDispose<
    CafeAdminMutationController, async_result.AsyncResult<void>>((ref) {
  return CafeAdminMutationController(ref);
});

final adminCafeMutationPendingIdsProvider = StateProvider<Set<String>>((ref) {
  return const <String>{};
});

class CafeAdminMutationController
    extends StateNotifier<async_result.AsyncResult<void>> {
  CafeAdminMutationController(this._ref)
      : super(const async_result.AsyncData(null));

  final Ref _ref;

  bool _isCafeMutationPending(String cafeId) {
    final normalizedCafeId = cafeId.trim();
    if (normalizedCafeId.isEmpty) {
      return false;
    }
    return _ref
        .read(adminCafeMutationPendingIdsProvider)
        .contains(normalizedCafeId);
  }

  void _setCafeMutationPending(String cafeId, bool isPending) {
    final normalizedCafeId = cafeId.trim();
    if (normalizedCafeId.isEmpty) {
      return;
    }

    final current = _ref.read(adminCafeMutationPendingIdsProvider);
    final next = <String>{...current};
    if (isPending) {
      next.add(normalizedCafeId);
    } else {
      next.remove(normalizedCafeId);
    }
    _ref.read(adminCafeMutationPendingIdsProvider.notifier).state =
        Set<String>.unmodifiable(next);
  }

  Future<Cafe?> _resolveDeleteTargetCafe(String normalizedCafeId) async {
    Cafe? matchedCafe = _ref.read(cafeProvider).featuredCafes.where((cafe) {
      return cafe.id == normalizedCafeId || cafe.placeId == normalizedCafeId;
    }).firstOrNull;

    matchedCafe ??= _ref.read(homeCafesProvider).where((cafe) {
      return cafe.id == normalizedCafeId || cafe.placeId == normalizedCafeId;
    }).firstOrNull;

    matchedCafe ??= _ref.read(cafesProvider).where((cafe) {
      return cafe.id == normalizedCafeId || cafe.placeId == normalizedCafeId;
    }).firstOrNull;

    matchedCafe ??= _ref.read(cafeByIdProvider(normalizedCafeId));

    final detailState = _ref.read(adminCafeDetailsProvider(normalizedCafeId));
    final detailCafe = detailState.valueOrNull;
    final matchedPlaceId = matchedCafe?.placeId?.trim();
    final detailPlaceId = detailCafe?.placeId?.trim();
    if (detailCafe != null &&
        (matchedCafe == null ||
            matchedPlaceId == null ||
            matchedPlaceId.isEmpty) &&
        detailPlaceId != null &&
        detailPlaceId.isNotEmpty) {
      return detailCafe;
    }

    matchedCafe ??=
        _ref.read(adminCafeListControllerProvider).cafes.where((cafe) {
      return cafe.id == normalizedCafeId || cafe.placeId == normalizedCafeId;
    }).firstOrNull;
    if (matchedCafe != null) {
      final currentPlaceId = matchedCafe.placeId?.trim();
      if (currentPlaceId != null && currentPlaceId.isNotEmpty) {
        return matchedCafe;
      }
    }

    try {
      final resolvedDetail =
          await _ref.read(adminCafeDetailsProvider(normalizedCafeId).future);
      final resolvedPlaceId = resolvedDetail?.placeId?.trim();
      if (resolvedDetail != null &&
          resolvedPlaceId != null &&
          resolvedPlaceId.isNotEmpty) {
        return resolvedDetail;
      }
    } catch (_) {
      return matchedCafe;
    }

    return matchedCafe;
  }

  Future<ServiceResult<void>> _ensureSecurityReadinessForAdminMutation() async {
    var shellState = _ref.read(appShellProvider);
    AppLogger.debug(
      '[ADMIN_READINESS] userPresent=${shellState.currentUser != null} isAdmin=${shellState.isAdmin} resolved=${shellState.isAdminRoleResolved}',
      key: 'admin-readiness-entry',
      throttle: Duration.zero,
    );
    if (shellState.currentUser == null) {
      return ServiceResult.failure(
        message: 'Admin cafe mutations require an authenticated session.',
        errorCode: AppErrorCode.permissionDenied,
        errorType: ServiceErrorType.auth,
      );
    }

    if (!shellState.isAdmin && !shellState.isAdminRoleResolved) {
      await _ref
          .read(appShellProvider.notifier)
          .refreshAdminRoleResolution(force: true);
      shellState = _ref.read(appShellProvider);
      AppLogger.debug(
        '[ADMIN_READINESS] phase=refresh isAdmin=${shellState.isAdmin} resolved=${shellState.isAdminRoleResolved}',
        key: 'admin-readiness-refresh',
        throttle: Duration.zero,
      );
    }

    if (!shellState.isAdmin) {
      if (!shellState.isAdminRoleResolved) {
        return ServiceResult.failure(
          message: shellState.adminRoleStatusMessage ??
              'Admin status is unknown because role verification did not complete.',
          errorCode: AppErrorCode.profileLoadFailed,
          errorType: ServiceErrorType.unavailable,
        );
      }

      return ServiceResult.failure(
        message: 'Admin privileges are required for cafe mutations.',
        errorCode: AppErrorCode.permissionDenied,
        errorType: ServiceErrorType.auth,
      );
    }

    try {
      final report = await _ref.read(securityReadinessProvider.future);
      if (report.blocksAdminMutations) {
        final probeFailed =
            report.failureType != null || !report.checkAvailable;
        return ServiceResult.failure(
          message: report.message,
          errorCode: probeFailed
              ? AppErrorCode.serviceUnavailable
              : AppErrorCode.permissionDenied,
          errorType: probeFailed
              ? (report.failureType ?? ServiceErrorType.unavailable)
              : ServiceErrorType.auth,
        );
      }
      return ServiceResult.success();
    } catch (_) {
      return ServiceResult.failure(
        message:
            'Security readiness check could not complete. Admin cafe mutations are blocked until environment checks pass.',
        errorCode: AppErrorCode.serviceUnavailable,
        errorType: ServiceErrorType.unavailable,
      );
    }
  }

  Future<ServiceResult<bool>> _ensureCafeUpdatePermission(String cafeId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      return ServiceResult.failure(
        message: 'Cafe updates require an authenticated session.',
        errorCode: AppErrorCode.permissionDenied,
        errorType: ServiceErrorType.auth,
      );
    }

    if (_ref.read(isAdminProvider)) {
      final readiness = await _ensureSecurityReadinessForAdminMutation();
      if (!readiness.ok) {
        return ServiceResult.failure(
          message: readiness.message,
          errorCode: readiness.errorCode,
          errorType: readiness.errorType,
        );
      }
      return ServiceResult.success(data: true);
    }

    if (user.role != ProfileRole.cafeOwner) {
      return ServiceResult.failure(
        message: 'Cafe owner role is required to manage this cafe.',
        errorCode: AppErrorCode.permissionDenied,
        errorType: ServiceErrorType.auth,
      );
    }

    final cafe = await _ref.read(adminCafeDetailsProvider(cafeId).future) ??
        _ref.read(cafeByIdProvider(cafeId));
    final ownerId = cafe?.ownerUserId?.trim();
    if (ownerId != null && ownerId.isNotEmpty && ownerId == user.id) {
      return ServiceResult.success(data: false);
    }

    return ServiceResult.failure(
      message: 'You can only manage cafes that you own.',
      errorCode: AppErrorCode.permissionDenied,
      errorType: ServiceErrorType.auth,
    );
  }

  Future<void> _refreshCanonicalCafeStateAfterMutation({
    bool refreshAdminList = true,
    bool refreshCafes = true,
  }) async {
    AppLogger.debug(
      '[ADMIN_MUTATION_REFRESH] refreshAdminList=$refreshAdminList refreshCafes=$refreshCafes',
      key: 'admin-mutation-refresh',
      throttle: Duration.zero,
    );
    _ref.invalidate(resolvedFavoriteCafesProvider);
    _ref.invalidate(resolvedComparedCafesProvider);
    _ref.invalidate(comparedCafesProvider);
    _ref.invalidate(comparedResolvedCafesProvider);
    await _ref.read(cafeRepositoryProvider).clearCache();
    if (refreshAdminList) {
      await _ref.read(adminCafeListControllerProvider.notifier).refresh();
    }
    if (refreshCafes) {
      await _ref.read(cafeProvider.notifier).refreshCafes();
    }
  }

  Future<ServiceResult<Cafe>> addCafe(CafeAdminUpdateInput input) async {
    if (!mounted) {
      return ServiceResult.failure(
        message: 'Cafe mutation controller is not active.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    final service = _ref.read(cafeCommandServiceProvider);
    if (service == null) {
      return ServiceResult.failure(
        message: 'Cafe admin service is unavailable.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    final readiness = await _ensureSecurityReadinessForAdminMutation();
    if (!readiness.ok) {
      return ServiceResult.failure(
        message: readiness.message,
        errorCode: readiness.errorCode,
        errorType: readiness.errorType,
      );
    }

    if (!mounted) {
      return ServiceResult.failure(
        message: 'Cafe mutation controller is not active.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    state = const async_result.AsyncLoading();
    final result = await service.addCafe(input);
    if (!mounted) {
      return result;
    }
    state = result.ok
        ? const async_result.AsyncData(null)
        : async_result.AsyncError<void>(
            result.errorCode ?? AppErrorCode.cafeAddFailed,
            debugMessage: result.message,
            originalError: result.error,
          );

    if (result.ok && result.data != null) {
      _ref.read(cafeProvider.notifier).upsertCafe(result.data!);
      _ref.read(analyticsServiceProvider).trackAdminCafeAdded(result.data!.id);
      await _refreshCanonicalCafeStateAfterMutation(refreshCafes: false);
    }

    return result;
  }

  Future<ServiceResult<Cafe>> importDiscoveredCafe(Cafe cafe) async {
    final placeId = cafe.placeId?.trim();
    if (placeId == null || placeId.isEmpty) {
      return ServiceResult.failure(
        message: 'Google Place ID is required for discovered cafe import.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }
    if (_isCafeMutationPending(placeId)) {
      return ServiceResult.failure(
        message: 'Import already in progress for this cafe.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }

    final alreadySaved = _ref.read(adminCafesProvider).any((savedCafe) {
      return _discoveredCafeIdentityKeys(savedCafe)
          .intersection(_discoveredCafeIdentityKeys(cafe))
          .isNotEmpty;
    });
    if (alreadySaved) {
      return ServiceResult.failure(
        message: 'Cafe already exists in Supabase.',
        errorCode: AppErrorCode.dataConflict,
        errorType: ServiceErrorType.conflict,
      );
    }

    _setCafeMutationPending(placeId, true);
    try {
      final input = CafeAdminUpdateInput(
        name: cafe.name,
        category: cafe.category.value,
        district: cafe.district,
        neighborhood: cafe.neighborhood,
        address: cafe.address,
        description: cafe.description,
        priceLevel: cafe.hasPriceLevel ? cafe.priceLevel.value : null,
        tags: cafe.tags,
        wifiQuality: cafe.wifiQuality.value,
        outletAvailability: cafe.outletAvailability.value,
        quietnessLevel: cafe.quietnessLevel.value,
        studyFriendly: cafe.studyFriendly,
        petFriendly: cafe.petFriendly,
        outdoorSeating: cafe.outdoorSeating,
        smokingPolicy: cafe.smokingPolicy.value,
        openingHours: cafe.openingHours,
        images: cafe.photoUrls,
        menuHighlights: cafe.menuHighlights,
        googlePlaceId: placeId,
        ownerApprovalStatus: 'approved',
        ownerUserId: null,
        isDeleted: false,
        isFeatured: false,
      );
      final result = await addCafe(input);
      if (result.ok) {
        _ref.invalidate(adminDiscoveredCafesProvider);
      }
      return result;
    } finally {
      _setCafeMutationPending(placeId, false);
    }
  }

  Future<ServiceResult<Cafe>> updateCafe(
    String cafeId,
    CafeAdminUpdateInput input,
  ) async {
    if (!mounted) {
      return ServiceResult.failure(
        message: 'Cafe mutation controller is not active.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    final service = _ref.read(cafeCommandServiceProvider);
    if (service == null) {
      return ServiceResult.failure(
        message: 'Cafe admin service is unavailable.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    final permission = await _ensureCafeUpdatePermission(cafeId);
    if (!permission.ok) {
      return ServiceResult.failure(
        message: permission.message,
        errorCode: permission.errorCode,
        errorType: permission.errorType,
      );
    }

    if (!mounted) {
      return ServiceResult.failure(
        message: 'Cafe mutation controller is not active.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    state = const async_result.AsyncLoading();

    final isAdminUpdate = permission.data == true;
    final effectiveInput = isAdminUpdate
        ? input
        : CafeAdminUpdateInput(
            name: input.name,
            category: input.category,
            district: input.district,
            neighborhood: input.neighborhood,
            address: input.address,
            description: input.description,
            priceLevel: input.priceLevel,
            tags: input.tags,
            wifiQuality: input.wifiQuality,
            outletAvailability: input.outletAvailability,
            quietnessLevel: input.quietnessLevel,
            studyFriendly: input.studyFriendly,
            petFriendly: input.petFriendly,
            outdoorSeating: input.outdoorSeating,
            smokingPolicy: input.smokingPolicy,
            openingHours: input.openingHours,
            menuHighlights: input.menuHighlights,
          );

    final result = isAdminUpdate
        ? await service.updateCafeByAdmin(cafeId, effectiveInput)
        : await service.updateCafeByOwner(cafeId, effectiveInput);

    if (!mounted) {
      return result;
    }

    state = result.ok
        ? const async_result.AsyncData(null)
        : async_result.AsyncError<void>(
            result.errorCode ?? AppErrorCode.cafeUpdateFailed,
            debugMessage: result.message,
            originalError: result.error,
          );

    if (result.ok && result.data != null) {
      final updatedCafe = result.data!;
      final previousCafe = _ref.read(cafesProvider).where((cafe) {
        return cafe.canonicalIdentityKey == updatedCafe.canonicalIdentityKey ||
            cafe.id == cafeId ||
            cafe.placeId == cafeId;
      }).firstOrNull;
      final featuredVisibilityChanged = previousCafe == null
          ? updatedCafe.isActiveFeatured
          : previousCafe.isActiveFeatured != updatedCafe.isActiveFeatured ||
              previousCafe.isFeatured != updatedCafe.isFeatured ||
              previousCafe.isVisibleInPublic != updatedCafe.isVisibleInPublic;
      _ref.read(analyticsServiceProvider).trackAdminCafeUpdated(updatedCafe.id);
      // Patch the single cafe in-memory — no full reload needed.
      _ref.invalidate(adminCafeDetailsProvider(cafeId));
      _ref.read(cafeProvider.notifier).upsertCafe(
            updatedCafe,
            preserveExistingMedia: !effectiveInput.clearImages,
          );
      await _refreshCanonicalCafeStateAfterMutation(
        refreshCafes: featuredVisibilityChanged,
      );
    }

    return result;
  }

  /// Soft-deletes a cafe and immediately removes it from the visible list.
  Future<ServiceResult<Cafe>> deleteCafe(String cafeId) async {
    if (!mounted) {
      return ServiceResult.failure(
        message: 'Cafe mutation controller is not active.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    final normalizedCafeId = cafeId.trim();
    AppLogger.debug(
      '[ADMIN_DELETE_TAP] requestedId=$normalizedCafeId',
      key: 'admin-delete-tap-$normalizedCafeId',
      throttle: Duration.zero,
    );
    if (normalizedCafeId.isEmpty) {
      return ServiceResult.failure(
        message: 'Cafe id is required for delete.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }
    if (_isCafeMutationPending(normalizedCafeId)) {
      return ServiceResult.failure(
        message: 'Delete already in progress for this cafe.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }

    _setCafeMutationPending(normalizedCafeId, true);
    AppLogger.debug(
      '[ADMIN_DELETE_CONTROLLER] phase=entry requestedId=$normalizedCafeId',
      key: 'admin-delete-controller-$normalizedCafeId',
      throttle: Duration.zero,
    );
    AppLogger.debug(
      '[ADMIN_DELETE_CONTROLLER_ENTER] controllerMethod=CafeAdminMutationController.deleteCafe selectedId=$normalizedCafeId',
      key: 'admin-delete-controller-enter-$normalizedCafeId',
      throttle: Duration.zero,
    );

    final matchedCafe = await _resolveDeleteTargetCafe(normalizedCafeId);
    final placeId = matchedCafe?.placeId?.trim();
    final resolvedId = matchedCafe?.id.trim() ?? '';
    final resolvedPlaceId = placeId ?? '';
    final resolutionPath = matchedCafe == null
        ? 'unresolved'
        : (resolvedId == normalizedCafeId
            ? 'id'
            : (resolvedPlaceId == normalizedCafeId || resolvedPlaceId.isNotEmpty
                ? 'google_place_id'
                : 'unresolved'));
    AppLogger.debug(
      '[ADMIN_DELETE_TARGET] requestedId=$normalizedCafeId resolvedId=${matchedCafe?.id ?? ''} placeId=${placeId ?? ''} google_place_id=${placeId ?? ''}',
      key: 'admin-delete-target-$normalizedCafeId',
      throttle: Duration.zero,
    );
    AppLogger.debug(
      '[ADMIN_DELETE_RESOLUTION] requestedId=$normalizedCafeId hasCafe=${matchedCafe != null} hasPlaceId=${resolvedPlaceId.isNotEmpty} path=$resolutionPath',
      key: 'admin-delete-resolution-$normalizedCafeId',
      throttle: Duration.zero,
    );
    AppLogger.debug(
      '[ADMIN_DELETE_IDENTITY] id=$normalizedCafeId placeId=${placeId ?? ''} googlePlaceId=${placeId ?? ''} canonicalKey=${matchedCafe == null ? '' : matchedCafe.canonicalIdentityKey.hashCode.abs()}',
      key: 'admin-delete-identity-$normalizedCafeId',
      throttle: Duration.zero,
    );
    final adminId = _ref.read(currentUserProvider)?.id;
    final shellState = _ref.read(appShellProvider);
    AppLogger.debug(
      '[ADMIN_DELETE_AUTH] authUid=${adminId == null ? 'no' : 'yes'} profileRow=${shellState.isAdminRoleResolved ? 'yes' : 'no'} adminSource=${shellState.isAdmin ? 'role' : (shellState.isAdminRoleResolved ? 'not_admin' : 'unresolved')}',
      key: 'admin-delete-auth-$normalizedCafeId',
      throttle: Duration.zero,
    );
    final service = _ref.read(cafeCommandServiceProvider);
    if (service == null) {
      _setCafeMutationPending(normalizedCafeId, false);
      return ServiceResult.failure(
        message: 'Cafe admin service is unavailable.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    final readiness = await _ensureSecurityReadinessForAdminMutation();
    if (!readiness.ok) {
      _setCafeMutationPending(normalizedCafeId, false);
      return ServiceResult.failure(
        message: readiness.message,
        errorCode: readiness.errorCode,
        errorType: readiness.errorType,
      );
    }

    if (!mounted) {
      _setCafeMutationPending(normalizedCafeId, false);
      return ServiceResult.failure(
        message: 'Cafe mutation controller is not active.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    state = const async_result.AsyncLoading();
    try {
      AppLogger.debug(
        '[ADMIN_DELETE_SERVICE] requestedId=$normalizedCafeId resolvedId=$resolvedId placeId=${placeId ?? ''} adminPresent=${adminId != null}',
        key: 'admin-delete-service-$normalizedCafeId',
        throttle: Duration.zero,
      );
      final serviceCafeId =
          resolvedId.isNotEmpty ? resolvedId : normalizedCafeId;
      final result = await service.softDeleteCafe(
        cafeId: serviceCafeId,
        externalPlaceId: placeId,
        deletedBy: adminId,
      );
      if (!mounted) {
        return result;
      }

      state = result.ok
          ? const async_result.AsyncData(null)
          : async_result.AsyncError<void>(
              result.errorCode ?? AppErrorCode.cafeUpdateFailed,
              debugMessage: result.message,
              originalError: result.error,
            );
      AppLogger.debug(
        '[ADMIN_DELETE_RESULT] requestedId=$normalizedCafeId ok=${result.ok} errorCode=${result.errorCode ?? ''} resultId=${result.data?.id ?? ''} placeId=${result.data?.placeId ?? ''} message=${result.message ?? ''}',
        key: 'admin-delete-result-$normalizedCafeId',
        throttle: Duration.zero,
      );

      if (result.ok) {
        final deletedCafe = result.data;
        _ref
            .read(analyticsServiceProvider)
            .trackAdminCafeDeleted(deletedCafe?.id ?? normalizedCafeId);
        final removalKeys = <String>{normalizedCafeId};
        if (placeId != null && placeId.isNotEmpty) {
          removalKeys.add(placeId);
        }
        if (matchedCafe != null) {
          removalKeys.addAll(_mutationCafeIdentityKeys(matchedCafe));
        }
        var removedFavorites = 0;
        var removedCompare = 0;
        var removedCache = 0;
        if (deletedCafe != null) {
          removalKeys.addAll(_mutationCafeIdentityKeys(deletedCafe));
        }
        var expanded = true;
        while (expanded) {
          expanded = false;
          for (final cafe in <Cafe>[
            ..._ref.read(cafesProvider),
            ..._ref.read(homeCafesProvider),
            ..._ref.read(cafeProvider).featuredCafes,
            ..._ref.read(adminCafeListControllerProvider).cafes,
          ]) {
            final id = cafe.id.trim();
            final place = cafe.placeId?.trim();
            final matches = removalKeys.contains(id) ||
                (place != null &&
                    place.isNotEmpty &&
                    removalKeys.contains(place));
            if (!matches) {
              continue;
            }
            if (id.isNotEmpty && removalKeys.add(id)) {
              expanded = true;
            }
            if (place != null && place.isNotEmpty && removalKeys.add(place)) {
              expanded = true;
            }
            for (final key in _mutationCafeIdentityKeys(cafe)) {
              if (removalKeys.add(key)) {
                expanded = true;
              }
            }
          }
        }

        final cafeRemoval =
            _ref.read(cafeProvider.notifier).removeCafesByIdentity(removalKeys);
        final removedAdmin = _ref
            .read(adminCafeListControllerProvider.notifier)
            .removeCafesByIdentity(removalKeys);
        _registerDeletedCafeIdentities(removalKeys);

        final storage = _ref.read(localStorageServiceProvider);
        final scope = _ref.read(currentUserProvider)?.id ?? 'guest';
        if (storage != null) {
          final favorites = await storage.loadFavorites(scope);
          final filteredFavorites = favorites
              .where((id) => !removalKeys.contains(id.trim()))
              .toList(growable: false);
          removedFavorites = favorites.length - filteredFavorites.length;
          if (removedFavorites > 0) {
            await storage.saveFavorites(scope, filteredFavorites);
          }

          final compareList = await storage.loadCompareList(scope);
          final filteredCompare = compareList
              .where((id) => !removalKeys.contains(id.trim()))
              .toList(growable: false);
          removedCompare = compareList.length - filteredCompare.length;
          if (removedCompare > 0) {
            await storage.saveCompareList(scope, filteredCompare);
          }

          AppLogger.debug(
            '[ADMIN_DELETE_CACHE] requestedId=$normalizedCafeId favoritesRemoved=$removedFavorites compareRemoved=$removedCompare',
            key: 'admin-delete-cache-$normalizedCafeId',
            throttle: Duration.zero,
          );
        } else {
          AppLogger.debug(
            '[ADMIN_DELETE_CACHE] requestedId=$normalizedCafeId storageUnavailable=true',
            key: 'admin-delete-cache-$normalizedCafeId',
            throttle: Duration.zero,
          );
        }

        removedCache =
            await _ref.read(cafeRepositoryProvider).removeCafeFromCache(
                  removalKeys,
                );
        AppLogger.debug(
          '[CAFE_CACHE_PURGE] id=$normalizedCafeId placeId=${placeId ?? ''} canonicalKey=${matchedCafe == null ? '' : matchedCafe.canonicalIdentityKey.hashCode.abs()} source=cache/provider removed=$removedCache',
          key: 'cafe-cache-purge-$normalizedCafeId',
          throttle: Duration.zero,
        );
        final profileBefore = _ref.read(profileProvider);
        _ref.read(profileProvider.notifier).removeCafeReferences(removalKeys);
        final profileAfter = _ref.read(profileProvider);
        removedFavorites =
            profileBefore.favorites.length - profileAfter.favorites.length;
        removedCompare =
            profileBefore.compareList.length - profileAfter.compareList.length;
        for (final key in removalKeys) {
          _ref.invalidate(adminCafeDetailsProvider(key));
          _ref.invalidate(cafeByIdProvider(key));
        }
        _invalidateAfterAdminDelete(
          normalizedCafeId: normalizedCafeId,
          placeId: placeId,
        );
        AppLogger.debug(
          '[ADMIN_DELETE_LOCAL_CLEANUP] removedFeatured=${cafeRemoval.removedFeatured} removedHome=${cafeRemoval.removedHome} removedAdmin=$removedAdmin removedFavorites=$removedFavorites removedCompare=$removedCompare removedCache=$removedCache',
          key: 'admin-delete-local-cleanup-$normalizedCafeId',
          throttle: Duration.zero,
        );
        AppLogger.debug(
          '[ADMIN_DELETE_REMOVE] requestedId=$normalizedCafeId removalKeys=${removalKeys.join(",")} cafesRemoved=${cafeRemoval.removedCafes} homeRemoved=${cafeRemoval.removedHome} featuredRemoved=${cafeRemoval.removedFeatured}',
          key: 'admin-delete-remove-$normalizedCafeId',
          throttle: Duration.zero,
        );

        AppLogger.debug(
          '[ADMIN_MUTATION_REFRESH] refreshAdminList=false refreshCafes=false',
          key: 'admin-mutation-refresh-delete-$normalizedCafeId',
          throttle: Duration.zero,
        );
        _ref.invalidate(resolvedFavoriteCafesProvider);
        _ref.invalidate(resolvedComparedCafesProvider);
        _ref.invalidate(comparedCafesProvider);
        _ref.invalidate(comparedResolvedCafesProvider);
      }
      return result;
    } finally {
      _setCafeMutationPending(normalizedCafeId, false);
    }
  }

  void logDeletePostVerify({
    required String deletedId,
    required bool stillInRoute,
  }) {
    final normalized = deletedId.trim();
    if (normalized.isEmpty) {
      return;
    }

    bool matchesCafe(Cafe cafe) {
      if (cafe.id == normalized) {
        return true;
      }
      final placeId = cafe.placeId?.trim();
      return placeId != null && placeId.isNotEmpty && placeId == normalized;
    }

    final stillInDetailProvider =
        _ref.read(cafeByIdProvider(normalized)) != null;
    final stillInFeaturedProvider =
        _ref.read(activeFeaturedCafesProvider).any(matchesCafe);
    final stillInAdminList =
        _ref.read(adminCafeListControllerProvider).cafes.any(matchesCafe);

    AppLogger.debug(
      '[ADMIN_DELETE_POST_VERIFY] deletedId=$normalized stillInRoute=$stillInRoute stillInDetailProvider=$stillInDetailProvider stillInFeaturedProvider=$stillInFeaturedProvider stillInAdminList=$stillInAdminList',
      key: 'admin-delete-post-verify-$normalized',
      throttle: Duration.zero,
    );
  }

  void _registerDeletedCafeIdentities(Set<String> removalKeys) {
    final normalized =
        removalKeys.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (normalized.isEmpty) {
      return;
    }
    final current = _ref.read(deletedCafeIdentityIdsProvider);
    _ref.read(deletedCafeIdentityIdsProvider.notifier).state = {
      ...current,
      ...normalized,
    };
  }

  Set<String> _mutationCafeIdentityKeys(Cafe cafe) {
    final keys = <String>{
      cafe.id.trim(),
      cafe.canonicalIdentityKey.trim(),
      _mutationCafeFallbackIdentityKey(cafe),
    };
    final placeId = cafe.placeId?.trim();
    if (placeId != null && placeId.isNotEmpty) {
      keys.add(placeId);
      keys.add('place:$placeId');
    }
    keys.removeWhere((key) => key.isEmpty);
    return keys;
  }

  String _mutationCafeFallbackIdentityKey(Cafe cafe) {
    return 'fallback:${normalizeSearchText(cafe.name)}|${normalizeSearchText(cafe.district)}|${normalizeSearchText(cafe.neighborhood)}|${normalizeSearchText(cafe.address)}';
  }

  void _invalidateAfterAdminDelete({
    required String normalizedCafeId,
    required String? placeId,
  }) {
    _ref.invalidate(homeCafesProvider);
    _ref.invalidate(activeFeaturedCafesProvider);
    _ref.invalidate(featuredCafesProvider);
    _ref.invalidate(homeSponsoredCafesProvider);
    _ref.invalidate(searchableCafeCorpusProvider);
    _ref.invalidate(filteredCafesProvider);
    _ref.invalidate(exploreCafeResultsProvider);
    _ref.invalidate(mapFilteredCafesProvider);
    _ref.invalidate(mapVisibleCafesProvider);
    _ref.invalidate(mapCafeResultsProvider);
    _ref.invalidate(adminCafesProvider);
    AppLogger.debug(
      '[ADMIN_DELETE_INVALIDATE] id=$normalizedCafeId placeId=${placeId ?? ''} providers=detail,home,featured,search,explore,map,admin',
      key: 'admin-delete-invalidate-$normalizedCafeId',
      throttle: Duration.zero,
    );
  }

  Future<ServiceResult<Cafe>> restoreCafe(String cafeId) async {
    if (!mounted) {
      return ServiceResult.failure(
        message: 'Cafe mutation controller is not active.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    final normalizedCafeId = cafeId.trim();
    if (normalizedCafeId.isEmpty) {
      return ServiceResult.failure(
        message: 'Cafe id is required for restore.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }
    if (_isCafeMutationPending(normalizedCafeId)) {
      return ServiceResult.failure(
        message: 'Restore already in progress for this cafe.',
        errorCode: AppErrorCode.validationFailed,
        errorType: ServiceErrorType.validation,
      );
    }

    _setCafeMutationPending(normalizedCafeId, true);

    final service = _ref.read(cafeCommandServiceProvider);
    if (service == null) {
      _setCafeMutationPending(normalizedCafeId, false);
      return ServiceResult.failure(
        message: 'Cafe admin service is unavailable.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    final readiness = await _ensureSecurityReadinessForAdminMutation();
    if (!readiness.ok) {
      _setCafeMutationPending(normalizedCafeId, false);
      return ServiceResult.failure(
        message: readiness.message,
        errorCode: readiness.errorCode,
        errorType: readiness.errorType,
      );
    }

    if (!mounted) {
      _setCafeMutationPending(normalizedCafeId, false);
      return ServiceResult.failure(
        message: 'Cafe mutation controller is not active.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    state = const async_result.AsyncLoading();
    try {
      final result = await service.restoreCafe(cafeId: normalizedCafeId);
      if (!mounted) {
        return result;
      }

      state = result.ok
          ? const async_result.AsyncData(null)
          : async_result.AsyncError<void>(
              result.errorCode ?? AppErrorCode.cafeUpdateFailed,
              debugMessage: result.message,
              originalError: result.error,
            );

      if (result.ok && result.data != null) {
        final restoredCafe = result.data!;
        _ref
            .read(analyticsServiceProvider)
            .trackAdminCafeRestored(restoredCafe.id);
        _ref.invalidate(adminCafeDetailsProvider(normalizedCafeId));
        _ref.read(cafeProvider.notifier).upsertCafe(restoredCafe);
        await _refreshCanonicalCafeStateAfterMutation();
      }

      return result;
    } finally {
      _setCafeMutationPending(normalizedCafeId, false);
    }
  }
}

class ProfileUpdatePayload {
  const ProfileUpdatePayload({
    required this.firstName,
    required this.lastName,
    required this.username,
    this.avatarBytes,
    this.avatarExtension,
    this.removeAvatar = false,
  });

  final String firstName;
  final String lastName;
  final String username;
  final Uint8List? avatarBytes;
  final String? avatarExtension;
  final bool removeAvatar;
}

final profileUpdateControllerProvider = StateNotifierProvider.autoDispose<
    ProfileUpdateController, async_result.AsyncResult<void>>((ref) {
  return ProfileUpdateController(ref);
});

class ProfileUpdateController
    extends StateNotifier<async_result.AsyncResult<void>> {
  ProfileUpdateController(this._ref)
      : super(const async_result.AsyncData(null));

  final Ref _ref;

  Future<ServiceResult<void>> saveProfile(ProfileUpdatePayload payload) async {
    final user = _ref.read(currentUserProvider);
    final connectivity = _ref.read(connectivityServiceProvider);
    final offlineSync = _ref.read(offlineSyncProvider.notifier);
    final service = _ref.read(profilesServiceProvider);

    if (user == null) {
      return ServiceResult.failure(
        message: 'No authenticated user is available.',
        errorType: ServiceErrorType.auth,
      );
    }
    if (service == null) {
      return ServiceResult.failure(
        message: 'Profile service is unavailable.',
        errorType: ServiceErrorType.unavailable,
      );
    }

    state = const async_result.AsyncLoading();

    final fullName = '${payload.firstName} ${payload.lastName}'.trim();
    final previousAvatarReference = user.avatarUrl;
    var nextAvatarStoredValue =
        payload.removeAvatar ? null : previousAvatarReference;
    var nextAvatarDisplayUrl = nextAvatarStoredValue;

    Future<void> queueOfflineUpdate() async {
      await offlineSync.enqueueProfileUpdate({
        'userId': user.id,
        'first_name': payload.firstName,
        'last_name': payload.lastName,
        'full_name': fullName,
        'username': payload.username,
        'avatarBytes': payload.avatarBytes?.toList(growable: false),
        'avatarExtension': payload.avatarExtension,
        'removeAvatar': payload.removeAvatar,
        'previousAvatarUrl': previousAvatarReference,
      });

      _ref.read(profileProvider.notifier).updateCurrentUser(
            (u) => CurrentUser(
              id: u.id,
              email: u.email,
              name: fullName,
              username: payload.username,
              firstName: payload.firstName,
              lastName: payload.lastName,
              avatarUrl: payload.removeAvatar ? null : u.avatarUrl,
              isAdmin: u.isAdmin,
            ),
          );
    }

    if (!connectivity.currentlyOnline) {
      await queueOfflineUpdate();
      state = const async_result.AsyncData(null);
      return ServiceResult.success(
          message: ServiceResultMessages.offlineQueued);
    }

    if (payload.avatarBytes != null &&
        payload.avatarBytes!.isNotEmpty &&
        payload.avatarExtension != null &&
        payload.avatarExtension!.isNotEmpty) {
      final uploadResult = await service.uploadAvatar(
        userId: user.id,
        bytes: payload.avatarBytes!,
        fileExtension: payload.avatarExtension!,
      );
      if (!uploadResult.ok || uploadResult.data == null) {
        if (uploadResult.errorType.isTransient) {
          await queueOfflineUpdate();
          state = const async_result.AsyncData(null);
          return ServiceResult.success(
            message: ServiceResultMessages.offlineQueued,
          );
        }
        state = async_result.AsyncError<void>(
          uploadResult.errorCode ?? AppErrorCode.avatarUploadFailed,
          debugMessage: uploadResult.message,
          originalError: uploadResult.error,
        );
        return ServiceResult.failure(
          message: uploadResult.message,
          error: uploadResult.error,
          errorCode: uploadResult.errorCode,
          errorType: uploadResult.errorType,
        );
      }
      nextAvatarStoredValue = uploadResult.data!.path;
      nextAvatarDisplayUrl =
          await service.resolveAvatarUrl(nextAvatarStoredValue) ??
              uploadResult.data!.publicUrl;
    }

    final result = await service.updateProfile(user.id, {
      'first_name': payload.firstName,
      'last_name': payload.lastName,
      'full_name': fullName,
      'username': payload.username,
      'avatar_url': nextAvatarStoredValue,
    });

    if (!result.ok) {
      if (result.errorType.isTransient) {
        await queueOfflineUpdate();
        state = const async_result.AsyncData(null);
        return ServiceResult.success(
            message: ServiceResultMessages.offlineQueued);
      }
      if (payload.avatarBytes != null &&
          nextAvatarStoredValue != previousAvatarReference) {
        await service.deleteAvatarByPublicUrl(nextAvatarStoredValue);
      }
      state = async_result.AsyncError<void>(
        result.errorCode ?? AppErrorCode.profileUpdateFailed,
        debugMessage: result.message,
        originalError: result.error,
      );
      return result;
    }

    if (previousAvatarReference != null &&
        previousAvatarReference != nextAvatarStoredValue) {
      await service.deleteAvatarByPublicUrl(previousAvatarReference);
    }

    _ref.read(profileProvider.notifier).updateCurrentUser(
          (u) => CurrentUser(
            id: u.id,
            email: u.email,
            name: fullName,
            username: payload.username,
            firstName: payload.firstName,
            lastName: payload.lastName,
            avatarUrl: nextAvatarDisplayUrl,
            isAdmin: u.isAdmin,
          ),
        );

    state = const async_result.AsyncData(null);
    return result;
  }
}

/// Google Places-backed discovery service used for remote cafe hydration.
final placesServiceProvider = Provider<PlacesService>((ref) {
  final service = PlacesService(
    districtCatalogLoader: () => ref.read(activeDistrictsProvider),
    cityDisplayNameLoader: () => ref.read(discoveryCityDisplayNameProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Repository combining remote cafe data, in-flight deduping, and local cache.
final cafeRepositoryProvider = Provider<CafeRepository>((ref) {
  final repository = CafeRepository(
    ref.watch(placesServiceProvider),
    ref.watch(cafeQueryServiceProvider),
    ref.watch(localStorageServiceProvider),
    ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Repository for app-level profile reads.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(profilesServiceProvider));
});

/// Placeholder social service to keep the app ready for a future friends layer.
final friendsServiceProvider = Provider<FriendsServiceBase>((ref) {
  return const NoopFriendsService();
});

/// Repository wrapper for future friend relationships and map presence.
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepository(ref.watch(friendsServiceProvider));
});

/// Optional persistent device storage for cached app state.
final localStorageServiceProvider =
    Provider<LocalStorageService?>((ref) => null);
