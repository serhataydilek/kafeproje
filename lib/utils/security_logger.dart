import 'app_logger.dart';
import '../constants/security_config.dart';

/// Logs security-related events with appropriate categorization.
///
/// Uses the security configuration to determine log levels and event types.
/// All security events should be routed through this logger for consistency.
void logSecurityEvent(
  SecurityEventType type,
  String message, {
  Object? error,
  StackTrace? stackTrace,
  String? key,
}) {
  if (!SecurityConfig.enableSecurityLogging) {
    return;
  }

  final shouldLog = _shouldLogEventType(type);
  if (!shouldLog) {
    return;
  }

  final eventKey = 'security-${type.name}${key != null ? '-$key' : ''}';

  _logByLevel(
    type: type,
    message: message,
    error: error,
    stackTrace: stackTrace,
    eventKey: eventKey,
  );
}

/// Logs authentication failure events specifically.
void logAuthFailure(
  String reason, {
  String? userId,
  String? operation,
  Object? error,
}) {
  if (!SecurityConfig.logAuthFailures) {
    return;
  }

  final details = <String>[
    reason,
    if (userId != null) 'userId=$userId',
    if (operation != null) 'operation=$operation',
  ].join(' | ');

  logSecurityEvent(
    SecurityEventType.authenticationFailed,
    details,
    error: error,
    key: 'auth-failure',
  );
}

/// Logs authorization/permission denial events.
void logAuthorizationFailure(
  String reason, {
  String? userId,
  String? resource,
  String? action,
  Object? error,
}) {
  if (!SecurityConfig.logAuthorizationFailures) {
    return;
  }

  final details = <String>[
    reason,
    if (userId != null) 'userId=$userId',
    if (resource != null) 'resource=$resource',
    if (action != null) 'action=$action',
  ].join(' | ');

  logSecurityEvent(
    SecurityEventType.unauthorizedAccess,
    details,
    error: error,
    key: 'authz-failure',
  );
}

/// Logs RLS (Row-Level Security) violations.
void logRlsViolation(
  String message, {
  String? userId,
  String? table,
  String? policy,
  Object? error,
}) {
  if (!SecurityConfig.logAuthorizationFailures) {
    return;
  }

  final details = <String>[
    message,
    if (userId != null) 'userId=$userId',
    if (table != null) 'table=$table',
    if (policy != null) 'policy=$policy',
  ].join(' | ');

  logSecurityEvent(
    SecurityEventType.rlsViolation,
    details,
    error: error,
    key: 'rls-violation',
  );
}

/// Logs rate limit violations.
void logRateLimitViolation(
  String operation, {
  String? userId,
  String? requestId,
  int? retryAfterSeconds,
}) {
  if (!SecurityConfig.logRateLimitViolations) {
    return;
  }

  final details = <String>[
    'Rate limit exceeded for: $operation',
    if (userId != null) 'userId=$userId',
    if (requestId != null) 'requestId=$requestId',
    if (retryAfterSeconds != null) 'retryAfter=${retryAfterSeconds}s',
  ].join(' | ');

  logSecurityEvent(
    SecurityEventType.rateLimitExceeded,
    details,
    key: 'rate-limit-$operation',
  );
}

/// Logs suspicious/anomalous activity.
void logSuspiciousActivity(
  String description, {
  String? userId,
  String? activityType,
  Map<String, dynamic>? context,
}) {
  if (!SecurityConfig.logSuspiciousActivity) {
    return;
  }

  final parts = <String>[
    description,
    if (userId != null) 'userId=$userId',
    if (activityType != null) 'type=$activityType',
  ];

  if (context != null && context.isNotEmpty) {
    parts.add('context=${context.toString()}');
  }

  logSecurityEvent(
    SecurityEventType.suspiciousActivity,
    parts.join(' | '),
    key: activityType,
  );
}

/// Logs input validation failures for security-sensitive fields.
void logValidationFailure(
  String fieldName,
  String validationError, {
  String? userId,
  Object? error,
}) {
  if (!SecurityConfig.logValidationFailures) {
    return;
  }

  final message = <String>[
    'Validation failed for: $fieldName',
    'Error: $validationError',
    if (userId != null) 'userId=$userId',
  ].join(' | ');

  logSecurityEvent(
    SecurityEventType.invalidInputDetected,
    message,
    error: error,
    key: 'validation-$fieldName',
  );
}

/// Logs potential credential/API key exposure.
void logCredentialExposure(
  String message, {
  String? credentialType,
  String? exposureSource,
  Object? error,
}) {
  if (!SecurityConfig.logAuthorizationFailures) {
    return;
  }

  final details = <String>[
    message,
    if (credentialType != null) 'type=$credentialType',
    if (exposureSource != null) 'source=$exposureSource',
  ].join(' | ');

  logSecurityEvent(
    SecurityEventType.credentialExposure,
    details,
    error: error,
    key: 'credential-exposure',
  );
}

/// Determines if an event type should be logged based on current log level.
bool _shouldLogEventType(SecurityEventType type) {
  return switch (currentSecurityLogLevel) {
    SecurityLogLevel.off => false,
    SecurityLogLevel.error => _isErrorLevel(type),
    SecurityLogLevel.warning => !_isInfoLevel(type),
    SecurityLogLevel.info => true,
    SecurityLogLevel.debug => true,
    SecurityLogLevel.verbose => true,
  };
}

/// Returns true if the event is a critical error-level security event.
bool _isErrorLevel(SecurityEventType type) {
  return switch (type) {
    SecurityEventType.credentialExposure ||
    SecurityEventType.rlsViolation ||
    SecurityEventType.certificateError =>
      true,
    _ => false,
  };
}

/// Returns true if the event is an informational/debug event.
bool _isInfoLevel(SecurityEventType type) {
  return switch (type) {
    SecurityEventType.passwordChanged ||
    SecurityEventType.passwordResetRequested =>
      true,
    _ => false,
  };
}

/// Routes logging to appropriate AppLogger method based on level.
void _logByLevel({
  required SecurityEventType type,
  required String message,
  required Object? error,
  required StackTrace? stackTrace,
  required String eventKey,
}) {
  switch (currentSecurityLogLevel) {
    case SecurityLogLevel.off:
      return;

    case SecurityLogLevel.error:
      AppLogger.error(
        message,
        error: error,
        stackTrace: stackTrace,
        key: eventKey,
      );

    case SecurityLogLevel.warning:
    case SecurityLogLevel.info:
      AppLogger.warn(
        message,
        key: eventKey,
      );

    case SecurityLogLevel.debug:
    case SecurityLogLevel.verbose:
      AppLogger.debug(
        message,
        key: eventKey,
      );
  }
}
