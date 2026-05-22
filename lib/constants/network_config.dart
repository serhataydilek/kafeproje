/// Shared runtime configuration for network-bound operations and startup cache
/// hydration. Centralizing these values keeps timeout and radius behavior
/// consistent across services, providers, and map UI.
class NetworkTimeoutConfig {
  NetworkTimeoutConfig._();

  /// Timeout for auth requests made through Supabase.
  static const Duration authRequestTimeout = Duration(seconds: 12);

  /// Timeout for standard Supabase data requests.
  static const Duration supabaseDataRequestTimeout = Duration(seconds: 15);

  /// Timeout for review-specific Supabase requests.
  static const Duration reviewsRequestTimeout = Duration(seconds: 15);

  /// Timeout for storage uploads such as profile avatar updates.
  static const Duration uploadRequestTimeout = Duration(minutes: 2);

  /// Timeout for Google Places HTTP requests.
  static const Duration placesRequestTimeout = Duration(seconds: 10);

  /// Timeout for remote image and cafe photo requests.
  static const Duration imageRequestTimeout = Duration(seconds: 10);

  /// Delay required by paginated Google Places text search requests.
  static const Duration placesPaginationDelay = Duration(seconds: 2);

  /// Initial backoff used for retrying transient Google Places failures.
  static const Duration placesRetryInitialDelay = Duration(milliseconds: 350);

  /// Backoff multiplier used between Google Places retry attempts.
  static const double placesRetryBackoffMultiplier = 1.8;
}

/// Startup cache behavior shared by app bootstrap and map filtering.
class StartupConfig {
  StartupConfig._();

  /// Radius used when device location is available.
  static const int defaultMapNearbyRadiusMeters = 1000;

  /// Radius used when location access is unavailable and the app falls back to
  /// Istanbul center.
  static const int fallbackMapRadiusMeters = 1000;

  /// Cached cafe list freshness tolerated during startup before triggering a
  /// visible background refresh state.
  static const Duration cafeCacheFreshness = Duration(minutes: 30);
}
