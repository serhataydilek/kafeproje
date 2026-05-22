import '../models/index.dart';
import 'text_normalization.dart';

/// Optional viewport/bounds descriptor for view-scoped cache keys.
class CafeViewportBounds {
  const CafeViewportBounds({
    required this.southWest,
    required this.northEast,
  });

  final Coordinates southWest;
  final Coordinates northEast;
}

/// Deterministic cache keys for cafe discovery and UI projections.
///
/// Discovery keys are for repository caches and must only include parameters
/// that can change the remote dataset. Presentation keys can additionally
/// include client-side filters, sort, or viewport metadata.
class CafeCacheKeys {
  CafeCacheKeys._();

  static String discovery({
    Coordinates? center,
    required int radiusMeters,
    String? district,
    Iterable<String> districts = const <String>[],
    CafeViewportBounds? viewport,
  }) {
    final normalizedDistricts = _normalizedDistricts(districts);
    final normalizedDistrict = normalizedDistricts.isNotEmpty
        ? normalizedDistricts.join(',')
        : _normalizedString(district);
    final mode = normalizedDistrict != null
        ? 'district'
        : viewport != null
            ? 'viewport'
            : 'nearby';

    return [
      'v2',
      'mode=$mode',
      'districts=${normalizedDistrict ?? '-'}',
      'center=${center == null ? '-' : _coordinates(center, precision: 3)}',
      'radius=${normalizedDistrict == null ? radiusMeters : '-'}',
      'viewport=${_viewport(viewport)}',
    ].join('|');
  }

  static String presentation({
    required String discoveryKey,
    Filters filters = Filters.empty,
    SortOption? sortOption,
    CafeViewportBounds? viewport,
  }) {
    return [
      'v1',
      'discovery=$discoveryKey',
      'filters=${filtersSignature(filters)}',
      'sort=${sortSignature(sortOption)}',
      'viewport=${_viewport(viewport)}',
    ].join('|');
  }

  static String request(
    String discoveryKey, {
    String? pageToken,
  }) {
    final normalizedPageToken = pageToken?.trim();
    if (normalizedPageToken == null || normalizedPageToken.isEmpty) {
      return '$discoveryKey|page=first';
    }
    return '$discoveryKey|page=${Uri.encodeComponent(normalizedPageToken)}';
  }

  static String filtersSignature(Filters filters) {
    return [
      'category=${filters.category?.value ?? '-'}',
      'districts=${_filtersDistrictSegment(filters)}',
      'neighborhood=${_normalizedString(filters.neighborhood) ?? '-'}',
      'minRating=${filters.minRating?.toStringAsFixed(1) ?? '-'}',
      'price=${filters.priceLevel?.value ?? '-'}',
      'wifi=${filters.wifiQuality?.value ?? '-'}',
      'outlet=${filters.outletAvailability?.value ?? '-'}',
      'quiet=${filters.quietnessLevel?.value ?? '-'}',
      'outdoor=${_boolSegment(filters.outdoorSeating)}',
      'pet=${_boolSegment(filters.petFriendly)}',
      'study=${_boolSegment(filters.studyFriendly)}',
      'openNow=${_boolSegment(filters.openNow)}',
      'smoking=${filters.smokingPolicy?.value ?? '-'}',
      'query=${_normalizedString(filters.searchQuery) ?? '-'}',
    ].join('&');
  }

  static String sortSignature(SortOption? sortOption) {
    return sortOption?.name ?? 'default';
  }

  static String _coordinates(
    Coordinates coordinates, {
    int precision = 4,
  }) {
    return '${coordinates.lat.toStringAsFixed(precision)},'
        '${coordinates.lng.toStringAsFixed(precision)}';
  }

  static String _viewport(CafeViewportBounds? viewport) {
    if (viewport == null) {
      return '-';
    }
    return '${_coordinates(viewport.southWest)}:'
        '${_coordinates(viewport.northEast)}';
  }

  static String _boolSegment(bool? value) {
    return switch (value) {
      true => '1',
      false => '0',
      null => '-',
    };
  }

  static String? _normalizedString(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return normalizeSearchText(trimmed);
  }

  static List<String> _normalizedDistricts(Iterable<String> districts) {
    final normalized = districts
        .map(_normalizedString)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return normalized;
  }

  static String _filtersDistrictSegment(Filters filters) {
    final selected = _normalizedDistricts(filters.effectiveDistricts);
    if (selected.isEmpty) {
      return '-';
    }
    return selected.join(',');
  }
}
