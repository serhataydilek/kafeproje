import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/l10n/app_localizations_en.dart';
import 'package:kafeproje/l10n/l10n.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/utils/filter_sort.dart';

import 'test_helpers.dart';

void main() {
  group('filter and sort logic', () {
    test('rating label ignores Google rating when app reviews are missing', () {
      final cafe =
          buildTestCafe(id: '1', name: 'Imported Cafe', rating: 0).copyWith(
        googlePlaceData: () => const GooglePlaceData(
          googleRating: 4.9,
          googleReviewCount: 280,
          usesAppDefaults: true,
        ),
      );

      final label = cafeRatingLabel(AppLocalizationsEn(), cafe);
      expect(label, 'No ratings yet');
    });

    test('rating label ignores manual fallback when app reviews are missing',
        () {
      final cafe =
          buildTestCafe(id: '1', name: 'Manual Only', rating: 0).copyWith(
        reviewCount: 0,
        manualRating: () => 4.8,
        manualRatingCount: () => 42,
      );

      final label = cafeRatingLabel(AppLocalizationsEn(), cafe);
      expect(label, 'No ratings yet');
    });

    test('cheapest sort uses enum price ordering', () {
      final cafes = [
        buildTestCafe(
            id: '1', name: 'Moderate', priceLevel: PriceLevel.moderate),
        buildTestCafe(id: '2', name: 'Cheap', priceLevel: PriceLevel.cheap),
        buildTestCafe(
            id: '3', name: 'Expensive', priceLevel: PriceLevel.expensive),
      ];

      final sorted = sortCafes(cafes, SortOption.cheapest);

      expect(sorted.map((cafe) => cafe.name).toList(), [
        'Cheap',
        'Moderate',
        'Expensive',
      ]);
    });

    test('study sort prefers study-friendly cafes with stronger work signals',
        () {
      final cafes = [
        buildTestCafe(
          id: '1',
          name: 'Balanced Spot',
          studyFriendly: true,
          wifiQuality: WifiQuality.average,
          outletAvailability: OutletAvailability.medium,
          quietnessLevel: QuietnessLevel.balanced,
        ),
        buildTestCafe(
          id: '2',
          name: 'Work Haven',
          studyFriendly: true,
          wifiQuality: WifiQuality.strong,
          outletAvailability: OutletAvailability.high,
          quietnessLevel: QuietnessLevel.quiet,
        ),
        buildTestCafe(
          id: '3',
          name: 'Social Cafe',
          studyFriendly: false,
          wifiQuality: WifiQuality.weak,
          outletAvailability: OutletAvailability.low,
          quietnessLevel: QuietnessLevel.busy,
        ),
      ];

      final sorted = sortCafes(cafes, SortOption.study);

      expect(sorted.first.name, 'Work Haven');
      expect(sorted.last.name, 'Social Cafe');
    });

    test(
        'study sort pushes Google-only placeholder cafes behind community data',
        () {
      final cafes = [
        buildTestCafe(
          id: '1',
          name: 'Imported Cafe',
        ).copyWith(
          googlePlaceData: () => const GooglePlaceData(usesAppDefaults: true),
        ),
        buildTestCafe(
          id: '2',
          name: 'Community Workspace',
          studyFriendly: true,
          wifiQuality: WifiQuality.strong,
          outletAvailability: OutletAvailability.high,
          quietnessLevel: QuietnessLevel.quiet,
        ),
      ];

      final sorted = sortCafes(cafes, SortOption.study);

      expect(sorted.first.name, 'Community Workspace');
      expect(sorted.last.name, 'Imported Cafe');
    });

    test('topRated sort ignores Google imported ratings', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Low', rating: 3.2),
        buildTestCafe(id: '2', name: 'Imported High', rating: 0).copyWith(
          googlePlaceData: () => const GooglePlaceData(
            googleRating: 4.9,
            googleReviewCount: 280,
            usesAppDefaults: true,
          ),
        ),
        buildTestCafe(id: '3', name: 'Mid', rating: 4.0),
      ];

      final sorted = sortCafes(cafes, SortOption.topRated);

      expect(sorted.first.name, 'Mid');
      expect(sorted.last.name, 'Imported High');
    });

    test('topRated sort ignores manual fallback ratings without app reviews',
        () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Community Rated', rating: 4.0),
        buildTestCafe(id: '2', name: 'Manual Fallback', rating: 0).copyWith(
          reviewCount: 0,
          manualRating: () => 4.9,
          manualRatingCount: () => 300,
        ),
      ];

      final sorted = sortCafes(cafes, SortOption.topRated);

      expect(sorted.first.name, 'Community Rated');
      expect(sorted.last.name, 'Manual Fallback');
    });

    test('topRated sort can reuse the original list when inPlace is true', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Low', rating: 3.2),
        buildTestCafe(id: '2', name: 'High', rating: 4.9),
      ];

      final sorted = sortCafes(cafes, SortOption.topRated, null, true);

      expect(identical(sorted, cafes), isTrue);
      expect(cafes.first.name, 'High');
    });

    test('aesthetic sort uses ambiance score', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Plain', ambianceScore: 2.5),
        buildTestCafe(id: '2', name: 'Beautiful', ambianceScore: 4.8),
      ];

      final sorted = sortCafes(cafes, SortOption.aesthetic);

      expect(sorted.first.name, 'Beautiful');
    });

    test('nearest sort falls back to alphabetical without user location', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Zara Cafe'),
        buildTestCafe(id: '2', name: 'Alpha Cafe'),
      ];

      final sorted = sortCafes(cafes, SortOption.nearest);

      expect(sorted.first.name, 'Alpha Cafe');
    });

    test(
      'search applies relevance tiers first, then nearest within the same tier',
      () {
        const userLocation = Coordinates(lat: 41.0000, lng: 29.0000);
        final cafes = [
          buildTestCafe(id: '1', name: 'Latte Point').copyWith(
            coordinates: const Coordinates(lat: 41.0010, lng: 29.0000),
          ),
          buildTestCafe(id: '2', name: 'Latte Lab').copyWith(
            coordinates: const Coordinates(lat: 41.0030, lng: 29.0000),
          ),
          buildTestCafe(id: '3', name: 'Point Latte House').copyWith(
            coordinates: const Coordinates(lat: 41.0002, lng: 29.0000),
          ),
        ];

        final sorted = sortCafes(
          cafes,
          SortOption.nearest,
          userLocation,
          false,
          'latte',
        );

        expect(
          sorted.map((cafe) => cafe.id).toList(growable: false),
          ['1', '2', '3'],
        );
      },
    );

    test(
        'search with topRated keeps explicit sort behavior within relevance tier',
        () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Latte Oak', rating: 4.2),
        buildTestCafe(id: '2', name: 'Latte Beam', rating: 4.9),
        buildTestCafe(id: '3', name: 'Oak Latte House', rating: 5.0),
      ];

      final sorted = sortCafes(
        cafes,
        SortOption.topRated,
        null,
        false,
        'latte',
      );

      expect(
        sorted.map((cafe) => cafe.id).toList(growable: false),
        ['2', '1', '3'],
      );
    });
  });

  group('filtering', () {
    test('no filters returns all cafes', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'A'),
        buildTestCafe(id: '2', name: 'B'),
      ];

      expect(applyFilters(cafes, Filters.empty), hasLength(2));
    });

    test('district filter matches canonical Turkish district values', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Cafe A', district: 'Kadıköy'),
        buildTestCafe(id: '2', name: 'Cafe B', district: 'Besiktas'),
      ];

      final result = applyFilters(
        cafes,
        const Filters(district: 'Kadikoy'),
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'Cafe A');
    });

    test('district filter matches any selected district', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Cafe A', district: 'Kadikoy'),
        buildTestCafe(id: '2', name: 'Cafe B', district: 'Besiktas'),
        buildTestCafe(id: '3', name: 'Cafe C', district: 'Sisli'),
      ];

      final result = applyFilters(
        cafes,
        const Filters(
          selectedDistricts: {'Kadikoy', 'Besiktas'},
        ),
      );

      expect(result.map((cafe) => cafe.id).toList(), ['1', '2']);
    });

    test('active count includes each selected district', () {
      const filters = Filters(
        selectedDistricts: {'Kadikoy', 'Besiktas'},
        minRating: 4,
      );

      expect(filters.activeCount, 3);
    });

    test('openNow filter respects explicit source open state', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Open Cafe').copyWith(
          openNow: true,
          openingHours: const [],
        ),
        buildTestCafe(id: '2', name: 'Closed Cafe').copyWith(
          openNow: false,
          openingHours: const [],
        ),
      ];

      final result = applyFilters(
        cafes,
        const Filters(openNow: true),
      );

      expect(result.map((cafe) => cafe.name).toList(), ['Open Cafe']);
    });

    test('minRating filter excludes low rated cafes', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Good', rating: 4.5),
        buildTestCafe(id: '2', name: 'Bad', rating: 2.5),
      ];

      final result = applyFilters(
        cafes,
        const Filters(minRating: 4.0),
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'Good');
    });

    test('minRating filter ignores Google imported ratings', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Manual', rating: 4.5),
        buildTestCafe(id: '2', name: 'Imported', rating: 0).copyWith(
          googlePlaceData: () => const GooglePlaceData(
            googleRating: 4.7,
            usesAppDefaults: true,
          ),
        ),
      ];

      final result = applyFilters(
        cafes,
        const Filters(minRating: 4.6),
      );

      expect(result, isEmpty);
    });

    test('minRating filter ignores manual fallback without app reviews', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Community', rating: 4.7),
        buildTestCafe(id: '2', name: 'Manual Fallback', rating: 0).copyWith(
          reviewCount: 0,
          manualRating: () => 5,
          manualRatingCount: () => 12,
        ),
      ];

      final result = applyFilters(
        cafes,
        const Filters(minRating: 4.8),
      );

      expect(result, isEmpty);
    });

    test('priceLevel filter matches enum-to-string correctly', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Cheap', priceLevel: PriceLevel.cheap)
            .copyWith(hasPriceLevel: true),
        buildTestCafe(
            id: '2', name: 'Expensive', priceLevel: PriceLevel.expensive),
      ].map((cafe) {
        return cafe.copyWith(hasPriceLevel: true);
      }).toList();

      final result = applyFilters(
        cafes,
        const Filters(priceLevel: PriceLevel.cheap),
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'Cheap');
    });

    test('price filter does not treat missing price as moderate by default',
        () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Missing Price').copyWith(
          hasPriceLevel: false,
          priceLevel: PriceLevel.moderate,
        ),
        buildTestCafe(
          id: '2',
          name: 'Moderate Price',
          priceLevel: PriceLevel.moderate,
        ).copyWith(hasPriceLevel: true),
      ];

      final result = applyFilters(
        cafes,
        const Filters(priceLevel: PriceLevel.moderate),
      );

      expect(result.map((cafe) => cafe.name).toList(), ['Moderate Price']);
    });

    test('wifiQuality filter uses canonical comparison', () {
      final cafes = [
        buildTestCafe(
            id: '1', name: 'Strong Wifi', wifiQuality: WifiQuality.strong),
        buildTestCafe(
            id: '2', name: 'Weak Wifi', wifiQuality: WifiQuality.weak),
      ];

      final result = applyFilters(
        cafes,
        const Filters(wifiQuality: WifiQuality.strong),
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'Strong Wifi');
    });

    test('smokingPolicy filter handles case-insensitive matching', () {
      final cafes = [
        buildTestCafe(
            id: '1', name: 'No Smoke', smokingPolicy: SmokingPolicy.notAllowed),
        buildTestCafe(
            id: '2',
            name: 'Outdoor Smoke',
            smokingPolicy: SmokingPolicy.outdoorOnly),
      ];

      final result = applyFilters(
        cafes,
        const Filters(smokingPolicy: SmokingPolicy.notAllowed),
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'No Smoke');
    });

    test('boolean filters work correctly', () {
      final cafes = [
        buildTestCafe(
            id: '1', name: 'Study', studyFriendly: true, petFriendly: false),
        buildTestCafe(
            id: '2', name: 'Social', studyFriendly: false, petFriendly: true),
      ];

      expect(
        applyFilters(cafes, const Filters(studyFriendly: true)),
        hasLength(1),
      );
      expect(
        applyFilters(cafes, const Filters(petFriendly: true)),
        hasLength(1),
      );
    });

    test('community filters exclude imported Google placeholder values', () {
      final cafes = [
        buildTestCafe(
          id: '1',
          name: 'Imported Cafe',
          studyFriendly: true,
          wifiQuality: WifiQuality.strong,
        ).copyWith(
          googlePlaceData: () => const GooglePlaceData(usesAppDefaults: true),
        ),
        buildTestCafe(
          id: '2',
          name: 'Verified Workspace',
          studyFriendly: true,
          wifiQuality: WifiQuality.strong,
        ),
      ];

      final result = applyFilters(
        cafes,
        const Filters(
          studyFriendly: true,
          wifiQuality: WifiQuality.strong,
        ),
      );

      expect(result.map((cafe) => cafe.name).toList(), ['Verified Workspace']);
    });

    test('search query matches name, district, neighborhood, address, and tags',
        () {
      final cafes = [
        buildTestCafe(
          id: '1',
          name: 'Sunrise Cafe',
          district: 'Kadıköy',
          neighborhood: 'Moda',
          tags: const ['specialty'],
        ).copyWith(address: 'Caferağa, Kadıköy, İstanbul'),
      ];

      expect(applyFilters(cafes, const Filters(searchQuery: 'sunrise')),
          hasLength(1));
      expect(applyFilters(cafes, const Filters(searchQuery: 'kadikoy')),
          hasLength(1));
      expect(applyFilters(cafes, const Filters(searchQuery: 'moda')),
          hasLength(1));
      expect(applyFilters(cafes, const Filters(searchQuery: 'caferaga')),
          hasLength(1));
      expect(applyFilters(cafes, const Filters(searchQuery: 'specialty')),
          hasLength(1));
      expect(applyFilters(cafes, const Filters(searchQuery: 'nonexistent')),
          hasLength(0));
    });

    test('multiple filters combine correctly', () {
      final cafes = [
        buildTestCafe(
          id: '1',
          name: 'Perfect',
          district: 'Kadikoy',
          rating: 4.8,
          studyFriendly: true,
        ),
        buildTestCafe(
          id: '2',
          name: 'Good',
          district: 'Kadikoy',
          rating: 3.5,
          studyFriendly: true,
        ),
        buildTestCafe(
          id: '3',
          name: 'Wrong District',
          district: 'Besiktas',
          rating: 4.8,
          studyFriendly: true,
        ),
      ];

      final result = applyFilters(
        cafes,
        const Filters(
          district: 'Kadikoy',
          minRating: 4.0,
          studyFriendly: true,
        ),
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'Perfect');
    });
  });

  group('searchCafes', () {
    test('empty query returns all cafes', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'A'),
        buildTestCafe(id: '2', name: 'B'),
      ];

      expect(searchCafes(cafes, ''), hasLength(2));
      expect(searchCafes(cafes, '   '), hasLength(2));
    });

    test('search is case-insensitive', () {
      final cafes = [
        buildTestCafe(id: '1', name: 'Sunrise Cafe'),
      ];

      expect(searchCafes(cafes, 'SUNRISE'), hasLength(1));
      expect(searchCafes(cafes, 'sunrise'), hasLength(1));
    });
  });
}
