class RateLimitConfig {
  RateLimitConfig._();

  static const int processingBatchSize = 4;
  static const int maxRequestAttempts = 3;
  static const int maxNearbyResults = 20;
  static const int textSearchPageSize = 20;
  static const int maxTextSearchPages = 8;
}

enum LargeRadiusCoverageProfile {
  conservative,
  balanced,
  aggressive,
}

class RequestTuningConfig {
  RequestTuningConfig._();

  /// Single tuning knob for the largest map discovery radius intensity.
  /// - conservative: lower API usage, lower edge coverage
  /// - balanced: default coverage/perf tradeoff
  /// - aggressive: higher API usage, best edge coverage
  static const LargeRadiusCoverageProfile largeRadiusCoverageProfile =
      LargeRadiusCoverageProfile.balanced;

  /// If the initial seed phase returns at least this many cafes,
  /// immediate full discovery is skipped to reduce cold-path API cost.
  static const int seedAdequateCafeCount = 25;

  static const Duration nearbySearchMinInterval = Duration(milliseconds: 650);
  static const Duration placeDetailsMinInterval = Duration(milliseconds: 300);
  static const Duration photoFetchMinInterval = Duration(milliseconds: 300);
  static const Duration textSearchMinInterval = Duration(milliseconds: 400);
  static const Duration reverseGeocodeMinInterval = Duration(milliseconds: 500);

  static const Duration mapFetchDebounce = Duration(milliseconds: 600);
  static const Duration filterChangeDebounce = Duration(milliseconds: 300);
  static const Duration searchInputDebounce = Duration(milliseconds: 350);

  static const int nearbyQueryMemoryEntries = 12;
  static const Duration nearbyQueryMemoryTtl = Duration(minutes: 6);

  static const int textSearchMemoryEntries = 24;
  static const Duration textSearchMemoryTtl = Duration(minutes: 8);

  static const int placeDetailsMemoryEntries = 96;
  static const Duration placeDetailsMemoryTtl = Duration(hours: 6);

  static const int photoProviderMemoryEntries = 32;
  static const Duration photoProviderMemoryTtl = Duration(minutes: 20);
}

class ImageCacheConfig {
  ImageCacheConfig._();

  static const int maximumSize = 120;
  static const int maximumSizeBytes = 60 * 1024 * 1024;
}
