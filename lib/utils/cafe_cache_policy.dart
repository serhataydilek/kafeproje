import '../constants/network_config.dart';
import '../constants/app_cache_config.dart';
import '../constants/ui_config.dart';

/// Shared cache limits and staleness rules for repository-owned cafe caches.
///
/// Rules:
/// - L1 memory mirrors L2 entries for active queries in the current session
/// - L2 keeps query-scoped snapshots for offline/startup hydration
/// - list entries older than [listHardTtl] are evicted and never shown
/// - list entries newer than [listFreshTtl] can be used without a refresh
/// - stale list entries can still be shown with a background refresh
class CafeCachePolicy {
  CafeCachePolicy._();

  static const int memoryListEntryLimit = 8;
  static const int memoryDetailEntryLimit =
      RequestTuningConfig.placeDetailsMemoryEntries;
  static const int persistentListEntryLimit = 12;
  static const int persistentDetailEntryLimit = 36;

  static const Duration listFreshTtl = StartupConfig.cafeCacheFreshness;
  static const Duration memoryListTtl =
      RequestTuningConfig.nearbyQueryMemoryTtl;
  static const Duration districtFreshTtl = Duration(hours: 12);
  static const Duration detailFreshTtl =
      RequestTuningConfig.placeDetailsMemoryTtl;
  static const Duration listHardTtl = AppCacheConfig.cafeCacheMaxAge;
  static const Duration detailHardTtl = AppCacheConfig.cafeCacheMaxAge;
  static const Duration photoMetadataFreshTtl = Duration(days: 10);

  static bool isStaleList(
    DateTime? cachedAt, {
    DateTime? now,
  }) {
    if (cachedAt == null) {
      return true;
    }
    return !isFreshList(cachedAt, now: now);
  }

  static bool isFreshList(
    DateTime cachedAt, {
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now().toUtc();
    return referenceTime.difference(cachedAt.toUtc()) <= listFreshTtl;
  }

  static bool isExpiredList(
    DateTime? cachedAt, {
    DateTime? now,
  }) {
    if (cachedAt == null) {
      return false;
    }
    final referenceTime = now ?? DateTime.now().toUtc();
    return referenceTime.difference(cachedAt.toUtc()) > listHardTtl;
  }

  static bool isFreshDetail(
    DateTime? cachedAt, {
    DateTime? now,
  }) {
    if (cachedAt == null) {
      return false;
    }
    final referenceTime = now ?? DateTime.now().toUtc();
    return referenceTime.difference(cachedAt.toUtc()) <= detailFreshTtl;
  }

  static bool isStaleDetail(
    DateTime? cachedAt, {
    DateTime? now,
  }) {
    return !isFreshDetail(cachedAt, now: now);
  }

  static bool isExpiredDetail(
    DateTime? cachedAt, {
    DateTime? now,
  }) {
    if (cachedAt == null) {
      return false;
    }
    final referenceTime = now ?? DateTime.now().toUtc();
    return referenceTime.difference(cachedAt.toUtc()) > detailHardTtl;
  }
}
