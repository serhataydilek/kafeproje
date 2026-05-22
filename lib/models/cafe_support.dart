import '../data/fallback_districts.dart';
import '../utils/district_utils.dart';
import '../utils/text_normalization.dart';
import 'district.dart';

extension DistrictExtension on District {
  static District fromString(
    String value, {
    Iterable<District>? districts,
    String city = FallbackDistrictCatalog.defaultCity,
  }) {
    return tryFromText(value, districts: districts, city: city) ??
        District.unknown;
  }

  static District? tryFromText(
    String value, {
    Iterable<District>? districts,
    String city = FallbackDistrictCatalog.defaultCity,
  }) {
    return matchDistrict(value, districts: districts, city: city);
  }
}

String normalizedDistrictOrUnknown(
  String? value, {
  Iterable<District>? districts,
  String city = FallbackDistrictCatalog.defaultCity,
}) {
  return matchDistrict(value, districts: districts, city: city)?.displayName ??
      District.unknown.displayName;
}

enum CafeCategory {
  normalCafe,
  cafeLounge,
}

extension CafeCategoryExtension on CafeCategory {
  String get value {
    switch (this) {
      case CafeCategory.normalCafe:
        return 'normal_cafe';
      case CafeCategory.cafeLounge:
        return 'cafe_lounge';
    }
  }

  String get displayName {
    switch (this) {
      case CafeCategory.normalCafe:
        return 'Normal Cafe';
      case CafeCategory.cafeLounge:
        return 'Cafe Lounge';
    }
  }

  static CafeCategory fromString(String value) {
    final normalized =
        _normalizedToken(value).replaceAll('coffeehouse', 'cafe');
    if (normalized.contains('lounge')) {
      return CafeCategory.cafeLounge;
    }
    return CafeCategory.normalCafe;
  }
}

enum WifiQuality { weak, average, strong }

extension WifiQualityExtension on WifiQuality {
  String get value {
    switch (this) {
      case WifiQuality.weak:
        return 'Weak';
      case WifiQuality.average:
        return 'Average';
      case WifiQuality.strong:
        return 'Strong';
    }
  }

  static WifiQuality fromString(String value) {
    switch (_normalizedToken(value)) {
      case 'weak':
        return WifiQuality.weak;
      case 'strong':
        return WifiQuality.strong;
      default:
        return WifiQuality.average;
    }
  }

  int get score {
    switch (this) {
      case WifiQuality.weak:
        return 1;
      case WifiQuality.average:
        return 2;
      case WifiQuality.strong:
        return 3;
    }
  }
}

enum OutletAvailability { low, medium, high }

extension OutletAvailabilityExtension on OutletAvailability {
  String get value {
    switch (this) {
      case OutletAvailability.low:
        return 'Low';
      case OutletAvailability.medium:
        return 'Medium';
      case OutletAvailability.high:
        return 'High';
    }
  }

  static OutletAvailability fromString(String value) {
    switch (_normalizedToken(value)) {
      case 'low':
        return OutletAvailability.low;
      case 'high':
        return OutletAvailability.high;
      default:
        return OutletAvailability.medium;
    }
  }

  int get score {
    switch (this) {
      case OutletAvailability.low:
        return 1;
      case OutletAvailability.medium:
        return 2;
      case OutletAvailability.high:
        return 3;
    }
  }
}

enum QuietnessLevel { busy, balanced, quiet }

extension QuietnessLevelExtension on QuietnessLevel {
  String get value {
    switch (this) {
      case QuietnessLevel.busy:
        return 'Busy';
      case QuietnessLevel.balanced:
        return 'Balanced';
      case QuietnessLevel.quiet:
        return 'Quiet';
    }
  }

  static QuietnessLevel fromString(String value) {
    switch (_normalizedToken(value)) {
      case 'busy':
        return QuietnessLevel.busy;
      case 'quiet':
        return QuietnessLevel.quiet;
      default:
        return QuietnessLevel.balanced;
    }
  }

  int get score {
    switch (this) {
      case QuietnessLevel.busy:
        return 1;
      case QuietnessLevel.balanced:
        return 2;
      case QuietnessLevel.quiet:
        return 3;
    }
  }
}

enum SmokingPolicy { allowed, outdoorOnly, notAllowed }

extension SmokingPolicyExtension on SmokingPolicy {
  String get value {
    switch (this) {
      case SmokingPolicy.allowed:
        return 'allowed';
      case SmokingPolicy.outdoorOnly:
        return 'outdoor_only';
      case SmokingPolicy.notAllowed:
        return 'not_allowed';
    }
  }

  static SmokingPolicy fromString(String value) {
    switch (_normalizedToken(value).replaceAll('-', '_')) {
      case 'allowed':
        return SmokingPolicy.allowed;
      case 'mixed':
      case 'outdoor_only':
        return SmokingPolicy.outdoorOnly;
      default:
        return SmokingPolicy.notAllowed;
    }
  }

  int get score {
    switch (this) {
      case SmokingPolicy.allowed:
        return 1;
      case SmokingPolicy.outdoorOnly:
        return 2;
      case SmokingPolicy.notAllowed:
        return 3;
    }
  }
}

enum PriceLevel { cheap, moderate, expensive }

extension PriceLevelExtension on PriceLevel {
  String get value {
    switch (this) {
      case PriceLevel.cheap:
        return r'$';
      case PriceLevel.moderate:
        return r'$$';
      case PriceLevel.expensive:
        return r'$$$';
    }
  }

  static PriceLevel fromString(String value) {
    switch (value.trim()) {
      case r'$':
      case 'PRICE_LEVEL_INEXPENSIVE':
        return PriceLevel.cheap;
      case r'$$$':
      case 'PRICE_LEVEL_EXPENSIVE':
      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return PriceLevel.expensive;
      default:
        return PriceLevel.moderate;
    }
  }

  int get sortScore {
    switch (this) {
      case PriceLevel.cheap:
        return 1;
      case PriceLevel.moderate:
        return 2;
      case PriceLevel.expensive:
        return 3;
    }
  }
}

enum SortOption { topRated, nearest, cheapest, study, aesthetic }

enum PreferenceKey {
  wifi,
  quiet,
  outlet,
  study,
  aesthetic,
  outdoor,
  petFriendly,
  budget,
}

extension PreferenceKeyExtension on PreferenceKey {
  String get value {
    switch (this) {
      case PreferenceKey.wifi:
        return 'wifi';
      case PreferenceKey.quiet:
        return 'quiet';
      case PreferenceKey.outlet:
        return 'outlet';
      case PreferenceKey.study:
        return 'study';
      case PreferenceKey.aesthetic:
        return 'aesthetic';
      case PreferenceKey.outdoor:
        return 'outdoor';
      case PreferenceKey.petFriendly:
        return 'petFriendly';
      case PreferenceKey.budget:
        return 'budget';
    }
  }

  static PreferenceKey fromString(String value) {
    return PreferenceKey.values.firstWhere(
      (item) => item.value == value,
      orElse: () => PreferenceKey.wifi,
    );
  }
}

enum ProfileRole {
  admin,
  cafeOwner,
  user;

  static ProfileRole fromString(String? value, {bool isAdmin = false}) {
    if (isAdmin) {
      return ProfileRole.admin;
    }
    switch (value?.trim().toLowerCase()) {
      case 'admin':
        return ProfileRole.admin;
      case 'cafe_owner':
      case 'cafeowner':
      case 'owner':
        return ProfileRole.cafeOwner;
      case 'user':
      default:
        return ProfileRole.user;
    }
  }

  String get value => switch (this) {
        ProfileRole.admin => 'admin',
        ProfileRole.cafeOwner => 'cafe_owner',
        ProfileRole.user => 'user',
      };
}

String normalizedToken(String value) => _normalizedToken(value);

String _normalizedToken(String value) {
  return normalizeSearchText(value).replaceAll(RegExp(r'[^a-z0-9_]+'), '');
}
