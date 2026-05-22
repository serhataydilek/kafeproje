import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/services/analytics_service.dart';

void main() {
  group('AnalyticsService privacy helpers', () {
    test('stableAnalyticsIdHash is stable and does not expose raw cafe IDs',
        () {
      const rawCafeId = 'google-place-id-12345';

      final first = stableAnalyticsIdHash(rawCafeId);
      final second = stableAnalyticsIdHash(rawCafeId);

      expect(first, second);
      expect(first, isNot(rawCafeId));
      expect(first.contains(rawCafeId), isFalse);
      expect(first, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('analytics event parameter sanitizers keep bounded values', () {
      expect(sanitizeAnalyticsQueryLength(-1), 0);
      expect(sanitizeAnalyticsQueryLength(1200), 1000);
      expect(sanitizeAnalyticsRadiusMeters(-50), 0);
      expect(sanitizeAnalyticsRadiusMeters(150000), 100000);
      expect(sanitizeAnalyticsRadiusPreset(' Medium '), 'medium');
      expect(sanitizeAnalyticsRadiusPreset('custom address'), 'unknown');
      expect(sanitizeAnalyticsFilterCategory('wifi_quality'), 'wifi_quality');
      expect(
        sanitizeAnalyticsFilterCategory('Kadikoy exact search'),
        'unknown',
      );
    });

    test('DebugAnalyticsService methods are no-op safe', () {
      const service = DebugAnalyticsService();

      expect(
        () {
          service.trackAppOpen();
          service.trackCafeDetailOpened('raw-cafe-id');
          service.trackFavoriteToggled('raw-cafe-id', isFavorite: true);
          service.trackCompareAdded('raw-cafe-id');
          service.trackCompareRemoved('raw-cafe-id');
          service.trackReviewSubmitted('raw-cafe-id');
          service.trackReviewDeleted('raw-cafe-id');
          service.trackMapRadiusChanged(preset: 'medium', radiusMeters: 4000);
          service.trackSearchPerformed(queryLength: 'sensitive query'.length);
          service.trackFilterApplied(filterCategory: 'district');
          service.trackAdminCafeAdded('raw-cafe-id');
          service.trackAdminCafeUpdated('raw-cafe-id');
          service.trackAdminCafeDeleted('raw-cafe-id');
          service.trackAdminCafeRestored('raw-cafe-id');
        },
        returnsNormally,
      );
    });

    test('FirebaseAnalyticsService swallows logging failures', () {
      final service = FirebaseAnalyticsService(
        logEvent: ({required name, parameters}) async {
          throw StateError('Firebase unavailable');
        },
      );

      expect(
        () {
          service.trackAppOpen();
          service.trackCafeDetailOpened('raw-cafe-id');
          service.trackFavoriteToggled('raw-cafe-id', isFavorite: false);
          service.trackCompareAdded('raw-cafe-id');
          service.trackCompareRemoved('raw-cafe-id');
          service.trackReviewSubmitted('raw-cafe-id');
          service.trackReviewDeleted('raw-cafe-id');
          service.trackMapRadiusChanged(
            preset: 'unexpected preset',
            radiusMeters: -1,
          );
          service.trackSearchPerformed(queryLength: 2000);
          service.trackFilterApplied(filterCategory: 'raw search text');
          service.trackAdminCafeAdded('raw-cafe-id');
          service.trackAdminCafeUpdated('raw-cafe-id');
          service.trackAdminCafeDeleted('raw-cafe-id');
          service.trackAdminCafeRestored('raw-cafe-id');
        },
        returnsNormally,
      );
    });
  });
}
