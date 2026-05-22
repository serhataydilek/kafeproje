import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/utils/cafe_discovery_classifier.dart';
import 'package:kafeproje/utils/cafe_discovery_debug_report.dart';

import 'test_helpers.dart';

void main() {
  group('CafeDiscoveryDebugReportRecorder', () {
    test('builds a structured diagnostics report with lifecycle sections', () {
      final recorder = CafeDiscoveryDebugReportRecorder.instance;
      recorder.beginSession(
        requestKey: 'diag|nearby|radius=8000',
        radiusMeters: 8000,
        seedOnly: false,
        radiusPreset: 'large',
      );

      final deniedPlace = <String, dynamic>{
        'id': 'p-denied',
        'displayName': const <String, dynamic>{'text': 'Cocktail Bar'},
        'types': const <String>['bar', 'food'],
        'primaryType': 'bar',
        'shortFormattedAddress': 'Istanbul',
      };
      final allowedPlace = <String, dynamic>{
        'id': 'p-allowed',
        'displayName': const <String, dynamic>{'text': 'Fig Coffee & Cocktail'},
        'types': const <String>['bar', 'food', 'point_of_interest'],
        'primaryType': 'bar',
        'shortFormattedAddress': 'Istanbul',
      };

      recorder.recordRawCandidate(
        place: deniedPlace,
        sourceQuery: 'coffee cocktail',
        sourceLabel: 'nearby:coffee cocktail',
        searchKind: 'text',
      );
      recorder.recordClassifierDecision(
        place: deniedPlace,
        assessment: assessGoogleCafeCandidate(deniedPlace),
        sourceQuery: 'coffee cocktail',
      );

      recorder.recordRawCandidate(
        place: allowedPlace,
        sourceQuery: 'fig coffee cocktail',
        sourceLabel: 'nearby:fig coffee cocktail',
        searchKind: 'text',
      );
      recorder.recordClassifierDecision(
        place: allowedPlace,
        assessment: assessGoogleCafeCandidate(allowedPlace),
        sourceQuery: 'fig coffee cocktail',
      );

      final allowedCafe = buildTestCafe(
        id: 'visible-1',
        name: 'Fig Coffee & Cocktail',
      ).copyWith(placeId: 'p-allowed');
      final deletedCafe = buildTestCafe(
        id: 'deleted-1',
        name: 'Coffee Hidden',
      ).copyWith(placeId: 'p-deleted');

      recorder.recordSupabaseCount(count: 17);
      recorder.recordMergedCandidates([allowedCafe]);
      recorder.recordDeletedOverlayRemoval([deletedCafe]);
      recorder.recordFilterStage(
        base: [allowedCafe],
        filtered: const <Cafe>[],
        scope: 'map',
        searchQuery: 'coffee',
        activeFilterCount: 1,
      );
      recorder.recordFinalVisible(
        base: [allowedCafe],
        visible: const <Cafe>[],
      );

      final report = recorder.buildReport();

      expect(report, contains('[Summary Counts]'));
      expect(report, contains('raw_places_count: 2'));
      expect(report, contains('classifier_denied_count: 1'));
      expect(report, contains('[Top Deny Reasons]'));
      expect(report, contains('[Rejected Candidates]'));
      expect(report, contains('[Suspicious Mixed Cafe Candidates]'));
      expect(report, contains('[Canary Checks]'));
      expect(report, contains('fig coffee cocktail -> allowed_not_visible'));
      expect(report, contains('[Final Visible Cafes]'));
    });
  });
}
