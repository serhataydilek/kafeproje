import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/cafe_media.dart';

void main() {
  group('cafe image media helpers', () {
    test('google photo urls can be sized for lightweight thumbnails', () {
      final url = resolveCafeImageUrl(
        'https://places.googleapis.com/v1/places/abc/photos/photo-1/media',
        maxWidthPx: CafeImageVariant.mapPreview.requestWidthPx,
      );

      expect(url, isNotNull);
      expect(url, contains('maxWidthPx=320'));
    });

    test('new places photo name becomes v1 media URL with width', () {
      final url = resolveCafeImageUrl(
        'places/PLACE_ID/photos/PHOTO_RESOURCE',
        maxWidthPx: CafeImageVariant.listThumbnail.requestWidthPx,
      );

      final uri = Uri.parse(url!);
      expect(uri.host, 'places.googleapis.com');
      expect(uri.path, '/v1/places/PLACE_ID/photos/PHOTO_RESOURCE/media');
      expect(uri.queryParameters['maxWidthPx'], '720');
      expect(uri.queryParameters['maxHeightPx'], isNull);
    });

    test('photo name already ending in media is not double suffixed', () {
      final url = buildGooglePhotoMediaUrl(
        'places/PLACE_ID/photos/PHOTO_RESOURCE/media',
        apiKey: 'test_google_places_photo_api_key',
        maxWidthPx: CafeImageVariant.listThumbnail.requestWidthPx,
      );

      final uri = Uri.parse(url);
      expect(uri.path, '/v1/places/PLACE_ID/photos/PHOTO_RESOURCE/media');
      expect('/media'.allMatches(uri.path).length, 1);
    });

    test('full places photo URL gets required width when missing', () {
      final url = resolveCafeImageUrl(
        'https://places.googleapis.com/v1/places/abc/photos/photo-1/media?key=old',
        maxWidthPx: CafeImageVariant.mapPreview.requestWidthPx,
      );

      final uri = Uri.parse(url!);
      expect(uri.host, 'places.googleapis.com');
      expect(uri.path, '/v1/places/abc/photos/photo-1/media');
      expect(uri.queryParameters['maxWidthPx'], '320');
      expect(uri.queryParameters['maxHeightPx'], isNull);
      expect(uri.toString(), isNot(contains('%2F')));
    });

    test('invalid places.googleapis.com URL is not passed through', () {
      final url = resolveCafeImageUrl(
        'https://places.googleapis.com/v1/bad-photo-path',
        maxWidthPx: CafeImageVariant.mapPreview.requestWidthPx,
      );

      expect(url, isNull);
    });

    test('non-google image urls stay normalized without added sizing params',
        () {
      final url = resolveCafeImageUrl(
        'http://example.com/cafe.png',
        maxWidthPx: CafeImageVariant.listThumbnail.requestWidthPx,
      );

      expect(url, 'https://example.com/cafe.png');
    });

    test('normalizeCafeImageUrls removes duplicates while preserving order',
        () {
      final urls = normalizeCafeImageUrls([
        'https://example.com/a.png',
        'https://example.com/a.png',
        'https://example.com/b.png',
      ]);

      expect(urls, [
        'https://example.com/a.png',
        'https://example.com/b.png',
      ]);
    });

    test('legacy google photo references build a photo URL', () {
      final url = resolveCafeImageUrl(
        'Aap_uE1b2c3d4e5f6g7h8i9j0k',
        maxWidthPx: CafeImageVariant.mapPreview.requestWidthPx,
      );

      expect(url, isNotNull);
      expect(url, contains('maps.googleapis.com/maps/api/place/photo'));
      expect(url, contains('photoreference='));
      expect(url, contains('maxwidth=320'));
    });

    test('legacy google photo references are not treated as v1 photo names',
        () {
      const legacy = 'Aap_uE1b2c3d4e5f6g7h8i9j0k';

      expect(normalizeGooglePhotoName(legacy), isNull);
      expect(resolveCafeImageUrl(legacy), contains('maps.googleapis.com'));
    });

    test('invalid size params are replaced with a valid default', () {
      final url = buildGooglePhotoMediaUrl(
        'places/PLACE_ID/photos/PHOTO_RESOURCE',
        apiKey: 'test_google_places_photo_api_key',
        maxWidthPx: 0,
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters['maxWidthPx'], isNot('0'));
      expect(uri.queryParameters['maxWidthPx'], isNotEmpty);
      expect(uri.queryParameters['maxHeightPx'], isNull);
    });

    test('remembered failed google image urls are skipped until cleared', () {
      clearRememberedFailedCafeImageUrls();
      const raw = 'places/PLACE_ID/photos/PHOTO_RESOURCE';
      final resolved = resolveCafeImageUrl(raw);

      expect(normalizeCafeImageUrls([raw]), hasLength(1));

      rememberFailedCafeImageUrl(resolved);

      expect(isKnownFailedCafeImageUrl(raw), isTrue);
      expect(normalizeCafeImageUrls([raw]), isEmpty);

      clearRememberedFailedCafeImageUrls();
    });

    test('known bad google image does not block later valid candidates', () {
      clearRememberedFailedCafeImageUrls();
      const bad = 'places/PLACE_ID/photos/BAD_RESOURCE';
      const good = 'Aap_uE1b2c3d4e5f6g7h8i9j0k';
      rememberFailedCafeImageUrl(resolveCafeImageUrl(bad));

      final urls = normalizeCafeImageUrls([bad, good]);

      expect(urls, hasLength(1));
      expect(urls.single, contains('maps.googleapis.com'));
      expect(urls.single, contains('photoreference='));

      clearRememberedFailedCafeImageUrls();
    });

    test('priority normalization defers generated places media candidates', () {
      final urls = normalizeCafeImageUrlsByPriority([
        'places/PLACE_ID/photos/GENERATED_RESOURCE',
        'https://example.com/direct.jpg',
      ]);

      expect(urls, hasLength(2));
      expect(urls.first, 'https://example.com/direct.jpg');
      expect(isGeneratedPlacesMediaImageUrl(urls.last), isTrue);
    });

    test('photo url breakdown separates stored, generated, and display urls',
        () {
      final breakdown = cafePhotoUrlBreakdownFromRaw(
        const <String, Object?>{
          'photo_urls': ['https://example.com/stored.jpg'],
          'photos': [
            {'name': 'places/PLACE_ID/photos/GENERATED_RESOURCE'},
          ],
        },
      );

      expect(breakdown.storedPhotoUrls, ['https://example.com/stored.jpg']);
      expect(breakdown.generatedPhotoUrls, hasLength(1));
      expect(
          isGeneratedPlacesMediaImageUrl(
            breakdown.generatedPhotoUrls.single,
          ),
          isTrue);
      expect(breakdown.resolvedDisplayUrls.first,
          'https://example.com/stored.jpg');
    });

    test('new google photo media urls include key and width', () {
      final url = buildGooglePhotoMediaUrl(
        'places/place-1/photos/photo-1/media',
        apiKey: 'test_google_places_photo_api_key',
        maxWidthPx: CafeImageVariant.listThumbnail.requestWidthPx,
      );

      final uri = Uri.parse(url);
      expect(uri.host, 'places.googleapis.com');
      expect(uri.path, '/v1/places/place-1/photos/photo-1/media');
      expect(uri.queryParameters['maxWidthPx'], '720');
      expect(
        uri.queryParameters['key'],
        'test_google_places_photo_api_key',
      );
    });

    test('google photo urls require an API key in production-like mode', () {
      expect(
        resolveCafeImageUrl(
          'places/PLACE_ID/photos/PHOTO_RESOURCE',
          allowUnauthenticatedGooglePhotoUrls: false,
        ),
        isNull,
      );
      expect(
        resolveCafeImageUrl(
          'Aap_uE1b2c3d4e5f6g7h8i9j0k',
          allowUnauthenticatedGooglePhotoUrls: false,
        ),
        isNull,
      );
    });

    test('priority normalization skips failed first image and keeps fallback',
        () {
      clearRememberedFailedCafeImageUrls();
      const brokenGenerated = 'places/PLACE_ID/photos/BROKEN_RESOURCE';
      const fallbackDirect = 'https://example.com/fallback.jpg';
      rememberFailedCafeImageUrl(resolveCafeImageUrl(brokenGenerated));

      final urls = normalizeCafeImageUrlsByPriority([
        brokenGenerated,
        fallbackDirect,
      ]);

      expect(urls, [fallbackDirect]);

      clearRememberedFailedCafeImageUrls();
    });

    test('example.com stays trusted for deterministic test/dev fixtures', () {
      expect(
        isTrustedAdminImageUrl('https://example.com/admin-seed.jpg'),
        isTrue,
      );
    });

    test('example.com is rejected in production-like trust mode', () {
      expect(
        isTrustedAdminImageUrl(
          'https://example.com/admin-seed.jpg',
          allowNonProductionHosts: false,
        ),
        isFalse,
      );
      expect(
        isTrustedAdminImageUrl(
          'https://maps.googleapis.com/maps/api/place/photo',
          allowNonProductionHosts: false,
        ),
        isTrue,
      );
    });
  });
}
