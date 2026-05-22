import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/cafe_category.dart';
import '../utils/cafe_hours.dart';
import '../utils/cafe_media.dart';
import '../utils/cafe_visibility.dart';
import '../utils/input_validation.dart';
import '../utils/app_logger.dart';
import 'district.dart';
import 'cafe_support.dart';

class Coordinates {
  const Coordinates({required this.lat, required this.lng});

  factory Coordinates.fromJson(Map<String, dynamic> json) {
    return Coordinates(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coordinates && lat == other.lat && lng == other.lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

class OpeningHour {
  const OpeningHour({
    required this.day,
    this.open,
    this.close,
    this.closed = false,
  });

  factory OpeningHour.fromJson(Map<String, dynamic> json) {
    final day = (json['day'] as String? ?? '').trim();
    final open = (json['open'] as String?)?.trim();
    final close = (json['close'] as String?)?.trim();
    final closed = json['closed'] as bool? ??
        ((open == null || open.isEmpty) && (close == null || close.isEmpty));
    return OpeningHour(
      day: canonicalWeekday(day),
      open: open?.isEmpty == true ? null : open,
      close: close?.isEmpty == true ? null : close,
      closed: closed,
    );
  }

  final String day;
  final String? open;
  final String? close;
  final bool closed;

  bool get hasSchedule =>
      !closed &&
      open != null &&
      open!.isNotEmpty &&
      close != null &&
      close!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'day': day,
        'open': open,
        'close': close,
        'closed': closed,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpeningHour &&
          day == other.day &&
          open == other.open &&
          close == other.close &&
          closed == other.closed;

  @override
  int get hashCode => Object.hash(day, open, close, closed);
}

class GooglePlaceData {
  const GooglePlaceData({
    this.googlePlaceId,
    this.googleRating,
    this.googleReviewCount,
    this.googleOpenNow,
    this.formattedAddress,
    this.lastSyncedAt,
    this.hasPriceLevel = false,
    this.usesAppDefaults = false,
    this.sourceTypes = const <String>[],
  });

  final String? googlePlaceId;
  final double? googleRating;
  final int? googleReviewCount;
  final bool? googleOpenNow;
  final String? formattedAddress;
  final String? lastSyncedAt;
  final bool hasPriceLevel;
  final bool usesAppDefaults;
  final List<String> sourceTypes;

  GooglePlaceData copyWith({
    String? googlePlaceId,
    double? googleRating,
    int? googleReviewCount,
    bool? googleOpenNow,
    String? formattedAddress,
    String? lastSyncedAt,
    bool? hasPriceLevel,
    bool? usesAppDefaults,
    List<String>? sourceTypes,
  }) {
    return GooglePlaceData(
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      googleRating: googleRating ?? this.googleRating,
      googleReviewCount: googleReviewCount ?? this.googleReviewCount,
      googleOpenNow: googleOpenNow ?? this.googleOpenNow,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      hasPriceLevel: hasPriceLevel ?? this.hasPriceLevel,
      usesAppDefaults: usesAppDefaults ?? this.usesAppDefaults,
      sourceTypes: sourceTypes ?? this.sourceTypes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GooglePlaceData &&
          googlePlaceId == other.googlePlaceId &&
          googleRating == other.googleRating &&
          googleReviewCount == other.googleReviewCount &&
          googleOpenNow == other.googleOpenNow &&
          formattedAddress == other.formattedAddress &&
          lastSyncedAt == other.lastSyncedAt &&
          hasPriceLevel == other.hasPriceLevel &&
          usesAppDefaults == other.usesAppDefaults;

  @override
  int get hashCode => Object.hash(
        googlePlaceId,
        googleRating,
        googleReviewCount,
        googleOpenNow,
        formattedAddress,
        lastSyncedAt,
        hasPriceLevel,
        usesAppDefaults,
      );
}

class Cafe {
  Cafe({
    required this.id,
    this.placeId,
    required this.name,
    required this.category,
    required this.district,
    required this.neighborhood,
    this.address = '',
    required this.rating,
    required this.reviewCount,
    required Object priceLevel,
    this.hasPriceLevel = false,
    required this.tags,
    required List<String> images,
    required this.description,
    required this.openingHours,
    required Object wifiQuality,
    required Object outletAvailability,
    required Object quietnessLevel,
    required this.ambianceScore,
    required this.studyFriendly,
    required this.petFriendly,
    required this.outdoorSeating,
    required this.menuHighlights,
    required this.seatingComfort,
    this.openNow = false,
    required Object smokingPolicy,
    required this.coordinates,
    this.phoneNumber,
    this.websiteUri,
    this.ownerApprovalStatus = 'approved',
    this.ownerUserId,
    this.isDeleted = false,
    this.favoriteCount = 0,
    this.manualRating,
    this.manualRatingCount,
    this.isFeatured = false,
    this.featuredPriority = 0,
    this.featuredUntil,
    this.featuredLabel,
    this.googlePlaceData,
  })  : images = List<String>.unmodifiable(
          normalizeCafeImageUrls(images),
        ),
        priceLevel = priceLevel is PriceLevel
            ? priceLevel
            : PriceLevelExtension.fromString(priceLevel.toString()),
        wifiQuality = wifiQuality is WifiQuality
            ? wifiQuality
            : WifiQualityExtension.fromString(wifiQuality.toString()),
        outletAvailability = outletAvailability is OutletAvailability
            ? outletAvailability
            : OutletAvailabilityExtension.fromString(
                outletAvailability.toString(),
              ),
        quietnessLevel = quietnessLevel is QuietnessLevel
            ? quietnessLevel
            : QuietnessLevelExtension.fromString(quietnessLevel.toString()),
        smokingPolicy = smokingPolicy is SmokingPolicy
            ? smokingPolicy
            : SmokingPolicyExtension.fromString(smokingPolicy.toString());

  factory Cafe.empty({String id = 'placeholder'}) {
    return Cafe(
      id: id,
      name: 'Unknown Cafe',
      category: CafeCategory.normalCafe,
      district: District.unknown.value,
      neighborhood: '',
      address: 'Istanbul',
      rating: 0,
      reviewCount: 0,
      priceLevel: PriceLevel.moderate,
      hasPriceLevel: false,
      tags: const <String>[],
      images: const <String>[],
      description: '',
      openingHours: const <OpeningHour>[],
      wifiQuality: WifiQuality.average,
      outletAvailability: OutletAvailability.medium,
      quietnessLevel: QuietnessLevel.balanced,
      ambianceScore: 0,
      studyFriendly: false,
      petFriendly: false,
      outdoorSeating: false,
      menuHighlights: const <String>[],
      seatingComfort: 0,
      smokingPolicy: SmokingPolicy.notAllowed,
      coordinates: const Coordinates(lat: 41.0082, lng: 28.9784),
      isDeleted: false,
      favoriteCount: 0,
    );
  }

  factory Cafe.fromSupabaseRow(Map<String, dynamic> row) {
    final id = (row['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw const FormatException('Cafe id is required.');
    }

    final name = (row['name'] as String?)?.trim();
    final safeName = name == null || name.isEmpty ? 'Unknown Cafe' : name;
    final openingHours = _parseOpeningHoursSafe(row['opening_hours']);
    final coordinates = _coordinatesFromLooseJson(
          _toStringKeyedMap(row['coordinates']) ?? const <String, dynamic>{},
        ) ??
        _coordinatesFromLooseJson(
          <String, dynamic>{
            'lat': row['lat'],
            'lng': row['lng'],
            'latitude': row['latitude'],
            'longitude': row['longitude'],
          },
        ) ??
        const Coordinates(lat: 41.0082, lng: 28.9784);
    final district = normalizedDistrictOrUnknown(
      _firstStringValue(row, const ['district', 'town']),
    );
    final neighborhood = _firstStringValue(
          row,
          const ['neighborhood', 'degree', 'neighbourhood', 'quarter'],
        ) ??
        '';
    final rawPriceLevel = _firstStringValue(
      row,
      const ['price_level', 'priceRange'],
    );
    final hasPriceLevel = (rawPriceLevel?.trim().isNotEmpty ?? false) ||
        (row['google_has_price_level'] as bool? ?? false);
    final tags = _stringListOrEmpty(row['tags']);
    final menuHighlights = _stringListOrEmpty(row['menu_highlights']);
    final rating = _clampDouble(
      (row['rating'] as num?)?.toDouble() ?? 0.0,
      min: 0,
      max: 5,
    );
    final reviewCount =
        ((row['review_count'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30);
    final manualRatingRaw = (row['manual_rating'] as num?)?.toDouble();
    final manualRating = manualRatingRaw == null
        ? null
        : _clampDouble(
            manualRatingRaw,
            min: 0,
            max: 5,
          );
    final manualRatingCount =
        ((row['manual_rating_count'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30);
    final isDeleted = isSuppressedCafeRow(row);
    final favoriteCount = (row['favorite_count'] as num?)?.toInt() ?? 0;
    final images = _extractPhotoUrls(row);
    final featuredPriority =
        ((row['featured_priority'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30);
    final featuredUntil = _parseOptionalDateTime(row['featured_until']);
    final featuredLabel = _normalizeOptionalString(row['featured_label']);

    GooglePlaceData? googleData;
    if (row['google_place_id'] != null ||
        row['google_rating'] != null ||
        row['google_review_count'] != null ||
        row['google_open_now'] != null ||
        row['formatted_address'] != null ||
        row['google_has_price_level'] != null ||
        row['google_uses_app_defaults'] != null) {
      googleData = GooglePlaceData(
        googlePlaceId: row['google_place_id'] as String?,
        googleRating: (row['google_rating'] as num?)?.toDouble(),
        googleReviewCount: row['google_review_count'] as int?,
        googleOpenNow: _asNullableBool(row['google_open_now']) ??
            _asNullableBool(row['open_now']),
        formattedAddress: row['formatted_address'] as String?,
        lastSyncedAt: row['external_last_synced_at'] as String?,
        hasPriceLevel: row['google_has_price_level'] as bool? ?? false,
        usesAppDefaults: row['google_uses_app_defaults'] as bool? ?? false,
      );
    }

    _logModelPhotoNormalization(
      source: 'supabase',
      cafeId: id,
      cafeName: safeName,
      rawImageInput: <String, Object?>{
        'images': row['images'],
        'photo_urls': row['photo_urls'],
        'photoUrl': row['photoUrl'],
        'image_url': row['image_url'],
        'image_urls': row['image_urls'],
        'photos': row['photos'],
        'media': row['media'],
        'google_photo_reference': row['google_photo_reference'],
        'google_photo_references': row['google_photo_references'],
      },
      normalizedPhotoUrls: images,
    );

    return Cafe(
      id: id,
      placeId: row['google_place_id'] as String?,
      name: safeName,
      category: inferCafeCategory(
        rawCategory: _firstStringValue(
          row,
          const ['category', 'cafe_category', 'venue_type', 'type'],
        ),
        name: safeName,
        tags: tags,
      ),
      district: district,
      neighborhood: neighborhood,
      address: _firstStringValue(
            row,
            const ['address', 'formatted_address'],
          ) ??
          _buildFallbackAddress(neighborhood, district),
      rating: rating,
      reviewCount: reviewCount,
      priceLevel: PriceLevelExtension.fromString(rawPriceLevel ?? ''),
      hasPriceLevel: hasPriceLevel,
      tags: tags,
      images: images,
      description: row['description'] as String? ?? '',
      openingHours: openingHours,
      wifiQuality: WifiQualityExtension.fromString(
        row['wifi_quality'] as String? ?? '',
      ),
      outletAvailability: OutletAvailabilityExtension.fromString(
        row['outlet_availability'] as String? ?? '',
      ),
      quietnessLevel: QuietnessLevelExtension.fromString(
        row['quietness_level'] as String? ?? '',
      ),
      ambianceScore: (row['ambiance_score'] as num?)?.toDouble() ?? 0.0,
      studyFriendly: row['study_friendly'] as bool? ?? false,
      petFriendly: row['pet_friendly'] as bool? ?? false,
      outdoorSeating: row['outdoor_seating'] as bool? ?? false,
      menuHighlights: menuHighlights,
      seatingComfort: _clampDouble(
        (row['seating_comfort'] as num?)?.toDouble() ?? 0.0,
        min: 0,
        max: 5,
      ),
      openNow: _asNullableBool(row['open_now']) ??
          resolveCafeOpenState(openingHours),
      smokingPolicy: SmokingPolicyExtension.fromString(
        row['smoking_policy'] as String? ??
            ((row['smoking_allowed'] == true) ? 'allowed' : 'not_allowed'),
      ),
      coordinates: coordinates,
      phoneNumber: row['phone_number'] as String?,
      websiteUri: row['website_uri'] as String?,
      ownerApprovalStatus:
          row['owner_approval_status'] as String? ?? 'approved',
      ownerUserId: row['owner_user_id'] as String?,
      isDeleted: isDeleted,
      favoriteCount: favoriteCount,
      manualRating: manualRating,
      manualRatingCount: manualRatingCount,
      isFeatured: _asNullableBool(row['is_featured']) ?? false,
      featuredPriority: featuredPriority,
      featuredUntil: featuredUntil,
      featuredLabel: featuredLabel,
      googlePlaceData: googleData,
    );
  }

  factory Cafe.fromGooglePlace(
    Map<String, dynamic> place, {
    int maxImageCount = 5,
  }) {
    final id = place['id'] as String;
    final address = (place['shortFormattedAddress'] as String? ?? '').trim();
    final sourceTypes = (place['types'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final hoursPayload =
        place['currentOpeningHours'] ?? place['regularOpeningHours'];
    final openingHours = parseGoogleOpeningHours(hoursPayload);
    final explicitOpenNow = parseGoogleOpenNow(hoursPayload) ??
        parseGoogleOpenNow(place['openingHours']) ??
        _asNullableBool(place['open_now']);
    final images = _extractGooglePhotoUrls(
      place['photos'],
      maxImageCount: maxImageCount,
    );
    _logModelPhotoNormalization(
      source: 'google',
      cafeId: id,
      cafeName: place['displayName']?['text'] as String? ?? 'Unknown Cafe',
      rawImageInput: <String, Object?>{
        'photos': place['photos'],
        'photo_urls': place['photo_urls'],
        'photoUrl': place['photoUrl'],
        'image_url': place['image_url'],
        'image_urls': place['image_urls'],
        'media': place['media'],
      },
      normalizedPhotoUrls: images,
    );

    return Cafe(
      id: id,
      placeId: id,
      name: place['displayName']?['text'] as String? ?? 'Unknown Cafe',
      category: inferCafeCategory(
        rawCategory: place['primaryType'] as String?,
        name: place['displayName']?['text'] as String? ?? '',
        types: sourceTypes,
      ),
      district: normalizedDistrictOrUnknown(address),
      neighborhood: address,
      address: address.isEmpty ? 'Istanbul' : address,
      rating: 0.0,
      reviewCount: 0,
      priceLevel: PriceLevelExtension.fromString(
        place['priceLevel'] as String? ?? '',
      ),
      hasPriceLevel: place['priceLevel'] != null,
      tags: _buildPlaceTags(place),
      images: normalizeCafeImageUrls(images),
      description: '',
      openingHours: openingHours,
      wifiQuality: WifiQuality.average,
      outletAvailability: OutletAvailability.medium,
      quietnessLevel: QuietnessLevel.balanced,
      ambianceScore: 0,
      studyFriendly: false,
      petFriendly: false,
      outdoorSeating: false,
      menuHighlights: const [],
      seatingComfort: 0,
      openNow: explicitOpenNow ?? resolveCafeOpenState(openingHours),
      smokingPolicy: SmokingPolicy.notAllowed,
      coordinates: Coordinates(
        lat: ((place['location']?['latitude'] as num?)?.toDouble() ?? 41.0082),
        lng: ((place['location']?['longitude'] as num?)?.toDouble() ?? 28.9784),
      ),
      phoneNumber: place['internationalPhoneNumber'] as String?,
      websiteUri: place['websiteUri'] as String?,
      isDeleted: false,
      favoriteCount: 0,
      googlePlaceData: GooglePlaceData(
        googlePlaceId: id,
        googleRating: (place['rating'] as num?)?.toDouble(),
        googleReviewCount: place['userRatingCount'] as int?,
        googleOpenNow: explicitOpenNow,
        formattedAddress: address,
        hasPriceLevel: place['priceLevel'] != null,
        usesAppDefaults: true,
        sourceTypes: sourceTypes,
      ),
    );
  }

  final String id;
  final String? placeId;
  final String name;
  final CafeCategory category;
  final String district;
  final String neighborhood;
  final String address;
  final double rating;
  final int reviewCount;
  final PriceLevel priceLevel;
  final bool hasPriceLevel;
  final List<String> tags;
  final List<String> images;
  final String description;
  final List<OpeningHour> openingHours;
  final WifiQuality wifiQuality;
  final OutletAvailability outletAvailability;
  final QuietnessLevel quietnessLevel;
  final double ambianceScore;
  final bool studyFriendly;
  final bool petFriendly;
  final bool outdoorSeating;
  final List<String> menuHighlights;
  final double seatingComfort;
  final bool openNow;
  final SmokingPolicy smokingPolicy;
  final Coordinates coordinates;
  final String? phoneNumber;
  final String? websiteUri;
  final String ownerApprovalStatus;
  final String? ownerUserId;
  final bool isDeleted;
  final int favoriteCount;
  final double? manualRating;
  final int? manualRatingCount;
  final bool isFeatured;
  final int featuredPriority;
  final DateTime? featuredUntil;
  final String? featuredLabel;
  final GooglePlaceData? googlePlaceData;

  /// Stable cafe identity across Google and Supabase rows.
  ///
  /// Prefer the external Google Place id when present so the same venue does
  /// not fork into separate identities across sources.
  String get canonicalIdentityKey {
    final normalizedPlaceId = placeId?.trim();
    if (normalizedPlaceId != null && normalizedPlaceId.isNotEmpty) {
      return 'place:$normalizedPlaceId';
    }
    return 'id:$id';
  }

  String get dedupKey {
    return canonicalIdentityKey;
  }

  /// True when app-managed fields override Google defaults for this cafe.
  bool get usesAppManagedFields => googlePlaceData?.usesAppDefaults != true;
  bool get hasCommunityExperienceData => usesAppManagedFields;
  bool get hasWorkingHours => openingHours.any((hour) => hour.hasSchedule);
  bool get isVisibleInPublic =>
      !isDeleted && ownerApprovalStatus.trim().toLowerCase() == 'approved';
  bool get isActiveFeatured => isFeatured && isVisibleInPublic;
  String get sourceType =>
      (placeId?.trim().isNotEmpty ?? false) ? 'google' : 'manual';
  List<String> get photoUrls => images;
  bool get hasImageGallery => photoUrls.length > 1;
  double? get appRating => rating > 0 ? rating : null;
  int? get appReviewCount => reviewCount > 0 ? reviewCount : null;
  double? get adminFallbackRating =>
      (manualRating != null && manualRating! > 0) ? manualRating : null;
  int? get adminFallbackReviewCount =>
      (manualRatingCount != null && manualRatingCount! > 0)
          ? manualRatingCount
          : null;
  double? get googleRating => googlePlaceData?.googleRating;
  int? get googleReviewCount => googlePlaceData?.googleReviewCount;
  // Product policy: user-facing primary score is app/admin data only.
  // Google values are kept in metadata for optional secondary display.
  double get effectiveRating => appRating ?? adminFallbackRating ?? 0;
  int get effectiveReviewCount =>
      appReviewCount ?? adminFallbackReviewCount ?? 0;

  WifiQuality? get communityWifiQuality =>
      hasCommunityExperienceData ? wifiQuality : null;
  OutletAvailability? get communityOutletAvailability =>
      hasCommunityExperienceData ? outletAvailability : null;
  QuietnessLevel? get communityQuietnessLevel =>
      hasCommunityExperienceData ? quietnessLevel : null;
  double? get communityAmbianceScore =>
      hasCommunityExperienceData && ambianceScore > 0 ? ambianceScore : null;
  double? get communitySeatingComfort =>
      hasCommunityExperienceData && seatingComfort > 0 ? seatingComfort : null;
  bool? get communityStudyFriendly =>
      hasCommunityExperienceData ? studyFriendly : null;
  bool? get communityPetFriendly =>
      hasCommunityExperienceData ? petFriendly : null;
  bool? get communityOutdoorSeating =>
      hasCommunityExperienceData ? outdoorSeating : null;
  SmokingPolicy? get communitySmokingPolicy =>
      hasCommunityExperienceData ? smokingPolicy : null;

  Cafe copyWith({
    String? id,
    String? placeId,
    String? name,
    CafeCategory? category,
    String? district,
    String? neighborhood,
    String? address,
    double? rating,
    int? reviewCount,
    Object? priceLevel,
    bool? hasPriceLevel,
    List<String>? tags,
    List<String>? images,
    String? description,
    List<OpeningHour>? openingHours,
    Object? wifiQuality,
    Object? outletAvailability,
    Object? quietnessLevel,
    double? ambianceScore,
    bool? studyFriendly,
    bool? petFriendly,
    bool? outdoorSeating,
    List<String>? menuHighlights,
    double? seatingComfort,
    bool? openNow,
    Object? smokingPolicy,
    Coordinates? coordinates,
    String? phoneNumber,
    String? websiteUri,
    String? ownerApprovalStatus,
    String? Function()? ownerUserId,
    bool? isDeleted,
    int? favoriteCount,
    double? Function()? manualRating,
    int? Function()? manualRatingCount,
    bool? isFeatured,
    int? featuredPriority,
    DateTime? Function()? featuredUntil,
    String? Function()? featuredLabel,
    GooglePlaceData? Function()? googlePlaceData,
  }) {
    return Cafe(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      category: category ?? this.category,
      district: district ?? this.district,
      neighborhood: neighborhood ?? this.neighborhood,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      priceLevel: priceLevel ?? this.priceLevel,
      hasPriceLevel: hasPriceLevel ?? this.hasPriceLevel,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      description: description ?? this.description,
      openingHours: openingHours ?? this.openingHours,
      wifiQuality: wifiQuality ?? this.wifiQuality,
      outletAvailability: outletAvailability ?? this.outletAvailability,
      quietnessLevel: quietnessLevel ?? this.quietnessLevel,
      ambianceScore: ambianceScore ?? this.ambianceScore,
      studyFriendly: studyFriendly ?? this.studyFriendly,
      petFriendly: petFriendly ?? this.petFriendly,
      outdoorSeating: outdoorSeating ?? this.outdoorSeating,
      menuHighlights: menuHighlights ?? this.menuHighlights,
      seatingComfort: seatingComfort ?? this.seatingComfort,
      openNow: openNow ?? this.openNow,
      smokingPolicy: smokingPolicy ?? this.smokingPolicy,
      coordinates: coordinates ?? this.coordinates,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      websiteUri: websiteUri ?? this.websiteUri,
      ownerApprovalStatus: ownerApprovalStatus ?? this.ownerApprovalStatus,
      ownerUserId: ownerUserId != null ? ownerUserId() : this.ownerUserId,
      isDeleted: isDeleted ?? this.isDeleted,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      manualRating: manualRating != null ? manualRating() : this.manualRating,
      manualRatingCount: manualRatingCount != null
          ? manualRatingCount()
          : this.manualRatingCount,
      isFeatured: isFeatured ?? this.isFeatured,
      featuredPriority: featuredPriority ?? this.featuredPriority,
      featuredUntil:
          featuredUntil != null ? featuredUntil()?.toUtc() : this.featuredUntil,
      featuredLabel: featuredLabel != null
          ? _normalizeOptionalString(featuredLabel())
          : this.featuredLabel,
      googlePlaceData:
          googlePlaceData != null ? googlePlaceData() : this.googlePlaceData,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'google_place_id': placeId,
        'name': name,
        'category': category.value,
        'district': district,
        'neighborhood': neighborhood,
        'address': address,
        'rating': rating,
        'review_count': reviewCount,
        'price_level': hasPriceLevel ? priceLevel.value : null,
        'tags': tags,
        'images': photoUrls,
        'photo_urls': photoUrls,
        'description': description,
        'opening_hours': openingHours.map((hour) => hour.toJson()).toList(),
        'wifi_quality': wifiQuality.value,
        'outlet_availability': outletAvailability.value,
        'quietness_level': quietnessLevel.value,
        'ambiance_score': ambianceScore,
        'study_friendly': studyFriendly,
        'pet_friendly': petFriendly,
        'outdoor_seating': outdoorSeating,
        'menu_highlights': menuHighlights,
        'seating_comfort': seatingComfort,
        'open_now': openNow,
        'smoking_policy': smokingPolicy.value,
        'coordinates': coordinates.toJson(),
        'phone_number': phoneNumber,
        'website_uri': websiteUri,
        'owner_approval_status': ownerApprovalStatus,
        'owner_user_id': ownerUserId,
        'is_deleted': isDeleted,
        'favorite_count': favoriteCount,
        'manual_rating': manualRating,
        'manual_rating_count': manualRatingCount,
        'is_featured': isFeatured,
        'google_rating': googlePlaceData?.googleRating,
        'google_review_count': googlePlaceData?.googleReviewCount,
        'google_open_now': googlePlaceData?.googleOpenNow,
        'formatted_address': googlePlaceData?.formattedAddress,
        'external_last_synced_at': googlePlaceData?.lastSyncedAt,
        'google_has_price_level':
            googlePlaceData?.hasPriceLevel ?? hasPriceLevel,
        'google_uses_app_defaults': googlePlaceData?.usesAppDefaults ?? false,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cafe &&
          id == other.id &&
          placeId == other.placeId &&
          name == other.name &&
          category == other.category &&
          district == other.district &&
          neighborhood == other.neighborhood &&
          rating == other.rating &&
          priceLevel == other.priceLevel &&
          wifiQuality == other.wifiQuality &&
          outletAvailability == other.outletAvailability &&
          quietnessLevel == other.quietnessLevel &&
          smokingPolicy == other.smokingPolicy &&
          openNow == other.openNow &&
          phoneNumber == other.phoneNumber &&
          websiteUri == other.websiteUri &&
          ownerUserId == other.ownerUserId &&
          isDeleted == other.isDeleted &&
          favoriteCount == other.favoriteCount &&
          isFeatured == other.isFeatured &&
          featuredPriority == other.featuredPriority &&
          featuredUntil == other.featuredUntil &&
          featuredLabel == other.featuredLabel;

  @override
  int get hashCode => Object.hashAll([
        id,
        placeId,
        name,
        category,
        district,
        neighborhood,
        rating,
        priceLevel,
        wifiQuality,
        outletAvailability,
        quietnessLevel,
        smokingPolicy,
        openNow,
        phoneNumber,
        websiteUri,
        ownerUserId,
        isDeleted,
        favoriteCount,
        isFeatured,
        featuredPriority,
        featuredUntil,
        featuredLabel,
      ]);
}

class Filters {
  const Filters({
    this.category,
    this.district,
    this.selectedDistricts = const <String>{},
    this.neighborhood,
    this.minRating,
    this.priceLevel,
    this.wifiQuality,
    this.outletAvailability,
    this.quietnessLevel,
    this.outdoorSeating,
    this.petFriendly,
    this.studyFriendly,
    this.openNow,
    this.smokingPolicy,
    this.searchQuery,
  });

  final CafeCategory? category;
  final String? district;
  final Set<String> selectedDistricts;
  final String? neighborhood;
  final double? minRating;
  final PriceLevel? priceLevel;
  final WifiQuality? wifiQuality;
  final OutletAvailability? outletAvailability;
  final QuietnessLevel? quietnessLevel;
  final bool? outdoorSeating;
  final bool? petFriendly;
  final bool? studyFriendly;
  final bool? openNow;
  final SmokingPolicy? smokingPolicy;
  final String? searchQuery;

  static const empty = Filters();

  Filters copyWith({
    CafeCategory? Function()? category,
    String? Function()? district,
    Set<String> Function()? selectedDistricts,
    String? Function()? neighborhood,
    double? Function()? minRating,
    PriceLevel? Function()? priceLevel,
    WifiQuality? Function()? wifiQuality,
    OutletAvailability? Function()? outletAvailability,
    QuietnessLevel? Function()? quietnessLevel,
    bool? Function()? outdoorSeating,
    bool? Function()? petFriendly,
    bool? Function()? studyFriendly,
    bool? Function()? openNow,
    SmokingPolicy? Function()? smokingPolicy,
    String? Function()? searchQuery,
  }) {
    return Filters(
      category: category != null ? category() : this.category,
      district: district != null ? district() : this.district,
      selectedDistricts: selectedDistricts != null
          ? Set<String>.unmodifiable(selectedDistricts())
          : this.selectedDistricts,
      neighborhood: neighborhood != null ? neighborhood() : this.neighborhood,
      minRating: minRating != null ? minRating() : this.minRating,
      priceLevel: priceLevel != null ? priceLevel() : this.priceLevel,
      wifiQuality: wifiQuality != null ? wifiQuality() : this.wifiQuality,
      outletAvailability: outletAvailability != null
          ? outletAvailability()
          : this.outletAvailability,
      quietnessLevel:
          quietnessLevel != null ? quietnessLevel() : this.quietnessLevel,
      outdoorSeating:
          outdoorSeating != null ? outdoorSeating() : this.outdoorSeating,
      petFriendly: petFriendly != null ? petFriendly() : this.petFriendly,
      studyFriendly:
          studyFriendly != null ? studyFriendly() : this.studyFriendly,
      openNow: openNow != null ? openNow() : this.openNow,
      smokingPolicy:
          smokingPolicy != null ? smokingPolicy() : this.smokingPolicy,
      searchQuery: searchQuery != null ? searchQuery() : this.searchQuery,
    );
  }

  Set<String> get effectiveDistricts {
    if (selectedDistricts.isNotEmpty) {
      return selectedDistricts;
    }
    final legacyDistrict = district?.trim();
    if (legacyDistrict == null || legacyDistrict.isEmpty) {
      return const <String>{};
    }
    return <String>{legacyDistrict};
  }

  int get activeCount {
    int count = 0;
    if (category != null) count++;
    count += effectiveDistricts.length;
    if (neighborhood != null) count++;
    if (minRating != null) count++;
    if (priceLevel != null) count++;
    if (wifiQuality != null) count++;
    if (outletAvailability != null) count++;
    if (quietnessLevel != null) count++;
    if (outdoorSeating != null) count++;
    if (petFriendly != null) count++;
    if (studyFriendly != null) count++;
    if (openNow != null) count++;
    if (smokingPolicy != null) count++;
    if (searchQuery != null && searchQuery!.trim().isNotEmpty) count++;
    return count;
  }
}

class CafeAdminUpdateInput {
  const CafeAdminUpdateInput({
    this.name,
    this.category,
    this.district,
    this.neighborhood,
    this.address,
    this.description,
    this.priceLevel,
    this.tags,
    this.wifiQuality,
    this.outletAvailability,
    this.quietnessLevel,
    this.studyFriendly,
    this.petFriendly,
    this.outdoorSeating,
    this.smokingPolicy,
    this.openingHours,
    this.images,
    this.clearImages = false,
    this.menuHighlights,
    this.googlePlaceId,
    this.ownerApprovalStatus,
    this.ownerUserId,
    this.isDeleted,
    this.deletedBy,
    this.isFeatured,
    this.featuredPriority,
    this.featuredUntil,
    this.clearFeaturedUntil = false,
    this.featuredLabel,
  });

  final String? name;
  final String? category;
  final String? district;
  final String? neighborhood;
  final String? address;
  final String? description;
  final String? priceLevel;
  final List<String>? tags;
  final String? wifiQuality;
  final String? outletAvailability;
  final String? quietnessLevel;
  final bool? studyFriendly;
  final bool? petFriendly;
  final bool? outdoorSeating;
  final String? smokingPolicy;
  final List<OpeningHour>? openingHours;
  final List<String>? images;
  final bool clearImages;
  final List<String>? menuHighlights;
  final String? googlePlaceId;
  final String? ownerApprovalStatus;
  final String? ownerUserId;
  final bool? isDeleted;

  /// UUID of the admin who deleted this cafe (for soft-delete audit trail).
  final String? deletedBy;
  final bool? isFeatured;
  final int? featuredPriority;
  final DateTime? featuredUntil;
  final bool clearFeaturedUntil;
  final String? featuredLabel;

  Map<String, dynamic> toRow() {
    final row = <String, dynamic>{};
    if (name != null) row['name'] = sanitizeInput(name!);
    if (category != null) row['category'] = sanitizeInput(category!);
    if (district != null) row['district'] = sanitizeInput(district!);
    if (neighborhood != null) {
      row['neighborhood'] = sanitizeInput(neighborhood!);
    }
    if (address != null) row['address'] = sanitizeInput(address!);
    if (description != null) row['description'] = sanitizeInput(description!);
    if (priceLevel != null) {
      final normalizedPriceLevel = priceLevel!.trim();
      row['price_level'] =
          normalizedPriceLevel.isEmpty ? null : normalizedPriceLevel;
    }
    if (tags != null) {
      row['tags'] = tags!
          .map(sanitizeTag)
          .where((tag) => tag.isNotEmpty)
          .take(12)
          .toList(growable: false);
    }
    if (wifiQuality != null) row['wifi_quality'] = wifiQuality;
    if (outletAvailability != null) {
      row['outlet_availability'] = outletAvailability;
    }
    if (quietnessLevel != null) row['quietness_level'] = quietnessLevel;
    if (studyFriendly != null) row['study_friendly'] = studyFriendly;
    if (petFriendly != null) row['pet_friendly'] = petFriendly;
    if (outdoorSeating != null) row['outdoor_seating'] = outdoorSeating;
    if (smokingPolicy != null) row['smoking_policy'] = smokingPolicy;
    if (openingHours != null) {
      row['opening_hours'] =
          openingHours!.map((hour) => hour.toJson()).toList();
    }
    if (clearImages) {
      row['images'] = const <String>[];
    } else if (images != null) {
      row['images'] = images!
          .map((image) => image.trim())
          .where((image) =>
              image.startsWith('http://') || image.startsWith('https://'))
          .take(8)
          .toList(growable: false);
    }
    if (menuHighlights != null) {
      row['menu_highlights'] = menuHighlights!
          .map(sanitizeInput)
          .where((item) => item.isNotEmpty)
          .take(8)
          .toList(growable: false);
    }
    if (googlePlaceId != null) {
      final normalizedPlaceId = googlePlaceId!.trim();
      row['google_place_id'] =
          normalizedPlaceId.isEmpty ? null : normalizedPlaceId;
    }
    if (ownerApprovalStatus != null) {
      row['owner_approval_status'] = sanitizeInput(ownerApprovalStatus!);
    }
    if (ownerUserId != null) {
      final normalizedOwner = ownerUserId!.trim();
      row['owner_user_id'] = normalizedOwner.isEmpty ? null : normalizedOwner;
    }
    if (isDeleted != null) {
      row['is_deleted'] = isDeleted;
      // Auto-set deleted_at timestamp on soft delete.
      if (isDeleted == true) {
        row['deleted_at'] = DateTime.now().toUtc().toIso8601String();
      } else {
        // Clear timestamp on restore.
        row['deleted_at'] = null;
        row['deleted_by'] = null;
      }
    }
    if (deletedBy != null) {
      row['deleted_by'] = deletedBy;
    }
    if (isFeatured != null) {
      row['is_featured'] = isFeatured;
    }
    return row;
  }
}

Map<String, dynamic>? _toStringKeyedMap(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  return raw.map((key, value) => MapEntry(key.toString(), value));
}

bool? _asNullableBool(Object? raw) {
  if (raw is bool) {
    return raw;
  }
  if (raw is num) {
    if (raw == 1) {
      return true;
    }
    if (raw == 0) {
      return false;
    }
  }
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return null;
}

String? _normalizeOptionalString(Object? raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

DateTime? _parseOptionalDateTime(Object? raw) {
  if (raw is DateTime) {
    return raw.toUtc();
  }
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

Coordinates? _coordinatesFromLooseJson(Map<String, dynamic> json) {
  final latRaw = json['lat'] ?? json['latitude'];
  final lngRaw = json['lng'] ?? json['longitude'];
  final lat = latRaw is num ? latRaw.toDouble() : double.tryParse('$latRaw');
  final lng = lngRaw is num ? lngRaw.toDouble() : double.tryParse('$lngRaw');
  if (lat == null || lng == null) {
    return null;
  }
  return Coordinates(lat: lat, lng: lng);
}

String? _firstStringValue(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

List<String> _extractPhotoUrls(Map<String, dynamic> row) {
  final urls = <String>[];
  final seen = <String>{};
  late void Function(Object? raw) addFromRawValue;

  void addUrlCandidate(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }

    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        addFromRawValue(jsonDecode(trimmed));
        return;
      } catch (_) {
        // Ignore malformed JSON payloads and continue with URL parsing.
      }
    }

    if (trimmed.contains(',') ||
        trimmed.contains('\n') ||
        trimmed.contains('\r')) {
      final parts = trimmed
          .split(RegExp(r'[\r\n,]+'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty);
      var consumedMultipleValues = false;
      for (final part in parts) {
        consumedMultipleValues = true;
        addUrlCandidate(part);
      }
      if (consumedMultipleValues) {
        return;
      }
    }

    final normalized = _normalizeRemoteImageUrl(trimmed);
    if (normalized == null || !seen.add(normalized)) {
      return;
    }
    urls.add(normalized);
  }

  void addFromMap(Map<dynamic, dynamic> map) {
    addUrlCandidate(
      _firstNonEmptyString(
        map,
        const [
          'url',
          'image_url',
          'imageUrl',
          'photo_url',
          'photoUrl',
          'photoUri',
          'thumbnail_url',
          'thumbnailUrl',
          'google_photo_reference',
          'googlePhotoReference',
          'photo_reference',
          'photoReference',
          'name',
        ],
      ),
    );

    final nestedCollections = [
      map['images'],
      map['photo_urls'],
      map['photoUrls'],
      map['image_urls'],
      map['photos'],
      map['photo_references'],
      map['photoReferences'],
      map['google_photo_references'],
      map['googlePhotoReferences'],
      map['gallery'],
      map['media'],
    ];
    for (final nested in nestedCollections) {
      addFromRawValue(nested);
    }
  }

  addFromRawValue = (Object? raw) {
    if (raw == null) {
      return;
    }
    if (raw is String) {
      addUrlCandidate(raw);
      return;
    }
    if (raw is List) {
      for (final item in raw) {
        addFromRawValue(item);
      }
      return;
    }
    if (raw is Map) {
      addFromMap(raw);
      return;
    }

    // Some cached payloads may carry non-string entries; treat them as strings.
    addUrlCandidate(raw.toString());
  };

  // Source of truth for Supabase/media alias handling: iterate all known
  // aliases in a deterministic order. Empty or malformed values never
  // short-circuit fallback aliases.
  for (final key in const [
    'images',
    'photo_urls',
    'photoUrls',
    'image_urls',
    'photos',
    'gallery',
    'media',
    'image_url',
    'imageUrl',
    'image',
    'photo_url',
    'photoUrl',
    'photo',
    'thumbnail_url',
    'thumbnailUrl',
    'google_photo_reference',
    'googlePhotoReference',
    'photo_reference',
    'photoReference',
    'google_photo_references',
    'googlePhotoReferences',
    'photo_references',
    'photoReferences',
  ]) {
    addFromRawValue(row[key]);
  }

  return List<String>.unmodifiable(urls);
}

String? _normalizeRemoteImageUrl(String? value) => resolveCafeImageUrl(value);

List<String> _extractGooglePhotoUrls(
  Object? rawPhotos, {
  required int maxImageCount,
}) {
  if (maxImageCount <= 0) {
    return const <String>[];
  }

  final urls = _extractPhotoUrls(
    <String, dynamic>{
      'photos': rawPhotos,
    },
  );
  if (urls.length <= maxImageCount) {
    return urls;
  }

  return List<String>.unmodifiable(
    urls.take(maxImageCount.clamp(0, 8)),
  );
}

String? _firstNonEmptyString(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

String _buildFallbackAddress(String neighborhood, String district) {
  if (neighborhood.trim().isEmpty &&
      normalizedDistrictOrUnknown(district) == District.unknown.value) {
    return 'Istanbul';
  }

  final parts = <String>[
    if (neighborhood.trim().isNotEmpty) neighborhood.trim(),
    if (district.trim().isNotEmpty &&
        normalizedDistrictOrUnknown(district) != District.unknown.value)
      district.trim(),
    'Istanbul',
  ];
  return parts.join(', ');
}

List<String> _buildPlaceTags(Map<String, dynamic> place) {
  final tags = <String>{'Cafe'};
  final primaryType = place['primaryType'] as String?;
  if (primaryType != null && primaryType.trim().isNotEmpty) {
    tags.add(primaryType.replaceAll('_', ' '));
  }
  for (final type
      in (place['types'] as List<dynamic>? ?? const []).whereType<String>()) {
    tags.add(type.replaceAll('_', ' '));
    if (tags.length >= 6) {
      break;
    }
  }
  return tags.toList(growable: false);
}

void _logModelPhotoNormalization({
  required String source,
  required String cafeId,
  required String cafeName,
  required Map<String, Object?> rawImageInput,
  required List<String> normalizedPhotoUrls,
}) {
  if (!kDebugMode || !_enablePhotoModelDiagnostics) {
    return;
  }
  final normalizedId = cafeId.trim();
  if (normalizedId.isEmpty) {
    return;
  }
  final sampleKey = '$source|$normalizedId';
  if (_photoModelLoggedKeys.contains(sampleKey)) {
    return;
  }
  final currentCount = _photoModelSampleCounts[source] ?? 0;
  if (currentCount >= _photoModelSampleLimit) {
    return;
  }

  final presence = _photoFieldPresence(rawImageInput);
  final presentFields = presence.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList(growable: false);
  if (presentFields.isEmpty && normalizedPhotoUrls.isEmpty) {
    return;
  }
  final breakdown = cafePhotoUrlBreakdownFromRaw(rawImageInput);
  _photoModelLoggedKeys.add(sampleKey);
  _photoModelSampleCounts[source] = currentCount + 1;
  AppLogger.debug(
    '[CAFE_DIAG_PHOTO_MODEL] source=$source id=$cafeId name="$cafeName" presentFieldCount=${presentFields.length}/${presence.length} presentFields=$presentFields storedPhotoUrls=${breakdown.storedPhotoUrls.length} generatedPhotoUrls=${breakdown.generatedPhotoUrls.length} resolvedDisplayUrls=${normalizedPhotoUrls.length} hasFirstPhoto=${normalizedPhotoUrls.isNotEmpty}',
    key: 'cafe-diag-photo-model-$source',
    throttle: const Duration(seconds: 1),
  );
}

const int _photoModelSampleLimit = 3;
const bool _enablePhotoModelDiagnostics = bool.fromEnvironment(
  'ENABLE_CAFE_PHOTO_MODEL_DIAGNOSTICS',
  defaultValue: true,
);
final Map<String, int> _photoModelSampleCounts = <String, int>{};
final Set<String> _photoModelLoggedKeys = <String>{};

@visibleForTesting
void resetPhotoModelDiagnosticsLimit() {
  _photoModelSampleCounts.clear();
  _photoModelLoggedKeys.clear();
}

Map<String, bool> _photoFieldPresence(Map<String, Object?> rawImageInput) {
  return <String, bool>{
    for (final entry in rawImageInput.entries)
      entry.key: _hasPhotoPayload(entry.value),
  };
}

bool _hasPhotoPayload(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  if (value is List) {
    return value.any(_hasPhotoPayload);
  }
  if (value is Map) {
    return value.values.any(_hasPhotoPayload);
  }
  return true;
}

List<OpeningHour> _parseOpeningHoursSafe(Object? raw) {
  try {
    return parseOpeningHours(raw);
  } catch (_) {
    return const <OpeningHour>[];
  }
}

List<String> _stringListOrEmpty(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

double _clampDouble(
  double value, {
  required double min,
  required double max,
}) {
  return value.clamp(min, max).toDouble();
}
