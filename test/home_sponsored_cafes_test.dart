import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/cafe_cache.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'package:kafeproje/screens/compare_screen.dart';
import 'package:kafeproje/screens/explore_screen.dart';
import 'package:kafeproje/screens/favorites_screen.dart';
import 'package:kafeproje/screens/home_screen.dart';
import 'package:kafeproje/theme/app_theme.dart';
import 'package:kafeproje/utils/cafe_media.dart';
import 'package:kafeproje/widgets/cafes/cafe_image_carousel.dart';
import 'package:kafeproje/widgets/ui/shimmer_loading.dart';

import 'test_helpers.dart';

void main() {
  group('home sponsored cafes', () {
    test('filters active sponsored cafes and orders by priority', () {
      final activeFuture = DateTime.utc(2035, 1, 1);
      final expiredPast = DateTime.utc(2020, 1, 1);
      final cafes = [
        _sponsoredCafe(
          id: 'low',
          name: 'Low Priority',
          priority: 1,
          until: activeFuture,
        ),
        _sponsoredCafe(
          id: 'expired',
          name: 'Expired Sponsor',
          priority: 100,
          until: expiredPast,
        ),
        _sponsoredCafe(
          id: 'hidden',
          name: 'Hidden Sponsor',
          priority: 90,
          until: activeFuture,
          approvalStatus: 'pending',
        ),
        _sponsoredCafe(
          id: 'deleted',
          name: 'Deleted Sponsor',
          priority: 80,
          until: activeFuture,
          isDeleted: true,
        ),
        _sponsoredCafe(
          id: 'tie-a',
          name: 'Alpha Sponsor',
          priority: 5,
          rating: 4.8,
          until: activeFuture,
        ),
        _sponsoredCafe(
          id: 'tie-b',
          name: 'Beta Sponsor',
          priority: 5,
          rating: 4.6,
          until: activeFuture,
        ),
        buildTestCafe(id: 'organic', name: 'Organic Cafe'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes.where((cafe) => !cafe.isActiveFeatured).toList(),
          featuredCafes: cafes.where((cafe) => cafe.isActiveFeatured).toList(),
        ),
      );
      addTearDown(container.dispose);

      final sponsored = container.read(homeSponsoredCafesProvider);

      expect(
        sponsored.map((cafe) => cafe.id),
        ['low', 'tie-a', 'tie-b', 'expired'],
      );
    });

    test('sponsored projection does not depend on favorite hydration',
        () async {
      final sponsor = _sponsoredCafe(
        id: 'favorite-proof-sponsor',
        name: 'Favorite Proof Sponsor',
        priority: 10,
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          featuredCafes: [sponsor],
          favorites: const [],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      expect(
        container.read(homeSponsoredCafesProvider).single.favoriteCount,
        0,
      );

      await container
          .read(profileProvider.notifier)
          .toggleFavorite('favorite-proof-sponsor');

      final sponsored = container.read(homeSponsoredCafesProvider);
      expect(sponsored.map((cafe) => cafe.id), ['favorite-proof-sponsor']);
      expect(sponsored.single.favoriteCount, 0);
    });

    test('sponsored projection preserves image urls', () {
      final sponsor = _sponsoredCafe(
        id: 'image-preserve-sponsor',
        name: 'Image Preserve Sponsor',
        priority: 10,
      ).copyWith(images: const ['https://example.com/preserve.jpg']);
      final container = createTestContainer(
        state: buildTestAppShellState(featuredCafes: [sponsor]),
      );
      addTearDown(container.dispose);

      final sponsored = container.read(homeSponsoredCafesProvider);
      expect(sponsored.single.photoUrls, ['https://example.com/preserve.jpg']);
    });

    test('hydrates featured images from cached cafe place id', () {
      final featured = _sponsoredCafe(
        id: 'featured-hydrate-1',
        name: 'Featured Hydrate',
        priority: 5,
      ).copyWith(placeId: 'place-hydrate-1', images: const <String>[]);
      final cached = buildTestCafe(
        id: 'cached-1',
        name: 'Cached Cafe',
        images: const ['https://example.com/hydrated.jpg'],
      ).copyWith(placeId: 'place-hydrate-1');

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cached],
          homeCafes: [cached],
          featuredCafes: [featured],
        ),
      );
      addTearDown(container.dispose);

      final sponsored = container.read(homeSponsoredCafesProvider);
      expect(sponsored.single.photoUrls, ['https://example.com/hydrated.jpg']);
    });

    test('featured prefers cached working photos over stale generated photos',
        () {
      clearRememberedFailedCafeImageUrls();
      final featured = _sponsoredCafe(
        id: 'featured-stale-photo',
        name: 'Featured Stale Photo',
        priority: 5,
      ).copyWith(
        placeId: 'place-stale-photo',
        images: const ['places/place-stale-photo/photos/stale-resource'],
      );
      final staleUrl = resolveCafeImageUrl(featured.photoUrls.first);
      rememberFailedCafeImageUrl(staleUrl);
      final cached = buildTestCafe(
        id: 'cached-working-photo',
        name: 'Cached Working Photo',
        images: const ['Aap_uE1b2c3d4e5f6g7h8i9j0k'],
      ).copyWith(placeId: 'place-stale-photo');

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cached],
          homeCafes: [cached],
          featuredCafes: [featured],
        ),
      );
      addTearDown(() {
        clearRememberedFailedCafeImageUrls();
        container.dispose();
      });

      final sponsored = container.read(homeSponsoredCafesProvider);
      expect(sponsored.single.photoUrls, hasLength(1));
      expect(sponsored.single.photoUrls.first, contains('maps.googleapis.com'));
      expect(sponsored.single.photoUrls.first, contains('photoreference='));
    });

    test(
        'featured with only generated places media prefers matching cached photo urls',
        () {
      clearRememberedFailedCafeImageUrls();
      final featured = _sponsoredCafe(
        id: 'featured-generated-only',
        name: 'Featured Generated Only',
        priority: 5,
      ).copyWith(
        placeId: 'place-generated-only',
        images: const ['places/place-generated-only/photos/generated-resource'],
      );
      final cached = buildTestCafe(
        id: 'cached-direct-photo',
        name: 'Cached Direct Photo',
        images: const ['https://example.com/cached-direct.jpg'],
      ).copyWith(placeId: 'place-generated-only');

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cached],
          homeCafes: [cached],
          featuredCafes: [featured],
        ),
      );
      addTearDown(() {
        clearRememberedFailedCafeImageUrls();
        container.dispose();
      });

      final sponsored = container.read(homeSponsoredCafesProvider).single;
      expect(sponsored.photoUrls, ['https://example.com/cached-direct.jpg']);
      expect(sponsored.isFeatured, isTrue);
      expect(sponsored.featuredPriority, 5);
    });

    test(
        'featured Supabase UUID hydrates from cache google place id when ids differ',
        () {
      final featuredUntil = DateTime.utc(2035, 1, 1);
      final featured = _sponsoredCafe(
        id: 'b78363df-20c4-408d-83f3-b07b86511a27',
        name: 'Featured UUID Sponsor',
        priority: 17,
        until: featuredUntil,
        label: 'Partner',
      ).copyWith(
        placeId: 'ChIJ-featured-cache-match',
        images: const [
          'https://places.googleapis.com/v1/places/ChIJ-featured-cache-match/photos/stale/media?maxWidthPx=1280',
        ],
      );
      final cached = buildTestCafe(
        id: 'normal-row-different-id',
        name: 'Featured UUID Sponsor',
        images: const ['https://example.com/cache-working.jpg'],
      ).copyWith(
        googlePlaceData: () => const GooglePlaceData(
          googlePlaceId: 'ChIJ-featured-cache-match',
        ),
      );

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cached],
          homeCafes: [cached],
          featuredCafes: [featured],
        ),
      );
      addTearDown(container.dispose);

      final sponsored = container.read(homeSponsoredCafesProvider).single;
      expect(sponsored.id, 'b78363df-20c4-408d-83f3-b07b86511a27');
      expect(sponsored.placeId, 'ChIJ-featured-cache-match');
      expect(sponsored.photoUrls, ['https://example.com/cache-working.jpg']);
      expect(
          isGeneratedPlacesMediaImageUrl(sponsored.photoUrls.first), isFalse);
      expect(sponsored.isFeatured, isTrue);
      expect(sponsored.featuredPriority, 17);
      expect(sponsored.featuredLabel, 'Partner');
      expect(sponsored.featuredUntil, featuredUntil);
    });

    test('cached non-generated images outrank generated cache candidates', () {
      final featured = _sponsoredCafe(
        id: 'featured-cache-precedence',
        name: 'Featured Cache Precedence',
        priority: 5,
      ).copyWith(
        placeId: 'ChIJ-cache-precedence',
        images: const [
          'https://places.googleapis.com/v1/places/ChIJ-cache-precedence/photos/featured-generated/media?maxWidthPx=1280',
        ],
      );
      final generatedCache = buildTestCafe(
        id: 'ChIJ-cache-precedence',
        name: 'Generated Cache',
        images: const [
          'https://places.googleapis.com/v1/places/ChIJ-cache-precedence/photos/cache-generated-a/media?maxWidthPx=1280',
          'https://places.googleapis.com/v1/places/ChIJ-cache-precedence/photos/cache-generated-b/media?maxWidthPx=1280',
        ],
      );
      final directCache = buildTestCafe(
        id: 'direct-cache-row',
        name: 'Direct Cache',
        images: const ['https://example.com/direct-cache.jpg'],
      ).copyWith(
        googlePlaceData: () => const GooglePlaceData(
          googlePlaceId: 'ChIJ-cache-precedence',
        ),
      );

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [generatedCache],
          homeCafes: [directCache],
          featuredCafes: [featured],
        ),
      );
      addTearDown(container.dispose);

      final sponsored = container.read(homeSponsoredCafesProvider).single;
      expect(sponsored.photoUrls, ['https://example.com/direct-cache.jpg']);
      expect(
          isGeneratedPlacesMediaImageUrl(sponsored.photoUrls.first), isFalse);
    });

    test(
        'featured hydrates from cache by normalized name and location when ids do not match',
        () {
      final featured = _sponsoredCafe(
        id: '1ffceb66-2a64-4a05-a9a4-fdc4b549ab02',
        name: '7K coffee workshop (Specialty coffee)',
        priority: 8,
      ).copyWith(
        placeId: 'ChIJ-featured-place-only',
        district: 'Besiktas',
        neighborhood: 'Akaretler',
        images: const [
          'https://places.googleapis.com/v1/places/ChIJ-featured-place-only/photos/generated/media?maxWidthPx=1280',
        ],
      );
      final cached = buildTestCafe(
        id: 'normal-cache-row',
        name: '7K coffee workshop (Specialty coffee)',
        district: 'Besiktas',
        neighborhood: 'Akaretler',
        images: const ['https://example.com/name-location-cache.jpg'],
      ).copyWith(placeId: 'ChIJ-different-cache-place');

      final container = createTestContainer(
        state: buildTestAppShellState(
          homeCafes: [cached],
          featuredCafes: [featured],
        ),
      );
      addTearDown(container.dispose);

      final sponsored = container.read(homeSponsoredCafesProvider).single;
      expect(sponsored.id, '1ffceb66-2a64-4a05-a9a4-fdc4b549ab02');
      expect(sponsored.placeId, 'ChIJ-featured-place-only');
      expect(
          sponsored.photoUrls, ['https://example.com/name-location-cache.jpg']);
      expect(
          isGeneratedPlacesMediaImageUrl(sponsored.photoUrls.first), isFalse);
      expect(sponsored.isFeatured, isTrue);
      expect(sponsored.featuredPriority, 8);
    });

    test('featured with only generated places media renders no image candidate',
        () {
      clearRememberedFailedCafeImageUrls();
      final featured = _sponsoredCafe(
        id: 'featured-generated-no-cache',
        name: 'Featured Generated No Cache',
        priority: 5,
      ).copyWith(
        placeId: 'place-generated-no-cache',
        images: const [
          'places/place-generated-no-cache/photos/generated-resource',
        ],
      );

      final container = createTestContainer(
        state: buildTestAppShellState(featuredCafes: [featured]),
      );
      addTearDown(() {
        clearRememberedFailedCafeImageUrls();
        container.dispose();
      });

      final sponsored = container.read(homeSponsoredCafesProvider).single;
      expect(sponsored.photoUrls, isEmpty);
      expect(sponsored.isFeatured, isTrue);
      expect(sponsored.featuredPriority, 5);
    });

    test(
        'featured with generated-only images refreshes from Google place details',
        () async {
      var refreshCalls = 0;
      final featuredUntil = DateTime.utc(2036, 1, 1);
      const staleUrl =
          'https://places.googleapis.com/v1/places/ChIJ-refresh/photos/stale/media?maxWidthPx=1280';
      const freshUrl =
          'https://places.googleapis.com/v1/places/ChIJ-refresh/photos/fresh/media?maxWidthPx=1280';
      final featured = _sponsoredCafe(
        id: 'featured-refresh-id',
        name: 'Featured Refresh',
        priority: 11,
        until: featuredUntil,
        label: 'Sponsored',
      ).copyWith(
        placeId: 'ChIJ-refresh',
        images: [staleUrl],
      );
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchFeaturedCafes: () async => [featured],
        onHydrateFeaturedGoogleRatingMetadata: (cafes) async {
          refreshCalls += 1;
          final cafe = cafes.single;
          return [
            cafe.copyWith(
              images: [freshUrl],
              googlePlaceData: () => const GooglePlaceData(
                googlePlaceId: 'ChIJ-refresh',
                sourceTypes: ['featured_image_refresh'],
                usesAppDefaults: true,
              ),
            ),
          ];
        },
      );
      final container = createTestContainer(
        state: buildTestAppShellState(),
        overrides: [cafeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).ensureFeaturedCafesLoaded();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final sponsored = container.read(homeSponsoredCafesProvider).single;
      expect(refreshCalls, 1);
      expect(sponsored.id, 'featured-refresh-id');
      expect(sponsored.placeId, 'ChIJ-refresh');
      expect(sponsored.photoUrls, [freshUrl]);
      expect(sponsored.photoUrls, isNot(contains(staleUrl)));
      expect(sponsored.isFeatured, isTrue);
      expect(sponsored.featuredPriority, 11);
      expect(sponsored.featuredLabel, 'Sponsored');
      expect(sponsored.featuredUntil, featuredUntil);
    });

    test('featured image refresh failure falls back without repeated fetch',
        () async {
      var refreshCalls = 0;
      final featured = _sponsoredCafe(
        id: 'featured-refresh-fail',
        name: 'Featured Refresh Fail',
        priority: 7,
      ).copyWith(
        placeId: 'ChIJ-refresh-fail',
        images: const [
          'https://places.googleapis.com/v1/places/ChIJ-refresh-fail/photos/stale/media?maxWidthPx=1280',
        ],
      );
      final repository = FakeCafeRepository(
        onFetch: (_) async =>
            const CafeRepositoryResult(cafes: [], usedRemote: false),
        onFetchFeaturedCafes: () async => [featured],
        onHydrateFeaturedGoogleRatingMetadata: (cafes) async {
          refreshCalls += 1;
          return const <Cafe>[];
        },
      );
      final container = createTestContainer(
        state: buildTestAppShellState(),
        overrides: [cafeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).ensureFeaturedCafesLoaded();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await container.read(cafeProvider.notifier).ensureFeaturedCafesLoaded();

      final sponsored = container.read(homeSponsoredCafesProvider).single;
      expect(refreshCalls, 1);
      expect(sponsored.photoUrls, isEmpty);
      expect(sponsored.isFeatured, isTrue);
      expect(sponsored.featuredPriority, 7);
    });

    test('hydration preserves featured metadata', () {
      final featuredUntil = DateTime.utc(2032, 5, 1);
      final featured = _sponsoredCafe(
        id: 'featured-meta-1',
        name: 'Featured Meta',
        priority: 22,
        until: featuredUntil,
        label: 'Featured Label',
      ).copyWith(placeId: 'place-meta-1', images: const <String>[]);
      final cached = buildTestCafe(
        id: 'cached-meta',
        name: 'Cached Meta',
        images: const ['https://example.com/meta.jpg'],
      ).copyWith(placeId: 'place-meta-1');

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cached],
          homeCafes: [cached],
          featuredCafes: [featured],
        ),
      );
      addTearDown(container.dispose);

      final sponsored = container.read(homeSponsoredCafesProvider).single;
      expect(sponsored.isFeatured, isTrue);
      expect(sponsored.featuredPriority, 22);
      expect(sponsored.featuredLabel, 'Featured Label');
      expect(sponsored.featuredUntil, featuredUntil);
    });

    testWidgets('featured card renders hydrated image', (tester) async {
      final featured = _sponsoredCafe(
        id: 'featured-card-1',
        name: 'Featured Card',
        priority: 9,
      ).copyWith(placeId: 'place-card-1', images: const <String>[]);
      final cached = buildTestCafe(
        id: 'cached-card',
        name: 'Cached Card',
        images: const ['https://example.com/card.jpg'],
      ).copyWith(placeId: 'place-card-1');

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cached],
          homeCafes: [cached],
          featuredCafes: [featured],
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      final carousel = tester.widget<CafeImageCarousel>(
        find.byKey(
          const ValueKey('cafe-card-gallery-home-sponsored-featured-card-1'),
        ),
      );
      expect(carousel.imageUrls, ['https://example.com/card.jpg']);
    });

    testWidgets('placeholder appears when no image exists anywhere',
        (tester) async {
      final featured = _sponsoredCafe(
        id: 'featured-empty-1',
        name: 'Featured Empty',
        priority: 12,
      ).copyWith(placeId: 'place-empty-1', images: const <String>[]);

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          homeCafes: const [],
          featuredCafes: [featured],
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      final carousel = tester.widget<CafeImageCarousel>(
        find.byKey(
          const ValueKey('cafe-card-gallery-home-sponsored-featured-empty-1'),
        ),
      );
      expect(carousel.imageUrls, isEmpty);
    });

    testWidgets('hides the sponsored section when no active sponsors exist',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'organic', name: 'Organic Cafe')],
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Sponsored cafes'), findsNothing);
      expect(find.text('Sponsored'), findsNothing);
      expect(find.byKey(const Key('home-sponsored-organic')), findsNothing);
    });

    testWidgets('shows sponsored section with custom and fallback badges',
        (tester) async {
      final cafes = [
        _sponsoredCafe(
          id: 'partner',
          name: 'Partner Cafe',
          priority: 20,
          label: 'Partner Pick',
        ),
        _sponsoredCafe(
          id: 'fallback',
          name: 'Fallback Cafe',
          priority: 10,
        ),
        buildTestCafe(id: 'organic', name: 'Organic Cafe'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes.where((cafe) => !cafe.isActiveFeatured).toList(),
          featuredCafes: cafes.where((cafe) => cafe.isActiveFeatured).toList(),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Sponsored cafes'), findsOneWidget);
      expect(find.byKey(const Key('home-sponsored-partner')), findsOneWidget);
      expect(find.byKey(const Key('home-sponsored-fallback')), findsOneWidget);
      expect(find.text('Partner Pick'), findsOneWidget);
      expect(find.text('Sponsored'), findsOneWidget);
      expect(
        find.byKey(const Key('cafe-card-sponsored-badge-partner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cafe-card-sponsored-badge-fallback')),
        findsOneWidget,
      );
    });

    testWidgets('sponsored card does not show Google rating on Home card',
        (tester) async {
      final sponsor = _sponsoredCafe(
        id: 'google-rated-sponsor',
        name: 'Google Rated Sponsor',
        priority: 1,
      ).copyWith(
        placeId: 'place-google-rated-sponsor',
        googlePlaceData: () => const GooglePlaceData(
          googlePlaceId: 'place-google-rated-sponsor',
          googleRating: 4.9,
          googleReviewCount: 321,
        ),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(featuredCafes: [sponsor]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('home-sponsored-google-rated-sponsor')),
          findsOneWidget);
      expect(find.text('4.9 (321)'), findsNothing);
      expect(find.text('4.9'), findsNothing);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('sponsored card hides rating instead of showing fake zero',
        (tester) async {
      final sponsor = _sponsoredCafe(
        id: 'unrated-sponsor',
        name: 'Unrated Sponsor',
        priority: 1,
        rating: 0,
      ).copyWith(
        placeId: 'place-unrated-sponsor',
        googlePlaceData: () => const GooglePlaceData(
          googlePlaceId: 'place-unrated-sponsor',
        ),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(featuredCafes: [sponsor]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('home-sponsored-unrated-sponsor')),
          findsOneWidget);
      expect(find.text('0.0'), findsNothing);
      expect(find.text('No ratings yet'), findsNothing);
    });

    testWidgets('sponsored card uses description and address fallback text',
        (tester) async {
      final described = _sponsoredCafe(
        id: 'described',
        name: 'Described Cafe',
        priority: 1,
      ).copyWith(description: 'Curated workspace with strong coffee.');
      final fallback = _sponsoredCafe(
        id: 'fallback-summary',
        name: 'Fallback Summary Cafe',
        priority: 2,
      ).copyWith(description: '', address: 'Moda, Kadikoy');
      final container = createTestContainer(
        state: buildTestAppShellState(
          featuredCafes: [described, fallback],
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(
          find.text('Curated workspace with strong coffee.'), findsOneWidget);
      expect(find.text('Moda, Kadikoy'), findsWidgets);
    });

    testWidgets('featured card renders image when photo url exists',
        (tester) async {
      final sponsor = _sponsoredCafe(
        id: 'image-sponsor',
        name: 'Image Sponsor',
        priority: 1,
      ).copyWith(images: const ['https://example.com/featured.jpg']);
      final container = createTestContainer(
        state: buildTestAppShellState(featuredCafes: [sponsor]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      final carousel = tester.widget<CafeImageCarousel>(
        find.byKey(
          const ValueKey('cafe-card-gallery-home-sponsored-image-sponsor'),
        ),
      );
      expect(carousel.imageUrls, ['https://example.com/featured.jpg']);
      expect(find.text('No photos available yet'), findsNothing);
    });

    testWidgets('sponsored carousel shows fallback when image load fails',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(
            body: CafeImageCarousel(
              key: ValueKey('sponsored-error-carousel'),
              imageUrls: ['https://example.com/missing-featured.jpg'],
              imageProviders: [_FailingImageProvider()],
              height: 160,
              colors: lightColors,
              borderRadius: BorderRadius.zero,
              traceTag: 'home-sponsored:image-error-sponsor',
              diagnosticCafeId: 'image-error-sponsor',
              diagnosticCafeName: 'Image Error Sponsor',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const ValueKey('sponsored-error-carousel')),
        findsOneWidget,
      );
      expect(find.text('No photos available yet'), findsOneWidget);
    });

    testWidgets('sponsored carousel tries next candidate after first fails',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(
            body: CafeImageCarousel(
              key: ValueKey('sponsored-next-candidate-carousel'),
              imageUrls: [
                'https://example.com/missing-featured.jpg',
                'https://example.com/working-featured.jpg',
              ],
              imageProviders: [
                _FailingImageProvider(),
                _PendingImageProvider(),
              ],
              height: 160,
              colors: lightColors,
              borderRadius: BorderRadius.zero,
              traceTag: 'home-sponsored:image-next-candidate-sponsor',
              diagnosticCafeId: 'image-next-candidate-sponsor',
              diagnosticCafeName: 'Image Next Candidate Sponsor',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('sponsored-next-candidate-carousel')),
        findsOneWidget,
      );
      expect(find.text('No data'), findsNothing);
      expect(find.text('No photos available yet'), findsNothing);
    });

    testWidgets('featured card renders placeholder when photo url missing',
        (tester) async {
      final sponsor = _sponsoredCafe(
        id: 'missing-image-sponsor',
        name: 'Missing Image Sponsor',
        priority: 1,
      ).copyWith(images: const []);
      final container = createTestContainer(
        state: buildTestAppShellState(featuredCafes: [sponsor]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No photos available yet'), findsOneWidget);
    });

    testWidgets('sponsored badge renders alongside image carousel',
        (tester) async {
      final sponsor = _sponsoredCafe(
        id: 'badge-image-sponsor',
        name: 'Badge Image Sponsor',
        priority: 1,
        label: 'Sponsored',
      ).copyWith(images: const ['https://example.com/sponsored.jpg']);
      final container = createTestContainer(
        state: buildTestAppShellState(featuredCafes: [sponsor]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'cafe-card-gallery-home-sponsored-badge-image-sponsor',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('cafe-card-sponsored-badge-badge-image-sponsor'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'renders sponsored section even while normal home cafes are still loading',
        (tester) async {
      final sponsor = _sponsoredCafe(
        id: 'loading-sponsor',
        name: 'Loading Sponsor',
        priority: 30,
      );
      final repository = FakeCafeRepository(
        onFetch: (_) async => const CafeRepositoryResult(
          cafes: <Cafe>[],
          usedRemote: true,
        ),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) async =>
            const CafeRepositoryResult(
          cafes: <Cafe>[],
          usedRemote: true,
        ),
        onFetchFeaturedCafes: () async => [sponsor],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          homeCafes: const [],
          featuredCafes: [sponsor],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.read(cafeProvider.notifier).state =
          container.read(cafeProvider).copyWith(
                isHomeCafesLoading: true,
              );

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sponsored cafes'), findsOneWidget);
      expect(
        find.byKey(const Key('home-sponsored-loading-sponsor')),
        findsOneWidget,
      );
      expect(find.byType(ShimmerCafeList), findsNothing);
    });

    testWidgets(
        'Home first render uses cached cafes without immediate Places discovery',
        (tester) async {
      final cachedCafe = buildTestCafe(
        id: 'cached-first-paint',
        name: 'Cached First Paint',
      );
      var discoveryFetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async {
          discoveryFetchCount += 1;
          return const CafeRepositoryResult(
            cafes: <Cafe>[],
            usedRemote: true,
          );
        },
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) async {
          discoveryFetchCount += 1;
          return const CafeRepositoryResult(
            cafes: <Cafe>[],
            usedRemote: true,
          );
        },
        onLoadCachedCafeList: (cacheKey) async => CafeListCacheSnapshot(
          cafes: [cachedCafe],
          cacheKey: cacheKey,
          metadata: CafeCacheMetadata(
            lastUpdated: DateTime.now().toUtc().subtract(
                  const Duration(days: 2),
                ),
            source: CafeCacheDataSource.localCache,
          ),
        ),
        onFetchFeaturedCafes: () async => const <Cafe>[],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          homeCafes: const [],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(discoveryFetchCount, 0);
      expect(container.read(homeCafesProvider).map((cafe) => cafe.id),
          ['cached-first-paint']);
    });

    test('does not reorder Explore, Map, or Compare providers by sponsorship',
        () {
      final cafes = [
        buildTestCafe(id: 'a', name: 'Organic First'),
        _sponsoredCafe(
          id: 'b',
          name: 'Sponsored Second',
          priority: 100,
        ),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: cafes,
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
          compareList: const ['a', 'b'],
        ),
      );
      addTearDown(container.dispose);

      expect(
        container.read(exploreCafeResultsProvider).map((cafe) => cafe.id),
        ['a', 'b'],
      );
      expect(
        container.read(mapCafeResultsProvider).map((cafe) => cafe.id),
        ['a', 'b'],
      );
      expect(
        container.read(comparedCafesProvider).map((cafe) => cafe.id),
        ['a', 'b'],
      );
    });

    test('keeps sponsored cafes independent from map radius discovery',
        () async {
      final nearby = buildTestCafe(
        id: 'nearby',
        name: 'Nearby Cafe',
      ).copyWith(coordinates: const Coordinates(lat: 41.0, lng: 29.0));
      final farSponsor = _sponsoredCafe(
        id: 'far-sponsored',
        name: 'Far Sponsored',
        priority: 90,
      ).copyWith(coordinates: const Coordinates(lat: 41.2, lng: 29.2));
      var fetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async => CafeRepositoryResult(
          cafes: [nearby],
          usedRemote: true,
        ),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) async {
          fetchCount += 1;
          return CafeRepositoryResult(
            cafes: [nearby],
            usedRemote: true,
          );
        },
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [nearby],
          featuredCafes: [farSponsor],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
          mapRadiusPreset: MapRadiusPreset.small,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
          ['far-sponsored']);
      expect(container.read(mapCafeResultsProvider).map((cafe) => cafe.id),
          ['nearby']);

      await container
          .read(cafeProvider.notifier)
          .setMapRadiusPreset(MapRadiusPreset.medium);
      await container
          .read(cafeProvider.notifier)
          .setMapRadiusPreset(MapRadiusPreset.large);
      await container
          .read(cafeProvider.notifier)
          .setMapRadiusPreset(MapRadiusPreset.small);

      expect(fetchCount, 2);
      expect(container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
          ['far-sponsored']);
      expect(container.read(mapCafeResultsProvider).map((cafe) => cafe.id),
          ['nearby']);
      expect(container.read(exploreCafeResultsProvider).map((cafe) => cafe.id),
          ['nearby']);
    });

    testWidgets(
        'renders fetched sponsored cafes outside the active visible corpus',
        (tester) async {
      final nearby = buildTestCafe(
        id: 'nearby',
        name: 'Nearby Cafe',
      ).copyWith(coordinates: const Coordinates(lat: 41.0, lng: 29.0));
      final farSponsor = _sponsoredCafe(
        id: 'far-sponsored',
        name: 'Far Sponsored',
        priority: 40,
      ).copyWith(coordinates: const Coordinates(lat: 42.5, lng: 30.5));
      final repository = FakeCafeRepository(
        onFetch: (_) async => CafeRepositoryResult(
          cafes: [nearby],
          usedRemote: true,
        ),
        onFetchFeaturedCafes: () async => [farSponsor],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [nearby],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
          mapRadiusPreset: MapRadiusPreset.small,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
          ['far-sponsored']);
      expect(find.byKey(const Key('home-sponsored-far-sponsored')),
          findsOneWidget);
      expect(container.read(mapCafeResultsProvider).map((cafe) => cafe.id),
          ['nearby']);
      expect(container.read(exploreCafeResultsProvider).map((cafe) => cafe.id),
          ['nearby']);
    });

    testWidgets(
        'renders fetched sponsored cafes while discovery is still empty',
        (tester) async {
      final discovery = Completer<CafeRepositoryResult>();
      var discoveryStarted = false;
      final farSponsor = _sponsoredCafe(
        id: 'loading-sponsored',
        name: 'Loading Sponsored',
        priority: 60,
      ).copyWith(coordinates: const Coordinates(lat: 42.5, lng: 30.5));
      final repository = FakeCafeRepository(
        onFetch: (_) {
          discoveryStarted = true;
          return discovery.future;
        },
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) {
          discoveryStarted = true;
          return discovery.future;
        },
        onFetchFeaturedCafes: () async => [farSponsor],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
          hasInitializedDiscovery: false,
          mapRadiusPreset: MapRadiusPreset.small,
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(discoveryStarted, isFalse);
      expect(container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
          ['loading-sponsored']);
      expect(find.byKey(const Key('home-sponsored-loading-sponsored')),
          findsOneWidget);
      expect(container.read(mapCafeResultsProvider), isEmpty);
      expect(container.read(exploreCafeResultsProvider), isEmpty);

      discovery.complete(
        const CafeRepositoryResult(cafes: [], usedRemote: true),
      );
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Favorites -> Home navigation does not duplicate top home cafe when cache identity drifts',
        (tester) async {
      final topGoogle = buildTestCafe(
        id: 'ChITopCafe',
        name: 'Top Cafe',
      ).copyWith(placeId: 'ChITopCafe');
      final topLegacy = buildTestCafe(
        id: 'legacy-top-cafe',
        name: 'Top Cafe',
      );
      final secondCafe = buildTestCafe(
        id: 'second-cafe',
        name: 'Second Cafe',
      );

      final repository = FakeCafeRepository(
        onFetch: (_) async => CafeRepositoryResult(
          cafes: [topGoogle, secondCafe],
          usedRemote: true,
        ),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) async {
          return const CafeRepositoryResult.failure(
            errorMessage: 'simulated transient discovery failure',
          );
        },
        onLoadCachedCafeList: (cacheKey) async => CafeListCacheSnapshot(
          cafes: [topLegacy],
          cacheKey: cacheKey,
          metadata: CafeCacheMetadata(
            lastUpdated: DateTime.now().toUtc(),
            source: CafeCacheDataSource.localCache,
          ),
        ),
        onFetchFeaturedCafes: () async => const <Cafe>[],
      );

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [topGoogle, secondCafe],
          homeCafes: [topGoogle, secondCafe],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const FavoritesScreen()),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      final topCafeCount = container
          .read(homeCafesProvider)
          .where((cafe) => cafe.name == 'Top Cafe')
          .length;

      expect(topCafeCount, 1);
    });

    testWidgets(
        'cold start retries non-terminal empty featured probe and keeps sponsored visible across Favorites -> Home churn',
        (tester) async {
      final organic = buildTestCafe(
        id: 'organic',
        name: 'Organic Cafe',
      );
      final sponsor = _sponsoredCafe(
        id: 'sponsor-retry',
        name: 'Sponsor Retry',
        priority: 77,
      );

      var featuredFetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async => CafeRepositoryResult(
          cafes: [organic],
          usedRemote: true,
        ),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) async {
          return CafeRepositoryResult(
            cafes: [organic],
            usedRemote: true,
          );
        },
        onFetchFeaturedCafes: () async {
          featuredFetchCount += 1;
          if (featuredFetchCount == 1) {
            return const <Cafe>[];
          }
          return <Cafe>[sponsor];
        },
      );

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          homeCafes: const [],
          featuredCafes: const [],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(featuredFetchCount, 2);
      expect(find.byKey(const Key('home-sponsored-sponsor-retry')),
          findsOneWidget);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const FavoritesScreen()),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(featuredFetchCount, 2);
      expect(find.byKey(const Key('home-sponsored-sponsor-retry')),
          findsOneWidget);
      expect(
        container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
        contains('sponsor-retry'),
      );
    });

    testWidgets(
        'sponsored load distinguishes transient featured fetch failure from successful empty result',
        (tester) async {
      final organic = buildTestCafe(
        id: 'organic-transient',
        name: 'Organic Transient',
      );
      final sponsor = _sponsoredCafe(
        id: 'sponsor-after-error',
        name: 'Sponsor After Error',
        priority: 60,
      );

      var featuredFetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async => CafeRepositoryResult(
          cafes: [organic],
          usedRemote: true,
        ),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) async {
          return CafeRepositoryResult(
            cafes: [organic],
            usedRemote: true,
          );
        },
        onFetchFeaturedCafes: () async {
          featuredFetchCount += 1;
          if (featuredFetchCount == 1) {
            throw Exception('simulated transient featured failure');
          }
          return <Cafe>[sponsor];
        },
      );

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          homeCafes: const [],
          featuredCafes: const [],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(featuredFetchCount, greaterThanOrEqualTo(2));
      expect(
        find.byKey(const Key('home-sponsored-sponsor-after-error')),
        findsOneWidget,
      );
      expect(
        container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
        contains('sponsor-after-error'),
      );
    });

    testWidgets(
        'successful empty featured result does not create endless retry loop',
        (tester) async {
      final organic = buildTestCafe(
        id: 'organic-empty',
        name: 'Organic Empty',
      );

      var featuredFetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async => CafeRepositoryResult(
          cafes: [organic],
          usedRemote: true,
        ),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) async {
          return CafeRepositoryResult(
            cafes: [organic],
            usedRemote: true,
          );
        },
        onFetchFeaturedCafes: () async {
          featuredFetchCount += 1;
          return const <Cafe>[];
        },
      );

      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          homeCafes: const [],
          featuredCafes: const [],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      final fetchCountAfterSettle = featuredFetchCount;
      expect(fetchCountAfterSettle, 2);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildTestApp(container: container, child: const FavoritesScreen()),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(featuredFetchCount, fetchCountAfterSettle);
      expect(
          find.byKey(const Key('home-sponsored-organic-empty')), findsNothing);
      expect(container.read(homeSponsoredCafesProvider), isEmpty);
    });

    test('empty force refresh cannot overwrite already loaded sponsored cafes',
        () async {
      final sponsor = _sponsoredCafe(
        id: 'fresh-sponsored',
        name: 'Fresh Sponsored',
        priority: 20,
      );
      var featuredFetchCount = 0;
      final repository = FakeCafeRepository(
        onFetch: (_) async => const CafeRepositoryResult(
          cafes: <Cafe>[],
          usedRemote: false,
        ),
        onFetchFeaturedCafes: () async {
          featuredFetchCount += 1;
          return featuredFetchCount == 1 ? [sponsor] : const <Cafe>[];
        },
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          featuredCafes: const [],
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(cafeProvider.notifier)
          .ensureFeaturedCafesLoaded(forceRemote: true);
      expect(
        container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
        ['fresh-sponsored'],
      );

      await container
          .read(cafeProvider.notifier)
          .ensureFeaturedCafesLoaded(forceRemote: true);

      expect(featuredFetchCount, 2);
      expect(
        container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
        ['fresh-sponsored'],
      );
    });

    test('general cafe upserts do not append to Home or sponsored state', () {
      final homeOrganic = buildTestCafe(
        id: 'home-stable',
        name: 'Home Stable',
      );
      final sponsor = _sponsoredCafe(
        id: 'stable-sponsor',
        name: 'Stable Sponsor',
        priority: 10,
      );
      final mapDiscoveredSponsor = _sponsoredCafe(
        id: 'map-sponsored',
        name: 'Map Sponsored',
        priority: 100,
      );
      final mapDiscoveredOrganic = buildTestCafe(
        id: 'map-organic',
        name: 'Map Organic',
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const <Cafe>[],
          homeCafes: [homeOrganic],
          featuredCafes: [sponsor],
        ),
      );
      addTearDown(container.dispose);

      container.read(cafeProvider.notifier)
        ..upsertCafe(mapDiscoveredSponsor)
        ..upsertCafe(mapDiscoveredOrganic);

      expect(
        container.read(homeCafesProvider).map((cafe) => cafe.id),
        ['home-stable'],
      );
      expect(
        container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
        ['stable-sponsor'],
      );
      expect(
        container.read(cafesProvider).map((cafe) => cafe.id),
        containsAll(<String>['map-sponsored', 'map-organic']),
      );
    });

    test('deleted featured cafe disappears from Home sponsored state', () {
      final sponsor = _sponsoredCafe(
        id: 'delete-sponsored',
        name: 'Delete Sponsored',
        priority: 10,
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [sponsor],
          homeCafes: [sponsor],
          featuredCafes: [sponsor],
        ),
      );
      addTearDown(container.dispose);

      container.read(cafeProvider.notifier).upsertCafe(
            sponsor.copyWith(isDeleted: true, isFeatured: false),
            remove: true,
          );

      expect(container.read(homeSponsoredCafesProvider), isEmpty);
      expect(container.read(homeCafesProvider), isEmpty);
      expect(container.read(cafesProvider), isEmpty);
    });

    testWidgets(
        'Home stays visually stable while map discovery refresh is in flight',
        (tester) async {
      final homeOrganic = buildTestCafe(
        id: 'home-organic',
        name: 'Home Organic',
      ).copyWith(coordinates: const Coordinates(lat: 41.0, lng: 29.0));
      final homeSponsor = _sponsoredCafe(
        id: 'home-sponsor',
        name: 'Home Sponsor',
        priority: 90,
      );
      final mapRefresh = Completer<CafeRepositoryResult>();
      final repository = FakeCafeRepository(
        onFetch: (_) async => CafeRepositoryResult(
          cafes: [homeOrganic],
          usedRemote: true,
        ),
        onFetchRequest: ({
          String? pageToken,
          double? lat,
          double? lng,
          String? district,
          int radius = 5000,
          bool seedOnly = false,
          String? discoveryCacheKey,
        }) {
          if (district == 'Sisli') {
            return mapRefresh.future;
          }
          return Future.value(
            CafeRepositoryResult(
              cafes: [homeOrganic],
              usedRemote: true,
            ),
          );
        },
        onFetchFeaturedCafes: () async => [homeSponsor],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [buildTestCafe(id: 'map-base', name: 'Map Base')],
          homeCafes: [homeOrganic],
          featuredCafes: [homeSponsor],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-sponsored-home-sponsor')),
        findsOneWidget,
      );
      expect(
        container.read(homeCafesProvider).map((cafe) => cafe.id),
        contains('home-organic'),
      );

      final refreshFuture = container.read(cafeProvider.notifier).setMapFilters(
            const Filters(district: 'Sisli'),
          );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('home-sponsored-home-sponsor')),
        findsOneWidget,
      );
      expect(
        container.read(homeCafesProvider).map((cafe) => cafe.id),
        contains('home-organic'),
      );

      mapRefresh.complete(
        CafeRepositoryResult(
          cafes: [buildTestCafe(id: 'map-updated', name: 'Map Updated')],
          usedRemote: true,
        ),
      );
      await refreshFuture;
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-sponsored-home-sponsor')),
        findsOneWidget,
      );
      expect(
        container.read(homeCafesProvider).map((cafe) => cafe.id),
        contains('home-organic'),
      );
      expect(find.text('Map Updated'), findsNothing);
    });

    testWidgets(
        'Home sponsored section does not depend on favorites or detail hydration',
        (tester) async {
      final homeOrganic = buildTestCafe(
        id: 'hydrate-organic',
        name: 'Hydrate Organic',
      );
      final homeSponsor = _sponsoredCafe(
        id: 'hydrate-sponsor',
        name: 'Hydrate Sponsor',
        priority: 50,
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [homeOrganic],
          homeCafes: [homeOrganic],
          featuredCafes: [homeSponsor],
          favorites: const [],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-sponsored-hydrate-sponsor')),
        findsOneWidget,
      );

      await container
          .read(profileProvider.notifier)
          .toggleFavorite('hydrate-organic');
      container.read(cafeProvider.notifier).upsertCafe(
            homeOrganic.copyWith(rating: 4.9),
          );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-sponsored-hydrate-sponsor')),
        findsOneWidget,
      );
      expect(
        container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
        contains('hydrate-sponsor'),
      );
    });

    test('does not derive featured cafes from organic home cache', () {
      final cafes = [
        _sponsoredCafe(
          id: 'sponsor',
          name: 'Sponsored Cafe',
          priority: 80,
        ),
        buildTestCafe(id: 'organic-1', name: 'Organic One', rating: 4.8),
        buildTestCafe(id: 'organic-2', name: 'Organic Two', rating: 4.6),
      ];

      final container = createTestContainer(
        state: buildTestAppShellState(cafes: cafes),
      );
      addTearDown(container.dispose);

      final featured = container.read(featuredCafesProvider);
      expect(featured, isEmpty);
    });

    testWidgets('does not rely on canonical discovery as sponsored source',
        (tester) async {
      final organic = buildTestCafe(id: 'organic', name: 'Organic Cafe');
      final sponsor = _sponsoredCafe(
        id: 'saved-sponsor',
        name: 'Saved Sponsor',
        priority: 30,
      );
      final repository = FakeCafeRepository(
        onFetch: (_) async => CafeRepositoryResult(
          cafes: [organic, sponsor],
          usedRemote: true,
        ),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [organic],
          currentLocation: const Coordinates(lat: 41.0, lng: 29.0),
        ),
        overrides: [
          cafeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cafeProvider.notifier).refreshCafes();

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(container.read(homeSponsoredCafesProvider), isEmpty);
      expect(
          find.byKey(const Key('home-sponsored-saved-sponsor')), findsNothing);
      expect(
          find.byKey(const Key('home-featured-saved-sponsor')), findsNothing);
    });

    testWidgets('does not show sponsored visual treatment in Explore',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            _sponsoredCafe(
              id: 'explore-sponsored',
              name: 'Explore Sponsored',
              label: 'Partner Pick',
            ),
          ],
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ExploreScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore-cafe-explore-sponsored')),
          findsOneWidget);
      expect(find.text('Partner Pick'), findsNothing);
      expect(find.text('Sponsored'), findsNothing);
      expect(
        find.byKey(const Key('cafe-card-sponsored-badge-explore-sponsored')),
        findsNothing,
      );
    });

    testWidgets('does not show sponsored visual treatment in Compare',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            _sponsoredCafe(
              id: 'compare-sponsored',
              name: 'Compare Sponsored',
              label: 'Partner Pick',
            ),
          ],
          compareList: const ['compare-sponsored'],
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const CompareScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compare Sponsored'), findsWidgets);
      expect(find.text('Partner Pick'), findsNothing);
      expect(find.text('Sponsored'), findsNothing);
      expect(
        find.byKey(const Key('cafe-card-sponsored-badge-compare-sponsored')),
        findsNothing,
      );
    });
  });

  group('home featured cafes', () {
    testWidgets('duplicate sponsored and featured IDs render only one section',
        (tester) async {
      final featuredUntil = DateTime.utc(2035, 1, 1);
      final featuredCafes = List.generate(
        3,
        (index) => buildTestCafe(
          id: 'dupe-featured-$index',
          name: 'Dupe Featured $index',
        ).copyWith(
          isFeatured: true,
          featuredPriority: index + 1,
          featuredUntil: () => featuredUntil,
        ),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(featuredCafes: featuredCafes),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Sponsored cafes'), findsOneWidget);
      expect(find.text('Featured cafes'), findsNothing);
      for (final cafe in featuredCafes) {
        expect(find.byKey(ValueKey('home-featured-${cafe.id}')), findsNothing);
      }
    });

    test('lower featured guard allows genuinely distinct IDs', () {
      final sponsored = [
        buildTestCafe(id: 'sponsored-1', name: 'Sponsored One'),
      ];
      final featured = [
        buildTestCafe(id: 'featured-1', name: 'Featured One'),
      ];

      expect(isDuplicateHomeFeaturedSection(sponsored, featured), isFalse);
    });

    test('normal home cafes exclude sponsored ids and place ids', () {
      final sponsored = [
        buildTestCafe(id: 'sponsored-1', name: 'Sponsored One')
            .copyWith(placeId: 'place-1'),
      ];
      final homeCafes = [
        buildTestCafe(id: 'sponsored-1', name: 'Same Id'),
        buildTestCafe(id: 'home-place-match', name: 'Same Place')
            .copyWith(placeId: 'place-1'),
        buildTestCafe(id: 'home-distinct', name: 'Distinct Home')
            .copyWith(placeId: 'place-2'),
      ];

      expect(
        excludeSponsoredHomeCafes(homeCafes, sponsored).map((cafe) => cafe.id),
        ['home-distinct'],
      );
    });

    testWidgets(
        'featured render count stays tied to featured provider even with large home cache',
        (tester) async {
      final featuredUntil = DateTime.utc(2035, 1, 1);
      final featuredCafes = List.generate(
        3,
        (index) => buildTestCafe(
          id: 'featured-$index',
          name: 'Featured $index',
        ).copyWith(
          isFeatured: true,
          featuredPriority: index + 1,
          featuredUntil: () => featuredUntil,
        ),
      );
      final homeCafes = List.generate(
        151,
        (index) => buildTestCafe(
          id: 'home-$index',
          name: 'Home $index',
        ),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: homeCafes,
          homeCafes: homeCafes,
          featuredCafes: featuredCafes,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(container.read(featuredCafesProvider), hasLength(3));
      expect(container.read(homeSponsoredCafesProvider), hasLength(3));
      expect(find.text('Sponsored cafes'), findsOneWidget);
      expect(find.text('Featured cafes'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home-normal-home-0')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('home-normal-home-0')), findsOneWidget);
    });

    testWidgets('deleted featured rows do not inflate home featured render',
        (tester) async {
      final featuredUntil = DateTime.utc(2035, 1, 1);
      final activeFeatured = List.generate(
        3,
        (index) => buildTestCafe(
          id: 'active-featured-$index',
          name: 'Active Featured $index',
        ).copyWith(
          isFeatured: true,
          featuredPriority: index + 1,
          featuredUntil: () => featuredUntil,
        ),
      );
      final staleFeaturedRows = [
        buildTestCafe(id: 'deleted-featured', name: 'Deleted Featured')
            .copyWith(
          isFeatured: true,
          isDeleted: true,
          featuredUntil: () => featuredUntil,
        ),
        buildTestCafe(id: 'expired-featured', name: 'Expired Featured')
            .copyWith(
          isFeatured: true,
          featuredUntil: () => DateTime.utc(2020, 1, 1),
        ),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          homeCafes: const [],
          featuredCafes: [...activeFeatured, ...staleFeaturedRows],
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(container.read(featuredCafesProvider), hasLength(4));
      expect(container.read(homeSponsoredCafesProvider), hasLength(4));
      expect(find.text('Sponsored cafes'), findsOneWidget);
      expect(find.text('Featured cafes'), findsNothing);
    });

    testWidgets('delete reduces featured and sponsored render counts by one',
        (tester) async {
      final featuredUntil = DateTime.utc(2035, 1, 1);
      final featuredCafes = List.generate(
        3,
        (index) => buildTestCafe(
          id: 'featured-del-$index',
          name: 'Featured Del $index',
        ).copyWith(
          isFeatured: true,
          featuredPriority: index + 1,
          featuredUntil: () => featuredUntil,
        ),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          homeCafes: const [],
          featuredCafes: featuredCafes,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(container.read(featuredCafesProvider), hasLength(3));
      expect(container.read(homeSponsoredCafesProvider), hasLength(3));
      expect(find.text('Sponsored cafes'), findsOneWidget);
      expect(find.text('Featured cafes'), findsNothing);

      final nextFeatured = featuredCafes.sublist(1);
      container.read(cafeProvider.notifier).state =
          container.read(cafeProvider).copyWith(
                featuredCafes: nextFeatured,
                hasLoadedFeaturedCafes: true,
              );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(container.read(featuredCafesProvider), hasLength(2));
      expect(container.read(homeSponsoredCafesProvider), hasLength(2));
      expect(find.text('Sponsored cafes'), findsOneWidget);
      expect(find.text('Featured cafes'), findsNothing);
    });

    testWidgets(
        'normal home section renders non-sponsored cafes and excludes sponsored duplicates',
        (tester) async {
      final featuredUntil = DateTime.utc(2035, 1, 1);
      final sponsoredCafe = buildTestCafe(
        id: 'sponsored-normal-filter',
        name: 'Sponsored Normal Filter',
      ).copyWith(
        isFeatured: true,
        featuredUntil: () => featuredUntil,
        placeId: 'sponsored-place',
      );
      final homeCafes = [
        sponsoredCafe.copyWith(isFeatured: false),
        buildTestCafe(id: 'home-place-copy', name: 'Home Place Copy')
            .copyWith(placeId: 'sponsored-place'),
        buildTestCafe(id: 'home-normal-one', name: 'Home Normal One'),
        buildTestCafe(id: 'home-normal-two', name: 'Home Normal Two'),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: homeCafes,
          homeCafes: homeCafes,
          featuredCafes: [sponsoredCafe],
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey('home-sponsored-sponsored-normal-filter')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-normal-sponsored-normal-filter')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('home-normal-home-place-copy')),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home-normal-home-normal-one')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('home-normal-home-normal-one')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home-normal-home-normal-two')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('home-normal-home-normal-two')),
        findsOneWidget,
      );
    });

    test('general home cache cannot add extra featured cards', () {
      final homeCafes = [
        buildTestCafe(id: 'home-1', name: 'Home One').copyWith(
          isFeatured: true,
        ),
        buildTestCafe(id: 'home-2', name: 'Home Two').copyWith(
          isFeatured: true,
        ),
      ];
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: homeCafes,
          homeCafes: homeCafes,
          featuredCafes: const [],
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(featuredCafesProvider), isEmpty);
      expect(container.read(homeSponsoredCafesProvider), isEmpty);
    });

    testWidgets('no duplicate cafe cards appear across home featured sections',
        (tester) async {
      final featuredUntil = DateTime.utc(2035, 1, 1);
      final cafe = buildTestCafe(
        id: 'single-featured',
        name: 'Single Featured',
      ).copyWith(
        isFeatured: true,
        featuredUntil: () => featuredUntil,
      );
      final container = createTestContainer(
        state: buildTestAppShellState(featuredCafes: [cafe]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const ValueKey('home-sponsored-single-featured')),
          findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-featured-single-featured')),
        findsNothing,
      );
      expect(find.text('Single Featured'), findsOneWidget);
    });

    testWidgets(
        'home remains populated by normal cafes when sponsored is small',
        (tester) async {
      final featuredUntil = DateTime.utc(2035, 1, 1);
      final sponsoredCafe = buildTestCafe(
        id: 'small-sponsored',
        name: 'Small Sponsored',
      ).copyWith(
        isFeatured: true,
        featuredUntil: () => featuredUntil,
      );
      final homeCafe = buildTestCafe(
        id: 'normal-home-populated',
        name: 'Normal Home Populated',
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [homeCafe],
          homeCafes: [homeCafe],
          featuredCafes: [sponsoredCafe],
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const ValueKey('home-sponsored-small-sponsored')),
          findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home-normal-normal-home-populated')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('home-normal-normal-home-populated')),
        findsOneWidget,
      );
    });
  });
}

class _FailingImageProvider extends ImageProvider<_FailingImageProvider> {
  const _FailingImageProvider();

  @override
  Future<_FailingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_FailingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _FailingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(
        StateError('forced image load failure'),
        StackTrace.current,
      ),
    );
  }
}

class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  const _PendingImageProvider();

  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_PendingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }
}

Cafe _sponsoredCafe({
  required String id,
  required String name,
  int priority = 0,
  double rating = 4.5,
  DateTime? until,
  String? label,
  bool isDeleted = false,
  String approvalStatus = 'approved',
}) {
  return buildTestCafe(
    id: id,
    name: name,
    rating: rating,
  ).copyWith(
    isFeatured: true,
    featuredPriority: priority,
    featuredUntil: () => until,
    featuredLabel: () => label,
    isDeleted: isDeleted,
    ownerApprovalStatus: approvalStatus,
  );
}
