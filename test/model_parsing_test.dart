import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/utils/cafe_hours.dart';
import 'package:kafeproje/utils/filter_sort.dart';

import 'test_helpers.dart';

Map<String, dynamic> _baseSupabaseRow({
  required String id,
  required String name,
  Map<String, Object?> extra = const <String, Object?>{},
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'district': 'Kadikoy',
    'neighborhood': 'Moda',
    'rating': 4.2,
    'review_count': 5,
    'price_level': '\$\$',
    'tags': <String>[],
    'images': <String>[],
    'description': 'desc',
    'opening_hours': <Map<String, dynamic>>[],
    'wifi_quality': 'average',
    'outlet_availability': 'medium',
    'quietness_level': 'balanced',
    'ambiance_score': 4.0,
    'study_friendly': false,
    'pet_friendly': false,
    'outdoor_seating': false,
    'menu_highlights': <String>[],
    'seating_comfort': 4.0,
    'smoking_policy': 'not_allowed',
    'coordinates': {'lat': 41.0, 'lng': 29.0},
    ...extra,
  };
}

void main() {
  group('Cafe image ordering', () {
    test('direct image URLs are preferred before generated Google media', () {
      final cafe = buildTestCafe(
        id: 'image-priority',
        name: 'Image Priority',
        images: const [
          'places/PLACE_ID/photos/GENERATED_RESOURCE',
          'https://example.com/direct.jpg',
        ],
      );

      expect(cafe.photoUrls, hasLength(2));
      expect(cafe.photoUrls.first, 'https://example.com/direct.jpg');
      expect(cafe.photoUrls.last, contains('places.googleapis.com'));
    });
  });

  group('Cafe row parsing', () {
    test('fromSupabaseRow maps google_place_id into placeId', () {
      final cafe = Cafe.fromSupabaseRow(
        _baseSupabaseRow(
          id: 'cafe-gp-1',
          name: 'Cafe PlaceId',
          extra: const <String, Object?>{
            'google_place_id': 'ChIJPlaceId123',
          },
        ),
      );

      expect(cafe.placeId, 'ChIJPlaceId123');
    });

    test('fromSupabaseRow normalizes Turkish district values and fallback keys',
        () {
      final cafe = Cafe.fromSupabaseRow({
        'id': 'cafe-1',
        'name': 'Cafe One',
        'district': 'Kadıköy',
        'degree': 'Moda',
        'rating': 4.6,
        'review_count': 12,
        'price_level': '\$\$\$',
        'tags': ['quiet'],
        'images': <String>[],
        'description': 'desc',
        'opening_hours': <Map<String, dynamic>>[],
        'wifi_quality': 'strong',
        'outlet_availability': 'high',
        'quietness_level': 'quiet',
        'ambiance_score': 4.2,
        'study_friendly': true,
        'pet_friendly': false,
        'outdoor_seating': true,
        'menu_highlights': ['Latte'],
        'seating_comfort': 4.1,
        'smoking_policy': 'OUTDOOR_ONLY',
        'coordinates': {'lat': 41.0, 'lng': 29.0},
      });

      expect(cafe.district, 'Kadıköy');
      expect(cafe.neighborhood, 'Moda');
      expect(cafe.priceLevel, PriceLevel.expensive);
      expect(cafe.wifiQuality, WifiQuality.strong);
      expect(cafe.outletAvailability, OutletAvailability.high);
      expect(cafe.quietnessLevel, QuietnessLevel.quiet);
      expect(cafe.smokingPolicy, SmokingPolicy.outdoorOnly);
    });

    test(
        'fromSupabaseRow keeps unknown district unknown instead of defaulting to Kadikoy',
        () {
      final cafe = Cafe.fromSupabaseRow({
        'id': 'cafe-2',
        'name': 'Cafe Two',
        'district': 'Unparseable District',
        'neighborhood': 'Unknown Area',
        'rating': 4.6,
        'review_count': 12,
        'price_level': '\$\$',
        'tags': <String>[],
        'images': <String>[],
        'description': 'desc',
        'opening_hours': <Map<String, dynamic>>[],
        'wifi_quality': 'strong',
        'outlet_availability': 'high',
        'quietness_level': 'quiet',
        'ambiance_score': 4.2,
        'study_friendly': true,
        'pet_friendly': false,
        'outdoor_seating': true,
        'menu_highlights': <String>[],
        'seating_comfort': 4.1,
        'smoking_policy': 'OUTDOOR_ONLY',
        'coordinates': {'lat': 41.0, 'lng': 29.0},
      });

      expect(cafe.district, 'Unknown');
    });

    test('fromGooglePlace keeps google rating in metadata and not app rating',
        () {
      final cafe = Cafe.fromGooglePlace({
        'id': 'place-1',
        'displayName': {'text': 'Cafe One'},
        'rating': 4.8,
        'userRatingCount': 321,
        'shortFormattedAddress': 'Moda, Kadikoy, Istanbul',
        'location': {'latitude': 41.0, 'longitude': 29.0},
      });

      expect(cafe.district, 'Kadıköy');
      expect(cafe.rating, 0);
      expect(cafe.googlePlaceData?.googleRating, 4.8);
      expect(cafe.googlePlaceData?.usesAppDefaults, isTrue);
      expect(cafe.hasCommunityExperienceData, isFalse);
      expect(cafe.effectiveRating, 0);
      expect(cafe.effectiveReviewCount, 0);
      expect(cafe.communityWifiQuality, isNull);
      expect(cafe.communityStudyFriendly, isNull);
      expect(cafe.communityAmbianceScore, isNull);
    });

    test('fromGooglePlace maps explicit openNow=true to Open status', () {
      final cafe = Cafe.fromGooglePlace({
        'id': 'place-open',
        'displayName': {'text': 'Open Cafe'},
        'shortFormattedAddress': 'Kadikoy, Istanbul',
        'location': {'latitude': 41.0, 'longitude': 29.0},
        'currentOpeningHours': {'openNow': true},
      });

      expect(cafe.googlePlaceData?.googleOpenNow, isTrue);
      expect(resolveCafeOpenStatus(cafe), CafeOpenStatus.open);
    });

    test('fromGooglePlace maps explicit openNow=false to Closed status', () {
      final cafe = Cafe.fromGooglePlace({
        'id': 'place-closed',
        'displayName': {'text': 'Closed Cafe'},
        'shortFormattedAddress': 'Kadikoy, Istanbul',
        'location': {'latitude': 41.0, 'longitude': 29.0},
        'currentOpeningHours': {'openNow': false},
      });

      expect(cafe.googlePlaceData?.googleOpenNow, isFalse);
      expect(resolveCafeOpenStatus(cafe), CafeOpenStatus.closed);
    });

    test('fromGooglePlace keeps status Unknown when openNow is missing', () {
      final cafe = Cafe.fromGooglePlace({
        'id': 'place-unknown-hours',
        'displayName': {'text': 'Unknown Hours Cafe'},
        'shortFormattedAddress': 'Kadikoy, Istanbul',
        'location': {'latitude': 41.0, 'longitude': 29.0},
      });

      expect(cafe.googlePlaceData?.googleOpenNow, isNull);
      expect(resolveCafeOpenStatus(cafe), CafeOpenStatus.unknown);
    });

    test('fromGooglePlace can keep only a lightweight summary image set', () {
      final cafe = Cafe.fromGooglePlace({
        'id': 'place-photos',
        'displayName': {'text': 'Cafe Photos'},
        'shortFormattedAddress': 'Besiktas, Istanbul',
        'location': {'latitude': 41.0, 'longitude': 29.0},
        'photos': [
          {'name': 'photos/one'},
          {'name': 'photos/two'},
          {'name': 'photos/three'},
        ],
      }, maxImageCount: 1);

      expect(cafe.images, hasLength(1));
      expect(cafe.images.first, contains('photos/one/media'));
    });

    test('dedupKey prefers stable place id over display name similarities', () {
      final branchA = buildTestCafe(
        id: 'local-a',
        name: 'Starbucks',
      ).copyWith(placeId: 'google-place-a');
      final branchB = buildTestCafe(
        id: 'local-b',
        name: 'Starbucks',
      ).copyWith(placeId: 'google-place-b');
      final sameSource = buildTestCafe(
        id: 'remote-copy',
        name: 'Starbucks Reserve',
      ).copyWith(placeId: 'google-place-a');

      expect(branchA.dedupKey, isNot(branchB.dedupKey));
      expect(branchA.dedupKey, equals(sameSource.dedupKey));
    });

    test(
        'fromSupabaseRow keeps usable image urls from legacy single-url fields',
        () {
      final cafe = Cafe.fromSupabaseRow({
        'id': 'cafe-photo-1',
        'name': 'Cafe Photo',
        'district': 'Levent',
        'neighborhood': 'Levent',
        'rating': 4.2,
        'review_count': 5,
        'price_level': '\$\$',
        'tags': <String>[],
        'image_url': 'http://example.com/cafe-photo.jpg',
        'description': 'desc',
        'opening_hours': <Map<String, dynamic>>[],
        'wifi_quality': 'average',
        'outlet_availability': 'medium',
        'quietness_level': 'balanced',
        'ambiance_score': 4.0,
        'study_friendly': false,
        'pet_friendly': false,
        'outdoor_seating': false,
        'menu_highlights': <String>[],
        'seating_comfort': 4.0,
        'smoking_policy': 'not_allowed',
        'coordinates': {'lat': 41.0, 'lng': 29.0},
      });

      expect(cafe.images, ['https://example.com/cafe-photo.jpg']);
    });

    test('fromSupabaseRow normalizes photos when only images alias exists', () {
      final cafe = Cafe.fromSupabaseRow(
        _baseSupabaseRow(
          id: 'cafe-photo-images-only',
          name: 'Cafe Images Only',
          extra: {
            'images': <String>['http://example.com/images-only.jpg'],
            'photo_urls': null,
          },
        ),
      );

      expect(cafe.images, ['https://example.com/images-only.jpg']);
    });

    test('fromSupabaseRow falls back to photo_urls when images is empty', () {
      final cafe = Cafe.fromSupabaseRow(
        _baseSupabaseRow(
          id: 'cafe-photo-photo-urls-only',
          name: 'Cafe Photo Urls Only',
          extra: {
            'images': <String>[],
            'photo_urls': <String>['https://example.com/photo-urls-only.jpg'],
          },
        ),
      );

      expect(cafe.images, ['https://example.com/photo-urls-only.jpg']);
    });

    test('fromSupabaseRow accepts singular photoUrl alias', () {
      final cafe = Cafe.fromSupabaseRow(
        _baseSupabaseRow(
          id: 'cafe-photo-photourl-only',
          name: 'Cafe PhotoUrl Only',
          extra: {
            'images': <String>[],
            'photoUrl': 'http://example.com/photo-url-only.jpg',
          },
        ),
      );

      expect(cafe.images, ['https://example.com/photo-url-only.jpg']);
    });

    test('fromSupabaseRow deduplicates mixed photo aliases in stable order',
        () {
      final cafe = Cafe.fromSupabaseRow(
        _baseSupabaseRow(
          id: 'cafe-photo-mixed-dedupe',
          name: 'Cafe Mixed Dedupe',
          extra: {
            'images': <String>[
              'https://example.com/a.jpg',
              'http://example.com/a.jpg',
              '',
            ],
            'photo_urls': <String>[
              'https://example.com/b.jpg',
              'https://example.com/a.jpg',
            ],
            'photoUrl': 'https://example.com/b.jpg',
            'image_url': 'https://example.com/c.jpg',
          },
        ),
      );

      expect(
        cafe.images,
        [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
          'https://example.com/c.jpg',
        ],
      );
    });

    test('fromSupabaseRow tolerates malformed photo payloads', () {
      final row = _baseSupabaseRow(
        id: 'cafe-photo-malformed',
        name: 'Cafe Malformed',
        extra: {
          'images': <Object?>[
            null,
            '',
            123,
            {'url': '  '},
            {
              'photos': <Object?>[
                {'name': 'photos/malformed-ok'}
              ]
            },
            '{not-json',
          ],
          'media': {
            'items': <Object?>[
              {'photoUrl': 'http://example.com/malformed-survivor.jpg'},
              {'photoUrl': null},
            ],
          },
        },
      );

      expect(() => Cafe.fromSupabaseRow(row), returnsNormally);
      final cafe = Cafe.fromSupabaseRow(row);
      expect(cafe.images, isNotEmpty);
    });

    test(
        'fromSupabaseRow returns empty normalized photos when no valid aliases exist',
        () {
      final row = _baseSupabaseRow(
        id: 'cafe-photo-empty',
        name: 'Cafe Empty Photos',
        extra: {
          'images': <Object?>[
            null,
            '',
            '   ',
            {'url': ''}
          ],
          'photo_urls': <Object?>[],
          'photoUrl': '   ',
          'image_url': 'not-a-url',
          'google_photo_reference': '',
          'google_photo_references': <Object?>[],
          'photos': null,
          'media': {'value': null},
        },
      );

      expect(() => Cafe.fromSupabaseRow(row), returnsNormally);
      expect(Cafe.fromSupabaseRow(row).images, isEmpty);
    });

    test('photo model diagnostics stay compact and avoid raw URL dumps',
        () async {
      final messages = <String>[];
      final originalDebugPrint = debugPrint;
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          messages.add(message);
        }
      };

      // Wait for the logger throttle window so this test can observe a fresh
      // compact diagnostics line deterministically.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      resetPhotoModelDiagnosticsLimit();

      final longUrl =
          'https://example.com/${List<String>.filled(90, 'segment').join('/')}.jpg';
      final cafe = Cafe.fromSupabaseRow(
        _baseSupabaseRow(
          id: 'cafe-photo-log-compact',
          name: 'Cafe Photo Log Compact',
          extra: {
            'images': <String>[longUrl],
          },
        ),
      );

      expect(cafe.images, hasLength(1));

      final modelLog = messages.firstWhere(
        (message) => message.contains('[CAFE_DIAG_PHOTO_MODEL]'),
      );
      expect(modelLog, contains('presentFieldCount='));
      expect(modelLog, contains('normalizedCount=1'));
      expect(modelLog, contains('hasFirstPhoto=true'));
      expect(modelLog, isNot(contains('raw=')));
      expect(modelLog, isNot(contains('firstUrl=')));
      expect(modelLog, isNot(contains(longUrl)));
    });

    test('fromSupabaseRow reads cached coordinate maps with dynamic keys', () {
      final dynamicCoordinateMap = <Object?, Object?>{
        'lat': 41.0815,
        'lng': 29.0135,
      };

      final cafe = Cafe.fromSupabaseRow({
        'id': 'cafe-coords-1',
        'name': 'Cafe Coords',
        'district': 'Levent',
        'neighborhood': 'Levent',
        'rating': 4.2,
        'review_count': 5,
        'price_level': '\$\$',
        'tags': <String>[],
        'images': <String>[],
        'description': 'desc',
        'opening_hours': <Object?>[],
        'wifi_quality': 'average',
        'outlet_availability': 'medium',
        'quietness_level': 'balanced',
        'ambiance_score': 4.0,
        'study_friendly': false,
        'pet_friendly': false,
        'outdoor_seating': false,
        'menu_highlights': <String>[],
        'seating_comfort': 4.0,
        'smoking_policy': 'not_allowed',
        'coordinates': dynamicCoordinateMap,
      });

      expect(cafe.coordinates, const Coordinates(lat: 41.0815, lng: 29.0135));
    });

    test('fromSupabaseRow defaults missing featured fields safely', () {
      final cafe = Cafe.fromSupabaseRow({
        'id': 'cafe-featured-defaults',
        'name': 'Cafe Defaults',
        'district': 'Kadikoy',
        'neighborhood': 'Moda',
        'rating': 4.2,
        'review_count': 5,
        'tags': <String>[],
        'images': <String>[],
        'description': 'desc',
        'opening_hours': <Map<String, dynamic>>[],
        'coordinates': {'lat': 41.0, 'lng': 29.0},
      });

      expect(cafe.isFeatured, isFalse);
      expect(cafe.featuredPriority, 0);
      expect(cafe.featuredUntil, isNull);
      expect(cafe.featuredLabel, isNull);
      expect(cafe.isActiveFeatured, isFalse);
    });

    test('featured status comes from is_featured only', () {
      final activeCafe = Cafe.fromSupabaseRow({
        'id': 'cafe-featured-active',
        'name': 'Cafe Active',
        'district': 'Kadikoy',
        'neighborhood': 'Moda',
        'rating': 4.2,
        'review_count': 5,
        'tags': <String>[],
        'images': <String>[],
        'description': 'desc',
        'opening_hours': <Map<String, dynamic>>[],
        'coordinates': {'lat': 41.0, 'lng': 29.0},
        'is_featured': true,
      });
      final deletedCafe = Cafe.fromSupabaseRow({
        'id': 'cafe-featured-deleted',
        'name': 'Cafe Deleted',
        'district': 'Kadikoy',
        'neighborhood': 'Moda',
        'rating': 4.2,
        'review_count': 5,
        'tags': <String>[],
        'images': <String>[],
        'description': 'desc',
        'opening_hours': <Map<String, dynamic>>[],
        'coordinates': {'lat': 41.0, 'lng': 29.0},
        'is_featured': true,
        'deleted_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      });

      expect(activeCafe.isFeatured, isTrue);
      expect(activeCafe.featuredPriority, 0);
      expect(activeCafe.featuredUntil, isNull);
      expect(activeCafe.featuredLabel, isNull);
      expect(activeCafe.isActiveFeatured, isTrue);
      expect(deletedCafe.isActiveFeatured, isFalse);
    });

    test('fromSupabaseRow parses featured metadata and images jsonb', () {
      final cafe = Cafe.fromSupabaseRow({
        'id': 'cafe-featured-metadata',
        'name': 'Cafe Featured Metadata',
        'district': 'Kadikoy',
        'neighborhood': 'Moda',
        'rating': 4.2,
        'review_count': 5,
        'tags': <String>['Study'],
        'images': [
          {'url': 'https://images.example/one.jpg'},
          'https://images.example/two.jpg',
        ],
        'description': '',
        'opening_hours': <Map<String, dynamic>>[],
        'coordinates': {'lat': 41.0, 'lng': 29.0},
        'is_featured': true,
        'featured_priority': 7,
        'featured_until': '2099-01-01T00:00:00Z',
        'featured_label': '  Partner Pick  ',
      });

      expect(cafe.photoUrls, [
        'https://images.example/one.jpg',
        'https://images.example/two.jpg',
      ]);
      expect(cafe.featuredPriority, 7);
      expect(cafe.featuredUntil, DateTime.utc(2099));
      expect(cafe.featuredLabel, 'Partner Pick');
      expect(cafe.isActiveFeatured, isTrue);
    });

    test('featured Supabase-shaped JSON preserves images and google_place_id',
        () {
      final cafe = Cafe.fromSupabaseRow({
        'id': 'cafe-featured-images',
        'name': 'Cafe Featured Images',
        'district': 'Kadikoy',
        'neighborhood': 'Moda',
        'rating': 4.2,
        'review_count': 5,
        'tags': <String>['Study'],
        'images': <String>['https://example.com/featured-live.jpg'],
        'description': '',
        'opening_hours': <Map<String, dynamic>>[],
        'coordinates': {'lat': 41.0, 'lng': 29.0},
        'google_place_id': 'place-featured-images',
        'is_featured': true,
      });

      expect(cafe.photoUrls, ['https://example.com/featured-live.jpg']);
      expect(cafe.placeId, 'place-featured-images');

      final roundTrip = Cafe.fromSupabaseRow(cafe.toJson());
      expect(roundTrip.photoUrls, ['https://example.com/featured-live.jpg']);
      expect(roundTrip.placeId, 'place-featured-images');
    });

    test('only is_featured round-trips through cache serialization', () {
      final cafe = Cafe.fromSupabaseRow({
        'id': 'cafe-featured-round-trip',
        'name': 'Cafe Round Trip',
        'district': 'Kadikoy',
        'neighborhood': 'Moda',
        'rating': 4.2,
        'review_count': 5,
        'tags': <String>[],
        'images': <String>[],
        'description': 'desc',
        'opening_hours': <Map<String, dynamic>>[],
        'coordinates': {'lat': 41.0, 'lng': 29.0},
        'is_featured': true,
      });

      final roundTrip = Cafe.fromSupabaseRow(cafe.toJson());

      expect(roundTrip.isFeatured, isTrue);
      expect(roundTrip.featuredPriority, 0);
      expect(roundTrip.featuredUntil, isNull);
      expect(roundTrip.featuredLabel, isNull);
      expect(cafe.toJson(), isNot(contains('featured_priority')));
      expect(cafe.toJson(), isNot(contains('featured_until')));
      expect(cafe.toJson(), isNot(contains('featured_label')));
    });

    test('district normalization prefers scoped Istanbul localities', () {
      expect(normalizedDistrictOrUnknown('Bebek, Beşiktaş, Istanbul'), 'Bebek');
      expect(normalizedDistrictOrUnknown('Levent Mahallesi, Şişli'), 'Levent');
      expect(normalizedDistrictOrUnknown('Harbiye, Nişantaşı, Şişli'),
          'Nişantaşı');
      expect(normalizedDistrictOrUnknown('Taksim / Beyoğlu'), 'Taksim');
      expect(normalizedDistrictOrUnknown(''), 'Unknown');
    });

    test(
        'district normalization recognizes broader Şişli and Kağıthane aliases',
        () {
      expect(normalizedDistrictOrUnknown('Bomonti, Istanbul'), 'Şişli');
      expect(normalizedDistrictOrUnknown('Seyrantepe, Istanbul'), 'Kağıthane');
    });
  });

  group('Filter normalization', () {
    test('filters match Turkish and mixed-case variants consistently', () {
      final cafes = [
        buildTestCafe(
          id: '1',
          name: 'Çağrı',
          district: 'Kadıköy',
          wifiQuality: 'Strong',
          outletAvailability: 'High',
          quietnessLevel: 'Quiet',
          smokingPolicy: 'not_allowed',
        ),
      ];

      final filtered = applyFilters(
        cafes,
        const Filters(
          district: 'Kadıköy',
          wifiQuality: WifiQuality.strong,
          outletAvailability: OutletAvailability.high,
          quietnessLevel: QuietnessLevel.quiet,
          smokingPolicy: SmokingPolicy.notAllowed,
        ),
      );

      expect(filtered, hasLength(1));
    });
  });

  group('District browse shortcuts', () {
    test(
        'browseDistrictsProvider returns deterministic district labels independent from loaded cafes',
        () {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [
            buildTestCafe(id: '1', name: 'A', district: 'Kadıköy'),
            buildTestCafe(id: '2', name: 'B', district: 'Beşiktaş'),
            buildTestCafe(id: '3', name: 'C', district: 'Moda, Kadikoy'),
            buildTestCafe(id: '4', name: 'D', district: 'Unknown Area'),
            buildTestCafe(id: '5', name: 'E', district: 'Unknown'),
          ],
        ),
      );
      addTearDown(container.dispose);

      final result = container.read(browseDistrictsProvider);

      expect(
        result,
        containsAll(['Kadıköy', 'Beşiktaş']),
      );
    });
  });
}
