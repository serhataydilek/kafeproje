import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/models/service_result.dart';
import 'package:kafeproje/repositories/cafe_merge_policy.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'package:kafeproje/services/places_service.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/cafe_hours.dart';
import 'package:kafeproje/utils/request_cancellation.dart';

void main() {
  group('CafeMergePolicy', () {
    test('prefers Google identity while applying Supabase overrides', () {
      final googleCafe = _googleCafe();
      final supabaseCafe = _supabaseCafe(
        googlePlaceId: googleCafe.placeId!,
        usesAppDefaults: false,
      );

      final merged = CafeMergePolicy.mergeCafeSources(
        googlePlaceCafe: googleCafe,
        supabaseCafe: supabaseCafe,
      );

      expect(merged.id, googleCafe.id);
      expect(merged.placeId, googleCafe.placeId);
      expect(merged.name, 'Custom Cafe Name');
      expect(merged.description, 'Curated by the app team');
      expect(merged.wifiQuality, WifiQuality.strong);
      expect(merged.googlePlaceData?.googleRating, 4.7);
      expect(merged.effectiveRating, 4.8);
    });

    test('preserves Supabase is_featured during Google merge', () {
      final googleCafe = _googleCafe();
      final supabaseCafe = _supabaseCafe(
        googlePlaceId: googleCafe.placeId!,
        usesAppDefaults: false,
      ).copyWith(
        isFeatured: true,
      );

      final merged = CafeMergePolicy.mergeCafeSources(
        googlePlaceCafe: googleCafe,
        supabaseCafe: supabaseCafe,
      );

      expect(merged.id, googleCafe.id);
      expect(merged.isFeatured, isTrue);
      expect(merged.featuredPriority, 0);
      expect(merged.featuredUntil, isNull);
      expect(merged.featuredLabel, isNull);
      expect(merged.isActiveFeatured, isTrue);
    });

    test('applies live review aggregates without dropping Google metadata', () {
      final baseCafe = _googleCafe();
      final reviews = [
        CafeReview(
          id: 'review-1',
          cafeId: baseCafe.id,
          userId: 'user-1',
          rating: 5,
          wifiQuality: 5,
          noiseLevel: 4,
          studyFriendliness: 4,
          seatingComfort: 4,
          socketAvailability: 'high',
          smokingPolicy: 'not_allowed',
          createdAt: DateTime.utc(2026, 3, 28),
        ),
        CafeReview(
          id: 'review-2',
          cafeId: baseCafe.id,
          userId: 'user-2',
          rating: 4,
          wifiQuality: 4,
          noiseLevel: 5,
          studyFriendliness: 5,
          seatingComfort: 5,
          socketAvailability: 'medium',
          smokingPolicy: 'outdoor_only',
          createdAt: DateTime.utc(2026, 3, 28),
        ),
      ];

      final merged = CafeMergePolicy.applyReviewOverlay(baseCafe, reviews);

      expect(merged.rating, 4.5);
      expect(merged.reviewCount, 2);
      expect(merged.communityWifiQuality, WifiQuality.strong);
      expect(merged.communityQuietnessLevel, QuietnessLevel.quiet);
      expect(merged.communityStudyFriendly, isTrue);
      expect(merged.googlePlaceData?.googleRating, 4.7);
      expect(merged.googlePlaceData?.usesAppDefaults, isFalse);
    });

    test('does not promote manual fallback into primary merged rating', () {
      final googleCafe = _googleCafe();
      final supabaseCafe = _supabaseCafe(
        googlePlaceId: googleCafe.placeId!,
        usesAppDefaults: false,
      ).copyWith(
        rating: 0,
        reviewCount: 0,
        manualRating: () => 4.9,
        manualRatingCount: () => 140,
      );

      final merged = CafeMergePolicy.mergeCafeSources(
        googlePlaceCafe: googleCafe,
        supabaseCafe: supabaseCafe,
      );

      expect(merged.rating, 0);
      expect(merged.reviewCount, 0);
    });

    test(
        'keeps explicit Google open-now state when Supabase source lacks reliable hours',
        () {
      final baseGoogle = _googleCafe();
      final googleCafe = baseGoogle.copyWith(
        openingHours: const [],
        openNow: false,
        googlePlaceData: () =>
            baseGoogle.googlePlaceData?.copyWith(googleOpenNow: false),
      );
      final supabaseCafe = _supabaseCafe(
        googlePlaceId: googleCafe.placeId!,
        usesAppDefaults: false,
      ).copyWith(
        openingHours: const [],
        openNow: true,
        googlePlaceData: () => GooglePlaceData(
          googlePlaceId: googleCafe.placeId,
          usesAppDefaults: false,
        ),
      );

      final merged = CafeMergePolicy.mergeCafeSources(
        googlePlaceCafe: googleCafe,
        supabaseCafe: supabaseCafe,
      );

      expect(merged.googlePlaceData?.googleOpenNow, isFalse);
      expect(resolveCafeOpenStatus(merged), CafeOpenStatus.closed);
    });
  });

  group('CafeRepository merge flow', () {
    test('merges Supabase overlays before returning cafes to callers',
        () async {
      final repository = CafeRepository(
        _FakePlacesService(
          cafes: [_googleCafe()],
        ),
        _FakeCafeOverlaySource(
          cafesByPlaceIds: [_supabaseCafe(googlePlaceId: 'place-123')],
        ),
      );

      final result = await repository.fetchCafes();

      expect(result.ok, isTrue);
      expect(result.cafes, hasLength(1));
      expect(result.cafes.single.id, 'place-123');
      expect(result.cafes.single.description, 'Curated by the app team');
      expect(result.cafes.single.wifiQuality, WifiQuality.strong);
      expect(result.cafes.single.googlePlaceData?.googleRating, 4.7);
    });

    test('drops Google cafe when matching Supabase row is soft-deleted',
        () async {
      final repository = CafeRepository(
        _FakePlacesService(
          cafes: [_googleCafe()],
        ),
        _FakeCafeOverlaySource(
          cafesByPlaceIds: [
            _supabaseCafe(googlePlaceId: 'place-123').copyWith(isDeleted: true),
          ],
        ),
      );

      final result = await repository.fetchCafes();

      expect(result.ok, isTrue);
      expect(result.cafes, isEmpty);
    });

    test('drops Google cafe when matching Supabase row has deleted_at',
        () async {
      final repository = CafeRepository(
        _FakePlacesService(
          cafes: [_googleCafe()],
        ),
        _FakeCafeOverlaySource(
          cafesByPlaceIds: [
            Cafe.fromSupabaseRow({
              'id': 'supabase-row-1',
              'google_place_id': 'place-123',
              'name': 'Deleted Cafe',
              'is_featured': true,
              'is_deleted': false,
              'deleted_at': '2026-01-01T00:00:00Z',
            }),
          ],
        ),
      );

      final result = await repository.fetchCafes();

      expect(result.ok, isTrue);
      expect(result.cafes, isEmpty);
    });

    test('drops Google cafe when matching Supabase row is tombstoned',
        () async {
      final repository = CafeRepository(
        _FakePlacesService(
          cafes: [_googleCafe()],
        ),
        _FakeCafeOverlaySource(
          cafesByPlaceIds: [
            Cafe.fromSupabaseRow({
              'id': 'deleted-google-place_123',
              'google_place_id': 'place-123',
              'name': 'place-123',
              'is_featured': false,
              'is_deleted': true,
              'deleted_at': '2026-01-01T00:00:00Z',
            }),
          ],
        ),
      );

      final result = await repository.fetchCafes();

      expect(result.ok, isTrue);
      expect(result.cafes, isEmpty);
    });

    test('drops Arabic-script Google cafe from fresh merge output', () async {
      final arabicCafe = _googleCafe().copyWith(
        name: '\u0645\u0642\u0647\u0649 \u0627\u0644\u0642\u0647\u0648\u0629',
      );
      final repository = CafeRepository(
        _FakePlacesService(cafes: [arabicCafe]),
        _FakeCafeOverlaySource(),
      );

      final result = await repository.fetchCafes();

      expect(result.ok, isTrue);
      expect(result.cafes, isEmpty);
    });
  });
}

Cafe _googleCafe() {
  return Cafe(
    id: 'place-123',
    placeId: 'place-123',
    name: 'Google Cafe',
    category: CafeCategory.normalCafe,
    district: 'Kadıköy',
    neighborhood: 'Moda',
    address: 'Google Address',
    rating: 0,
    reviewCount: 0,
    priceLevel: PriceLevel.moderate,
    hasPriceLevel: true,
    tags: const ['Cafe', 'Coffee shop'],
    images: const ['https://images.example/google.jpg'],
    description: '',
    openingHours: const [],
    wifiQuality: WifiQuality.average,
    outletAvailability: OutletAvailability.medium,
    quietnessLevel: QuietnessLevel.balanced,
    ambianceScore: 0,
    studyFriendly: false,
    petFriendly: false,
    outdoorSeating: false,
    menuHighlights: const [],
    seatingComfort: 0,
    openNow: true,
    smokingPolicy: SmokingPolicy.notAllowed,
    coordinates: const Coordinates(lat: 40.99, lng: 29.03),
    phoneNumber: '+90 555 111 11 11',
    websiteUri: 'https://google.example',
    googlePlaceData: const GooglePlaceData(
      googlePlaceId: 'place-123',
      googleRating: 4.7,
      googleReviewCount: 180,
      formattedAddress: 'Google Address',
      hasPriceLevel: true,
      usesAppDefaults: true,
      sourceTypes: <String>['cafe'],
    ),
  );
}

Cafe _supabaseCafe({
  required String googlePlaceId,
  bool usesAppDefaults = false,
}) {
  return Cafe(
    id: 'supabase-row-1',
    placeId: googlePlaceId,
    name: 'Custom Cafe Name',
    category: CafeCategory.cafeLounge,
    district: 'Kadıköy',
    neighborhood: 'Moda Sahil',
    address: 'Custom Address',
    rating: 4.8,
    reviewCount: 24,
    priceLevel: PriceLevel.expensive,
    hasPriceLevel: true,
    tags: const ['App favorite', 'Study'],
    images: const ['https://images.example/custom.jpg'],
    description: 'Curated by the app team',
    openingHours: const [],
    wifiQuality: WifiQuality.strong,
    outletAvailability: OutletAvailability.high,
    quietnessLevel: QuietnessLevel.quiet,
    ambianceScore: 4.6,
    studyFriendly: true,
    petFriendly: true,
    outdoorSeating: true,
    menuHighlights: const ['Flat white'],
    seatingComfort: 4.7,
    openNow: false,
    smokingPolicy: SmokingPolicy.outdoorOnly,
    coordinates: const Coordinates(lat: 40.9905, lng: 29.031),
    phoneNumber: '+90 555 222 22 22',
    websiteUri: 'https://app.example',
    ownerApprovalStatus: 'approved',
    googlePlaceData: GooglePlaceData(
      googlePlaceId: googlePlaceId,
      googleRating: 4.2,
      googleReviewCount: 80,
      formattedAddress: 'Custom Address',
      usesAppDefaults: usesAppDefaults,
      sourceTypes: const <String>['cafe'],
    ),
  );
}

class _FakePlacesService implements PlacesServiceBase {
  _FakePlacesService({required this.cafes});

  final List<Cafe> cafes;

  @override
  bool get supportsExternalPagination => false;

  @override
  Future<PlacesResult> fetchCafes({
    double? lat,
    double? lng,
    String? district,
    int radius = 5000,
    String? pageToken,
    bool seedOnly = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    return PlacesResult(cafes: cafes);
  }

  @override
  Future<Cafe?> fetchCafeDetails(
    String placeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    for (final cafe in cafes) {
      if (cafe.placeId == placeId || cafe.id == placeId) {
        return cafe;
      }
    }
    return null;
  }

  @override
  Future<PlaceRatingMetadata?> fetchPlaceRatingMetadata(
    String placeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    return null;
  }
}

class _FakeCafeOverlaySource implements CafeOverlaySource {
  _FakeCafeOverlaySource({
    this.cafesByPlaceIds = const <Cafe>[],
    Cafe? cafeDetail,
  }) : _cafeDetail = cafeDetail;

  final List<Cafe> cafesByPlaceIds;
  final Cafe? _cafeDetail;

  @override
  Future<ServiceResult<List<Cafe>>> fetchDiscoverableCafes({
    String? district,
    int limit = 800,
    int offset = 0,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final normalizedDistrict = district?.trim().toLowerCase();
    final filtered = cafesByPlaceIds
        .where((cafe) {
          if (normalizedDistrict == null || normalizedDistrict.isEmpty) {
            return true;
          }
          return cafe.district.trim().toLowerCase() == normalizedDistrict;
        })
        .skip(offset)
        .take(limit)
        .toList(growable: false);
    return ServiceResult.success(data: filtered);
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchActiveFeaturedCafes({
    String? district,
    int limit = 40,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final normalizedDistrict = district?.trim().toLowerCase();
    final filtered = cafesByPlaceIds
        .where((cafe) => cafe.isActiveFeatured)
        .where((cafe) {
          if (normalizedDistrict == null || normalizedDistrict.isEmpty) {
            return true;
          }
          return cafe.district.trim().toLowerCase() == normalizedDistrict;
        })
        .take(limit)
        .toList(growable: false);
    return ServiceResult.success(data: filtered);
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafes() async {
    return ServiceResult.success(data: cafesByPlaceIds);
  }

  @override
  Future<ServiceResult<List<Cafe>>> searchCafesByName(
    String query, {
    int limit = 20,
    bool includeDeleted = false,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    final matches = cafesByPlaceIds
        .where((cafe) => cafe.name.toLowerCase().contains(normalizedQuery))
        .take(limit)
        .toList(growable: false);
    return ServiceResult.success(data: matches);
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafesByPlaceIds(
    Iterable<String> placeIds, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final placeIdSet = placeIds.toSet();
    return ServiceResult.success(
      data: cafesByPlaceIds
          .where((cafe) => placeIdSet.contains(cafe.placeId))
          .toList(growable: false),
    );
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafesByIds(
    Iterable<String> ids, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final idSet =
        ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    return ServiceResult.success(
      data: cafesByPlaceIds
          .where(
              (cafe) => idSet.contains(cafe.id) || idSet.contains(cafe.placeId))
          .toList(growable: false),
    );
  }

  @override
  Future<ServiceResult<Cafe?>> fetchCafeDetails(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    return ServiceResult.success(data: _cafeDetail);
  }

  @override
  Future<ServiceResult<Cafe?>> fetchCafeById(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    return fetchCafeDetails(
      cafeId,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
  }

  @override
  Future<ServiceResult<void>> updateGoogleRatingMetadata({
    required String cafeId,
    required String googlePlaceId,
    double? googleRating,
    int? googleReviewCount,
    String? externalLastSyncedAt,
    Duration? requestTimeout,
  }) async {
    return ServiceResult.success(data: null);
  }
}
