import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/models/service_result.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'package:kafeproje/services/local_storage_service.dart';
import 'package:kafeproje/services/places_service.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/request_cancellation.dart';

import 'test_helpers.dart';

void main() {
  group('CafeRepository.getCafesByIds', () {
    test('resolves Google place IDs through the overlay source', () async {
      final cafe = buildTestCafe(id: 'cafe-1', name: 'Cafe One').copyWith(
        placeId: 'place-1',
      );
      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: [cafe],
      );
      final repository = CafeRepository(null, overlay);

      final cafes = await repository.getCafesByIds(['place-1']);

      expect(overlay.fetchByIdCalls, 1);
      expect(overlay.fetchByPlaceIdCalls, 1);
      expect(cafes, [cafe]);
    });

    test(
        'resolves ids/placeIds from persisted list caches outside active scope without leaking unrelated cafes',
        () async {
      await Hive.close();
      final tempDir = await Directory.systemTemp.createTemp(
        'kafeproje-cafe-repository-test-',
      );
      addTearDown(() async {
        await Hive.close();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('app_state');
      final storage = LocalStorageService(box);

      final nearbyCafe = buildTestCafe(id: 'nearby-1', name: 'Nearby');
      final farById = buildTestCafe(id: 'far-id-1', name: 'Far Id');
      final farByPlace =
          buildTestCafe(id: 'far-row-2', name: 'Far Place').copyWith(
        placeId: 'place-far-2',
      );

      await storage.saveCafeListCache('scope:nearby', [nearbyCafe]);
      await storage.saveCafeListCache('scope:far', [farById, farByPlace]);

      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: const <Cafe>[],
      );
      final repository = CafeRepository(null, overlay, storage);

      await repository.loadCachedCafeList(cacheKey: 'scope:nearby');

      final cafes = await repository.getCafesByIds(
        ['far-id-1', 'place-far-2'],
      );

      expect(
        cafes.map((cafe) => cafe.id).toList(growable: false),
        ['far-id-1', 'far-row-2'],
      );
      expect(cafes.map((cafe) => cafe.id), isNot(contains('nearby-1')));
      expect(overlay.fetchByIdCalls, 0);
      expect(overlay.fetchByPlaceIdCalls, 0);
    });

    test('featured cache preserves images and google_place_id', () async {
      await Hive.close();
      final tempDir = await Directory.systemTemp.createTemp(
        'kafeproje-featured-cache-test-',
      );
      addTearDown(() async {
        await Hive.close();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('app_state');
      final storage = LocalStorageService(box);
      final featured = buildTestCafe(
        id: 'featured-cache-1',
        name: 'Cached Featured',
        images: const ['https://example.com/featured-cache.jpg'],
      ).copyWith(
        placeId: 'place-featured-cache-1',
        isFeatured: true,
        ownerApprovalStatus: 'approved',
      );

      await storage.saveCafeListCache('featured', [featured]);
      final snapshot = await storage.loadCafeListCache('featured');

      expect(snapshot, isNotNull);
      expect(snapshot!.cafes.single.photoUrls, [
        'https://example.com/featured-cache.jpg',
      ]);
      expect(snapshot.cafes.single.placeId, 'place-featured-cache-1');
    });
  });

  group('CafeRepository.fetchFeaturedCafes', () {
    test('uses dedicated featured source without general discovery classifier',
        () async {
      final sparseCuratedSponsor = buildTestCafe(
        id: 'featured-sparse-curated',
        name: 'Curated Workspace',
      ).copyWith(
        placeId: 'short-featured-place',
        category: CafeCategory.normalCafe,
        tags: const <String>[],
        isFeatured: true,
        featuredPriority: 10,
        ownerApprovalStatus: 'approved',
        isDeleted: false,
      );
      final hiddenSponsor = sparseCuratedSponsor.copyWith(
        id: 'featured-hidden',
        ownerApprovalStatus: 'pending',
      );
      final deletedSponsor = sparseCuratedSponsor.copyWith(
        id: 'featured-deleted',
        isDeleted: true,
      );
      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: const <Cafe>[],
        featuredCafes: [
          sparseCuratedSponsor,
          hiddenSponsor,
          deletedSponsor,
        ],
      );
      final repository = CafeRepository(null, overlay);

      final cafes = await repository.fetchFeaturedCafes();

      expect(overlay.fetchActiveFeaturedCalls, 1);
      expect(cafes.map((cafe) => cafe.id), ['featured-sparse-curated']);
    });
  });

  group('CafeRepository.fetchDiscoverableCafes', () {
    test('keeps active featured rows outside Google results out of discovery',
        () async {
      final googleCafe = buildTestCafe(
        id: 'google-cafe',
        name: 'Google Cafe',
      ).copyWith(placeId: 'google-place-1');
      final featuredCafe = buildTestCafe(
        id: 'featured-cafe',
        name: 'Featured Cafe',
      ).copyWith(
        isFeatured: true,
        featuredPriority: 50,
        ownerApprovalStatus: 'approved',
        isDeleted: false,
      );
      final organicSupabaseCafe = buildTestCafe(
        id: 'organic-db-cafe',
        name: 'Organic DB Cafe',
      );
      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: const <Cafe>[],
        discoverableCafes: [organicSupabaseCafe],
        featuredCafes: [featuredCafe],
      );
      final repository = CafeRepository(
        _FakePlacesService([googleCafe]),
        overlay,
      );

      final result = await repository.fetchDiscoverableCafes(
        lat: 41.0,
        lng: 29.0,
        radius: 1000,
        bypassRateLimit: true,
      );

      expect(result.ok, isTrue);
      expect(
        result.cafes.map((cafe) => cafe.id),
        contains('google-cafe'),
      );
      expect(
        result.cafes.map((cafe) => cafe.id),
        isNot(contains('featured-cafe')),
      );
      expect(
        result.cafes.map((cafe) => cafe.id),
        isNot(contains('organic-db-cafe')),
      );
      expect(overlay.fetchActiveFeaturedCalls, 1);
    });

    test('does not add active featured rows from other districts to discovery',
        () async {
      final districtCafe = buildTestCafe(
        id: 'district-cafe',
        name: 'District Cafe',
        district: 'Kadikoy',
      ).copyWith(placeId: 'district-place-1');
      final featuredCafe = buildTestCafe(
        id: 'featured-other-district',
        name: 'Featured Other District',
        district: 'Besiktas',
      ).copyWith(
        isFeatured: true,
        featuredPriority: 80,
        ownerApprovalStatus: 'approved',
        isDeleted: false,
      );
      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: const <Cafe>[],
        discoverableCafes: const <Cafe>[],
        featuredCafes: [featuredCafe],
      );
      final repository = CafeRepository(
        _FakePlacesService([districtCafe]),
        overlay,
      );

      final result = await repository.fetchDiscoverableCafes(
        district: 'Kadikoy',
        bypassRateLimit: true,
      );

      expect(result.ok, isTrue);
      expect(
        result.cafes.map((cafe) => cafe.id),
        contains('district-cafe'),
      );
      expect(
        result.cafes.map((cafe) => cafe.id),
        isNot(contains('featured-other-district')),
      );
      expect(overlay.lastActiveFeaturedDistrict, isNull);
    });

    test('uses separate radius-independent source for featured cafes',
        () async {
      final featuredCafe = buildTestCafe(
        id: 'featured-other-district',
        name: 'Featured Other District',
        district: 'Besiktas',
      ).copyWith(
        isFeatured: true,
        featuredPriority: 80,
        ownerApprovalStatus: 'approved',
        isDeleted: false,
      );
      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: const <Cafe>[],
        featuredCafes: [featuredCafe],
      );
      final repository = CafeRepository(null, overlay);

      final featured = await repository.fetchFeaturedCafes();

      expect(featured.map((cafe) => cafe.id), ['featured-other-district']);
      expect(overlay.fetchActiveFeaturedCalls, 1);
      expect(overlay.lastActiveFeaturedDistrict, isNull);
    });

    test('filters obvious non-cafe featured venues from public featured list',
        () async {
      final sponsoredCafe = buildTestCafe(
        id: 'curated-sponsored',
        name: 'Doner Sarayi',
        tags: const <String>[],
      ).copyWith(
        isFeatured: true,
        featuredPriority: 80,
        ownerApprovalStatus: 'approved',
        isDeleted: false,
      );
      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: const <Cafe>[],
        featuredCafes: [sponsoredCafe],
      );
      final repository = CafeRepository(null, overlay);

      final featured = await repository.fetchFeaturedCafes();

      expect(featured, isEmpty);
      expect(overlay.fetchActiveFeaturedCalls, 1);
    });

    test('keeps featured venues with explicit admin cafe override tag',
        () async {
      final overriddenCafe = buildTestCafe(
        id: 'curated-sponsored-override',
        name: 'Doner Sarayi',
        tags: const <String>['admin_allow_cafe'],
      ).copyWith(
        isFeatured: true,
        featuredPriority: 81,
        ownerApprovalStatus: 'approved',
        isDeleted: false,
      );
      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: const <Cafe>[],
        featuredCafes: [overriddenCafe],
      );
      final repository = CafeRepository(null, overlay);

      final featured = await repository.fetchFeaturedCafes();

      expect(
        featured.map((cafe) => cafe.id),
        ['curated-sponsored-override'],
      );
      expect(overlay.fetchActiveFeaturedCalls, 1);
    });
  });

  group('CafeRepository sponsored rating hydration', () {
    test('hydrates missing Google rating metadata and persists it', () async {
      final sponsor = buildTestCafe(
        id: 'rating-sponsor',
        name: 'Rating Sponsor',
      ).copyWith(
        placeId: 'place-rating-sponsor',
        isFeatured: true,
        images: const ['https://some-image.com/img.jpg'],
        googlePlaceData: () => const GooglePlaceData(
          googlePlaceId: 'place-rating-sponsor',
        ),
      );
      final places = _FakePlacesService(
        const <Cafe>[],
        ratingMetadata: const {
          'place-rating-sponsor': PlaceRatingMetadata(
            placeId: 'place-rating-sponsor',
            rating: 4.8,
            reviewCount: 456,
          ),
        },
      );
      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: const <Cafe>[],
      );
      final repository = CafeRepository(places, overlay);

      final updated =
          await repository.hydrateFeaturedGoogleRatingMetadata([sponsor]);

      expect(places.ratingMetadataCalls, 1);
      expect(updated, hasLength(1));
      expect(updated.single.googleRating, 4.8);
      expect(updated.single.googleReviewCount, 456);
      expect(overlay.ratingUpdateCalls, 1);
      expect(overlay.lastRatingUpdateCafeId, 'rating-sponsor');
      expect(overlay.lastRatingUpdatePlaceId, 'place-rating-sponsor');
    });

    test('skips Google metadata calls when sponsored rows are already rated',
        () async {
      final sponsor = buildTestCafe(
        id: 'already-rated-sponsor',
        name: 'Already Rated Sponsor',
      ).copyWith(
        placeId: 'place-already-rated-sponsor',
        isFeatured: true,
        images: const ['https://some-image.com/img.jpg'],
        googlePlaceData: () => const GooglePlaceData(
          googlePlaceId: 'place-already-rated-sponsor',
          googleRating: 4.7,
          googleReviewCount: 99,
        ),
      );
      final places = _FakePlacesService(const <Cafe>[]);
      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: const <Cafe>[],
      );
      final repository = CafeRepository(places, overlay);

      final updated =
          await repository.hydrateFeaturedGoogleRatingMetadata([sponsor]);

      expect(updated, isEmpty);
      expect(places.ratingMetadataCalls, 0);
      expect(overlay.ratingUpdateCalls, 0);
    });

    test('hydrates Google Places photos when a featured cafe has no images',
        () async {
      final sponsor = buildTestCafe(
        id: 'no-images-sponsor',
        name: 'No Images Sponsor',
      ).copyWith(
        placeId: 'place-no-images-sponsor',
        isFeatured: true,
        images: const [],
        googlePlaceData: () => const GooglePlaceData(
          googlePlaceId: 'place-no-images-sponsor',
          googleRating: 4.8,
          googleReviewCount: 120,
        ),
      );
      final googleCafe = buildTestCafe(
        id: 'no-images-sponsor',
        name: 'Google Rated Sponsor',
      ).copyWith(
        placeId: 'place-no-images-sponsor',
        images: const ['https://google.com/photo.jpg'],
        googlePlaceData: () => const GooglePlaceData(
          googlePlaceId: 'place-no-images-sponsor',
          googleRating: 4.9,
          googleReviewCount: 125,
        ),
      );
      final places = _FakePlacesService(
        const <Cafe>[],
        cafeDetails: {
          'place-no-images-sponsor': googleCafe,
        },
      );
      final overlay = _FakeCafeOverlaySource(
        cafesByIds: const <Cafe>[],
        cafesByPlaceIds: const <Cafe>[],
      );
      final repository = CafeRepository(places, overlay);

      final updated =
          await repository.hydrateFeaturedGoogleRatingMetadata([sponsor]);

      expect(places.cafeDetailsCalls, 1);
      expect(places.ratingMetadataCalls, 0);
      expect(updated, hasLength(1));
      expect(updated.single.photoUrls, ['https://google.com/photo.jpg']);
      expect(updated.single.googleRating, 4.9);
      expect(updated.single.googleReviewCount, 125);
    });
  });
}

class _FakeCafeOverlaySource implements CafeOverlaySource {
  _FakeCafeOverlaySource({
    required this.cafesByIds,
    required this.cafesByPlaceIds,
    this.discoverableCafes = const <Cafe>[],
    this.featuredCafes = const <Cafe>[],
  });

  final List<Cafe> cafesByIds;
  final List<Cafe> cafesByPlaceIds;
  final List<Cafe> discoverableCafes;
  final List<Cafe> featuredCafes;
  int fetchByIdCalls = 0;
  int fetchByPlaceIdCalls = 0;
  int fetchActiveFeaturedCalls = 0;
  int ratingUpdateCalls = 0;
  String? lastActiveFeaturedDistrict;
  String? lastRatingUpdateCafeId;
  String? lastRatingUpdatePlaceId;

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafesByIds(
    Iterable<String> ids, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    fetchByIdCalls += 1;
    return ServiceResult.success(data: cafesByIds);
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafesByPlaceIds(
    Iterable<String> placeIds, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    fetchByPlaceIdCalls += 1;
    return ServiceResult.success(data: cafesByPlaceIds);
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchDiscoverableCafes({
    String? district,
    int limit = 120,
    int offset = 0,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    return ServiceResult.success(data: discoverableCafes);
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchActiveFeaturedCafes({
    String? district,
    int limit = 40,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    fetchActiveFeaturedCalls += 1;
    lastActiveFeaturedDistrict = district;
    return ServiceResult.success(data: featuredCafes);
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafes() async {
    return ServiceResult.success(data: const <Cafe>[]);
  }

  @override
  Future<ServiceResult<List<Cafe>>> searchCafesByName(
    String query, {
    int limit = 20,
    bool includeDeleted = false,
  }) async {
    return ServiceResult.success(data: const <Cafe>[]);
  }

  @override
  Future<ServiceResult<Cafe?>> fetchCafeDetails(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    return ServiceResult.success(data: null);
  }

  @override
  Future<ServiceResult<Cafe?>> fetchCafeById(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    return ServiceResult.success(data: null);
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
    ratingUpdateCalls += 1;
    lastRatingUpdateCafeId = cafeId;
    lastRatingUpdatePlaceId = googlePlaceId;
    return ServiceResult.success(data: null);
  }
}

class _FakePlacesService implements PlacesServiceBase {
  _FakePlacesService(
    this.cafes, {
    this.ratingMetadata = const <String, PlaceRatingMetadata>{},
    this.cafeDetails = const <String, Cafe>{},
  });

  final List<Cafe> cafes;
  final Map<String, PlaceRatingMetadata> ratingMetadata;
  final Map<String, Cafe> cafeDetails;
  int ratingMetadataCalls = 0;
  int cafeDetailsCalls = 0;

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
    cafeDetailsCalls += 1;
    return cafeDetails[placeId];
  }

  @override
  Future<PlaceRatingMetadata?> fetchPlaceRatingMetadata(
    String placeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    ratingMetadataCalls += 1;
    return ratingMetadata[placeId];
  }
}
