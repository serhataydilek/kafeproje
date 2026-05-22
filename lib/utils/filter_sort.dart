import '../models/index.dart';
import 'cafe_hours.dart';
import 'cafe_utils.dart';
import 'district_utils.dart';
import 'text_normalization.dart';

const Coordinates _unknownCafeCoordinates = Coordinates(
  lat: 41.0082,
  lng: 28.9784,
);

List<Cafe> applyFilters(
  List<Cafe> cafes,
  Filters filters, {
  Iterable<District>? districts,
}) {
  if (filters.activeCount == 0) {
    return cafes;
  }

  final predicates = <bool Function(Cafe)>[];
  final query = filters.searchQuery?.trim();

  if (filters.category != null) {
    final category = filters.category!;
    predicates.add((cafe) => cafe.category == category);
  }
  final selectedDistricts = filters.effectiveDistricts;
  if (selectedDistricts.isNotEmpty) {
    predicates.add(
      (cafe) => selectedDistricts.any(
        (district) =>
            _matchesDistrictFilter(cafe, district, districts: districts),
      ),
    );
  }
  if (filters.neighborhood != null) {
    final neighborhood = filters.neighborhood!;
    predicates.add(
      (cafe) => _sameNormalizedValue(cafe.neighborhood, neighborhood),
    );
  }
  if (filters.minRating != null) {
    final minRating = filters.minRating!;
    predicates.add((cafe) => (cafe.appRating ?? 0) >= minRating);
  }
  if (filters.priceLevel != null) {
    final priceLevel = filters.priceLevel!;
    predicates.add(
      (cafe) => cafe.hasPriceLevel && cafe.priceLevel == priceLevel,
    );
  }
  if (filters.wifiQuality != null) {
    final wifiQuality = filters.wifiQuality!;
    predicates.add((cafe) => cafe.communityWifiQuality == wifiQuality);
  }
  if (filters.outletAvailability != null) {
    final outletAvailability = filters.outletAvailability!;
    predicates.add(
      (cafe) => cafe.communityOutletAvailability == outletAvailability,
    );
  }
  if (filters.quietnessLevel != null) {
    final quietnessLevel = filters.quietnessLevel!;
    predicates.add((cafe) => cafe.communityQuietnessLevel == quietnessLevel);
  }
  if (filters.outdoorSeating != null) {
    final outdoorSeating = filters.outdoorSeating!;
    predicates.add((cafe) => cafe.communityOutdoorSeating == outdoorSeating);
  }
  if (filters.petFriendly != null) {
    final petFriendly = filters.petFriendly!;
    predicates.add((cafe) => cafe.communityPetFriendly == petFriendly);
  }
  if (filters.studyFriendly != null) {
    final studyFriendly = filters.studyFriendly!;
    predicates.add((cafe) => cafe.communityStudyFriendly == studyFriendly);
  }
  if (filters.openNow == true) {
    predicates.add(_isCafeOpenNow);
  }
  if (filters.smokingPolicy != null) {
    final smokingPolicy = filters.smokingPolicy!;
    predicates.add((cafe) => cafe.communitySmokingPolicy == smokingPolicy);
  }
  if (query != null && query.isNotEmpty) {
    predicates.add((cafe) => _matchesSearchQuery(cafe, query));
  }

  return cafes
      .where((cafe) => predicates.every((predicate) => predicate(cafe)))
      .toList(growable: false);
}

List<Cafe> sortCafes(
  List<Cafe> cafes,
  SortOption sortOption, [
  Coordinates? userLocation,
  bool inPlace = false,
  String? searchQuery,
]) {
  if (cafes.length < 2) {
    return cafes;
  }

  if (sortOption == SortOption.topRated && _isAlreadyTopRatedSorted(cafes)) {
    return cafes;
  }

  final next = inPlace ? cafes : List<Cafe>.from(cafes);

  int compareBySortOption(Cafe a, Cafe b) {
    switch (sortOption) {
      case SortOption.topRated:
        return _compareTopRated(a, b);
      case SortOption.cheapest:
        final priceCompare =
            a.priceLevel.sortScore.compareTo(b.priceLevel.sortScore);
        if (priceCompare != 0) {
          return priceCompare;
        }
        return _compareName(a, b);
      case SortOption.study:
        final studyCompare = _studyScore(b).compareTo(_studyScore(a));
        if (studyCompare != 0) {
          return studyCompare;
        }
        return _compareTopRated(a, b);
      case SortOption.aesthetic:
        final ambianceCompare =
            _aestheticScore(b).compareTo(_aestheticScore(a));
        if (ambianceCompare != 0) {
          return ambianceCompare;
        }
        return _compareTopRated(a, b);
      case SortOption.nearest:
        if (userLocation != null) {
          final distanceA = _distanceSortKey(userLocation, a);
          final distanceB = _distanceSortKey(userLocation, b);
          final distanceCompare = distanceA.compareTo(distanceB);
          if (distanceCompare != 0) {
            return distanceCompare;
          }
          return _compareName(a, b);
        }
        return _compareName(a, b);
    }
  }

  final normalizedSearchQuery = normalizeSearchText(searchQuery ?? '');
  if (normalizedSearchQuery.isNotEmpty) {
    final relevanceTierByCafeId = <String, int>{
      for (final cafe in next)
        cafe.id: _searchRelevanceTier(cafe, normalizedSearchQuery),
    };
    next.sort((a, b) {
      final relevanceCompare = (relevanceTierByCafeId[b.id] ?? 0)
          .compareTo(relevanceTierByCafeId[a.id] ?? 0);
      if (relevanceCompare != 0) {
        return relevanceCompare;
      }
      return compareBySortOption(a, b);
    });
    return next;
  }

  switch (sortOption) {
    case SortOption.topRated:
      next.sort(_compareTopRated);
      break;
    case SortOption.cheapest:
      next.sort((a, b) {
        final priceCompare =
            a.priceLevel.sortScore.compareTo(b.priceLevel.sortScore);
        if (priceCompare != 0) {
          return priceCompare;
        }
        return _compareName(a, b);
      });
      break;
    case SortOption.study:
      next.sort((a, b) {
        final studyCompare = _studyScore(b).compareTo(_studyScore(a));
        if (studyCompare != 0) {
          return studyCompare;
        }
        return _compareTopRated(a, b);
      });
      break;
    case SortOption.aesthetic:
      next.sort((a, b) {
        final ambianceCompare =
            _aestheticScore(b).compareTo(_aestheticScore(a));
        if (ambianceCompare != 0) {
          return ambianceCompare;
        }
        return _compareTopRated(a, b);
      });
      break;
    case SortOption.nearest:
      if (userLocation != null) {
        next.sort((a, b) {
          final distanceA = _distanceSortKey(userLocation, a);
          final distanceB = _distanceSortKey(userLocation, b);
          final distanceCompare = distanceA.compareTo(distanceB);
          if (distanceCompare != 0) {
            return distanceCompare;
          }
          return _compareName(a, b);
        });
      } else {
        next.sort(_compareName);
      }
      break;
  }

  return next;
}

List<Cafe> searchCafes(List<Cafe> cafes, String query) {
  final q = query.trim();
  if (q.isEmpty) {
    return cafes;
  }

  final normalizedQuery = normalizeSearchText(q);
  final ranked = cafes
      .map((cafe) =>
          (cafe: cafe, score: _searchRelevanceScore(cafe, normalizedQuery)))
      .where((entry) => entry.score > 0)
      .toList(growable: false)
    ..sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return _compareTopRated(left.cafe, right.cafe);
    });

  return ranked.map((entry) => entry.cafe).toList(growable: false);
}

bool _matchesDistrictFilter(
  Cafe cafe,
  String selectedDistrict, {
  Iterable<District>? districts,
}) {
  return districtMatches(
    cafe.district,
    selectedDistrict,
    districts: districts,
  );
}

bool _matchesSearchQuery(Cafe cafe, String query) {
  final normalizedQuery = normalizeSearchText(query);
  return _searchRelevanceScore(cafe, normalizedQuery) > 0;
}

int _searchRelevanceScore(Cafe cafe, String normalizedQuery) {
  if (normalizedQuery.isEmpty) {
    return 0;
  }

  final normalizedName = normalizeSearchText(cafe.name);
  final normalizedDistrict = normalizeSearchText(cafe.district);
  final normalizedNeighborhood = normalizeSearchText(cafe.neighborhood);
  final normalizedAddress = normalizeSearchText(cafe.address);
  final normalizedTags = cafe.tags
      .map(normalizeSearchText)
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);
  final queryTokens = _tokenizeNormalizedText(normalizedQuery);
  final searchableCombined = [
    normalizedName,
    normalizedDistrict,
    normalizedNeighborhood,
    normalizedAddress,
    ...normalizedTags,
  ].where((value) => value.isNotEmpty).join(' ');

  if (normalizedName == normalizedQuery) {
    return 1000;
  }

  if (normalizedName.startsWith(normalizedQuery)) {
    return 900;
  }

  if (_containsWordPrefix(normalizedName, normalizedQuery)) {
    return 840;
  }

  if (normalizedDistrict == normalizedQuery) {
    return 790;
  }
  if (normalizedNeighborhood == normalizedQuery) {
    return 780;
  }

  if (normalizedDistrict.startsWith(normalizedQuery) ||
      normalizedNeighborhood.startsWith(normalizedQuery)) {
    return 740;
  }

  if (normalizedName.contains(normalizedQuery)) {
    return 700;
  }

  if (normalizedAddress.contains(normalizedQuery)) {
    return 520;
  }

  if (normalizedTags.any((tag) => tag.contains(normalizedQuery))) {
    return 500;
  }

  if (queryTokens.isNotEmpty &&
      queryTokens.every(searchableCombined.contains)) {
    return 320;
  }

  return 0;
}

int _searchRelevanceTier(Cafe cafe, String normalizedQuery) {
  final score = _searchRelevanceScore(cafe, normalizedQuery);
  if (score >= 900) {
    return 5;
  }
  if (score >= 740) {
    return 4;
  }
  if (score >= 700) {
    return 3;
  }
  if (score >= 500) {
    return 2;
  }
  if (score > 0) {
    return 1;
  }
  return 0;
}

bool _containsWordPrefix(String normalizedValue, String normalizedQuery) {
  final words = _tokenizeNormalizedText(normalizedValue);
  return words.any((word) => word.startsWith(normalizedQuery));
}

List<String> _tokenizeNormalizedText(String value) {
  if (value.isEmpty) {
    return const <String>[];
  }
  return value
      .split(' ')
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

bool _isCafeOpenNow(Cafe cafe) {
  return cafe.openNow || resolveCafeOpenState(cafe.openingHours);
}

bool _sameNormalizedValue(String left, String right) {
  return normalizeSearchText(left) == normalizeSearchText(right);
}

bool _isAlreadyTopRatedSorted(List<Cafe> cafes) {
  for (var index = 1; index < cafes.length; index++) {
    if (_compareTopRated(cafes[index - 1], cafes[index]) > 0) {
      return false;
    }
  }
  return true;
}

int _compareTopRated(Cafe a, Cafe b) {
  final aRating = a.appRating ?? 0;
  final bRating = b.appRating ?? 0;
  final ratingCompare = bRating.compareTo(aRating);
  if (ratingCompare != 0) {
    return ratingCompare;
  }

  final reviewCompare =
      (b.appReviewCount ?? 0).compareTo(a.appReviewCount ?? 0);
  if (reviewCompare != 0) {
    return reviewCompare;
  }

  return _compareName(a, b);
}

int _compareName(Cafe a, Cafe b) {
  return normalizeSearchText(a.name).compareTo(normalizeSearchText(b.name));
}

double _distanceSortKey(Coordinates userLocation, Cafe cafe) {
  if (!_hasUsableCafeCoordinates(cafe.coordinates)) {
    return double.infinity;
  }
  return distanceKm(userLocation, cafe.coordinates);
}

bool _hasUsableCafeCoordinates(Coordinates coordinates) {
  final lat = coordinates.lat;
  final lng = coordinates.lng;
  if (!lat.isFinite || !lng.isFinite) {
    return false;
  }

  if (lat.abs() > 90 || lng.abs() > 180) {
    return false;
  }

  return coordinates != _unknownCafeCoordinates;
}

int _studyScore(Cafe cafe) {
  if (!cafe.hasCommunityExperienceData) {
    return -1;
  }

  return ((cafe.communityStudyFriendly ?? false) ? 2 : 0) +
      (cafe.communityWifiQuality?.score ?? 0) +
      (cafe.communityOutletAvailability?.score ?? 0) +
      (cafe.communityQuietnessLevel?.score ?? 0);
}

double _aestheticScore(Cafe cafe) {
  return cafe.communityAmbianceScore ?? -1;
}
