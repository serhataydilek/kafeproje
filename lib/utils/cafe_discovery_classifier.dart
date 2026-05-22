import '../models/index.dart';
import 'app_logger.dart';
import 'text_normalization.dart';

const Set<String> kAllowedCafePlaceTypes = {
  'cafe',
  'coffee_shop',
  'coffee_roastery',
  'coffee_stand',
  'tea_house',
};

const List<String> kPositiveCafeKeywords = [
  'cafe',
  'kafe',
  'coffee',
  'kahve',
  'espresso',
  'roastery',
  'roaster',
  'third wave',
  'thirdwave',
  'specialty',
  'speciality',
  'brew',
];

const Set<String> kDeniedPrimaryPlaceTypes = {
  'accounting',
  'atm',
  'bakery',
  'bank',
  'bar',
  'bus_station',
  'car_rental',
  'clothing_store',
  'convenience_store',
  'dessert_restaurant',
  'drugstore',
  'electronics_store',
  'fast_food_restaurant',
  'gas_station',
  'grocery_store',
  'hamburger_restaurant',
  'hardware_store',
  'home_goods_store',
  'insurance_agency',
  'internet_cafe',
  'kebab_restaurant',
  'liquor_store',
  'lodging',
  'market',
  'meal_delivery',
  'meal_takeaway',
  'pharmacy',
  'pizza_restaurant',
  'pub',
  'ramen_restaurant',
  'real_estate_agency',
  'restaurant',
  'sandwich_shop',
  'seafood_restaurant',
  'shoe_store',
  'shopping_mall',
  'steak_house',
  'steakhouse',
  'store',
  'supermarket',
  'tourist_attraction',
  'travel_agency',
  'turkish_restaurant',
};

const Set<String> _weakMixedVenuePrimaryTypes = {
  'bar',
  'pub',
};

const List<String> kDeniedVenueKeywords = [
  'turizm',
  'tourism',
  'ofis',
  'office',
  'kuruyemis',
  'iddaa',
  'ganyan',
  'emlak',
  'rent a car',
  'seyahat',
  'tours',
  'sigorta',
  'bakkal',
  'market',
  'mini market',
  'supermarket',
  'grocery',
  'grocer',
  'convenience store',
  'tekel',
  'gida',
  'manav',
  'kiraathane',
  'kirathane',
  'kahvehane',
  'kahvehanesi',
  'cay ocagi',
  'cay bahcesi',
  'lokali',
  'lokal',
  'lokanta',
  'restoran',
  'restaurant',
  'yemek salonu',
  'pizza',
  'pizzaci',
  'pide',
  'pideci',
  'doner',
  'donerci',
  'simit sarayi',
  'firin',
  'unlu mamul',
  'unlu mamulleri',
  'ekmek',
  'bakery',
  'pastane',
  'patisserie',
  'borekci',
  'borek',
  'borekcisi',
  'borek ve pide',
  'borek ve pide salonu',
  'pide salonu',
  'kebab',
  'bufe',
  'lokantasi',
  'ocakbasi',
  'kebap',
  'lahmacun',
  'kasap',
  'tantuni',
  'kofte',
  'corba',
  'balik',
  'balik evi',
  'seafood',
  'steak',
  'steakhouse',
  'burger',
  'burgerci',
  'hamburgeci',
  'hamburger',
  'izgara',
  'hotel',
  'otel',
  'museum',
  'muze',
  'muzesi',
  'gas station',
  'petrol',
  'benzinlik',
  'akaryakit',
  'toptan',
  'wholesale',
  'catering',
  'banquet',
  'event venue',
  'kokorec',
  'kokoreç',
  'meyhane',
  'corbacisi',
  // Gaming / internet cafe venues
  'internet cafe',
  'internet kafe',
  'internet salonu',
  'e-spor',
  'espor',
  'esports',
  'e-sport',
  'esport',
  'gaming',
  'game center',
  'game centre',
  'playstation',
  'ps cafe',
  'ps kafe',
  'oyun salonu',
  'oyun merkezi',
  'xbox',
  'konsol',
  'atari salonu',
  'bilardo',
];

const Set<String> _strongCafeNameSignalTokens = {
  'cafe',
  'kafe',
  'coffee',
  'kahve',
  'espresso',
};

const Set<String> _strongCafeGoogleTypes = {
  'cafe',
  'coffee_shop',
};

const Set<String> _weakMixedVenueTokens = {
  'bar',
  'pub',
  'bistro',
  'cocktail',
  'cocktails',
};

const Set<String> _nargileOnlyTokens = {
  'nargile',
  'nargileci',
  'hookah',
  'shisha',
};

const Set<String> _hardBlockedSingleTokens = {
  'doner',
  'donerci',
  'ocakbasi',
  'lahmacun',
};

const Set<String> _hardBlockedPhrasePatterns = {
  'borek ve pide',
  'borek ve pide salonu',
  'pide salonu',
  'lahmacun salonu',
  'yemek salonu',
  'unlu mamul',
  'unlu mamulleri',
  // Gaming / internet cafe compound phrases
  'internet cafe',
  'internet kafe',
  'internet salonu',
  'e spor',
  'playstation cafe',
  'playstation kafe',
  'gaming cafe',
  'gaming kafe',
  'computer cafe',
  'computer kafe',
  'oyun cafe',
  'oyun kafe',
  'oyun salonu',
  'oyun merkezi',
  'ps cafe',
  'ps kafe',
  'game center',
  'game centre',
  'atari salonu',
  'gas station',
  'benzin istasyonu',
  'petrol istasyonu',
  'hotel lobby',
  'museum cafe',
};

const Set<String> _strongPositiveCafeTokens = {
  'cafe',
  'kafe',
  'coffee',
  'kahve',
  'espresso',
  'roastery',
  'thirdwave',
  'specialty',
};

const Set<String> _strongNegativeVenueTokens = {
  'borek',
  'borekci',
  'borekcisi',
  'pide',
  'pideci',
  'kebab',
  'kebap',
  'doner',
  'donerci',
  'ocakbasi',
  'lahmacun',
  'pizza',
  'pizzaci',
  'tantuni',
  'kofte',
  'corba',
  'balik',
  'izgara',
  'firin',
  'simit',
  'kiraathane',
  'kirathane',
  'kahvehane',
  'kahvehanesi',
  'hotel',
  'otel',
  'museum',
  'muze',
  'muzesi',
  'petrol',
  'benzinlik',
  'akaryakit',
  // Restaurant-identity tokens (meal-focused, no cafe signal needed to deny)
  'steakhouse',
  'burger',
  'burgerci',
  'hamburgeci',
  'seafood',
  'kokorec',
  'meyhane',
  'lokanta',
  'lokantasi',
  'restoran',
  'meal_takeaway',
  'meal_delivery',
  // Gaming / internet venue tokens
  'internet',
  'esports',
  'espor',
  'playstation',
  'gaming',
  'xbox',
  'konsol',
  'bilardo',
  // Market / grocery venues
  'market',
  'bakkal',
  'grocery',
  'grocer',
  'supermarket',
  'tekel',
};

const Set<String> _softNegativeVenueTokens = {
  'bakery',
  'pastane',
  'patisserie',
  'kasap',
  'catering',
  'wholesale',
  'banquet',
  // Grill/steak as soft-negatives: penalise score but allow strong cafe
  // primary types (e.g. 'cafe & grill') to still pass.
  'grill',
  'steak',
};

const Set<String> _identityNoiseTokens = {
  'istanbul',
  'turkiye',
  'turkey',
  'unknown',
  'venue',
  'place',
};

const Set<String> _adminCafeAllowOverrideTags = {
  'admin_allow_cafe',
  'admin allow cafe',
  'admin allow-cafe',
  'force_cafe',
  'force cafe',
  'manual_verified_cafe',
  'manual verified cafe',
};

const int _minimumAcceptedCafeScore = 3;
const int _minimumScoreWhenStrongNegativePresent = 6;
const int _maxTokenCacheEntries = 2048;

final Map<String, List<String>> _tokenCache = <String, List<String>>{};

const List<String> kWhitelistedCafeBrands = [
  'starbucks',
  'mikel coffee',
  'caffe nero',
  'cafe nero',
  'kahve dunyasi',
  'espressolab',
  'espresso lab',
  'caribou coffee',
  'caribou',
  'tchibo',
  'costa coffee',
  'fig coffee',
  'fig coffe',
  'fig coffee cocktail',
];

class CafeVenueAssessment {
  const CafeVenueAssessment({
    required this.isValidCafe,
    required this.score,
    required this.hasStrongPositiveSignal,
    required this.hasStrongNegativeSignal,
    required this.hasMeaningfulIdentity,
    required this.isHardBlocked,
    this.allowReason,
    this.denyReason,
    this.primaryType = '',
    this.types = const <String>{},
    this.name = '',
  });

  final bool isValidCafe;
  final int score;
  final bool hasStrongPositiveSignal;
  final bool hasStrongNegativeSignal;
  final bool hasMeaningfulIdentity;
  final bool isHardBlocked;
  final String? allowReason;
  final String? denyReason;
  final String primaryType;
  final Set<String> types;
  final String name;
}

CafeVenueAssessment assessGoogleCafeCandidate(Map<String, dynamic> place) {
  final rawName = place['displayName']?['text'] as String? ?? '';
  final primaryType =
      normalizeSearchText(place['primaryType'] as String? ?? '');
  final types = normalizedGooglePlaceTypes(place['types']);
  final normalizedName = normalizeSearchText(rawName);
  final normalizedAddress =
      normalizeSearchText(place['shortFormattedAddress'] as String? ?? '');
  final searchableText = [
    normalizedName,
    normalizedAddress,
  ].where((value) => value.isNotEmpty).join(' ');

  if (shouldRejectForPublicDiscoveryScript(rawName)) {
    if (kVerboseCafeDiagnostics) {
      AppLogger.debug(
        '[CAFE_CLASSIFIER_REJECT] reason=arabic_script_name nameHash=${rawName.hashCode.abs()} surface=merge',
        key: 'cafe-classifier-reject-arabic-${rawName.hashCode.abs()}',
        throttle: Duration.zero,
      );
    }
    return CafeVenueAssessment(
      isValidCafe: false,
      score: 0,
      hasStrongPositiveSignal: false,
      hasStrongNegativeSignal: false,
      hasMeaningfulIdentity: normalizedName.isNotEmpty,
      isHardBlocked: true,
      denyReason: 'arabic_script_name',
      primaryType: primaryType,
      types: types,
      name: normalizedName,
    );
  }

  return _assessVenueSignals(
    primaryType: primaryType,
    placeTypes: types,
    searchableText: searchableText,
    normalizedName: normalizedName,
  );
}

int googleCafeConfidenceScore(Map<String, dynamic> place) {
  return assessGoogleCafeCandidate(place).score;
}

CafeVenueAssessment assessCafeVenue(Cafe cafe) {
  final normalizedName = normalizeSearchText(cafe.name);
  final normalizedAddress = normalizeSearchText(cafe.address);
  final normalizedCategory = normalizeSearchText(cafe.category.name);
  final normalizedTags = cafe.tags
      .map(normalizeSearchText)
      .where((value) => value.isNotEmpty)
      .join(' ');
  final searchableText = [
    normalizedName,
    normalizedAddress,
    normalizedCategory,
    normalizedTags,
  ].where((value) => value.isNotEmpty).join(' ');

  final placeTypes = <String>{
    normalizedCategory,
    for (final tag in cafe.tags)
      ..._tokenizeNormalizedText(normalizeSearchText(tag)),
  }..removeWhere((value) => value.isEmpty);

  return _assessVenueSignals(
    primaryType: normalizedCategory,
    placeTypes: placeTypes,
    searchableText: searchableText,
    normalizedName: normalizedName,
  );
}

int cafeVenueConfidenceScore(Cafe cafe) {
  return assessCafeVenue(cafe).score;
}

bool isLikelyCafeVenue({
  required String primaryType,
  required Set<String> placeTypes,
  required String searchableText,
}) {
  final normalizedPrimaryType = normalizeSearchText(primaryType);
  final normalizedSearchableText = normalizeSearchText(searchableText);
  final normalizedPlaceTypes = placeTypes
      .map(normalizeSearchText)
      .where((value) => value.isNotEmpty)
      .toSet();

  return _assessVenueSignals(
    primaryType: normalizedPrimaryType,
    placeTypes: normalizedPlaceTypes,
    searchableText: normalizedSearchableText,
    normalizedName: normalizedSearchableText,
  ).isValidCafe;
}

Set<String> normalizedGooglePlaceTypes(Object? rawTypes) {
  if (rawTypes is! List) {
    return const <String>{};
  }

  return rawTypes
      .whereType<String>()
      .map(normalizeSearchText)
      .where((type) => type.isNotEmpty)
      .toSet();
}

bool shouldIncludeGoogleCafeCandidate(
  Map<String, dynamic> place, {
  String? expectedDistrict,
}) {
  return assessGoogleCafeCandidate(place).isValidCafe;
}

bool containsArabicScript(String text) {
  for (final codePoint in text.runes) {
    if ((codePoint >= 0x0600 && codePoint <= 0x06FF) ||
        (codePoint >= 0x0750 && codePoint <= 0x077F) ||
        (codePoint >= 0x08A0 && codePoint <= 0x08FF) ||
        (codePoint >= 0xFB50 && codePoint <= 0xFDFF) ||
        (codePoint >= 0xFE70 && codePoint <= 0xFEFF)) {
      return true;
    }
  }
  return false;
}

bool shouldRejectForPublicDiscoveryScript(String displayName) {
  return containsArabicScript(displayName);
}

bool isPublicDiscoveryScriptBlockedCafe(Cafe cafe) {
  return shouldRejectForPublicDiscoveryScript(cafe.name) &&
      !_hasAdminAllowCafeOverride(cafe);
}

bool isCafeBlockedFromPublic(Cafe cafe) {
  if (cafe.isDeleted) {
    return true;
  }

  final status = cafe.ownerApprovalStatus.trim().toLowerCase();
  if (status.isNotEmpty && status != 'approved') {
    return true;
  }

  return false;
}

bool isStrictlyValidCafe(Cafe cafe) {
  if (isCafeBlockedFromPublic(cafe)) {
    return false;
  }

  if (_hasAdminAllowCafeOverride(cafe)) {
    return true;
  }

  if (isPublicDiscoveryScriptBlockedCafe(cafe)) {
    if (kVerboseCafeDiagnostics) {
      AppLogger.debug(
        '[CAFE_CLASSIFIER_REJECT] reason=arabic_script_name nameHash=${cafe.name.hashCode.abs()} surface=cache',
        key: 'cafe-classifier-reject-arabic-cafe-${cafe.id}',
        throttle: Duration.zero,
      );
    }
    return false;
  }

  final assessment = assessCafeVenue(cafe);
  if (assessment.isHardBlocked) {
    return false;
  }

  if (assessment.isValidCafe) {
    return true;
  }

  final placeId = cafe.placeId?.trim();
  if (placeId == null || placeId.isEmpty) {
    return !assessment.hasStrongNegativeSignal &&
        assessment.hasMeaningfulIdentity;
  }

  return false;
}

CafeVenueAssessment _assessVenueSignals({
  required String primaryType,
  required Set<String> placeTypes,
  required String searchableText,
  required String normalizedName,
}) {
  final normalizedPrimaryType = normalizeSearchText(primaryType);
  final normalizedSearchableText = normalizeSearchText(searchableText);
  final tokens = _tokenizeNormalizedText(normalizedSearchableText);
  final tokenSet = tokens.toSet();
  final bigrams = _buildNgrams(tokens, 2);
  final trigrams = _buildNgrams(tokens, 3);

  final hasWhitelistedBrand =
      _hasWhitelistedCafeBrand(normalizedSearchableText);

  // Deny-first: hard-blocked venue identities override cafe-like names,
  // brand-like wording, and Google cafe/coffee_shop typing.
  final hardBlocked = _matchesHardBlockedPattern(
      tokenSet, bigrams, trigrams, normalizedSearchableText);
  if (hardBlocked) {
    if (kVerboseCafeDiagnostics) {
      AppLogger.debug(
        '[CAFE_CLASSIFIER_REJECT] reason=hard_blocked_venue_identity name=${normalizedName.length > 40 ? normalizedName.substring(0, 40) : normalizedName} primaryType=$normalizedPrimaryType',
        key: 'cafe-classifier-reject-hard-${normalizedName.hashCode.abs()}',
        throttle: Duration.zero,
      );
    }
    return CafeVenueAssessment(
      isValidCafe: false,
      score: -10,
      hasStrongPositiveSignal: false,
      hasStrongNegativeSignal: true,
      hasMeaningfulIdentity: true,
      isHardBlocked: true,
      denyReason: 'hard_blocked_venue_identity',
      primaryType: normalizedPrimaryType,
      types: placeTypes,
      name: normalizedName,
    );
  }

  final hasAllowedPrimaryType =
      kAllowedCafePlaceTypes.contains(normalizedPrimaryType);
  final hasAllowedSecondaryType =
      placeTypes.any(kAllowedCafePlaceTypes.contains);
  final hasAllowedType = hasAllowedPrimaryType || hasAllowedSecondaryType;

  final hasDeniedPrimaryType =
      kDeniedPrimaryPlaceTypes.contains(normalizedPrimaryType);
  final hasWeakMixedVenuePrimaryType =
      _weakMixedVenuePrimaryTypes.contains(normalizedPrimaryType);
  final hasWeakMixedVenueNameSignal =
      tokenSet.any(_weakMixedVenueTokens.contains);
  final hasStrongCafeNameSignal =
      tokenSet.any(_strongCafeNameSignalTokens.contains);
  final hasStrongCafeGoogleType =
      _strongCafeGoogleTypes.contains(normalizedPrimaryType) ||
          placeTypes.any(_strongCafeGoogleTypes.contains);
  final hasExplicitStrongCafeSignal =
      hasStrongCafeNameSignal || hasStrongCafeGoogleType;
  final hasNargileOnlySignal =
      tokenSet.any(_nargileOnlyTokens.contains) && !hasExplicitStrongCafeSignal;
  final hasRestaurantIdentityToken =
      tokenSet.contains('restaurant') || tokenSet.contains('restoran');

  final strongPositiveHits = _countUniqueSignalHits(
    tokens,
    _strongPositiveCafeTokens,
  );
  final strongNegativeHits = _countUniqueSignalHits(
    tokens,
    _strongNegativeVenueTokens,
  );
  final softNegativeHits = _countUniqueSignalHits(
    tokens,
    _softNegativeVenueTokens,
  );

  if (hasNargileOnlySignal) {
    return CafeVenueAssessment(
      isValidCafe: false,
      score: -3,
      hasStrongPositiveSignal: false,
      hasStrongNegativeSignal: true,
      hasMeaningfulIdentity: true,
      isHardBlocked: false,
      denyReason: 'nargile_without_cafe_signal',
      primaryType: normalizedPrimaryType,
      types: placeTypes,
      name: normalizedName,
    );
  }

  if (hasRestaurantIdentityToken && !hasStrongCafeGoogleType) {
    if (kVerboseCafeDiagnostics) {
      AppLogger.debug(
        '[CAFE_CLASSIFIER_REJECT] reason=restaurant_false_positive name=${normalizedName.length > 40 ? normalizedName.substring(0, 40) : normalizedName}',
        key:
            'cafe-classifier-reject-restaurant-${normalizedName.hashCode.abs()}',
        throttle: Duration.zero,
      );
    }
    return CafeVenueAssessment(
      isValidCafe: false,
      score: -4,
      hasStrongPositiveSignal: false,
      hasStrongNegativeSignal: true,
      hasMeaningfulIdentity: true,
      isHardBlocked: false,
      denyReason: 'restaurant_false_positive',
      primaryType: normalizedPrimaryType,
      types: placeTypes,
      name: normalizedName,
    );
  }

  // Deny-first: strong venue-negative tokens are identity signals, not score
  // penalties. They must not be rescued by a cafe token, known brand, or
  // Google primary/secondary cafe type.
  if (strongNegativeHits > 0) {
    if (kVerboseCafeDiagnostics) {
      AppLogger.debug(
        '[CAFE_CLASSIFIER_REJECT] reason=strong_negative_venue_token name=${normalizedName.length > 40 ? normalizedName.substring(0, 40) : normalizedName} primaryType=$normalizedPrimaryType hits=$strongNegativeHits',
        key: 'cafe-classifier-reject-neg-${normalizedName.hashCode.abs()}',
        throttle: Duration.zero,
      );
    }
    return CafeVenueAssessment(
      isValidCafe: false,
      score: -(strongNegativeHits * 3),
      hasStrongPositiveSignal: false,
      hasStrongNegativeSignal: true,
      hasMeaningfulIdentity: true,
      isHardBlocked: false,
      denyReason: 'strong_negative_venue_token',
      primaryType: normalizedPrimaryType,
      types: placeTypes,
      name: normalizedName,
    );
  }

  final hasMeaningfulIdentity = _hasMeaningfulIdentity(
    normalizedName: normalizedName,
    tokens: tokens,
    hasAllowedType: hasAllowedType,
    hasWhitelistedBrand: hasWhitelistedBrand,
  );

  // Positive scoring
  var score = 0;
  if (hasAllowedPrimaryType) {
    score += 5;
  }
  if (hasAllowedSecondaryType) {
    score += 4;
  }
  if (hasWhitelistedBrand) {
    score += 8;
  }
  score += strongPositiveHits * 2;

  final hasWeakMixedVenueSignal =
      hasWeakMixedVenuePrimaryType || hasWeakMixedVenueNameSignal;
  final deniedPrimaryDominates = hasDeniedPrimaryType &&
      !hasAllowedSecondaryType &&
      !(hasExplicitStrongCafeSignal && hasWeakMixedVenueSignal);

  if (hasDeniedPrimaryType && !hasAllowedSecondaryType) {
    score -= 4;
  }
  score -= strongNegativeHits * 3;
  score -= softNegativeHits;

  if (_hasDeniedVenueKeyword(normalizedSearchableText)) {
    score -= 2;
  }
  if (!hasMeaningfulIdentity) {
    score -= 3;
  }

  final hasStrongPositiveSignal = hasWhitelistedBrand ||
      hasAllowedType ||
      hasExplicitStrongCafeSignal ||
      strongPositiveHits >= 2 ||
      kPositiveCafeKeywords.any(tokenSet.contains);
  final hasStrongNegativeSignal =
      hardBlocked || strongNegativeHits > 0 || deniedPrimaryDominates;

  final dominatedByNegative =
      hasStrongNegativeSignal && score < _minimumScoreWhenStrongNegativePresent;

  final isValidCafe = !hardBlocked &&
      hasMeaningfulIdentity &&
      ((score >= _minimumAcceptedCafeScore && !dominatedByNegative) ||
          (hasStrongPositiveSignal && !dominatedByNegative));

  final allowReason = isValidCafe
      ? _allowReason(
          hasExplicitStrongCafeSignal: hasExplicitStrongCafeSignal,
          hasWhitelistedBrand: hasWhitelistedBrand,
          hasAllowedType: hasAllowedType,
          score: score,
        )
      : null;
  final denyReason = isValidCafe
      ? null
      : _denyReason(
          dominatedByNegative: dominatedByNegative,
          hasMeaningfulIdentity: hasMeaningfulIdentity,
          hasDeniedPrimaryType: hasDeniedPrimaryType,
          hasWeakMixedVenueSignal: hasWeakMixedVenueSignal,
          score: score,
        );

  if (isValidCafe && kVerboseCafeDiagnostics) {
    if (hasRestaurantIdentityToken && hasStrongCafeGoogleType) {
      AppLogger.debug(
        '[CAFE_CLASSIFIER_ACCEPT] reason=coffee_or_cafe_overrides_restaurant name=${normalizedName.length > 40 ? normalizedName.substring(0, 40) : normalizedName}',
        key:
            'cafe-classifier-accept-restaurant-${normalizedName.hashCode.abs()}',
        throttle: Duration.zero,
      );
    }
    AppLogger.debug(
      '[CAFE_CLASSIFIER_ACCEPT] reason=${allowReason ?? 'score_$score'} name=${normalizedName.length > 40 ? normalizedName.substring(0, 40) : normalizedName} primaryType=$normalizedPrimaryType score=$score',
      key: 'cafe-classifier-accept-${normalizedName.hashCode.abs()}',
      throttle: Duration.zero,
    );
  } else if (kVerboseCafeDiagnostics) {
    AppLogger.debug(
      '[CAFE_CLASSIFIER_REJECT] reason=${denyReason ?? 'unknown'} name=${normalizedName.length > 40 ? normalizedName.substring(0, 40) : normalizedName} primaryType=$normalizedPrimaryType score=$score',
      key: 'cafe-classifier-reject-score-${normalizedName.hashCode.abs()}',
      throttle: Duration.zero,
    );
  }

  return CafeVenueAssessment(
    isValidCafe: isValidCafe,
    score: score,
    hasStrongPositiveSignal: hasStrongPositiveSignal,
    hasStrongNegativeSignal: hasStrongNegativeSignal,
    hasMeaningfulIdentity: hasMeaningfulIdentity,
    isHardBlocked: hardBlocked,
    allowReason: allowReason,
    denyReason: denyReason,
    primaryType: normalizedPrimaryType,
    types: placeTypes,
    name: normalizedName,
  );
}

String _allowReason({
  required bool hasExplicitStrongCafeSignal,
  required bool hasWhitelistedBrand,
  required bool hasAllowedType,
  required int score,
}) {
  if (hasExplicitStrongCafeSignal) {
    return 'strong_cafe_signal';
  }
  if (hasWhitelistedBrand) {
    return 'whitelisted_cafe_brand';
  }
  if (hasAllowedType) {
    return 'allowed_google_place_type';
  }
  return 'score_$score';
}

String _denyReason({
  required bool dominatedByNegative,
  required bool hasMeaningfulIdentity,
  required bool hasDeniedPrimaryType,
  required bool hasWeakMixedVenueSignal,
  required int score,
}) {
  if (!hasMeaningfulIdentity) {
    return 'missing_meaningful_identity';
  }
  if (dominatedByNegative) {
    return 'dominated_by_negative_signal';
  }
  if (hasDeniedPrimaryType && !hasWeakMixedVenueSignal) {
    return 'denied_primary_type';
  }
  return 'score_below_threshold_$score';
}

bool _hasDeniedVenueKeyword(String normalizedSearchableText) {
  for (final keyword in kDeniedVenueKeywords) {
    if (normalizedSearchableText.contains(keyword)) {
      return true;
    }
  }
  return false;
}

bool _hasWhitelistedCafeBrand(String normalizedSearchableText) {
  for (final brand in kWhitelistedCafeBrands) {
    if (normalizedSearchableText.contains(normalizeSearchText(brand))) {
      return true;
    }
  }
  return false;
}

bool _matchesHardBlockedPattern(
  Set<String> tokenSet,
  Set<String> bigrams,
  Set<String> trigrams,
  String normalizedSearchableText,
) {
  if (tokenSet.any(_hardBlockedSingleTokens.contains)) {
    return true;
  }

  for (final phrase in _hardBlockedPhrasePatterns) {
    final normalizedPhrase = normalizeSearchText(phrase);
    if (bigrams.contains(normalizedPhrase) ||
        trigrams.contains(normalizedPhrase) ||
        normalizedSearchableText.contains(normalizedPhrase)) {
      return true;
    }
  }

  return false;
}

int _countUniqueSignalHits(List<String> tokens, Set<String> signals) {
  var hits = 0;
  final seen = <String>{};
  for (final token in tokens) {
    if (!signals.contains(token) || !seen.add(token)) {
      continue;
    }
    hits += 1;
  }
  return hits;
}

bool _hasMeaningfulIdentity({
  required String normalizedName,
  required List<String> tokens,
  required bool hasAllowedType,
  required bool hasWhitelistedBrand,
}) {
  if (hasAllowedType || hasWhitelistedBrand) {
    return true;
  }

  if (normalizedName.isEmpty || normalizedName.length < 3) {
    return false;
  }

  final meaningfulTokenCount = tokens
      .where(
          (token) => token.length > 1 && !_identityNoiseTokens.contains(token))
      .length;
  if (meaningfulTokenCount >= 2) {
    return true;
  }

  return meaningfulTokenCount == 1 && normalizedName.length >= 6;
}

List<String> _tokenizeNormalizedText(String normalizedText) {
  if (normalizedText.isEmpty) {
    return const <String>[];
  }

  final cached = _tokenCache[normalizedText];
  if (cached != null) {
    return cached;
  }

  final tokens = normalizedText
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);

  if (_tokenCache.length >= _maxTokenCacheEntries) {
    _tokenCache.clear();
  }
  _tokenCache[normalizedText] = tokens;
  return tokens;
}

Set<String> _buildNgrams(List<String> tokens, int size) {
  if (tokens.length < size || size < 2) {
    return const <String>{};
  }

  final ngrams = <String>{};
  for (var index = 0; index <= tokens.length - size; index++) {
    ngrams.add(tokens.sublist(index, index + size).join(' '));
  }
  return ngrams;
}

bool _hasAdminAllowCafeOverride(Cafe cafe) {
  if (cafe.tags.isEmpty) {
    return false;
  }

  for (final rawTag in cafe.tags) {
    final normalizedTag = normalizeSearchText(rawTag);
    if (_adminCafeAllowOverrideTags.contains(normalizedTag)) {
      return true;
    }
  }
  return false;
}
