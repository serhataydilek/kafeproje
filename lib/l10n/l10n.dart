import 'package:flutter/widgets.dart';

import '../constants/options.dart';
import 'app_localizations.dart';
import '../models/index.dart';
import '../utils/district_utils.dart';
import '../utils/cafe_hours.dart';
import '../utils/cafe_formatters.dart';
import '../utils/text_normalization.dart';

extension AppL10nBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

typedef LocalizedSortOption = ({SortOption key, String label});

String _districtValue(Object district) {
  return switch (district) {
    final District value => value.displayName,
    final String value => canonicalDistrictName(value) ?? value,
    _ => district.toString(),
  };
}

String _wifiValue(Object value) {
  return switch (value) {
    final WifiQuality wifi => wifi.value,
    final String text => WifiQualityExtension.fromString(text).value,
    _ => value.toString(),
  };
}

String _outletValue(Object value) {
  return switch (value) {
    final OutletAvailability outlet => outlet.value,
    final String text => OutletAvailabilityExtension.fromString(text).value,
    _ => value.toString(),
  };
}

String _quietnessValue(Object value) {
  return switch (value) {
    final QuietnessLevel quietness => quietness.value,
    final String text => QuietnessLevelExtension.fromString(text).value,
    _ => value.toString(),
  };
}

String _smokingPolicyValue(Object value) {
  return switch (value) {
    final SmokingPolicy policy => policy.value,
    final String text => SmokingPolicyExtension.fromString(text).value,
    _ => value.toString(),
  };
}

String districtLabel(AppLocalizations l10n, Object district) {
  final value = _districtValue(district);
  if (value.isEmpty || value == District.unknown.displayName) {
    return l10n.commonUnknown;
  }
  return value;
}

String unknownLabel(AppLocalizations l10n, String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return l10n.commonUnknown;
  }
  return trimmed;
}

String cafeDistrictLabel(AppLocalizations l10n, Cafe cafe) {
  return districtLabel(l10n, cafe.district);
}

String cafeNeighborhoodLabel(AppLocalizations l10n, Cafe cafe) {
  return unknownLabel(l10n, cafe.neighborhood);
}

String cafeLocationSummary(AppLocalizations l10n, Cafe cafe) {
  final district = cafeDistrictLabel(l10n, cafe);
  final neighborhood = cafe.neighborhood.trim();
  final address = cafe.address.trim();
  if (district == l10n.commonUnknown && neighborhood.isNotEmpty) {
    return neighborhood;
  }
  if (neighborhood.isNotEmpty &&
      _normalizedAddressText(address) == _normalizedAddressText(neighborhood)) {
    return district;
  }
  if (neighborhood.isEmpty) {
    return district;
  }
  return '$district - $neighborhood';
}

String cafeAddressLabel(AppLocalizations l10n, Cafe cafe) {
  final address = _cleanAddress(cafe.address);
  final location = cafeLocationSummary(l10n, cafe);
  if (address == null) {
    return l10n.commonUnknown;
  }
  if (_normalizedAddressText(address) == _normalizedAddressText(location)) {
    return l10n.commonUnknown;
  }
  return address;
}

String cafeRatingLabel(AppLocalizations l10n, Cafe cafe) {
  final appRating = cafe.appRating;
  if (appRating == null) {
    return l10n.cafeNoRatingsYet;
  }
  return appRating.toStringAsFixed(1);
}

bool cafeUsesPlaceholderAppFields(Cafe cafe) {
  return !cafe.hasCommunityExperienceData;
}

String cafePriceLabel(AppLocalizations l10n, Cafe cafe) {
  final label = formatPriceRange(cafe, noDataLabel: l10n.commonUnknown);
  return label;
}

String editablePriceLevelSelection(Cafe cafe) {
  return cafe.hasPriceLevel ? cafe.priceLevel.value : unknownPriceLevelOption;
}

String persistablePriceLevelValue(String selectedValue) {
  return selectedValue == unknownPriceLevelOption ? '' : selectedValue;
}

String priceLevelOptionLabel(AppLocalizations l10n, String value) {
  if (value == unknownPriceLevelOption) {
    return l10n.commonUnknown;
  }
  return value;
}

String cafeWifiDisplayLabel(AppLocalizations l10n, Cafe cafe) {
  final value = cafe.communityWifiQuality ?? cafe.wifiQuality;
  if (!cafe.hasCommunityExperienceData &&
      cafe.googlePlaceData?.usesAppDefaults == true) {
    return l10n.commonUnknown;
  }
  return wifiLabel(l10n, value);
}

String cafeOutletDisplayLabel(AppLocalizations l10n, Cafe cafe) {
  final value = cafe.communityOutletAvailability ?? cafe.outletAvailability;
  if (!cafe.hasCommunityExperienceData &&
      cafe.googlePlaceData?.usesAppDefaults == true) {
    return l10n.commonUnknown;
  }
  return outletLabel(l10n, value);
}

String cafeQuietnessDisplayLabel(AppLocalizations l10n, Cafe cafe) {
  final value = cafe.communityQuietnessLevel ?? cafe.quietnessLevel;
  if (!cafe.hasCommunityExperienceData &&
      cafe.googlePlaceData?.usesAppDefaults == true) {
    return l10n.commonUnknown;
  }
  return quietnessLabel(l10n, value);
}

String cafeSmokingDisplayLabel(AppLocalizations l10n, Cafe cafe) {
  final value = cafe.communitySmokingPolicy ?? cafe.smokingPolicy;
  if (!cafe.hasCommunityExperienceData &&
      cafe.googlePlaceData?.usesAppDefaults == true) {
    return l10n.commonUnknown;
  }
  return smokingPolicyLabel(l10n, value);
}

String cafeStudyFriendlyDisplayLabel(AppLocalizations l10n, Cafe cafe) {
  final value = cafe.communityStudyFriendly ?? cafe.studyFriendly;
  if (!cafe.hasCommunityExperienceData &&
      cafe.googlePlaceData?.usesAppDefaults == true) {
    return l10n.commonUnknown;
  }
  return value ? l10n.compareYes : l10n.compareNo;
}

String cafeAmbianceLabel(AppLocalizations l10n, Cafe cafe) {
  final value = cafe.communityAmbianceScore ??
      (cafe.ambianceScore > 0 ? cafe.ambianceScore : null);
  if (value == null) {
    return l10n.commonUnknown;
  }
  return value.toStringAsFixed(1);
}

String cafeSeatingComfortLabel(AppLocalizations l10n, Cafe cafe) {
  final value = cafe.communitySeatingComfort ??
      (cafe.seatingComfort > 0 ? cafe.seatingComfort : null);
  if (value == null) {
    return l10n.commonUnknown;
  }
  return value.toStringAsFixed(1);
}

String cafeCategoryValueLabel(AppLocalizations l10n, Object value) {
  final category = switch (value) {
    final CafeCategory category => category,
    final String text => CafeCategoryExtension.fromString(text),
    _ => CafeCategory.normalCafe,
  };

  return switch (category) {
    CafeCategory.normalCafe => l10n.cafeCategoryNormal,
    CafeCategory.cafeLounge => l10n.cafeCategoryLounge,
  };
}

String cafeCategoryLabel(AppLocalizations l10n, Cafe cafe) {
  return cafeCategoryValueLabel(l10n, cafe.category);
}

String formatWorkingHoursRangeLabel(
  AppLocalizations l10n,
  OpeningHour hour,
) {
  if (!hour.hasSchedule) {
    return l10n.commonNoData;
  }
  return '${hour.open} - ${hour.close}';
}

String summarizeWorkingHoursLabel(
  AppLocalizations l10n,
  List<OpeningHour> hours,
) {
  final today = canonicalWeekdays[(DateTime.now().weekday + 6) % 7];
  for (final entry in hours) {
    if (entry.day == today) {
      return entry.hasSchedule
          ? formatWorkingHoursRangeLabel(l10n, entry)
          : l10n.commonNoData;
    }
  }
  return l10n.commonNoData;
}

List<String> compactWorkingHoursLabel(
  AppLocalizations l10n,
  List<OpeningHour> hours,
) {
  if (hours.isEmpty) {
    return <String>[l10n.commonNoData];
  }

  final normalizedHours = normalizeWeeklyHours(hours);
  final rows = <String>[];
  var rangeStart = 0;

  while (rangeStart < normalizedHours.length) {
    final current = normalizedHours[rangeStart];
    final currentLabel = formatWorkingHoursRangeLabel(l10n, current);
    var rangeEnd = rangeStart;

    while (rangeEnd + 1 < normalizedHours.length &&
        formatWorkingHoursRangeLabel(l10n, normalizedHours[rangeEnd + 1]) ==
            currentLabel) {
      rangeEnd++;
    }

    final startDay = dayLabel(l10n, normalizedHours[rangeStart].day);
    final endDay = dayLabel(l10n, normalizedHours[rangeEnd].day);
    final dayRangeLabel =
        rangeStart == rangeEnd ? startDay : '$startDay-$endDay';
    rows.add('$dayRangeLabel  $currentLabel');
    rangeStart = rangeEnd + 1;
  }

  return rows;
}

String wifiLabel(AppLocalizations l10n, Object value) {
  return switch (_wifiValue(value)) {
    'Weak' => l10n.wifiWeak,
    'Average' => l10n.wifiAverage,
    'Strong' => l10n.wifiStrong,
    final label => label,
  };
}

String outletLabel(AppLocalizations l10n, Object value) {
  return switch (_outletValue(value)) {
    'Low' => l10n.outletLow,
    'Medium' => l10n.outletMedium,
    'High' => l10n.outletHigh,
    final label => label,
  };
}

String quietnessLabel(AppLocalizations l10n, Object value) {
  return switch (_quietnessValue(value)) {
    'Busy' => l10n.quietnessBusy,
    'Balanced' => l10n.quietnessBalanced,
    'Quiet' => l10n.quietnessQuiet,
    final label => label,
  };
}

String smokingPolicyLabel(AppLocalizations l10n, Object value) {
  return switch (_smokingPolicyValue(value)) {
    'allowed' => l10n.smokingAllowed,
    'outdoor_only' => l10n.smokingOutdoorOnly,
    'not_allowed' => l10n.smokingNotAllowed,
    final label => label,
  };
}

String dayLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Monday' || 'Mon' => l10n.dayMonday,
    'Tuesday' || 'Tue' => l10n.dayTuesday,
    'Wednesday' || 'Wed' => l10n.dayWednesday,
    'Thursday' || 'Thu' => l10n.dayThursday,
    'Friday' || 'Fri' => l10n.dayFriday,
    'Saturday' || 'Sat' => l10n.daySaturday,
    'Sunday' || 'Sun' => l10n.daySunday,
    _ => value,
  };
}

String preferenceLabel(AppLocalizations l10n, PreferenceKey key) {
  return switch (key) {
    PreferenceKey.wifi => l10n.preferenceWifi,
    PreferenceKey.quiet => l10n.preferenceQuiet,
    PreferenceKey.outlet => l10n.preferenceOutlet,
    PreferenceKey.study => l10n.preferenceStudy,
    PreferenceKey.aesthetic => l10n.preferenceAesthetic,
    PreferenceKey.outdoor => l10n.preferenceOutdoor,
    PreferenceKey.petFriendly => l10n.preferencePetFriendly,
    PreferenceKey.budget => l10n.preferenceBudget,
  };
}

List<String> categoryChipLabels(AppLocalizations l10n) {
  return [
    l10n.categoryStudy,
    l10n.categoryBestCoffee,
    l10n.categoryAffordable,
    l10n.categoryAesthetic,
    l10n.categoryQuiet,
    l10n.categoryOutdoor,
  ];
}

List<LocalizedSortOption> sortOptions(AppLocalizations l10n) {
  return [
    (key: SortOption.topRated, label: l10n.sortTopRated),
    (key: SortOption.nearest, label: l10n.sortNearest),
    (key: SortOption.cheapest, label: l10n.sortCheapest),
    (key: SortOption.study, label: l10n.sortStudy),
    (key: SortOption.aesthetic, label: l10n.sortAesthetic),
  ];
}

String? _cleanAddress(String value) {
  final parts = value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return null;
  }

  final deduped = <String>[];
  final seen = <String>{};
  for (final part in parts) {
    final normalized = _normalizedAddressText(part);
    if (normalized.isEmpty || !seen.add(normalized)) {
      continue;
    }
    deduped.add(part);
  }
  return deduped.isEmpty ? null : deduped.join(', ');
}

String _normalizedAddressText(String value) {
  return normalizeSearchText(value);
}
