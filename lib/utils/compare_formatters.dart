import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../models/index.dart';
import 'cafe_hours.dart';
import 'cafe_utils.dart';

class CompareMetric {
  const CompareMetric({
    required this.key,
    required this.icon,
    required this.label,
    required this.valueBuilder,
    this.scoreBuilder,
  });

  final String key;
  final IconData icon;
  final String label;
  final String Function(Cafe cafe) valueBuilder;
  final num? Function(Cafe cafe)? scoreBuilder;
}

List<CompareMetric> buildCompareMetrics(AppLocalizations l10n) {
  return [
    CompareMetric(
      key: 'category',
      icon: Icons.local_cafe_outlined,
      label: l10n.compareCategory,
      valueBuilder: (cafe) => cafeCategoryLabel(l10n, cafe),
    ),
    CompareMetric(
      key: 'rating',
      icon: Icons.star_rounded,
      label: l10n.compareCommunityRating,
      valueBuilder: (cafe) => cafeRatingLabel(l10n, cafe),
      scoreBuilder: (cafe) => cafe.rating > 0 ? cafe.rating : null,
    ),
    CompareMetric(
      key: 'google_rating',
      icon: Icons.travel_explore_rounded,
      label: l10n.compareGoogleRating,
      valueBuilder: (cafe) => googleRatingLabel(l10n, cafe),
      scoreBuilder: (cafe) => cafe.googleRating,
    ),
    CompareMetric(
      key: 'price',
      icon: Icons.attach_money_rounded,
      label: l10n.metricPrice,
      valueBuilder: (cafe) => cafePriceLabel(l10n, cafe),
      scoreBuilder: (cafe) =>
          cafe.hasPriceLevel ? cafe.priceLevel.sortScore : null,
    ),
    CompareMetric(
      key: 'wifi',
      icon: Icons.wifi,
      label: l10n.compareWifi,
      valueBuilder: (cafe) => cafeWifiDisplayLabel(l10n, cafe),
      scoreBuilder: (cafe) =>
          (cafe.communityWifiQuality ?? cafe.wifiQuality).score,
    ),
    CompareMetric(
      key: 'outlets',
      icon: Icons.power_outlined,
      label: l10n.compareOutlet,
      valueBuilder: (cafe) => cafeOutletDisplayLabel(l10n, cafe),
      scoreBuilder: (cafe) =>
          (cafe.communityOutletAvailability ?? cafe.outletAvailability).score,
    ),
    CompareMetric(
      key: 'quietness',
      icon: Icons.volume_up_outlined,
      label: l10n.compareQuietness,
      valueBuilder: (cafe) => cafeQuietnessDisplayLabel(l10n, cafe),
      scoreBuilder: (cafe) =>
          (cafe.communityQuietnessLevel ?? cafe.quietnessLevel).score,
    ),
    CompareMetric(
      key: 'ambiance',
      icon: Icons.palette_outlined,
      label: l10n.compareAmbiance,
      valueBuilder: (cafe) => cafeAmbianceLabel(l10n, cafe),
      scoreBuilder: (cafe) => cafe.communityAmbianceScore ?? cafe.ambianceScore,
    ),
    CompareMetric(
      key: 'seating',
      icon: Icons.chair_alt_outlined,
      label: l10n.compareSeatingComfort,
      valueBuilder: (cafe) => cafeSeatingComfortLabel(l10n, cafe),
      scoreBuilder: (cafe) =>
          cafe.communitySeatingComfort ?? cafe.seatingComfort,
    ),
    CompareMetric(
      key: 'study',
      icon: Icons.menu_book_outlined,
      label: l10n.compareStudyFriendly,
      valueBuilder: (cafe) => cafeStudyFriendlyDisplayLabel(l10n, cafe),
      scoreBuilder: (cafe) =>
          (cafe.communityStudyFriendly ?? cafe.studyFriendly) ? 1 : 0,
    ),
    CompareMetric(
      key: 'hours',
      icon: Icons.schedule_rounded,
      label: l10n.compareOpeningStatus,
      valueBuilder: (cafe) => cafeOpeningStatusLabel(l10n, cafe),
    ),
    CompareMetric(
      key: 'smoking',
      icon: Icons.smoking_rooms_outlined,
      label: l10n.compareSmoking,
      valueBuilder: (cafe) => cafeSmokingDisplayLabel(l10n, cafe),
      scoreBuilder: (cafe) =>
          (cafe.communitySmokingPolicy ?? cafe.smokingPolicy).score,
    ),
  ];
}

String googleRatingLabel(AppLocalizations l10n, Cafe cafe) {
  final rating = cafe.googleRating;
  if (rating == null || rating <= 0) {
    return l10n.commonNoData;
  }
  final reviewCount = cafe.googleReviewCount;
  if (reviewCount == null || reviewCount <= 0) {
    return rating.toStringAsFixed(1);
  }
  return '${rating.toStringAsFixed(1)} ($reviewCount)';
}

String cafeDistanceLabel(
    AppLocalizations l10n, Cafe cafe, Coordinates? center) {
  if (center == null) {
    return l10n.commonUnknown;
  }
  final km = distanceKm(center, cafe.coordinates);
  if (km < 1) {
    return '${(km * 1000).round()} m';
  }
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

String cafeFeatureSummaryLabel(AppLocalizations l10n, Cafe cafe) {
  final values = <String>[
    cafeWifiDisplayLabel(l10n, cafe),
    cafeOutletDisplayLabel(l10n, cafe),
    cafeQuietnessDisplayLabel(l10n, cafe),
  ].where((value) => value != l10n.commonUnknown).toList(growable: false);
  if (values.isEmpty) {
    return l10n.commonUnknown;
  }
  return values.join(' | ');
}

String cafeHighlightsLabel(AppLocalizations l10n, Cafe cafe) {
  final highlights = cafe.menuHighlights
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .take(3)
      .toList(growable: false);
  if (highlights.isEmpty) {
    return l10n.commonNoData;
  }
  return highlights.join(', ');
}

String cafeOpeningStatusLabel(AppLocalizations l10n, Cafe cafe) {
  final status = resolveCafeOpenStatus(cafe);
  final statusLabel = switch (status) {
    CafeOpenStatus.open => l10n.commonOpen,
    CafeOpenStatus.closed => l10n.commonClosed,
    CafeOpenStatus.unknown => l10n.commonUnknown,
  };
  final hours = cafe.hasWorkingHours
      ? summarizeWorkingHoursLabel(l10n, cafe.openingHours)
      : l10n.cafeDetailHoursEmpty;
  return '$statusLabel | $hours';
}

Map<String, String> resolveMetricWinners(
  List<CompareMetric> metrics,
  List<Cafe> cafes,
) {
  final winners = <String, String>{};

  for (final metric in metrics) {
    final scoreBuilder = metric.scoreBuilder;
    if (scoreBuilder == null || cafes.length < 2) {
      continue;
    }

    final scored = cafes
        .map((cafe) {
          final score = scoreBuilder(cafe);
          if (score == null) {
            return null;
          }
          return _ScoredCafe(id: cafe.id, score: score);
        })
        .whereType<_ScoredCafe>()
        .toList()
      ..sort((left, right) => right.score.compareTo(left.score));

    if (scored.length < 2 || scored.first.score <= scored[1].score) {
      continue;
    }

    winners[metric.key] = scored.first.id;
  }

  return winners;
}

class _ScoredCafe {
  const _ScoredCafe({
    required this.id,
    required this.score,
  });

  final String id;
  final num score;
}
