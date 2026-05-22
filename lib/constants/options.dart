import '../models/index.dart';

final List<String> cafeCategoryOptions = CafeCategory.values
    .map((category) => category.value)
    .toList(growable: false);

final List<String> priceLevels =
    PriceLevel.values.map((level) => level.value).toList(growable: false);

const String unknownPriceLevelOption = '__unknown_price__';

final List<String> editablePriceLevels = [
  unknownPriceLevelOption,
  ...priceLevels,
];

final List<String> wifiQualities =
    WifiQuality.values.map((quality) => quality.value).toList(growable: false);

final List<String> outletAvailabilities = OutletAvailability.values
    .map((availability) => availability.value)
    .toList(growable: false);

final List<String> quietnessLevels =
    QuietnessLevel.values.map((level) => level.value).toList(growable: false);

final List<String> smokingPolicies =
    SmokingPolicy.values.map((policy) => policy.value).toList(growable: false);

const List<PreferenceKey> preferenceOptions = [
  PreferenceKey.wifi,
  PreferenceKey.quiet,
  PreferenceKey.outlet,
  PreferenceKey.study,
  PreferenceKey.aesthetic,
  PreferenceKey.outdoor,
  PreferenceKey.petFriendly,
  PreferenceKey.budget,
];
