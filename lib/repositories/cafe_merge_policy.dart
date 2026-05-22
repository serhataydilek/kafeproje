import '../models/index.dart';

const Coordinates _unknownCafeCoordinates = Coordinates(
  lat: 41.0082,
  lng: 28.9784,
);

/// Centralized source-precedence rules for cafe data.
///
/// Ownership:
/// - Google Places owns canonical place identity and default place metadata
/// - Supabase owns app-managed overrides and custom/community metadata
/// - Live review aggregates can temporarily project over the merged cafe
class CafeMergePolicy {
  const CafeMergePolicy._();

  static String canonicalIdentityFor(Cafe cafe) => cafe.canonicalIdentityKey;

  static List<Cafe> mergeGooglePlacesWithSupabase(
    Iterable<Cafe> googlePlacesCafes,
    Iterable<Cafe> supabaseCafes,
  ) {
    final supabaseList = supabaseCafes.toList(growable: false);

    // Build a set of blocked google_place_ids (admin-deleted cafes).
    // These must never be shown even if they reappear from the Google API.
    final blockedPlaceIds = <String>{};
    for (final cafe in supabaseList) {
      if (cafe.isDeleted) {
        final pid = cafe.placeId;
        if (pid != null && pid.isNotEmpty) {
          blockedPlaceIds.add(pid);
        }
      }
    }

    final mergedByIdentity = <String, Cafe>{};

    for (final cafe in googlePlacesCafes) {
      // Skip cafes that have been admin-deleted.
      final pid = cafe.placeId;
      if (pid != null && blockedPlaceIds.contains(pid)) {
        continue;
      }
      mergedByIdentity[canonicalIdentityFor(cafe)] = cafe;
    }

    for (final supabaseCafe in supabaseList) {
      // Never surface deleted Supabase-only cafes.
      if (supabaseCafe.isDeleted) {
        continue;
      }
      final identity = canonicalIdentityFor(supabaseCafe);
      final googleCafe = mergedByIdentity[identity];
      mergedByIdentity[identity] = mergeCafeSources(
        googlePlaceCafe: googleCafe,
        supabaseCafe: supabaseCafe,
      );
    }

    return mergedByIdentity.values.toList(growable: false);
  }

  static Cafe mergeCafeSources({
    Cafe? googlePlaceCafe,
    Cafe? supabaseCafe,
  }) {
    if (googlePlaceCafe == null && supabaseCafe == null) {
      throw ArgumentError('At least one cafe source is required.');
    }
    if (googlePlaceCafe == null) {
      return supabaseCafe!;
    }
    if (supabaseCafe == null) {
      return googlePlaceCafe;
    }

    final hasCustomPlaceOverrides = supabaseCafe.usesAppManagedFields;

    return googlePlaceCafe.copyWith(
      // Keep the Google-backed id when available so routing stays stable.
      placeId: googlePlaceCafe.placeId ?? supabaseCafe.placeId,
      name: hasCustomPlaceOverrides
          ? _preferNonEmpty(supabaseCafe.name, googlePlaceCafe.name)
          : googlePlaceCafe.name,
      category: hasCustomPlaceOverrides
          ? supabaseCafe.category
          : googlePlaceCafe.category,
      district: hasCustomPlaceOverrides
          ? _preferDistrict(supabaseCafe.district, googlePlaceCafe.district)
          : googlePlaceCafe.district,
      neighborhood: hasCustomPlaceOverrides
          ? _preferNonEmpty(
              supabaseCafe.neighborhood,
              googlePlaceCafe.neighborhood,
            )
          : googlePlaceCafe.neighborhood,
      address: hasCustomPlaceOverrides
          ? _preferNonEmpty(supabaseCafe.address, googlePlaceCafe.address)
          : _preferNonEmpty(googlePlaceCafe.address, supabaseCafe.address),
      rating: supabaseCafe.appRating ?? 0,
      reviewCount: supabaseCafe.appReviewCount ?? 0,
      priceLevel: hasCustomPlaceOverrides && supabaseCafe.hasPriceLevel
          ? supabaseCafe.priceLevel
          : (googlePlaceCafe.hasPriceLevel
              ? googlePlaceCafe.priceLevel
              : supabaseCafe.priceLevel),
      hasPriceLevel:
          googlePlaceCafe.hasPriceLevel || supabaseCafe.hasPriceLevel,
      tags: _mergeDistinctStrings(
        supabaseCafe.tags,
        googlePlaceCafe.tags,
      ),
      images: hasCustomPlaceOverrides && supabaseCafe.images.isNotEmpty
          ? supabaseCafe.images
          : _preferList(supabaseCafe.images, googlePlaceCafe.images),
      description: _preferNonEmpty(
        supabaseCafe.description,
        googlePlaceCafe.description,
      ),
      openingHours: hasCustomPlaceOverrides && supabaseCafe.hasWorkingHours
          ? supabaseCafe.openingHours
          : _preferList(
              googlePlaceCafe.openingHours,
              supabaseCafe.openingHours,
            ),
      wifiQuality: supabaseCafe.wifiQuality,
      outletAvailability: supabaseCafe.outletAvailability,
      quietnessLevel: supabaseCafe.quietnessLevel,
      ambianceScore: supabaseCafe.ambianceScore > 0
          ? supabaseCafe.ambianceScore
          : googlePlaceCafe.ambianceScore,
      studyFriendly: supabaseCafe.studyFriendly,
      petFriendly: supabaseCafe.petFriendly,
      outdoorSeating: supabaseCafe.outdoorSeating,
      menuHighlights: _preferList(
        supabaseCafe.menuHighlights,
        googlePlaceCafe.menuHighlights,
      ),
      seatingComfort: supabaseCafe.seatingComfort > 0
          ? supabaseCafe.seatingComfort
          : googlePlaceCafe.seatingComfort,
      openNow: googlePlaceCafe.openNow ||
          (!googlePlaceCafe.hasWorkingHours && supabaseCafe.openNow),
      smokingPolicy: supabaseCafe.smokingPolicy,
      coordinates: hasCustomPlaceOverrides &&
              _hasUsableCoordinates(supabaseCafe.coordinates)
          ? supabaseCafe.coordinates
          : (_hasUsableCoordinates(googlePlaceCafe.coordinates)
              ? googlePlaceCafe.coordinates
              : supabaseCafe.coordinates),
      phoneNumber: hasCustomPlaceOverrides
          ? (supabaseCafe.phoneNumber ?? googlePlaceCafe.phoneNumber)
          : (googlePlaceCafe.phoneNumber ?? supabaseCafe.phoneNumber),
      websiteUri: hasCustomPlaceOverrides
          ? (supabaseCafe.websiteUri ?? googlePlaceCafe.websiteUri)
          : (googlePlaceCafe.websiteUri ?? supabaseCafe.websiteUri),
      ownerApprovalStatus: supabaseCafe.ownerApprovalStatus,
      isFeatured: supabaseCafe.isFeatured,
      featuredPriority: supabaseCafe.featuredPriority,
      featuredUntil: () => supabaseCafe.featuredUntil,
      featuredLabel: () => supabaseCafe.featuredLabel,
      googlePlaceData: () => _mergeGooglePlaceData(
        googlePlaceCafe.googlePlaceData,
        supabaseCafe.googlePlaceData,
      ),
    );
  }

  static Cafe applyReviewOverlay(
    Cafe cafe,
    Iterable<CafeReview> reviews,
  ) {
    final visibleReviews = reviews.toList(growable: false);
    if (visibleReviews.isEmpty) {
      return cafe;
    }

    double averageInt(Iterable<int?> values) {
      final filtered = values.whereType<int>().toList(growable: false);
      if (filtered.isEmpty) {
        return 0;
      }
      return filtered.reduce((left, right) => left + right) / filtered.length;
    }

    WifiQuality? resolveWifi() {
      final value =
          averageInt(visibleReviews.map((review) => review.wifiQuality));
      if (value <= 0) {
        return null;
      }
      if (value >= 4.25) {
        return WifiQuality.strong;
      }
      if (value >= 2.5) {
        return WifiQuality.average;
      }
      return WifiQuality.weak;
    }

    OutletAvailability? resolveOutlets() {
      final labels = visibleReviews
          .map((review) => review.socketAvailability?.trim().toLowerCase())
          .whereType<String>()
          .toList(growable: false);
      if (labels.isEmpty) {
        return null;
      }
      final highCount = labels.where((value) => value == 'high').length;
      final mediumCount = labels.where((value) => value == 'medium').length;
      if (highCount >= mediumCount && highCount > 0) {
        return OutletAvailability.high;
      }
      if (mediumCount > 0) {
        return OutletAvailability.medium;
      }
      return OutletAvailability.low;
    }

    QuietnessLevel? resolveQuietness() {
      final value =
          averageInt(visibleReviews.map((review) => review.noiseLevel));
      if (value <= 0) {
        return null;
      }
      if (value >= 4.25) {
        return QuietnessLevel.quiet;
      }
      if (value >= 2.5) {
        return QuietnessLevel.balanced;
      }
      return QuietnessLevel.busy;
    }

    double? resolveSeatingComfort() {
      final value =
          averageInt(visibleReviews.map((review) => review.seatingComfort));
      return value <= 0 ? null : value;
    }

    bool? resolveStudyFriendly() {
      final value = averageInt(
        visibleReviews.map((review) => review.studyFriendliness),
      );
      return value <= 0 ? null : value >= 3;
    }

    SmokingPolicy? resolveSmokingPolicy() {
      final labels = visibleReviews
          .map((review) => review.smokingPolicy?.trim().toLowerCase())
          .whereType<String>()
          .toList(growable: false);
      if (labels.isEmpty) {
        return null;
      }
      final notAllowedCount =
          labels.where((value) => value == 'not_allowed').length;
      final outdoorOnlyCount =
          labels.where((value) => value == 'outdoor_only').length;
      if (notAllowedCount >= outdoorOnlyCount && notAllowedCount > 0) {
        return SmokingPolicy.notAllowed;
      }
      if (outdoorOnlyCount > 0) {
        return SmokingPolicy.outdoorOnly;
      }
      return SmokingPolicy.allowed;
    }

    final averageRating =
        visibleReviews.fold<int>(0, (sum, review) => sum + review.rating) /
            visibleReviews.length;
    final wifi = resolveWifi();
    final outlets = resolveOutlets();
    final quietness = resolveQuietness();
    final seatingComfort = resolveSeatingComfort();
    final studyFriendly = resolveStudyFriendly();
    final smokingPolicy = resolveSmokingPolicy();
    final ambianceScore = [
      if (wifi != null) wifi.score.toDouble(),
      if (quietness != null) quietness.score.toDouble(),
      if (seatingComfort != null) seatingComfort,
      if (studyFriendly != null) studyFriendly ? 5.0 : 2.0,
    ];

    final googleMetadata =
        (cafe.googlePlaceData ?? GooglePlaceData(googlePlaceId: cafe.placeId))
            .copyWith(usesAppDefaults: false);

    return cafe.copyWith(
      rating: averageRating,
      reviewCount: visibleReviews.length,
      wifiQuality: wifi ?? cafe.wifiQuality,
      outletAvailability: outlets ?? cafe.outletAvailability,
      quietnessLevel: quietness ?? cafe.quietnessLevel,
      seatingComfort: seatingComfort ?? cafe.seatingComfort,
      studyFriendly: studyFriendly ?? cafe.studyFriendly,
      smokingPolicy: smokingPolicy ?? cafe.smokingPolicy,
      ambianceScore: ambianceScore.isEmpty
          ? cafe.ambianceScore
          : ambianceScore.reduce((left, right) => left + right) /
              ambianceScore.length,
      googlePlaceData: () => googleMetadata,
    );
  }

  static GooglePlaceData? _mergeGooglePlaceData(
    GooglePlaceData? googlePlaceData,
    GooglePlaceData? supabaseGoogleData,
  ) {
    if (googlePlaceData == null) {
      return supabaseGoogleData;
    }
    if (supabaseGoogleData == null) {
      return googlePlaceData;
    }

    return googlePlaceData.copyWith(
      googlePlaceId:
          supabaseGoogleData.googlePlaceId ?? googlePlaceData.googlePlaceId,
      googleRating:
          googlePlaceData.googleRating ?? supabaseGoogleData.googleRating,
      googleReviewCount: googlePlaceData.googleReviewCount ??
          supabaseGoogleData.googleReviewCount,
      googleOpenNow:
          googlePlaceData.googleOpenNow ?? supabaseGoogleData.googleOpenNow,
      formattedAddress: _preferNullableNonEmpty(
        googlePlaceData.formattedAddress,
        supabaseGoogleData.formattedAddress,
      ),
      lastSyncedAt:
          googlePlaceData.lastSyncedAt ?? supabaseGoogleData.lastSyncedAt,
      hasPriceLevel:
          googlePlaceData.hasPriceLevel || supabaseGoogleData.hasPriceLevel,
      usesAppDefaults: supabaseGoogleData.usesAppDefaults,
      sourceTypes: _mergeDistinctStrings(
        googlePlaceData.sourceTypes,
        supabaseGoogleData.sourceTypes,
      ),
    );
  }

  static bool _hasUsableCoordinates(Coordinates coordinates) {
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

  static String _preferDistrict(String primary, String fallback) {
    if (primary.trim().isNotEmpty && primary != District.unknown.value) {
      return primary;
    }
    return fallback;
  }

  static String _preferNonEmpty(String primary, String fallback) {
    return primary.trim().isNotEmpty ? primary : fallback;
  }

  static String? _preferNullableNonEmpty(String? primary, String? fallback) {
    if (primary != null && primary.trim().isNotEmpty) {
      return primary;
    }
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback;
    }
    return primary ?? fallback;
  }

  static List<T> _preferList<T>(List<T> primary, List<T> fallback) {
    return primary.isNotEmpty ? primary : fallback;
  }

  static List<String> _mergeDistinctStrings(
    List<String> primary,
    List<String> secondary,
  ) {
    final merged = <String>[];
    final seen = <String>{};
    for (final value in [...primary, ...secondary]) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      merged.add(trimmed);
    }
    return List<String>.unmodifiable(merged);
  }
}
