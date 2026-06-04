import 'package:flutter/foundation.dart';

import '../models/index.dart';
import 'app_logger.dart';
import 'cafe_discovery_classifier.dart';
import 'text_normalization.dart';

const List<String> _mixedCafeKeywords = <String>[
  'coffee',
  'cafe',
  'kafe',
  'kahve',
  'cocktail',
  'bistro',
  'espresso',
  'specialty',
];

const List<String> _canaryQueries = <String>[
  'fig coffee cocktail',
  'coffee cocktail',
  'cafe cocktail',
  'specialty coffee',
  'kahve',
  'espresso',
];

const int _maxRejectedCandidatesInReport = 160;
const int _maxSuspiciousCandidatesInReport = 120;
const int _maxVisibleCafesInReport = 120;

/// Debug-only recorder for cafe discovery diagnostics.
///
/// This utility intentionally stores in-memory state only and emits console
/// reports in debug builds. It never records in release mode.
class CafeDiscoveryDebugReportRecorder {
  CafeDiscoveryDebugReportRecorder._();

  static final CafeDiscoveryDebugReportRecorder instance =
      CafeDiscoveryDebugReportRecorder._();

  String? _requestKey;
  String? _district;
  int? _radiusMeters;
  String? _radiusPreset;
  bool _seedOnly = false;
  DateTime? _startedAt;

  int _rawPlacesCount = 0;
  int _supabaseCount = 0;
  int _mergedCount = 0;
  int _classifierAllowedCount = 0;
  int _classifierDeniedCount = 0;
  int _deletedOverlayRemovedCount = 0;
  int _filterRemovedCount = 0;
  int _finalVisibleCount = 0;
  int _textPagesFetched = 0;
  int _textPagesWithNextToken = 0;

  final Map<String, int> _denyReasonCounts = <String, int>{};
  final Map<String, int> _queryRawCounts = <String, int>{};
  final Map<String, int> _queryAcceptedCounts = <String, int>{};
  final Map<String, _CandidateRecord> _candidates =
      <String, _CandidateRecord>{};
  final Map<String, _VisibleCafeRecord> _finalVisible =
      <String, _VisibleCafeRecord>{};

  static const String preferredDebugReportPath =
      'debug_reports/cafe_discovery_rejected_report.txt';

  bool get isEnabled => kDebugMode;

  bool get hasData =>
      _requestKey != null && (_rawPlacesCount > 0 || _candidates.isNotEmpty);

  void beginSession({
    required String requestKey,
    required int radiusMeters,
    required bool seedOnly,
    String? radiusPreset,
    String? district,
  }) {
    if (!isEnabled) {
      return;
    }

    final normalizedRequestKey = requestKey.trim();
    final normalizedDistrict = district?.trim();
    final shouldReset = _requestKey != normalizedRequestKey ||
        _radiusMeters != radiusMeters ||
        _district != normalizedDistrict;

    if (shouldReset) {
      _reset();
      _startedAt = DateTime.now().toUtc();
      _requestKey = normalizedRequestKey;
      _radiusMeters = radiusMeters;
      _radiusPreset = radiusPreset?.trim();
      _district = normalizedDistrict;
      _seedOnly = seedOnly;
    }
  }

  void recordRawCandidate({
    required Map<String, dynamic> place,
    required String sourceQuery,
    required String sourceLabel,
    required String searchKind,
  }) {
    if (!isEnabled) {
      return;
    }

    _rawPlacesCount += 1;
    _queryRawCounts.update(sourceQuery, (value) => value + 1,
        ifAbsent: () => 1);

    final key = _candidateKeyFromPlace(place);
    final record = _candidates.putIfAbsent(
      key,
      () => _CandidateRecord(
        key: key,
        name: _readPlaceName(place),
        placeId: _readPlaceId(place),
      ),
    );

    record
      ..name = _readPlaceName(place)
      ..placeId = _readPlaceId(place)
      ..types = _readPlaceTypes(place)
      ..primaryType = _readPlacePrimaryType(place)
      ..address = _readPlaceAddress(place)
      ..radiusMeters = _radiusMeters
      ..radiusPreset = _radiusPreset
      ..searchKind = searchKind
      ..sourceQueries.add(sourceQuery)
      ..sourceLabels.add(sourceLabel);
  }

  void recordClassifierDecision({
    required Map<String, dynamic> place,
    required CafeVenueAssessment assessment,
    required String sourceQuery,
  }) {
    if (!isEnabled) {
      return;
    }

    final key = _candidateKeyFromPlace(place);
    final record = _candidates.putIfAbsent(
      key,
      () => _CandidateRecord(
        key: key,
        name: _readPlaceName(place),
        placeId: _readPlaceId(place),
      ),
    );

    record
      ..classifierAllowed = assessment.isValidCafe
      ..allowReason = assessment.allowReason
      ..denyReason = assessment.denyReason
      ..primaryType = assessment.primaryType
      ..types = Set<String>.from(assessment.types)
      ..sourceQueries.add(sourceQuery)
      ..name = _readPlaceName(place)
      ..placeId = _readPlaceId(place)
      ..address = _readPlaceAddress(place);

    if (assessment.isValidCafe) {
      _classifierAllowedCount += 1;
      _queryAcceptedCounts.update(sourceQuery, (value) => value + 1,
          ifAbsent: () => 1);
      return;
    }

    _classifierDeniedCount += 1;
    final denyReason =
        (assessment.denyReason == null || assessment.denyReason!.trim().isEmpty)
            ? 'unspecified'
            : assessment.denyReason!.trim();
    _denyReasonCounts.update(denyReason, (value) => value + 1,
        ifAbsent: () => 1);
  }

  void recordTextPage({
    required String textQuery,
    required int pageIndex,
    required int placesCount,
    required bool hasNextPageToken,
  }) {
    if (!isEnabled) {
      return;
    }

    _textPagesFetched += 1;
    if (hasNextPageToken) {
      _textPagesWithNextToken += 1;
    }

    final queryKey = textQuery.trim().isEmpty ? 'unknown-query' : textQuery;
    _queryRawCounts.update(queryKey, (value) => value + placesCount,
        ifAbsent: () => placesCount);

    AppLogger.debug(
      '[CAFE_DIAG_PAGE] query="$queryKey" page=${pageIndex + 1} count=$placesCount hasNextToken=$hasNextPageToken',
      key: 'cafe-diag-page-$queryKey-${pageIndex + 1}',
      throttle: Duration.zero,
    );
  }

  void recordSupabaseCount({required int count}) {
    if (!isEnabled) {
      return;
    }
    if (count > _supabaseCount) {
      _supabaseCount = count;
    }
  }

  void recordMergedCandidates(Iterable<Cafe> cafes) {
    if (!isEnabled) {
      return;
    }
    final list = cafes.toList(growable: false);
    _mergedCount = list.length;
    for (final cafe in list) {
      final key = _candidateKeyFromCafe(cafe);
      final record = _candidates.putIfAbsent(
        key,
        () => _CandidateRecord(
          key: key,
          name: cafe.name,
          placeId: cafe.placeId,
        ),
      );
      record
        ..name = cafe.name
        ..placeId = cafe.placeId
        ..address = cafe.address
        ..district = cafe.district
        ..sourceType = cafe.sourceType
        ..appRating = cafe.appRating
        ..googleRating = cafe.googleRating;
    }
  }

  void recordDeletedOverlayRemoval(Iterable<Cafe> blockedCafes) {
    if (!isEnabled) {
      return;
    }

    final blocked = blockedCafes.toList(growable: false);
    _deletedOverlayRemovedCount += blocked.length;
    for (final cafe in blocked) {
      final key = _candidateKeyFromCafe(cafe);
      final record = _candidates.putIfAbsent(
        key,
        () => _CandidateRecord(
          key: key,
          name: cafe.name,
          placeId: cafe.placeId,
        ),
      );
      record
        ..name = cafe.name
        ..placeId = cafe.placeId
        ..address = cafe.address
        ..removedByDeletedOverlay = true;
    }
  }

  void recordFilterStage({
    required Iterable<Cafe> base,
    required Iterable<Cafe> filtered,
    required String scope,
    required String? searchQuery,
    required int activeFilterCount,
  }) {
    if (!isEnabled) {
      return;
    }

    final filteredKeys = filtered.map(_candidateKeyFromCafe).toSet();
    final removed = <Cafe>[];

    for (final cafe in base) {
      final key = _candidateKeyFromCafe(cafe);
      final record = _candidates.putIfAbsent(
        key,
        () => _CandidateRecord(
          key: key,
          name: cafe.name,
          placeId: cafe.placeId,
        ),
      );
      record
        ..name = cafe.name
        ..placeId = cafe.placeId
        ..address = cafe.address
        ..district = cafe.district;

      if (!filteredKeys.contains(key)) {
        record.removedByFilter = true;
        removed.add(cafe);
      }
    }

    _filterRemovedCount = removed.length;
    final normalizedQuery = (searchQuery ?? '').trim();

    AppLogger.debug(
      '[CAFE_DIAG_FILTER] scope=$scope base=${base.length} filtered=${filtered.length} removed=${removed.length} activeFilters=$activeFilterCount search="$normalizedQuery"',
      key: 'cafe-diag-filter-$scope',
      throttle: const Duration(seconds: 2),
    );
  }

  void recordFinalVisible({
    required Iterable<Cafe> base,
    required Iterable<Cafe> visible,
  }) {
    if (!isEnabled) {
      return;
    }

    final visibleList = visible.toList(growable: false);
    final visibleKeys = visibleList.map(_candidateKeyFromCafe).toSet();

    _finalVisibleCount = visibleList.length;
    _finalVisible
      ..clear()
      ..addEntries(
        visibleList.map(
          (cafe) => MapEntry(
            _candidateKeyFromCafe(cafe),
            _VisibleCafeRecord(
              name: cafe.name,
              id: cafe.id,
              placeId: cafe.placeId,
              source: cafe.sourceType,
              appRating: cafe.appRating,
              googleRating: cafe.googleRating,
              district: cafe.district,
              address: cafe.address,
            ),
          ),
        ),
      );

    for (final cafe in base) {
      final key = _candidateKeyFromCafe(cafe);
      final record = _candidates.putIfAbsent(
        key,
        () => _CandidateRecord(
          key: key,
          name: cafe.name,
          placeId: cafe.placeId,
        ),
      );
      final isVisible = visibleKeys.contains(key);
      record
        ..name = cafe.name
        ..placeId = cafe.placeId
        ..district = cafe.district
        ..address = cafe.address
        ..wasVisible = isVisible
        ..removedByMapVisible = !isVisible;
    }
  }

  String buildReport() {
    if (!isEnabled) {
      return 'Cafe discovery debug report is available only in debug mode.';
    }

    final buffer = StringBuffer();
    final startedAt = _startedAt?.toIso8601String() ?? 'n/a';
    buffer
      ..writeln('Cafe Discovery Diagnostics Report')
      ..writeln('================================')
      ..writeln('generated_at_utc: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('session_started_at_utc: $startedAt')
      ..writeln('request_key: ${_requestKey ?? 'n/a'}')
      ..writeln('radius_meters: ${_radiusMeters ?? 0}')
      ..writeln('radius_preset: ${_radiusPreset ?? 'n/a'}')
      ..writeln('district: ${_district ?? 'none'}')
      ..writeln('seed_only: $_seedOnly')
      ..writeln('preferred_output_path: $preferredDebugReportPath')
      ..writeln();

    buffer
      ..writeln('[Summary Counts]')
      ..writeln('raw_places_count: $_rawPlacesCount')
      ..writeln('supabase_count: $_supabaseCount')
      ..writeln('merged_count: $_mergedCount')
      ..writeln('classifier_allowed_count: $_classifierAllowedCount')
      ..writeln('classifier_denied_count: $_classifierDeniedCount')
      ..writeln('deleted_overlay_removed_count: $_deletedOverlayRemovedCount')
      ..writeln('filter_removed_count: $_filterRemovedCount')
      ..writeln('final_visible_count: $_finalVisibleCount')
      ..writeln('text_pages_fetched: $_textPagesFetched')
      ..writeln('text_pages_with_next_token: $_textPagesWithNextToken')
      ..writeln();

    buffer.writeln('[Top Deny Reasons]');
    if (_denyReasonCounts.isEmpty) {
      buffer.writeln('none');
    } else {
      final sortedReasons = _denyReasonCounts.entries.toList(growable: false)
        ..sort((left, right) => right.value.compareTo(left.value));
      for (final reason in sortedReasons) {
        buffer.writeln('${reason.key} -> ${reason.value}');
      }
    }
    buffer.writeln();

    buffer.writeln('[Query Coverage]');
    if (_queryRawCounts.isEmpty) {
      buffer.writeln('none');
    } else {
      final sortedQueries = _queryRawCounts.entries.toList(growable: false)
        ..sort((left, right) => right.value.compareTo(left.value));
      for (final query in sortedQueries) {
        final accepted = _queryAcceptedCounts[query.key] ?? 0;
        buffer.writeln('${query.key} -> raw:${query.value} allowed:$accepted');
      }
    }
    buffer.writeln();

    buffer.writeln('[Rejected Candidates]');
    final rejected = _candidates.values
        .where((record) => record.classifierAllowed == false)
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    if (rejected.isEmpty) {
      buffer.writeln('none');
    } else {
      final display = rejected.take(_maxRejectedCandidatesInReport);
      for (final record in display) {
        final joinedTypes = record.types.isEmpty
            ? 'none'
            : record.types.toList(growable: false).join(',');
        buffer.writeln(
          '${record.name} | ${record.placeId ?? '-'} | $joinedTypes | ${record.denyReason ?? 'unspecified'} | ${record.primarySourceQuery}',
        );
      }
      if (rejected.length > _maxRejectedCandidatesInReport) {
        buffer.writeln(
          '... truncated ${rejected.length - _maxRejectedCandidatesInReport} more rejected candidates',
        );
      }
    }
    buffer.writeln();

    buffer.writeln('[Suspicious Mixed Cafe Candidates]');
    final suspicious = _candidates.values.where((record) {
      final normalized = normalizeSearchText(record.name);
      final hasKeyword = _mixedCafeKeywords.any(normalized.contains);
      if (!hasKeyword) {
        return false;
      }
      return record.classifierAllowed == false || !record.wasVisible;
    }).toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    if (suspicious.isEmpty) {
      buffer.writeln('none');
    } else {
      final display = suspicious.take(_maxSuspiciousCandidatesInReport);
      for (final record in display) {
        final status = record.classifierAllowed == false
            ? 'denied'
            : record.wasVisible
                ? 'visible'
                : 'allowed_not_visible';
        buffer.writeln(
          '${record.name} | status:$status | denyReason:${record.denyReason ?? '-'} | removedByFilter:${record.removedByFilter} | removedByMapVisible:${record.removedByMapVisible} | source:${record.primarySourceQuery}',
        );
      }
      if (suspicious.length > _maxSuspiciousCandidatesInReport) {
        buffer.writeln(
          '... truncated ${suspicious.length - _maxSuspiciousCandidatesInReport} more suspicious candidates',
        );
      }
    }
    buffer.writeln();

    buffer.writeln('[Canary Checks]');
    for (final canary in _canaryQueries) {
      final matches = _candidates.values.where((record) {
        final normalizedName = normalizeSearchText(record.name);
        return normalizedName.contains(canary);
      }).toList(growable: false);

      if (matches.isEmpty) {
        buffer.writeln('$canary -> not_retrieved');
        continue;
      }

      final hasVisible = matches.any((record) => record.wasVisible);
      final hasAllowed =
          matches.any((record) => record.classifierAllowed == true);
      final hasDenied =
          matches.any((record) => record.classifierAllowed == false);

      final status = hasVisible
          ? 'visible'
          : hasAllowed
              ? 'allowed_not_visible'
              : hasDenied
                  ? 'denied'
                  : 'retrieved_unknown';

      final denyReasons = matches
          .map((record) => record.denyReason)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();

      buffer.writeln(
        '$canary -> $status (matches:${matches.length}, denyReasons:${denyReasons.isEmpty ? '-' : denyReasons.join(',')})',
      );
    }
    buffer.writeln();

    buffer.writeln('[Final Visible Cafes]');
    if (_finalVisible.isEmpty) {
      buffer.writeln('none');
    } else {
      final visible = _finalVisible.values.toList(growable: false)
        ..sort((left, right) => left.name.compareTo(right.name));
      final display = visible.take(_maxVisibleCafesInReport);
      for (final cafe in display) {
        final rating = cafe.appRating?.toStringAsFixed(1) ??
            cafe.googleRating?.toStringAsFixed(1) ??
            '-';
        final identity =
            cafe.placeId?.trim().isNotEmpty == true ? cafe.placeId! : cafe.id;
        buffer.writeln(
          '${cafe.name} | $identity | ${cafe.source} | $rating | ${cafe.district} / ${cafe.address}',
        );
      }
      if (visible.length > _maxVisibleCafesInReport) {
        buffer.writeln(
          '... truncated ${visible.length - _maxVisibleCafesInReport} more visible cafes',
        );
      }
    }

    return buffer.toString();
  }

  void logReportToConsole({String trigger = 'manual'}) {
    if (!isEnabled || !hasData) {
      return;
    }

    final report = buildReport();
    AppLogger.debug(
      '[CAFE_DISCOVERY_REPORT_BEGIN trigger=$trigger]\n$report\n[CAFE_DISCOVERY_REPORT_END]',
      key: 'cafe-discovery-report',
      throttle: const Duration(seconds: 20),
    );
  }

  void _reset() {
    _rawPlacesCount = 0;
    _supabaseCount = 0;
    _mergedCount = 0;
    _classifierAllowedCount = 0;
    _classifierDeniedCount = 0;
    _deletedOverlayRemovedCount = 0;
    _filterRemovedCount = 0;
    _finalVisibleCount = 0;
    _textPagesFetched = 0;
    _textPagesWithNextToken = 0;
    _denyReasonCounts.clear();
    _queryRawCounts.clear();
    _queryAcceptedCounts.clear();
    _candidates.clear();
    _finalVisible.clear();
  }

  String _candidateKeyFromPlace(Map<String, dynamic> place) {
    final placeId = _readPlaceId(place);
    if (placeId != null && placeId.isNotEmpty) {
      return 'place:$placeId';
    }

    final normalizedName = normalizeSearchText(_readPlaceName(place));
    final normalizedAddress = normalizeSearchText(_readPlaceAddress(place));
    return 'name:$normalizedName|addr:$normalizedAddress';
  }

  String _candidateKeyFromCafe(Cafe cafe) {
    final placeId = cafe.placeId?.trim();
    if (placeId != null && placeId.isNotEmpty) {
      return 'place:$placeId';
    }
    return 'id:${cafe.id}';
  }

  String _readPlaceName(Map<String, dynamic> place) {
    final rawDisplayName = place['displayName'];
    if (rawDisplayName is Map<String, dynamic>) {
      final text = (rawDisplayName['text'] as String?)?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }

    final fallbackName = (place['name'] as String?)?.trim();
    if (fallbackName != null && fallbackName.isNotEmpty) {
      return fallbackName;
    }

    return 'unknown';
  }

  String? _readPlaceId(Map<String, dynamic> place) {
    final id = (place['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      return null;
    }
    return id;
  }

  Set<String> _readPlaceTypes(Map<String, dynamic> place) {
    final rawTypes = place['types'];
    if (rawTypes is! List) {
      return <String>{};
    }

    return rawTypes
        .map((value) => normalizeSearchText(value.toString()))
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  String _readPlacePrimaryType(Map<String, dynamic> place) {
    return normalizeSearchText((place['primaryType'] as String?)?.trim() ?? '');
  }

  String _readPlaceAddress(Map<String, dynamic> place) {
    final shortAddress = (place['shortFormattedAddress'] as String?)?.trim();
    if (shortAddress != null && shortAddress.isNotEmpty) {
      return shortAddress;
    }

    final vicinity = (place['vicinity'] as String?)?.trim();
    if (vicinity != null && vicinity.isNotEmpty) {
      return vicinity;
    }

    return '';
  }
}

class _CandidateRecord {
  _CandidateRecord({
    required this.key,
    required this.name,
    required this.placeId,
  });

  final String key;
  String name;
  String? placeId;
  Set<String> types = <String>{};
  String primaryType = '';
  String address = '';
  String? district;
  String? searchKind;
  String? sourceType;
  String? allowReason;
  String? denyReason;
  bool? classifierAllowed;
  bool removedByDeletedOverlay = false;
  bool removedByFilter = false;
  bool removedByMapVisible = false;
  bool wasVisible = false;
  int? radiusMeters;
  String? radiusPreset;
  double? appRating;
  double? googleRating;
  final Set<String> sourceQueries = <String>{};
  final Set<String> sourceLabels = <String>{};

  String get primarySourceQuery {
    if (sourceQueries.isEmpty) {
      return '-';
    }

    final sorted = sourceQueries.toList(growable: false)..sort();
    return sorted.first;
  }
}

class _VisibleCafeRecord {
  const _VisibleCafeRecord({
    required this.name,
    required this.id,
    required this.placeId,
    required this.source,
    required this.appRating,
    required this.googleRating,
    required this.district,
    required this.address,
  });

  final String name;
  final String id;
  final String? placeId;
  final String source;
  final double? appRating;
  final double? googleRating;
  final String district;
  final String address;
}
