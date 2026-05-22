/// Security configuration and best practices constants.
///
/// Defines security-related settings, logging levels, and security event types
/// to ensure consistent security monitoring and logging throughout the app.
class SecurityConfig {
  /// Enable comprehensive security event logging.
  static const bool enableSecurityLogging = true;

  /// Log failed authentication attempts.
  static const bool logAuthFailures = true;

  /// Log permission denials and unauthorized access attempts.
  static const bool logAuthorizationFailures = true;

  /// Log suspicious activity patterns.
  static const bool logSuspiciousActivity = true;

  /// Log rate limit violations and throttling events.
  static const bool logRateLimitViolations = true;

  /// Log data validation failures.
  static const bool logValidationFailures = true;

  /// Maximum failed login attempts before cooldown.
  static const int maxFailedLoginAttempts = 5;

  /// Cooldown period after max failed attempts.
  static const Duration loginCooldownDuration = Duration(minutes: 15);

  /// Maximum login attempt history to keep.
  static const int maxLoginHistorySize = 100;
}

/// Security event types for categorized logging.
enum SecurityEventType {
  /// Authentication token generation/validation failure.
  authTokenInvalid,

  /// User authentication failed.
  authenticationFailed,

  /// User session expired or terminated.
  sessionTerminated,

  /// Unauthorized access attempt (permission denied).
  unauthorizedAccess,

  /// User role/permission issue.
  permissionDenied,

  /// Rate limiting triggered.
  rateLimitExceeded,

  /// Suspicious activity detected.
  suspiciousActivity,

  /// Password reset flow initiated.
  passwordResetRequested,

  /// Password changed.
  passwordChanged,

  /// Data validation failed for critical input.
  invalidInputDetected,

  /// API key or credential violation.
  credentialExposure,

  /// HTTPS/SSL certificate issue.
  certificateError,

  /// Unusual user behavior pattern.
  anomalousActivity,

  /// RLS (Row-Level Security) violation.
  rlsViolation,

  /// Other security-related events.
  other,
}

/// Security headers and validation rules.
class SecurityHeaders {
  /// Expected HTTPS scheme enforcement.
  static const String expectedScheme = 'https';

  /// Certificate pinning enabled flag.
  static const bool enableCertificatePinning = false;

  /// Mixed content warning (HTTP on HTTPS app).
  static const bool warnMixedContent = true;

  /// Validate secure storage encryption.
  static const bool validateStorageEncryption = true;

  /// Require RLS verification on startup.
  static const bool requireRlsVerification = true;
}

/// Timeout configurations for security-sensitive operations.
class SecurityTimeouts {
  /// Session timeout duration.
  static const Duration sessionTimeout = Duration(minutes: 30);

  /// Re-authentication timeout for sensitive operations.
  static const Duration reauthTimeout = Duration(seconds: 60);

  /// API request timeout.
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Password reset link expiration time.
  static const Duration passwordResetExpiry = Duration(hours: 1);

  /// Email verification link expiration time.
  static const Duration emailVerificationExpiry = Duration(hours: 24);
}

/// Logging configuration levels.
enum SecurityLogLevel {
  /// Disabled - minimal logging.
  off,

  /// Error level - only critical failures.
  error,

  /// Warning level - potential issues.
  warning,

  /// Info level - general events.
  info,

  /// Debug level - detailed debugging info.
  debug,

  /// Verbose - all events including trace data.
  verbose,
}

/// Current security logging level (adjust based on environment).
const SecurityLogLevel currentSecurityLogLevel = SecurityLogLevel.debug;
