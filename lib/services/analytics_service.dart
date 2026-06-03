import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

import '../utils/app_logger.dart';

typedef AnalyticsLogEvent = Future<void> Function({
  required String name,
  Map<String, Object>? parameters,
});

abstract class AnalyticsService {
  void trackAppOpen();
  void trackCafeDetailOpened(String cafeId);
  void trackFavoriteToggled(String cafeId, {required bool isFavorite});
  void trackCompareAdded(String cafeId);
  void trackCompareRemoved(String cafeId);
  void trackReviewSubmitted(String cafeId);
  void trackReviewDeleted(String cafeId);
  void trackMapRadiusChanged({
    required String preset,
    required int radiusMeters,
  });
  void trackSearchPerformed({required int queryLength});
  void trackFilterApplied({required String filterCategory});
  void trackAdminCafeAdded(String cafeId);
  void trackAdminCafeUpdated(String cafeId);
  void trackAdminCafeDeleted(String cafeId);
  void trackAdminCafeRestored(String cafeId);
}

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({
    FirebaseAnalytics? analytics,
    AnalyticsLogEvent? logEvent,
  }) : _logEvent =
            logEvent ?? (analytics ?? FirebaseAnalytics.instance).logEvent;

  final AnalyticsLogEvent _logEvent;

  void _log(String name, [Map<String, Object>? parameters]) {
    unawaited(() async {
      try {
        await _logEvent(
          name: name,
          parameters: parameters,
        );
      } catch (error) {
        AppLogger.warn(
          'Analytics event failed: $name',
          key: 'analytics-event-failed-$name',
        );
        AppLogger.debug(
          'Analytics failure detail for $name: $error',
          key: 'analytics-event-failed-detail-$name',
        );
      }
    }());
  }

  @override
  void trackAppOpen() {
    _log('app_open');
  }

  @override
  void trackCafeDetailOpened(String cafeId) {
    _log('cafe_detail_opened', _cafeParams(cafeId));
  }

  @override
  void trackFavoriteToggled(String cafeId, {required bool isFavorite}) {
    _log('favorite_toggled', {
      ..._cafeParams(cafeId),
      'is_favorite': isFavorite,
    });
  }

  @override
  void trackCompareAdded(String cafeId) {
    _log('compare_added', _cafeParams(cafeId));
  }

  @override
  void trackCompareRemoved(String cafeId) {
    _log('compare_removed', _cafeParams(cafeId));
  }

  @override
  void trackReviewSubmitted(String cafeId) {
    _log('review_submitted', _cafeParams(cafeId));
  }

  @override
  void trackReviewDeleted(String cafeId) {
    _log('review_deleted', _cafeParams(cafeId));
  }

  @override
  void trackMapRadiusChanged({
    required String preset,
    required int radiusMeters,
  }) {
    _log('map_radius_changed', {
      'radius_preset': sanitizeAnalyticsRadiusPreset(preset),
      'radius_meters': sanitizeAnalyticsRadiusMeters(radiusMeters),
    });
  }

  @override
  void trackSearchPerformed({required int queryLength}) {
    _log('search_performed', {
      'query_length': sanitizeAnalyticsQueryLength(queryLength),
    });
  }

  @override
  void trackFilterApplied({required String filterCategory}) {
    _log('filter_applied', {
      'filter_category': sanitizeAnalyticsFilterCategory(filterCategory),
    });
  }

  @override
  void trackAdminCafeAdded(String cafeId) {
    _log('admin_cafe_added', _cafeParams(cafeId));
  }

  @override
  void trackAdminCafeUpdated(String cafeId) {
    _log('admin_cafe_updated', _cafeParams(cafeId));
  }

  @override
  void trackAdminCafeDeleted(String cafeId) {
    _log('admin_cafe_deleted', _cafeParams(cafeId));
  }

  @override
  void trackAdminCafeRestored(String cafeId) {
    _log('admin_cafe_restored', _cafeParams(cafeId));
  }
}

class DebugAnalyticsService implements AnalyticsService {
  const DebugAnalyticsService();

  void _log(String name, [Map<String, Object>? parameters]) {
    AppLogger.debug(
      'Analytics: event=$name props=${parameters ?? const <String, Object>{}}',
      key: 'analytics-$name',
    );
  }

  @override
  void trackAppOpen() {
    _log('app_open');
  }

  @override
  void trackCafeDetailOpened(String cafeId) {
    _log('cafe_detail_opened', _cafeParams(cafeId));
  }

  @override
  void trackFavoriteToggled(String cafeId, {required bool isFavorite}) {
    _log('favorite_toggled', {
      ..._cafeParams(cafeId),
      'is_favorite': isFavorite,
    });
  }

  @override
  void trackCompareAdded(String cafeId) {
    _log('compare_added', _cafeParams(cafeId));
  }

  @override
  void trackCompareRemoved(String cafeId) {
    _log('compare_removed', _cafeParams(cafeId));
  }

  @override
  void trackReviewSubmitted(String cafeId) {
    _log('review_submitted', _cafeParams(cafeId));
  }

  @override
  void trackReviewDeleted(String cafeId) {
    _log('review_deleted', _cafeParams(cafeId));
  }

  @override
  void trackMapRadiusChanged({
    required String preset,
    required int radiusMeters,
  }) {
    _log('map_radius_changed', {
      'radius_preset': sanitizeAnalyticsRadiusPreset(preset),
      'radius_meters': sanitizeAnalyticsRadiusMeters(radiusMeters),
    });
  }

  @override
  void trackSearchPerformed({required int queryLength}) {
    _log('search_performed', {
      'query_length': sanitizeAnalyticsQueryLength(queryLength),
    });
  }

  @override
  void trackFilterApplied({required String filterCategory}) {
    _log('filter_applied', {
      'filter_category': sanitizeAnalyticsFilterCategory(filterCategory),
    });
  }

  @override
  void trackAdminCafeAdded(String cafeId) {
    _log('admin_cafe_added', _cafeParams(cafeId));
  }

  @override
  void trackAdminCafeUpdated(String cafeId) {
    _log('admin_cafe_updated', _cafeParams(cafeId));
  }

  @override
  void trackAdminCafeDeleted(String cafeId) {
    _log('admin_cafe_deleted', _cafeParams(cafeId));
  }

  @override
  void trackAdminCafeRestored(String cafeId) {
    _log('admin_cafe_restored', _cafeParams(cafeId));
  }
}

Map<String, Object> _cafeParams(String cafeId) {
  return {
    'cafe_id_hash': stableAnalyticsIdHash(cafeId),
  };
}

const Set<String> _allowedAnalyticsRadiusPresets = <String>{
  'small',
  'medium',
  'large',
};

const Set<String> _allowedAnalyticsFilterCategories = <String>{
  'category',
  'district',
  'neighborhood',
  'min_rating',
  'price_level',
  'wifi_quality',
  'outlet_availability',
  'quietness_level',
  'outdoor_seating',
  'pet_friendly',
  'study_friendly',
  'open_now',
  'smoking_policy',
};

String sanitizeAnalyticsRadiusPreset(String preset) {
  final normalized = _normalizeAnalyticsToken(preset);
  if (_allowedAnalyticsRadiusPresets.contains(normalized)) {
    return normalized;
  }
  return 'unknown';
}

int sanitizeAnalyticsRadiusMeters(int radiusMeters) {
  return radiusMeters.clamp(0, 100000);
}

int sanitizeAnalyticsQueryLength(int queryLength) {
  return queryLength.clamp(0, 1000);
}

String sanitizeAnalyticsFilterCategory(String filterCategory) {
  final normalized = _normalizeAnalyticsToken(filterCategory);
  if (_allowedAnalyticsFilterCategories.contains(normalized)) {
    return normalized;
  }
  return 'unknown';
}

String _normalizeAnalyticsToken(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
}

String stableAnalyticsIdHash(String value) {
  final normalized = value.trim();
  var hash = 0;
  for (final codeUnit in normalized.codeUnits) {
    hash = (hash + codeUnit).toUnsigned(32);
    hash = (hash + (hash << 10)).toUnsigned(32);
    hash ^= hash >> 6;
  }
  hash = (hash + (hash << 3)).toUnsigned(32);
  hash ^= hash >> 11;
  hash = (hash + (hash << 15)).toUnsigned(32);
  return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
}
