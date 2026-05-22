import 'dart:math' as math;

import '../data/fallback_districts.dart';
import '../models/district.dart';
import 'text_normalization.dart';

List<District> resolveDistrictCatalog({
  Iterable<District>? districts,
  String city = FallbackDistrictCatalog.defaultCity,
}) {
  final resolved = districts?.where((district) => district.isActive).toList(
        growable: false,
      );
  if (resolved != null && resolved.isNotEmpty) {
    return resolved;
  }
  return FallbackDistrictCatalog.districtsForCity(city);
}

District? matchDistrict(
  String? value, {
  Iterable<District>? districts,
  String city = FallbackDistrictCatalog.defaultCity,
}) {
  final normalized = normalizedDistrictToken(value);
  if (normalized.isEmpty || normalized == normalizedDistrictToken(District.unknown.displayName)) {
    return null;
  }

  final catalog = resolveDistrictCatalog(districts: districts, city: city);

  // Prefer direct canonical district names over alias matches to avoid broad
  // alias districts overriding explicit district names in the input.
  District? leadingCanonicalMatch;
  var leadingCanonicalPosition = 1 << 30;
  var leadingCanonicalLength = -1;
  var leadingCanonicalSortOrder = 1 << 30;
  for (final district in catalog) {
    final canonicalTokens = <String>{
      normalizedDistrictToken(district.displayName),
      normalizedDistrictToken(district.name),
    }..removeWhere((token) => token.isEmpty);

    for (final token in canonicalTokens) {
      final position = normalized.indexOf(token);
      if (position == -1) {
        continue;
      }
      final isBetter =
          position < leadingCanonicalPosition ||
          (position == leadingCanonicalPosition &&
              token.length > leadingCanonicalLength) ||
          (position == leadingCanonicalPosition &&
              token.length == leadingCanonicalLength &&
              district.sortOrder < leadingCanonicalSortOrder);
      if (!isBetter) {
        continue;
      }
      leadingCanonicalMatch = district;
      leadingCanonicalPosition = position;
      leadingCanonicalLength = token.length;
      leadingCanonicalSortOrder = district.sortOrder;
    }
  }
  if (leadingCanonicalMatch != null) {
    return leadingCanonicalMatch;
  }

  District? bestMatch;
  var bestPosition = 1 << 30;
  var bestLength = -1;
  var bestSortOrder = 1 << 30;

  for (final district in catalog) {
    for (final term in district.searchTerms) {
      final normalizedTerm = normalizedDistrictToken(term);
      if (normalizedTerm.isEmpty) {
        continue;
      }
      final position = normalized.indexOf(normalizedTerm);
      if (position == -1) {
        continue;
      }
      final isBetterMatch =
          position < bestPosition ||
          (position == bestPosition && normalizedTerm.length > bestLength) ||
          (position == bestPosition &&
              normalizedTerm.length == bestLength &&
              district.sortOrder < bestSortOrder);
      if (!isBetterMatch) {
        continue;
      }
      bestMatch = district;
      bestPosition = position;
      bestLength = normalizedTerm.length;
      bestSortOrder = district.sortOrder;
    }
  }

  return bestMatch;
}

String normalizedDistrictOrUnknown(
  String? value, {
  Iterable<District>? districts,
  String city = FallbackDistrictCatalog.defaultCity,
}) {
  return matchDistrict(value, districts: districts, city: city)?.displayName ??
      District.unknown.displayName;
}

String? canonicalDistrictName(
  String? value, {
  Iterable<District>? districts,
  String city = FallbackDistrictCatalog.defaultCity,
}) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  if (normalizedDistrictToken(trimmed) ==
      normalizedDistrictToken(District.unknown.displayName)) {
    return null;
  }
  return matchDistrict(trimmed, districts: districts, city: city)?.displayName ??
      trimmed;
}

bool districtMatches(
  String? left,
  String? right, {
  Iterable<District>? districts,
  String city = FallbackDistrictCatalog.defaultCity,
}) {
  final leftCanonical =
      canonicalDistrictName(left, districts: districts, city: city);
  final rightCanonical =
      canonicalDistrictName(right, districts: districts, city: city);
  if (leftCanonical != null && rightCanonical != null) {
    return normalizeSearchText(leftCanonical) == normalizeSearchText(rightCanonical);
  }
  return normalizeSearchText(left ?? '') == normalizeSearchText(right ?? '');
}

List<String> districtDisplayNames(
  Iterable<District> districts, {
  bool includeUnknown = false,
}) {
  final sorted = districts.where((district) => district.isActive).toList()
    ..sort((left, right) {
      final order = left.sortOrder.compareTo(right.sortOrder);
      if (order != 0) {
        return order;
      }
      return normalizeSearchText(left.displayName).compareTo(
        normalizeSearchText(right.displayName),
      );
    });

  return <String>[
    if (includeUnknown) District.unknown.displayName,
    ...sorted.map((district) => district.displayName),
  ];
}

Map<String, dynamic>? districtLocationRestriction(District district) {
  if (district.hasBounds) {
    return <String, dynamic>{
      'rectangle': <String, dynamic>{
        'low': <String, dynamic>{
          'latitude': district.southwestLat,
          'longitude': district.southwestLng,
        },
        'high': <String, dynamic>{
          'latitude': district.northeastLat,
          'longitude': district.northeastLng,
        },
      },
    };
  }

  final radiusMeters = district.searchRadiusMeters;
  if (radiusMeters == null || radiusMeters <= 0) {
    return null;
  }
  final latDelta = radiusMeters / 111320.0;
  final cosLat = _clampCosLat(district.latitude);
  final lngDelta = radiusMeters / (111320.0 * cosLat);
  return <String, dynamic>{
    'rectangle': <String, dynamic>{
      'low': <String, dynamic>{
        'latitude': district.latitude - latDelta,
        'longitude': district.longitude - lngDelta,
      },
      'high': <String, dynamic>{
        'latitude': district.latitude + latDelta,
        'longitude': district.longitude + lngDelta,
      },
    },
  };
}

String normalizedDistrictToken(String? value) {
  return normalizeSearchText(value ?? '').replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

double _clampCosLat(double latitude) {
  final radians = latitude * 0.017453292519943295;
  final value = math.cos(radians).abs();
  if (value < 0.2) {
    return 0.2;
  }
  if (value > 1.0) {
    return 1.0;
  }
  return value;
}
