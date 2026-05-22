import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../constants/app_cache_config.dart';
import '../constants/error_codes.dart';
import '../constants/network_config.dart';
import '../constants/security_config.dart';
import '../models/cafe_cache.dart';
import '../models/async_result.dart' as async_result;
import '../models/index.dart';
import '../models/service_result.dart';
import '../providers/district_providers.dart';
import '../repositories/cafe_merge_policy.dart';
import '../repositories/cafe_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/profile_repository.dart';
import '../services/connectivity_service.dart';
import '../services/analytics_service.dart';
import '../services/favorites_service.dart';
import '../services/friends_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/offline_queue.dart';
import '../services/places_service.dart';
import '../services/reviews_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/cafe_cache_keys.dart';
import '../utils/cafe_cache_policy.dart';
import '../utils/cafe_branching.dart';
import '../utils/cafe_discovery_classifier.dart';
import '../utils/cafe_discovery_debug_report.dart';
import '../utils/cafe_media.dart';
import '../utils/cafe_utils.dart';
import '../utils/district_utils.dart';
import '../utils/filter_sort.dart';
import '../utils/input_validation.dart';
import '../utils/istanbul_region.dart';
import '../utils/log_sanitizer.dart';
import '../utils/request_cancellation.dart';
import '../utils/service_error.dart';
import '../utils/text_normalization.dart';

part 'app_services.dart';
part 'cafe_controller.dart';
part 'profile_controller.dart';
part 'friends_controller.dart';
part 'offline_sync_notifier.dart';
part 'app_selectors.dart';

enum AppStartupStatus {
  idle,
  hydrating,
  ready,
}

enum CafeSyncState {
  ready,
  loading,
  showingCachedWhileRefreshing,
  empty,
  error,
  errorWithCache,
}

enum MapRadiusPreset {
  small(1000),
  medium(2000),
  large(4000);

  const MapRadiusPreset(this.radiusMeters);

  static const MapRadiusPreset defaultPreset = MapRadiusPreset.small;

  final int radiusMeters;
}

class AppShellState {
  const AppShellState({
    this.startupStatus = AppStartupStatus.idle,
    this.themeMode = AppThemeMode.system,
    this.currentUser,
    this.isAuthReady = false,
    this.isOnboardingCompleted = false,
    this.isAdmin = false,
    this.isAdminRoleResolved = false,
    this.adminRoleStatusMessage,
    this.isSigningOut = false,
  });

  final AppStartupStatus startupStatus;
  final AppThemeMode themeMode;
  final CurrentUser? currentUser;
  final bool isAuthReady;
  final bool isOnboardingCompleted;
  final bool isAdmin;
  final bool isAdminRoleResolved;
  final String? adminRoleStatusMessage;
  final bool isSigningOut;

  AppShellState copyWith({
    AppStartupStatus? startupStatus,
    AppThemeMode? themeMode,
    CurrentUser? Function()? currentUser,
    bool? isAuthReady,
    bool? isOnboardingCompleted,
    bool? isAdmin,
    bool? isAdminRoleResolved,
    String? Function()? adminRoleStatusMessage,
    bool? isSigningOut,
  }) {
    return AppShellState(
      startupStatus: startupStatus ?? this.startupStatus,
      themeMode: themeMode ?? this.themeMode,
      currentUser: currentUser != null ? currentUser() : this.currentUser,
      isAuthReady: isAuthReady ?? this.isAuthReady,
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
      isAdmin: isAdmin ?? this.isAdmin,
      isAdminRoleResolved: isAdminRoleResolved ?? this.isAdminRoleResolved,
      adminRoleStatusMessage: adminRoleStatusMessage != null
          ? adminRoleStatusMessage()
          : this.adminRoleStatusMessage,
      isSigningOut: isSigningOut ?? this.isSigningOut,
    );
  }
}

enum AdminRoleResolutionState {
  loading,
  resolvedAdmin,
  resolvedNonAdmin,
  failed,
}

extension AppShellAdminRoleResolutionX on AppShellState {
  AdminRoleResolutionState get adminRoleResolutionState {
    if (currentUser == null || !isAuthReady) {
      return AdminRoleResolutionState.loading;
    }
    if (isAdminRoleResolved) {
      return isAdmin
          ? AdminRoleResolutionState.resolvedAdmin
          : AdminRoleResolutionState.resolvedNonAdmin;
    }
    if (adminRoleStatusMessage?.trim().isNotEmpty == true) {
      return AdminRoleResolutionState.failed;
    }
    return AdminRoleResolutionState.loading;
  }
}

typedef AdminRoleResolution = ({
  bool isAdmin,
  bool isAdminRoleResolved,
  String? adminRoleStatusMessage,
});

AdminRoleResolution resolveAdminRoleState({
  required AppShellState previousState,
  required String userId,
  required UserProfile? profile,
  required ServiceResult<UserProfile?> profileResult,
  required String unresolvedMessage,
}) {
  if (profile != null) {
    return (
      isAdmin: profile.role == ProfileRole.admin,
      isAdminRoleResolved: true,
      adminRoleStatusMessage: null,
    );
  }

  final preservesPreviousAdminRole = previousState.currentUser?.id == userId &&
      previousState.isAdminRoleResolved &&
      !profileResult.ok &&
      (profileResult.errorType == ServiceErrorType.timeout ||
          profileResult.errorType == ServiceErrorType.network ||
          profileResult.errorType == ServiceErrorType.rateLimit ||
          profileResult.errorType == ServiceErrorType.unavailable ||
          profileResult.errorType == ServiceErrorType.cancelled);

  if (preservesPreviousAdminRole) {
    return (
      isAdmin: previousState.isAdmin,
      isAdminRoleResolved: true,
      adminRoleStatusMessage: null,
    );
  }

  return (
    isAdmin: false,
    isAdminRoleResolved: false,
    adminRoleStatusMessage: unresolvedMessage,
  );
}

bool isTransientAdminRoleLookupFailure(
  ServiceResult<UserProfile?> profileResult,
) {
  if (profileResult.ok) {
    return false;
  }

  return profileResult.errorType == ServiceErrorType.cancelled ||
      profileResult.errorType.isTransient;
}

class AppShellNotifier extends StateNotifier<AppShellState> {
  AppShellNotifier(this._ref,
      {AppShellState initialState = const AppShellState()})
      : super(initialState) {
    _init();
  }

  AppShellNotifier.test(this._ref,
      {AppShellState initialState = const AppShellState()})
      : super(initialState);

  final Ref _ref;
  StreamSubscription<AuthState>? _authSub;
  Future<void>? _startupFuture;
  int _authBootstrapGeneration = 0;
  String? _activeBootstrapUserId;
  Future<void>? _activeBootstrapFuture;

  void _init() {
    if (!Env.hasGooglePlacesConfig) {
      AppLogger.warn(
        'Google Places API key is not configured. Cafes cannot be loaded.',
        key: 'missing-google-places-config',
      );
    }

    if (!Env.hasGoogleMapsConfig) {
      AppLogger.warn(
        'Google Maps API key is not configured. Maps will not work.',
        key: 'missing-google-maps-config',
      );
    }

    final googleApiWarnings = Env.googleApiConfigurationWarnings;
    if (googleApiWarnings.isNotEmpty) {
      for (var i = 0; i < googleApiWarnings.length; i++) {
        AppLogger.warn(
          googleApiWarnings[i],
          key: 'google-api-config-warning-${i + 1}',
        );
      }

      if (kReleaseMode) {
        AppLogger.critical(
          'Release build started with Google API configuration warnings. '
          'Review key restrictions, quota ceilings, and billing alerts before shipping.',
          key: 'google-api-config-release-risk',
        );
      }
    }

    unawaited(() async {
      try {
        final readiness = await _ref.read(securityReadinessProvider.future);
        if (readiness.shouldShowRuntimeWarning) {
          const strictMode =
              SecurityHeaders.requireRlsVerification || kReleaseMode;
          if (strictMode) {
            AppLogger.critical(
              'Security readiness check failed in strict mode: ${readiness.message}',
              key: 'security-readiness-startup-critical',
            );
          } else {
            AppLogger.warn(
              'Security readiness check failed: ${readiness.message}',
              key: 'security-readiness-startup-warning',
            );
          }
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'Security readiness check failed during startup',
          error: error,
          stackTrace: stackTrace,
          key: 'security-readiness-startup-error',
        );
      }
    }());

    unawaited(_ref.read(notificationServiceProvider).initialize());

    final client = _ref.read(supabaseClientProvider);
    if (client != null) {
      _authSub = client.auth.onAuthStateChange.listen((event) {
        _handleAuthStateChange(
          event.session,
          source: 'auth_stream:${event.event.name}',
        );
      });

      final currentSession = client.auth.currentSession;
      _handleAuthStateChange(currentSession, source: 'current_session');
    } else {
      _applySignedOutSession(source: 'no_supabase_client');
    }

    unawaited(preloadStartupState());
    _ref.read(analyticsServiceProvider).trackAppOpen();
  }

  void _scheduleSessionBootstrap({
    required int generation,
    required String source,
  }) {
    unawaited(Future<void>(() async {
      if (!mounted) {
        return;
      }
      _debugStartup(
        '[AUTH_RESTORE] phase=session_bootstrap_start source=$source generation=$generation currentUser=${state.currentUser?.id ?? 'guest'}',
        key: 'auth-restore-session-bootstrap-start-$generation',
      );
      await _ref.read(profileProvider.notifier).handleSessionChanged();
      if (!mounted || generation != _authBootstrapGeneration) {
        return;
      }
      await _ref.read(friendsProvider.notifier).handleSessionChanged();
      if (!mounted || generation != _authBootstrapGeneration) {
        return;
      }
      _debugStartup(
        '[AUTH_RESTORE] phase=session_bootstrap_done source=$source generation=$generation currentUser=${state.currentUser?.id ?? 'guest'}',
        key: 'auth-restore-session-bootstrap-done-$generation',
      );
    }));
  }

  Future<void> preloadStartupState() {
    return _startupFuture ??= _preloadStartupStateInternal();
  }

  Future<void> _preloadStartupStateInternal() async {
    state = state.copyWith(startupStatus: AppStartupStatus.hydrating);
    await _ref.read(cafeProvider.notifier).preloadStartupState();
    if (!mounted) {
      return;
    }
    state = state.copyWith(startupStatus: AppStartupStatus.ready);
  }

  void _handleAuthStateChange(
    Session? session, {
    required String source,
  }) {
    final user = session?.user;
    _debugStartup(
      '[AUTH_RESTORE] phase=event source=$source userId=${user?.id ?? 'guest'}',
      key: 'auth-restore-event-$source-${user?.id ?? 'guest'}',
    );
    if (user != null) {
      unawaited(_bootstrapAuthenticatedUser(user, source: source));
      return;
    }
    _applySignedOutSession(source: source);
  }

  void _applySignedOutSession({required String source}) {
    final generation = ++_authBootstrapGeneration;
    _activeBootstrapUserId = null;
    _activeBootstrapFuture = null;
    _debugStartup(
      '[AUTH_RESTORE] phase=signed_out source=$source generation=$generation',
      key: 'auth-restore-signed-out-$generation',
    );
    state = state.copyWith(
      currentUser: () => null,
      isAuthReady: true,
      isAdmin: false,
      isAdminRoleResolved: false,
      adminRoleStatusMessage: () => null,
    );
    _scheduleSessionBootstrap(generation: generation, source: source);
  }

  Future<void> _bootstrapAuthenticatedUser(
    User user, {
    required String source,
  }) {
    final normalizedUserId = user.id.trim();
    final activeFuture = _activeBootstrapFuture;
    if (_activeBootstrapUserId == normalizedUserId && activeFuture != null) {
      _debugStartup(
        '[AUTH_RESTORE] phase=dedupe source=$source userId=$normalizedUserId generation=$_authBootstrapGeneration',
        key: 'auth-restore-dedupe-$normalizedUserId',
      );
      return activeFuture;
    }

    final generation = ++_authBootstrapGeneration;
    _activeBootstrapUserId = normalizedUserId;
    late final Future<void> bootstrapFuture;
    bootstrapFuture = _onUserLoggedIn(
      user,
      generation: generation,
      source: source,
    ).whenComplete(() {
      if (_activeBootstrapFuture == bootstrapFuture) {
        _activeBootstrapFuture = null;
      }
      if (_activeBootstrapUserId == normalizedUserId) {
        _activeBootstrapUserId = null;
      }
    });
    _activeBootstrapFuture = bootstrapFuture;
    return bootstrapFuture;
  }

  Future<void> _onUserLoggedIn(
    User user, {
    required int generation,
    required String source,
  }) async {
    final previousState = state;
    final profileService = _ref.read(profilesServiceProvider);
    _debugStartup(
      '[PROFILE_FETCH] phase=start source=$source generation=$generation userId=${user.id}',
      key: 'profile-fetch-start-${user.id}-$generation',
    );
    final profileResult = profileService == null
        ? ServiceResult<UserProfile?>.failure(
            message: 'Profile service is unavailable.',
            errorCode: AppErrorCode.serviceUnavailable,
            errorType: ServiceErrorType.unavailable,
          )
        : await profileService.fetchProfileById(user.id);
    if (!mounted || generation != _authBootstrapGeneration) {
      _debugStartup(
        '[PROFILE_FETCH] phase=stale source=$source generation=$generation userId=${user.id}',
        key: 'profile-fetch-stale-${user.id}-$generation',
      );
      return;
    }
    final profile = profileResult.ok ? profileResult.data : null;
    final profileAvatarSummary = summarizeUrlForLog(
      profile?.avatarUrl,
      presenceLabel: 'hasAvatar',
    );
    _debugStartup(
      '[PROFILE_FETCH] phase=result source=$source generation=$generation userId=${user.id} ok=${profileResult.ok} role=${profile?.role.name ?? 'null'} avatar=$profileAvatarSummary errorType=${profileResult.errorType.name}',
      key: 'profile-fetch-result-${user.id}-$generation',
    );

    final metadataName = _metadataString(
      user.userMetadata,
      const ['full_name', 'name'],
    );
    final metadataUsername = _metadataString(
      user.userMetadata,
      const ['preferred_username', 'username', 'user_name'],
    );
    final metadataFirstName = _metadataString(
      user.userMetadata,
      const ['first_name', 'given_name'],
    );
    final metadataLastName = _metadataString(
      user.userMetadata,
      const ['last_name', 'family_name'],
    );
    final metadataAvatarUrl = _metadataString(
      user.userMetadata,
      const ['avatar_url', 'picture', 'avatar', 'photo_url'],
    );

    final profileFullName = profile?.fullName.trim();
    final resolvedName = (profileFullName != null && profileFullName.isNotEmpty)
        ? profileFullName
        : (metadataName ?? user.email ?? '');

    final adminResolution = resolveAdminRoleState(
      previousState: previousState,
      userId: user.id,
      profile: profile,
      profileResult: profileResult,
      unresolvedMessage: _adminRoleResolutionFailureMessage(profileResult),
    );

    final currentUser = CurrentUser(
      id: user.id,
      email: user.email ?? '',
      name: resolvedName,
      username: profile?.username ?? metadataUsername,
      firstName: profile?.firstName ?? metadataFirstName,
      lastName: profile?.lastName ?? metadataLastName,
      avatarUrl: profile?.avatarUrl ?? metadataAvatarUrl,
      isAdmin: adminResolution.isAdmin,
      role: profile?.role ?? ProfileRole.user,
    );

    final metadataAvatarSummary = summarizeUrlForLog(
      metadataAvatarUrl,
      presenceLabel: 'hasAvatar',
    );
    final resolvedAvatarSummary = summarizeUrlForLog(
      currentUser.avatarUrl,
      presenceLabel: 'hasAvatar',
    );
    _debugStartup(
      '[PROFILE_PHOTO] source=$source generation=$generation userId=${user.id} profileAvatar=$profileAvatarSummary metadataAvatar=$metadataAvatarSummary resolvedAvatar=$resolvedAvatarSummary',
      key: 'profile-photo-${user.id}-$generation',
    );
    _debugStartup(
      '[ADMIN_RESOLUTION] source=$source generation=$generation userId=${user.id} isAdmin=${adminResolution.isAdmin} resolved=${adminResolution.isAdminRoleResolved} message=${adminResolution.adminRoleStatusMessage ?? 'null'}',
      key: 'admin-resolution-${user.id}-$generation',
    );

    state = state.copyWith(
      currentUser: () => currentUser,
      isAuthReady: true,
      isAdmin: adminResolution.isAdmin,
      isAdminRoleResolved: adminResolution.isAdminRoleResolved,
      adminRoleStatusMessage: () => adminResolution.adminRoleStatusMessage,
    );

    if (!adminResolution.isAdminRoleResolved &&
        isTransientAdminRoleLookupFailure(profileResult)) {
      unawaited(refreshAdminRoleResolution(force: true));
    }

    await _ref.read(profileProvider.notifier).handleSessionChanged();
    if (!mounted || generation != _authBootstrapGeneration) {
      return;
    }
    await _ref.read(friendsProvider.notifier).handleSessionChanged();
  }

  @visibleForTesting
  Future<void> bootstrapAuthenticatedUserForTesting(
    User user, {
    String source = 'test',
  }) {
    return _bootstrapAuthenticatedUser(user, source: source);
  }

  @visibleForTesting
  void applySignedOutSessionForTesting({String source = 'test'}) {
    _applySignedOutSession(source: source);
  }

  void _debugStartup(String message, {required String key}) {
    if (!kDebugMode) {
      return;
    }
    AppLogger.debug(
      message,
      key: key,
      throttle: Duration.zero,
    );
  }

  String _adminRoleResolutionFailureMessage(
    ServiceResult<UserProfile?> profileResult,
  ) {
    if (profileResult.ok && profileResult.data == null) {
      return 'Admin status could not be verified because the profile row is missing.';
    }

    switch (profileResult.errorType) {
      case ServiceErrorType.timeout:
        return 'Admin status could not be verified because profile lookup timed out.';
      case ServiceErrorType.network:
        return 'Admin status could not be verified because profile lookup failed due to network/connectivity.';
      case ServiceErrorType.auth:
        return 'Admin status could not be verified because profile lookup was denied.';
      case ServiceErrorType.unavailable:
      case ServiceErrorType.rateLimit:
        return 'Admin status could not be verified because the profile service is temporarily unavailable.';
      case ServiceErrorType.notFound:
        return 'Admin status could not be verified because the profile row is missing.';
      default:
        return 'Admin status could not be verified because profile lookup failed at runtime.';
    }
  }

  String? _metadataString(Map<String, dynamic>? metadata, List<String> keys) {
    if (metadata == null || metadata.isEmpty) {
      return null;
    }

    for (final key in keys) {
      final raw = metadata[key];
      if (raw is! String) {
        continue;
      }
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  void reconcileAdminRoleFromProfileResult({
    required String userId,
    required ServiceResult<UserProfile?> profileResult,
  }) {
    final currentUser = state.currentUser;
    if (currentUser == null || currentUser.id != userId) {
      return;
    }

    final profile = profileResult.ok ? profileResult.data : null;
    final resolution = resolveAdminRoleState(
      previousState: state,
      userId: userId,
      profile: profile,
      profileResult: profileResult,
      unresolvedMessage: _adminRoleResolutionFailureMessage(profileResult),
    );

    state = state.copyWith(
      currentUser: () => currentUser.copyWith(
        isAdmin: resolution.isAdmin,
        role: profile?.role ?? currentUser.role,
      ),
      isAdmin: resolution.isAdmin,
      isAdminRoleResolved: resolution.isAdminRoleResolved,
      adminRoleStatusMessage: () => resolution.adminRoleStatusMessage,
    );
  }

  Future<void> refreshAdminRoleResolution({bool force = false}) async {
    final currentUser = state.currentUser;
    if (currentUser == null) {
      return;
    }
    if (!force && state.isAdminRoleResolved) {
      return;
    }

    final profileService = _ref.read(profilesServiceProvider);
    final profileResult = profileService == null
        ? ServiceResult<UserProfile?>.failure(
            message: 'Profile service is unavailable.',
            errorCode: AppErrorCode.serviceUnavailable,
            errorType: ServiceErrorType.unavailable,
          )
        : await profileService.fetchProfileById(currentUser.id);
    if (!mounted) {
      return;
    }

    reconcileAdminRoleFromProfileResult(
      userId: currentUser.id,
      profileResult: profileResult,
    );
  }

  void updateCurrentUser(CurrentUser Function(CurrentUser) updater) {
    final currentUser = state.currentUser;
    if (currentUser == null) {
      return;
    }
    state = state.copyWith(currentUser: () => updater(currentUser));
  }

  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void toggleThemeMode() {
    final next = state.themeMode == AppThemeMode.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
    state = state.copyWith(themeMode: next);
  }

  void setOnboardingCompleted(bool completed) {
    state = state.copyWith(isOnboardingCompleted: completed);
  }

  ServiceResult<void> _serviceFailureFromException(
    AppServiceException error, {
    Object? originalError,
    AppErrorCode fallbackCode = AppErrorCode.unknown,
  }) {
    return ServiceResult.failure(
      message: error.message,
      error: originalError ?? error.cause ?? error,
      errorCode: error.errorCode ?? fallbackCode,
      errorType: error.type,
    );
  }

  ServiceResult<void> _serviceFailure({
    required AppErrorCode errorCode,
    required ServiceErrorType errorType,
    Object? error,
    String? message,
  }) {
    return ServiceResult.failure(
      message: message,
      error: error,
      errorCode: errorCode,
      errorType: errorType,
    );
  }

  AppServiceException _mapAuthException(
    AuthException error, {
    required AppErrorCode fallbackCode,
  }) {
    final statusCode = error.statusCode?.trim();
    final code = error.code?.trim().toLowerCase();
    final message = error.message.toLowerCase();

    if (statusCode == '429' ||
        code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        message.contains('rate limit')) {
      return AppServiceException.auth(
        error.message,
        errorCode: AppErrorCode.authRateLimited,
        cause: error,
      );
    }

    if (code == 'email_exists' ||
        code == 'user_already_exists' ||
        code == 'identity_already_exists' ||
        code == 'email_conflict_identity_not_deletable' ||
        message.contains('already registered')) {
      return AppServiceException.conflict(
        error.message,
        errorCode: AppErrorCode.authEmailRegistered,
        cause: error,
      );
    }

    if (code == 'user_not_found' ||
        message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return AppServiceException.auth(
        error.message,
        errorCode: AppErrorCode.authInvalidCredentials,
        cause: error,
      );
    }

    if (statusCode == '408' ||
        code == 'request_timeout' ||
        code == 'hook_timeout' ||
        code == 'hook_timeout_after_retry') {
      return AppServiceException.timeout(
        error.message,
        errorCode: AppErrorCode.requestTimedOut,
        cause: error,
      );
    }

    if (statusCode == '500' ||
        statusCode == '502' ||
        statusCode == '503' ||
        statusCode == '504') {
      return AppServiceException.unavailable(
        error.message,
        errorCode: AppErrorCode.serviceUnavailable,
        cause: error,
      );
    }

    return AppServiceException.auth(
      error.message,
      errorCode: fallbackCode,
      cause: error,
    );
  }

  ServiceResult<void> _mapUnexpectedAuthError(
    Object error, {
    required String operation,
    required AppErrorCode fallbackCode,
  }) {
    if (error is AppServiceException) {
      return _serviceFailureFromException(
        error,
        originalError: error,
        fallbackCode: fallbackCode,
      );
    }
    if (error is TimeoutException) {
      return _serviceFailure(
        errorCode: AppErrorCode.requestTimedOut,
        errorType: ServiceErrorType.timeout,
        error: error,
      );
    }
    if (error is SocketException) {
      return _serviceFailure(
        errorCode: AppErrorCode.networkError,
        errorType: ServiceErrorType.network,
        error: error,
      );
    }

    final errorType = classifyServiceError(error);
    final errorCode = switch (errorType) {
      ServiceErrorType.timeout => AppErrorCode.requestTimedOut,
      ServiceErrorType.network => AppErrorCode.networkError,
      ServiceErrorType.rateLimit => AppErrorCode.authRateLimited,
      ServiceErrorType.unavailable => AppErrorCode.serviceUnavailable,
      _ => fallbackCode,
    };

    AppLogger.error(
      'AppShellNotifier.$operation failed',
      error: error,
      key: '$operation-failed',
    );

    return _serviceFailure(
      errorCode: errorCode,
      errorType: errorType,
      error: error,
    );
  }

  Future<ServiceResult<void>> signIn(String identifier, String password) async {
    final client = _ref.read(supabaseClientProvider);
    final profilesService = _ref.read(profilesServiceProvider);

    if (client == null || profilesService == null) {
      return _serviceFailure(
        errorCode: AppErrorCode.serviceUnavailable,
        errorType: ServiceErrorType.unavailable,
      );
    }

    try {
      var email = identifier.trim();
      if (!looksLikeEmail(email)) {
        final lookupResult = await profilesService
            .findEmailByUsernameResult(email)
            .timeout(NetworkTimeoutConfig.authRequestTimeout);
        if (!lookupResult.ok) {
          return _serviceFailure(
            errorCode: lookupResult.errorCode ?? AppErrorCode.profileLoadFailed,
            errorType: lookupResult.errorType,
            error: lookupResult.error,
            message: lookupResult.message,
          );
        }
        final found = lookupResult.data;
        if (found == null) {
          return _serviceFailure(
            errorCode: AppErrorCode.authInvalidCredentials,
            errorType: ServiceErrorType.auth,
          );
        }
        email = found;
      }

      await client.auth
          .signInWithPassword(
            email: normalizeEmail(email),
            password: password,
          )
          .timeout(NetworkTimeoutConfig.authRequestTimeout);

      return ServiceResult.success();
    } on AuthException catch (error) {
      AppLogger.warn(
        'AppShellNotifier.signIn auth failure status=${error.statusCode ?? 'n/a'} code=${error.code ?? 'n/a'}',
        key: 'sign-in-auth-error',
      );
      return _serviceFailureFromException(
        _mapAuthException(
          error,
          fallbackCode: AppErrorCode.authInvalidCredentials,
        ),
        originalError: error,
        fallbackCode: AppErrorCode.authInvalidCredentials,
      );
    } catch (error) {
      return _mapUnexpectedAuthError(
        error,
        operation: 'signIn',
        fallbackCode: AppErrorCode.unknown,
      );
    }
  }

  Future<ServiceResult<void>> signUp(
    String username,
    String firstName,
    String lastName,
    String email,
    String password,
  ) async {
    final client = _ref.read(supabaseClientProvider);
    final profilesService = _ref.read(profilesServiceProvider);

    if (client == null || profilesService == null) {
      return _serviceFailure(
        errorCode: AppErrorCode.serviceUnavailable,
        errorType: ServiceErrorType.unavailable,
      );
    }

    try {
      final normalizedEmail = normalizeEmail(email);
      final response = await client.auth
          .signUp(
            email: normalizedEmail,
            password: password,
          )
          .timeout(NetworkTimeoutConfig.authRequestTimeout);

      if (response.user != null) {
        try {
          await profilesService
              .createProfileIfMissing(
                id: response.user!.id,
                username: normalizeUsername(username),
                firstName: firstName.trim(),
                lastName: lastName.trim(),
                fullName: '${firstName.trim()} ${lastName.trim()}'.trim(),
                email: normalizedEmail,
              )
              .timeout(NetworkTimeoutConfig.authRequestTimeout);
        } catch (error) {
          AppLogger.error(
            'AppShellNotifier.signUp profile bootstrap failed',
            error: error,
            key: 'sign-up-profile-bootstrap-failed',
          );
          return _mapUnexpectedAuthError(
            error,
            operation: 'signUpProfileBootstrap',
            fallbackCode: AppErrorCode.profileUpdateFailed,
          );
        }
      }

      return ServiceResult.success();
    } on AuthException catch (error) {
      AppLogger.warn(
        'AppShellNotifier.signUp auth failure status=${error.statusCode ?? 'n/a'} code=${error.code ?? 'n/a'}',
        key: 'sign-up-auth-error',
      );
      return _serviceFailureFromException(
        _mapAuthException(
          error,
          fallbackCode: AppErrorCode.unknown,
        ),
        originalError: error,
      );
    } catch (error) {
      return _mapUnexpectedAuthError(
        error,
        operation: 'signUp',
        fallbackCode: AppErrorCode.unknown,
      );
    }
  }

  Future<ServiceResult<void>> resetPassword(String email) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      return _serviceFailure(
        errorCode: AppErrorCode.serviceUnavailable,
        errorType: ServiceErrorType.unavailable,
      );
    }

    try {
      await client.auth
          .resetPasswordForEmail(normalizeEmail(email))
          .timeout(NetworkTimeoutConfig.authRequestTimeout);
      return ServiceResult.success();
    } on AuthException catch (error) {
      AppLogger.warn(
        'AppShellNotifier.resetPassword auth failure status=${error.statusCode ?? 'n/a'} code=${error.code ?? 'n/a'}',
        key: 'reset-password-auth-error',
      );
      return _serviceFailureFromException(
        _mapAuthException(
          error,
          fallbackCode: AppErrorCode.authPasswordResetFailed,
        ),
        originalError: error,
        fallbackCode: AppErrorCode.authPasswordResetFailed,
      );
    } catch (error) {
      return _mapUnexpectedAuthError(
        error,
        operation: 'resetPassword',
        fallbackCode: AppErrorCode.authPasswordResetFailed,
      );
    }
  }

  Future<void> signOut() async {
    if (state.isSigningOut) {
      return;
    }

    state = state.copyWith(isSigningOut: true);
    var didSignOut = false;

    try {
      await _ref.read(supabaseClientProvider)?.auth.signOut();
      didSignOut = true;
    } catch (error) {
      AppLogger.error(
        'AppShellNotifier.signOut failed',
        error: error,
        key: 'sign-out-failed',
      );
      rethrow;
    } finally {
      if (didSignOut) {
        state = state.copyWith(
          currentUser: () => null,
          isAuthReady: true,
          isAdmin: false,
          isAdminRoleResolved: false,
          adminRoleStatusMessage: () => null,
        );
        await _ref.read(profileProvider.notifier).handleSessionChanged();
        if (mounted) {
          await _ref.read(friendsProvider.notifier).handleSessionChanged();
        }
        if (mounted) {
          _ref.read(cafeProvider.notifier).clearSelectedCafe();
        }
      }

      if (mounted) {
        state = state.copyWith(isSigningOut: false);
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final appShellProvider =
    StateNotifierProvider<AppShellNotifier, AppShellState>((ref) {
  return AppShellNotifier(ref);
});
