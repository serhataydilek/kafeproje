import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/constants/error_codes.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/log_redaction.dart' as legacy_redaction;
import 'package:kafeproje/utils/log_sanitizer.dart' as log_sanitizer;
import 'package:kafeproje/utils/service_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _tinyPngBytes = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
]);

void main() {
  group('CafeOwnerInviteService', () {
    test('maps missing edge function responses to deployment guidance', () {
      final message = cafeOwnerInviteFailureMessage(
        const FunctionException(
          status: 404,
          details: {'message': 'Function not found'},
          reasonPhrase: 'Not Found',
        ),
      );

      expect(
        message,
        'Cafe owner invite function is not deployed. Deploy the Supabase Edge Function invite-cafe-owner and try again.',
      );
    });

    test('adds structured function stage and code to backend errors', () {
      final message = cafeOwnerInviteFailureMessage(
        const FunctionException(
          status: 500,
          details: {
            'error': 'Cafe assignment failed.',
            'stage': 'assign_cafe',
            'code': 'cafe_assignment_failed',
          },
        ),
      );

      expect(
        message,
        'Cafe assignment failed. (stage=assign_cafe, code=cafe_assignment_failed)',
      );
    });

    test(
        'returns plain function response details when no structured payload exists',
        () {
      final message = cafeOwnerInviteFailureMessage(
        const FunctionException(
          status: 500,
          details: 'Unexpected function runtime error',
        ),
      );

      expect(message, 'Unexpected function runtime error');
    });
  });

  group('log URL redaction', () {
    test('signed Supabase URL token is removed from summaries', () {
      final summary = log_sanitizer.summarizeUrlForLog(
        'https://example.supabase.co/storage/v1/object/sign/avatars/profiles/user/avatar.png?token=secret-token&expires=123',
        presenceLabel: 'hasAvatar',
      );

      expect(summary, contains('hasAvatar=true'));
      expect(summary, contains('host=example.supabase.co'));
      expect(summary, contains('pathHash='));
      expect(summary, isNot(contains('secret-token')));
      expect(summary, isNot(contains('token=')));
      expect(summary, isNot(contains('expires=')));
    });

    test('Google Places key query param is removed from redacted URL logs', () {
      final summary = legacy_redaction.redactUrlForLog(
        'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=abc&key=google-secret',
      );

      expect(summary, contains('host=maps.googleapis.com'));
      expect(summary, contains('pathHash='));
      expect(summary, isNot(contains('google-secret')));
      expect(summary, isNot(contains('key=')));
      expect(summary, isNot(contains('photo_reference=')));
    });
  });

  group('CafeQueryService', () {
    final client = SupabaseClient('https://example.com', 'anon-key');

    test('discoverable cafe list columns use is_featured only', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      final listColumnsStart = source.indexOf('static const _listColumns =');
      final overlayColumnsStart =
          source.indexOf('static const _overlayColumns');
      final listColumnsBlock = source.substring(
        listColumnsStart,
        overlayColumnsStart,
      );

      expect(listColumnsBlock, contains('is_featured'));
      expect(listColumnsBlock, isNot(contains('featured_priority')));
      expect(listColumnsBlock, isNot(contains('featured_until')));
      expect(listColumnsBlock, isNot(contains('featured_label')));
      expect(listColumnsBlock, isNot(contains('is_sponsored')));
      expect(listColumnsBlock, contains('google_place_id'));
    });

    test('photo diagnostics keep compact field summaries only', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      final methodStart = source.indexOf('void _logRawSupabasePhotoRow(');
      final methodEnd = source.indexOf('bool _rowHasImagePayload', methodStart);
      final methodBlock = source.substring(methodStart, methodEnd);

      expect(methodBlock, contains('presentFieldCount='));
      expect(methodBlock, contains('presentFields='));
      expect(methodBlock, isNot(contains('raw=')));
      expect(methodBlock, isNot(contains('_previewForLog(')));
    });

    test('searchCafesByName keeps public visibility filters by default', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      final methodStart = source.indexOf(
        '@override\n  Future<ServiceResult<List<Cafe>>> searchCafesByName(',
      );
      final methodEnd = source.indexOf('  void _logPhotoFlow', methodStart);
      final methodBlock = source.substring(methodStart, methodEnd);

      expect(
        methodBlock,
        contains(".or('is_deleted.is.null,is_deleted.eq.false')"),
      );
      expect(
        methodBlock,
        contains(".isFilter('deleted_at', null)"),
      );
      expect(methodBlock, isNot(contains('owner_approval_status')));
    });

    test('featured query accepts legacy null deletion flags', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      final methodStart = source.indexOf(
        '@override\n  Future<ServiceResult<List<Cafe>>> fetchActiveFeaturedCafes(',
      );
      final methodEnd =
          source.indexOf('  int _compareFeaturedCafes', methodStart);
      final methodBlock = source.substring(methodStart, methodEnd);

      expect(methodBlock, contains('.select(_featuredColumns)'));
      expect(methodBlock, contains(".eq('is_featured', true)"));
      expect(
        methodBlock,
        contains(".isFilter('deleted_at', null)"),
      );
      expect(
        methodBlock,
        contains(".or('is_deleted.is.null,is_deleted.eq.false')"),
      );
      expect(methodBlock, contains("order('featured_priority'"));
      expect(methodBlock, isNot(contains('created_at')));
      expect(methodBlock, isNot(contains('is_sponsored')));
    });

    test('admin cafes query uses dedicated non-featured source filters', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      final methodStart = source.indexOf(
        'Future<ServiceResult<AdminCafePage>> fetchAdminCafes({',
      );
      final methodEnd = source.indexOf(
        '  Future<AdminCafePage?> _fallbackAdminCafePage',
        methodStart,
      );
      final methodBlock = source.substring(methodStart, methodEnd);

      expect(methodBlock, contains(".from('cafes').select(_adminColumns)"));
      expect(
        methodBlock,
        contains(".or('is_deleted.eq.false,is_deleted.is.null')"),
      );
      expect(methodBlock, contains(".isFilter('deleted_at', null)"));
      expect(methodBlock, contains(".order('name', ascending: true)"));
      expect(methodBlock, isNot(contains(".eq('is_featured', true)")));
      expect(methodBlock, isNot(contains('activeFeaturedCafesProvider')));
      expect(methodBlock, isNot(contains('homeSponsoredCafesProvider')));
      expect(methodBlock, isNot(contains(".order('updated_at'")));
      expect(methodBlock, isNot(contains(".order('created_at'")));
    });

    test('featured columns match live schema and include image metadata', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      final columnsStart = source.indexOf('static const _featuredColumns =');
      final adminColumnsStart = source.indexOf('static const _adminColumns');
      final columnsBlock = source.substring(columnsStart, adminColumnsStart);

      for (final column in const [
        'id',
        'name',
        'district',
        'neighborhood',
        'address',
        'formatted_address',
        'category',
        'rating',
        'review_count',
        'google_rating',
        'google_review_count',
        'price_level',
        'description',
        'tags',
        'images',
        'opening_hours',
        'menu_highlights',
        'wifi_quality',
        'outlet_availability',
        'quietness_level',
        'study_friendly',
        'pet_friendly',
        'outdoor_seating',
        'smoking_policy',
        'coordinates',
        'phone_number',
        'website_uri',
        'owner_approval_status',
        'google_place_id',
        'google_uses_app_defaults',
        'is_deleted',
        'favorite_count',
        'deleted_at',
        'deleted_by',
        'is_featured',
        'featured_priority',
        'featured_until',
        'featured_label',
      ]) {
        expect(columnsBlock, contains(column));
      }
      expect(columnsBlock, isNot(contains('photo_url')));
      expect(columnsBlock, isNot(contains('image_url')));
      expect(columnsBlock, isNot(contains(',status,')));
      expect(columnsBlock, isNot(contains("'status'")));
      expect(columnsBlock, isNot(contains('created_at')));
      expect(columnsBlock, isNot(contains('is_sponsored')));
    });

    test('cafes queries do not reference missing timestamp columns', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      final queryServiceStart = source.indexOf('class CafeQueryService');
      final commandServiceStart = source.indexOf('class CafeCommandService');
      final queryServiceBlock =
          source.substring(queryServiceStart, commandServiceStart);

      expect(queryServiceBlock, isNot(contains('updated_at')));
      expect(queryServiceBlock, isNot(contains('created_at')));
    });

    test('Google rating metadata update writes only live cafe columns', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      final methodStart = source.indexOf(
        'Future<ServiceResult<void>> updateGoogleRatingMetadata({',
      );
      final methodEnd = source.indexOf('class CafeCommandService', methodStart);
      final methodBlock = source.substring(methodStart, methodEnd);

      expect(methodBlock, contains('\'google_rating\''));
      expect(methodBlock, contains('\'google_review_count\''));
      expect(methodBlock, contains('\'external_last_synced_at\''));
      expect(methodBlock, contains(".from('cafes')"));
      expect(methodBlock, contains('.update(payload)'));
      expect(methodBlock, contains(".eq('id', normalizedCafeId)"));
      expect(
        methodBlock,
        contains('.eq(\'google_place_id\', normalizedPlaceId)'),
      );
      expect(methodBlock, isNot(contains("'updated_at'")));
      expect(methodBlock, isNot(contains("'created_at'")));
      expect(methodBlock, isNot(contains('.delete()')));
    });

    test('featured query does not reference place_id column', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      final methodStart = source.indexOf(
        '@override\n  Future<ServiceResult<List<Cafe>>> fetchActiveFeaturedCafes(',
      );
      final methodEnd =
          source.indexOf('  int _compareFeaturedCafes', methodStart);
      final methodBlock = source.substring(methodStart, methodEnd);

      expect(methodBlock, isNot(contains(".eq('place_id'")));
      expect(methodBlock, isNot(contains("inFilter('place_id'")));
    });

    test('fetchActiveFeaturedCafes uses featured state instead of list order',
        () async {
      final service = CafeQueryService(
        client,
        cafesLoader: () async => [
          _cafeRow(
            id: 'organic-high-rating',
            name: 'Organic High Rating',
            rating: 5.0,
          ),
          _cafeRow(
            id: 'featured-low-rating',
            name: 'Featured Low Rating',
            rating: 3.1,
            isDeleted: null,
            isFeatured: true,
          ),
          _cafeRow(
            id: 'deleted-featured',
            name: 'Deleted Featured',
            isFeatured: true,
            isDeleted: true,
          ),
        ],
      );

      final result = await service.fetchActiveFeaturedCafes();

      expect(result.ok, isTrue);
      expect(result.data?.map((cafe) => cafe.id), ['featured-low-rating']);
    });

    test('featured rows honor nullable delete flags from Supabase', () async {
      final service = CafeQueryService(
        client,
        cafesLoader: () async => [
          _cafeRow(
            id: 'featured-null-delete',
            name: 'Featured Null Delete',
            isFeatured: true,
            isDeleted: null,
          ),
          _cafeRow(
            id: 'featured-false-delete',
            name: 'Featured False Delete',
            isFeatured: true,
            isDeleted: false,
          ),
          _cafeRow(
            id: 'featured-true-delete',
            name: 'Featured True Delete',
            isFeatured: true,
            isDeleted: true,
          ),
          _cafeRow(
            id: 'featured-deleted-at',
            name: 'Featured Deleted At',
            isFeatured: true,
            isDeleted: false,
            deletedAt: DateTime.utc(2026, 1, 1),
          ),
          _cafeRow(
            id: 'organic',
            name: 'Organic',
            isFeatured: false,
            isDeleted: false,
          ),
        ],
      );

      final result = await service.fetchActiveFeaturedCafes();

      expect(result.ok, isTrue);
      expect(
        result.data?.map((cafe) => cafe.id),
        ['featured-false-delete', 'featured-null-delete'],
      );
    });

    test('discoverable and featured queries exclude soft-deleted cafe rows',
        () async {
      final deletedRow = _cafeRow(
        id: 'delete-test-featured-cafe-002',
        name: 'Delete Test Featured Cafe',
        isFeatured: true,
        isDeleted: true,
        deletedAt: DateTime.utc(2026, 5, 7),
      );
      final activeRow = _cafeRow(
        id: 'active-featured-cafe',
        name: 'Active Featured Cafe',
        isFeatured: true,
        isDeleted: false,
      );
      final service = CafeQueryService(
        client,
        cafesLoader: () async => [deletedRow, activeRow],
      );

      final discoverable = await service.fetchDiscoverableCafes();
      final featured = await service.fetchActiveFeaturedCafes();

      expect(discoverable.ok, isTrue);
      expect(featured.ok, isTrue);
      expect(
        discoverable.data?.map((cafe) => cafe.id),
        isNot(contains('delete-test-featured-cafe-002')),
      );
      expect(
        featured.data?.map((cafe) => cafe.id),
        isNot(contains('delete-test-featured-cafe-002')),
      );
      expect(featured.data?.map((cafe) => cafe.id),
          contains('active-featured-cafe'));
    });

    test('fetchCafesByPlaceIds parses cafes and deduplicates in-flight work',
        () async {
      final completer = Completer<List<Map<String, dynamic>>>();
      var loaderCount = 0;
      final service = CafeQueryService(
        client,
        cafesByPlaceIdsLoader: (
          placeIds, {
          required requestTimeout,
          cancellationToken,
        }) {
          loaderCount += 1;
          return completer.future;
        },
      );

      final first = service.fetchCafesByPlaceIds(['place-1', 'place-1']);
      final second = service.fetchCafesByPlaceIds(['place-1']);

      completer.complete([
        {
          'id': 'cafe-1',
          'google_place_id': 'place-1',
          'name': 'Cafe One',
          'district': 'Kadikoy',
          'neighborhood': 'Moda',
          'rating': 4.5,
          'review_count': 10,
          'price_level': '\$\$',
          'tags': ['Coffee'],
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
          'seating_comfort': 4.0,
          'smoking_policy': 'not_allowed',
          'coordinates': {'lat': 41.0, 'lng': 29.0},
        },
      ]);

      final results = await Future.wait([first, second]);

      expect(loaderCount, 1);
      expect(results.first.ok, isTrue);
      expect(results.first.data, hasLength(1));
      expect(results.first.data!.single.name, 'Cafe One');
      expect(results.last.data!.single.id, 'cafe-1');
    });

    test('fetchCafeDetails maps timeout failures consistently', () async {
      final service = CafeQueryService(
        client,
        cafeDetailLoader: (
          cafeId, {
          required requestTimeout,
          cancellationToken,
        }) async {
          throw const AppServiceException.timeout('details timed out');
        },
      );

      final result = await service.fetchCafeDetails('cafe-1');

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.timeout);
      expect(result.errorCode, AppErrorCode.requestTimedOut);
    });
  });

  group('CafeCommandService', () {
    final client = SupabaseClient('https://example.com', 'anon-key');

    test('admin cafe delete path never calls physical Supabase delete', () {
      final libFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final source = libFiles.map((file) => file.readAsStringSync()).join('\n');

      expect(source, isNot(contains(".from('cafes')\n        .delete()")));
      expect(source, isNot(contains(".from('cafes').delete()")));
      expect(source, contains('buttonHandlerReached=true'));
      expect(
        source,
        contains('controllerMethod=CafeAdminMutationController.deleteCafe'),
      );
      expect(source, contains('method=CafeCommandService.softDeleteCafe'));
      expect(source, contains('method=SupabaseService.softDeleteCafe'));
      expect(source, contains('operation=SOFT_UPDATE'));
      expect(source, contains('physicalDelete=false'));
    });

    test('softDeleteCafe implementation uses update filters, not delete', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      final methodStart = source.indexOf(
        'Future<ServiceResult<Cafe>> softDeleteCafe({',
      );
      final methodEnd =
          source.indexOf('  static String _safeSoftDeleteFailureMessage');
      final updateStart = source.indexOf(
        'Future<Map<String, dynamic>?> _runSoftDeleteUpdate(',
      );
      final updateEnd = methodStart;
      final methodBlock = source.substring(methodStart, methodEnd);
      final updateBlock = source.substring(updateStart, updateEnd);

      expect(methodBlock, isNot(contains('.delete()')));
      expect(updateBlock, contains(".from('cafes')"));
      expect(updateBlock, contains('.update(payload)'));
      expect(updateBlock, contains(".eq('id', resolvedRowId)"));
      expect(
          updateBlock, contains(".eq('google_place_id', normalizedPlaceId)"));
      expect(updateBlock, contains('if (rows.isEmpty)'));
    });

    test('addCafe rejects missing names before touching Supabase', () async {
      final service = CafeCommandService(client);

      final result = await service.addCafe(
        _buildCafeInput(name: ''),
      );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.validation);
      expect(result.errorCode, AppErrorCode.cafeNameRequired);
    });

    test('updateCafeByAdmin maps conflicts from the service layer', () async {
      final service = CafeCommandService(
        client,
        updateCafeLoader: (cafeId, payload) async {
          throw const AppServiceException.conflict('duplicate cafe');
        },
      );

      final result = await service.updateCafeByAdmin(
        'cafe-1',
        _buildCafeInput(),
      );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.conflict);
      expect(result.errorCode, AppErrorCode.dataConflict);
    });

    test(
      'updateCafeByAdmin place-id insert fallback seeds visible defaults',
      () {
        final source =
            File('lib/services/supabase_service.dart').readAsStringSync();
        final methodStart = source.indexOf(
          'Future<ServiceResult<Cafe>> updateCafeByAdmin(',
        );
        final methodEnd = source.indexOf(
          'Future<ServiceResult<Cafe>> updateCafe(',
          methodStart,
        );
        final methodBlock = source.substring(methodStart, methodEnd);

        expect(
          methodBlock,
          contains("..['owner_approval_status'] = 'approved'"),
        );
        expect(methodBlock, contains("..['is_deleted'] = false"));
      },
    );

    test(
      'updateCafeByAdmin allows empty description values',
      () async {
        var loaderCalled = false;
        final service = CafeCommandService(
          client,
          updateCafeLoader: (cafeId, payload) async {
            loaderCalled = true;
            throw const AppServiceException.conflict('duplicate cafe');
          },
        );

        final result = await service.updateCafeByAdmin(
          'cafe-1',
          const CafeAdminUpdateInput(
            name: 'Cafe Input',
            description: '',
          ),
        );

        expect(loaderCalled, isTrue);
        expect(result.ok, isFalse);
        expect(result.errorType, ServiceErrorType.conflict);
        expect(result.errorCode, AppErrorCode.dataConflict);
      },
    );

    test('softDeleteCafe treats zero updated rows as tombstone failure',
        () async {
      final service = CafeCommandService(
        client,
        softDeleteLookupLoader: (cafeId, candidatePlaceId) async => {
          'id': 'cafe-1',
          'google_place_id': 'place-1',
          'name': 'Cafe One',
          'is_deleted': false,
        },
        softDeleteUpdateLoader: (cafeId, payload) async => null,
        tombstoneLoader: (googlePlaceId, payload) async => null,
      );

      final result = await service.softDeleteCafe(
        cafeId: 'cafe-1',
        externalPlaceId: 'place-1',
        deletedBy: 'admin-1',
      );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.notFound);
    });

    test('softDeleteCafe updates delete flags by exact id', () async {
      Map<String, dynamic>? capturedPayload;
      String? capturedRowId;
      final service = CafeCommandService(
        client,
        softDeleteLookupLoader: (cafeId, candidatePlaceId) async => {
          'id': 'cafe-1',
          'google_place_id': 'place-1',
          'name': 'Cafe One',
          'is_deleted': false,
          'is_featured': true,
        },
        softDeleteUpdateLoader: (cafeId, payload) async {
          capturedRowId = cafeId;
          capturedPayload = Map<String, dynamic>.from(payload);
          return {
            'id': cafeId,
            'google_place_id': 'place-1',
            'name': 'Cafe One',
            ...payload,
          };
        },
      );

      final result = await service.softDeleteCafe(
        cafeId: 'cafe-1',
        externalPlaceId: 'place-1',
        deletedBy: 'admin-1',
      );

      expect(result.ok, isTrue);
      expect(capturedRowId, 'cafe-1');
      expect(capturedPayload?['is_deleted'], isTrue);
      expect(capturedPayload?['deleted_at'], isA<String>());
      expect(capturedPayload?['is_featured'], isFalse);
      expect(capturedPayload?['deleted_by'], 'admin-1');
      expect(result.data?.isDeleted, isTrue);
      expect(result.data?.isFeatured, isFalse);
      expect(result.data?.id, 'cafe-1');
    });

    test('softDeleteCafe resolves exact short place id before failing safely',
        () async {
      String? capturedCandidatePlaceId;
      String? updatedRowId;
      final service = CafeCommandService(
        client,
        softDeleteLookupLoader: (cafeId, candidatePlaceId) async {
          capturedCandidatePlaceId = candidatePlaceId;
          if (cafeId == 'short_place_1' ||
              candidatePlaceId == 'short_place_1') {
            return {
              'id': 'db-cafe-1',
              'google_place_id': 'short_place_1',
              'name': 'Cafe One',
              'is_deleted': false,
            };
          }
          return null;
        },
        softDeleteUpdateLoader: (cafeId, payload) async {
          updatedRowId = cafeId;
          return {
            'id': cafeId,
            'google_place_id': 'short_place_1',
            'name': 'Cafe One',
            ...payload,
          };
        },
      );

      final result = await service.softDeleteCafe(cafeId: 'short_place_1');

      expect(result.ok, isTrue);
      expect(capturedCandidatePlaceId, isNull);
      expect(updatedRowId, 'db-cafe-1');
      expect(result.data?.placeId, 'short_place_1');
      expect(result.data?.isDeleted, isTrue);
      expect(result.data?.isFeatured, isFalse);
    });

    test(
        'softDeleteCafe does not create tombstone for unresolved name-only input',
        () async {
      final service = CafeCommandService(
        client,
        softDeleteLookupLoader: (cafeId, candidatePlaceId) async => null,
      );

      final result = await service.softDeleteCafe(cafeId: 'Brew Lab');

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.notFound);
      expect(result.message, 'Cannot delete: missing stable id/place_id');
    });

    test('softDeleteCafe uses tombstone for Google-only cafe with placeId',
        () async {
      Map<String, dynamic>? capturedPayload;
      String? capturedPlaceId;
      final service = CafeCommandService(
        client,
        softDeleteLookupLoader: (cafeId, candidatePlaceId) async => null,
        tombstoneLoader: (googlePlaceId, payload) async {
          capturedPlaceId = googlePlaceId;
          capturedPayload = payload;
          return payload; // Return the payload to simulate successful insert/update
        },
      );

      final result = await service.softDeleteCafe(
        cafeId: 'ChIxyz123',
      );

      expect(result.ok, isTrue);
      expect(capturedPlaceId, 'ChIxyz123');
      expect(capturedPayload?['google_place_id'], 'ChIxyz123');
      expect(capturedPayload?['is_deleted'], isTrue);
      expect(result.data?.id, 'deleted-google-ChIxyz123');
      expect(result.data?.isDeleted, isTrue);
    });

    test('softDeleteCafe uses tombstone when update returns zero rows',
        () async {
      Map<String, dynamic>? capturedPayload;
      String? capturedPlaceId;
      final service = CafeCommandService(
        client,
        softDeleteLookupLoader: (cafeId, candidatePlaceId) async => {
          'id': 'cafe-1',
          'google_place_id': 'place-1',
          'name': 'Cafe One',
          'is_deleted': false,
        },
        softDeleteUpdateLoader: (cafeId, payload) async =>
            null, // Zero rows updated
        tombstoneLoader: (googlePlaceId, payload) async {
          capturedPlaceId = googlePlaceId;
          capturedPayload = payload;
          return payload;
        },
      );

      final result = await service.softDeleteCafe(
        cafeId: 'cafe-1',
        externalPlaceId: 'place-1',
      );

      expect(result.ok, isTrue);
      expect(capturedPlaceId, 'place-1');
      expect(capturedPayload?['is_deleted'], isTrue);
      expect(result.data?.isDeleted, isTrue);
      expect(result.data?.id, 'deleted-google-place-1');
    });

    test('softDeleteCafe fails clearly when no id and no google_place_id',
        () async {
      final service = CafeCommandService(
        client,
        softDeleteLookupLoader: (cafeId, candidatePlaceId) async => null,
      );

      final result = await service.softDeleteCafe(
        cafeId: 'Brew Lab',
      );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.notFound);
      expect(result.message, 'Cannot delete: missing stable id/place_id');
    });

    test('addCafe returns parsed cafes on success', () async {
      final service = CafeCommandService(
        client,
        addCafeLoader: (payload) async => {
          ...payload,
          'id': 'cafe-new',
          'rating': 4.7,
          'review_count': 8,
          'coordinates': {'lat': 41.0, 'lng': 29.0},
        },
      );

      final result = await service.addCafe(_buildCafeInput());

      expect(result.ok, isTrue);
      expect(result.data?.id, 'cafe-new');
      expect(result.data?.name, 'Cafe Input');
    });

    test('addCafe generates an id before insert', () async {
      late Map<String, dynamic> submittedPayload;
      final service = CafeCommandService(
        client,
        addCafeLoader: (payload) async {
          submittedPayload = Map<String, dynamic>.from(payload);
          return {
            ...payload,
            'rating': 4.7,
            'review_count': 8,
            'coordinates': {'lat': 41.0, 'lng': 29.0},
          };
        },
      );

      final result = await service.addCafe(_buildCafeInput());

      expect(result.ok, isTrue);
      expect(submittedPayload['id'], isA<String>());
      expect((submittedPayload['id'] as String).trim(), isNotEmpty);
      expect(result.data?.id, submittedPayload['id']);
    });

    test('CafeAdminUpdateInput writes only is_featured for featured state', () {
      final row = CafeAdminUpdateInput(
        isFeatured: true,
        featuredPriority: 9,
        featuredUntil: DateTime.parse('2099-01-01T00:00:00Z'),
        featuredLabel: '  Sponsored  ',
      ).toRow();

      expect(row['is_featured'], isTrue);
      expect(row, isNot(contains('featured_priority')));
      expect(row, isNot(contains('featured_until')));
      expect(row, isNot(contains('featured_label')));
    });

    test('CafeAdminUpdateInput ignores removed featured metadata columns', () {
      final row = const CafeAdminUpdateInput(
        clearFeaturedUntil: true,
        featuredLabel: '   ',
      ).toRow();

      expect(row, isNot(contains('featured_until')));
      expect(row, isNot(contains('featured_label')));
    });

    test('CafeAdminUpdateInput preserves google_place_id for imports', () {
      final row = const CafeAdminUpdateInput(
        name: 'Imported Cafe',
        googlePlaceId: '  place-import-1  ',
        ownerUserId: '',
        isDeleted: false,
        isFeatured: false,
      ).toRow();

      expect(row['google_place_id'], 'place-import-1');
      expect(row['owner_user_id'], isNull);
      expect(row['is_deleted'], isFalse);
      expect(row['is_featured'], isFalse);
    });
  });

  group('SecurityReadinessService', () {
    final client = SupabaseClient('https://example.com', 'anon-key');

    test('verifyCafeRlsReadiness parses a healthy readiness payload', () async {
      final service = SecurityReadinessService(
        client,
        readinessProbe: () async => <String, dynamic>{
          'is_ready': true,
          'rls_enabled': true,
          'has_admin_insert_policy': true,
          'has_admin_update_policy': true,
          'message': 'Security readiness check passed.',
        },
      );

      final report = await service.verifyCafeRlsReadiness();

      expect(report.isReady, isTrue);
      expect(report.checkAvailable, isTrue);
      expect(report.failureType, isNull);
      expect(report.message, 'Security readiness check passed.');
    });

    test('verifyCafeRlsReadiness accepts RPC payload wrapped as one row',
        () async {
      final service = SecurityReadinessService(
        client,
        readinessProbe: () async => [
          <String, dynamic>{
            'is_ready': true,
            'rls_enabled': true,
            'has_admin_insert_policy': true,
            'has_admin_update_policy': true,
            'message': 'Security readiness check passed.',
          },
        ],
      );

      final report = await service.verifyCafeRlsReadiness();

      expect(report.isReady, isTrue);
      expect(report.checkAvailable, isTrue);
      expect(report.hasAdminInsertPolicy, isTrue);
      expect(report.hasAdminUpdatePolicy, isTrue);
    });

    test('readiness SQL checks admin policy semantics, not exact names', () {
      final source =
          File('supabase/security_readiness_function.sql').readAsStringSync();

      expect(
          source, isNot(contains("p.policyname = 'Admins can insert cafes'")));
      expect(
          source, isNot(contains("p.policyname = 'Admins can update cafes'")));
      expect(source,
          contains("lower(COALESCE(p.with_check, '')) LIKE '%profiles%'"));
      expect(source, contains("lower(COALESCE(p.qual, '')) LIKE '%auth.uid%'"));
    });

    test(
        'verifyCafeRlsReadiness maps connectivity failures to a specific message',
        () async {
      final service = SecurityReadinessService(
        client,
        readinessProbe: () async {
          throw const SocketException('No route to host');
        },
      );

      final report = await service.verifyCafeRlsReadiness();

      expect(report.isReady, isFalse);
      expect(report.checkAvailable, isFalse);
      expect(report.failureType, ServiceErrorType.network);
      expect(report.message, contains('network/connectivity'));
    });

    test('verifyCafeRlsReadiness maps timeouts distinctly', () async {
      final service = SecurityReadinessService(
        client,
        readinessProbe: () async {
          throw TimeoutException('timed out');
        },
      );

      final report = await service.verifyCafeRlsReadiness();

      expect(report.isReady, isFalse);
      expect(report.checkAvailable, isFalse);
      expect(report.failureType, ServiceErrorType.timeout);
      expect(report.message, contains('timed out'));
    });

    test(
        'transient readiness probe failures are non-blocking warnings in runtime semantics',
        () {
      const report = SecurityReadinessReport(
        isReady: false,
        checkAvailable: false,
        rlsEnabled: false,
        hasAdminInsertPolicy: false,
        hasAdminUpdatePolicy: false,
        message: 'Readiness probe timed out.',
        failureType: ServiceErrorType.timeout,
      );

      expect(report.isTransientProbeFailure, isTrue);
      expect(report.shouldShowRuntimeWarning, isFalse);
      expect(report.blocksAdminMutations, isFalse);
    });

    test('configuration readiness failures remain blocking runtime warnings',
        () {
      const report = SecurityReadinessReport(
        isReady: false,
        checkAvailable: false,
        rlsEnabled: false,
        hasAdminInsertPolicy: false,
        hasAdminUpdatePolicy: false,
        message: 'Missing app_security_readiness migration.',
        failureType: ServiceErrorType.unavailable,
        isConfigurationFailure: true,
      );

      expect(report.isTransientProbeFailure, isFalse);
      expect(report.shouldShowRuntimeWarning, isTrue);
      expect(report.blocksAdminMutations, isTrue);
    });

    test('transient readiness probe failures do not trigger runtime warning',
        () {
      const report = SecurityReadinessReport(
        isReady: false,
        checkAvailable: false,
        rlsEnabled: false,
        hasAdminInsertPolicy: false,
        hasAdminUpdatePolicy: false,
        message: 'Network error while probing readiness.',
        failureType: ServiceErrorType.network,
      );

      expect(report.isTransientProbeFailure, isTrue);
      expect(report.shouldShowRuntimeWarning, isFalse);
      expect(report.blocksAdminMutations, isFalse);
    });

    test('definitive readiness failures still trigger warning and block', () {
      const report = SecurityReadinessReport(
        isReady: false,
        checkAvailable: true,
        rlsEnabled: false,
        hasAdminInsertPolicy: false,
        hasAdminUpdatePolicy: false,
        message: 'RLS policy missing.',
      );

      expect(report.isTransientProbeFailure, isFalse);
      expect(report.shouldShowRuntimeWarning, isTrue);
      expect(report.blocksAdminMutations, isTrue);
    });

    test(
        'configuration readiness failures remain warning-worthy even when probe is unavailable',
        () {
      const report = SecurityReadinessReport(
        isReady: false,
        checkAvailable: false,
        rlsEnabled: false,
        hasAdminInsertPolicy: false,
        hasAdminUpdatePolicy: false,
        message: 'Missing app_security_readiness() database function.',
        failureType: ServiceErrorType.unavailable,
        isConfigurationFailure: true,
      );

      expect(report.isTransientProbeFailure, isFalse);
      expect(report.shouldShowRuntimeWarning, isTrue);
      expect(report.blocksAdminMutations, isTrue);
    });
  });

  group('ProfilesService', () {
    final service = ProfilesService(
      SupabaseClient('https://example.com', 'anon-key'),
    );

    test('uploadAvatar rejects unsupported extension', () async {
      final result = await service.uploadAvatar(
        userId: 'user-1',
        bytes: _tinyPngBytes,
        fileExtension: 'exe',
      );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.validation);
      expect(result.errorCode, AppErrorCode.validationFailed);
      expect(result.message, contains('Unsupported avatar file type'));
    });

    test('uploadAvatar rejects oversized payloads', () async {
      final result = await service.uploadAvatar(
        userId: 'user-1',
        bytes: Uint8List(kMaxAvatarUploadBytes + 1),
        fileExtension: 'png',
      );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.validation);
      expect(result.errorCode, AppErrorCode.validationFailed);
      expect(result.message, contains('Maximum allowed size'));
    });

    test('uploadAvatar rejects malformed payloads for allowed extensions',
        () async {
      final result = await service.uploadAvatar(
        userId: 'user-1',
        bytes: Uint8List.fromList(const <int>[0x00, 0x01, 0x02, 0x03]),
        fileExtension: 'png',
      );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.validation);
      expect(result.errorCode, AppErrorCode.validationFailed);
      expect(result.message, contains('content is invalid'));
    });

    test('uploadAvatar accepts a valid supported image', () async {
      String? uploadedPath;
      FileOptions? uploadedOptions;
      final uploadService = ProfilesService(
        SupabaseClient('https://example.com', 'anon-key'),
        avatarBinaryUploader: ({
          required path,
          required bytes,
          required fileOptions,
        }) async {
          uploadedPath = path;
          uploadedOptions = fileOptions;
          expect(bytes, _tinyPngBytes);
        },
      );

      final result = await uploadService.uploadAvatar(
        userId: 'user-1',
        bytes: _tinyPngBytes,
        fileExtension: '.png',
      );

      expect(result.ok, isTrue);
      expect(uploadedPath, isNotNull);
      expect(uploadedPath, contains('profiles/user-1/avatar_'));
      expect(uploadedPath, endsWith('.png'));
      expect(uploadedOptions?.contentType, 'image/png');
      expect(result.data?.path, uploadedPath);
      expect(result.data?.publicUrl,
          contains('/storage/v1/object/public/avatars/'));
    });

    test('extractAvatarObjectPath keeps raw storage paths intact', () {
      expect(
        service.extractAvatarObjectPath('profiles/user-1/avatar.png'),
        'profiles/user-1/avatar.png',
      );
    });

    test('extractAvatarObjectPath parses public avatar URLs', () {
      expect(
        service.extractAvatarObjectPath(
          'https://example.supabase.co/storage/v1/object/public/avatars/profiles/user-1/avatar.png',
        ),
        'profiles/user-1/avatar.png',
      );
    });

    test('extractAvatarObjectPath parses signed avatar URLs', () {
      expect(
        service.extractAvatarObjectPath(
          'https://example.supabase.co/storage/v1/object/sign/avatars/profiles/user-1/avatar.png?token=abc',
        ),
        'profiles/user-1/avatar.png',
      );
    });

    test('extractAvatarObjectPath rejects unrelated buckets', () {
      expect(
        service.extractAvatarObjectPath(
          'https://example.supabase.co/storage/v1/object/public/cafes/profiles/user-1/avatar.png',
        ),
        isNull,
      );
    });
  });
}

Map<String, dynamic> _cafeRow({
  required String id,
  required String name,
  double rating = 4.2,
  bool isFeatured = false,
  bool? isDeleted = false,
  DateTime? deletedAt,
}) {
  return {
    'id': id,
    'google_place_id': '$id-place',
    'name': name,
    'category': 'normal_cafe',
    'district': 'Kadikoy',
    'neighborhood': 'Moda',
    'address': 'Moda, Kadikoy',
    'rating': rating,
    'review_count': 10,
    'price_level': '\$\$',
    'wifi_quality': 'strong',
    'outlet_availability': 'high',
    'quietness_level': 'quiet',
    'study_friendly': true,
    'pet_friendly': false,
    'outdoor_seating': true,
    'smoking_policy': 'not_allowed',
    'is_deleted': isDeleted,
    'deleted_at': deletedAt?.toIso8601String(),
    'is_featured': isFeatured,
    'tags': <String>[],
    'images': <String>[],
    'coordinates': {'lat': 41.0, 'lng': 29.0},
  };
}

CafeAdminUpdateInput _buildCafeInput({String name = 'Cafe Input'}) {
  return CafeAdminUpdateInput(
    name: name,
    category: 'normal_cafe',
    district: 'Kadikoy',
    neighborhood: 'Moda',
    address: 'Moda, Kadikoy',
    description: 'A nice cafe',
    priceLevel: '\$\$',
    tags: const ['Coffee'],
    images: const <String>[],
    openingHours: const <OpeningHour>[],
    wifiQuality: 'strong',
    outletAvailability: 'high',
    quietnessLevel: 'quiet',
    studyFriendly: true,
    petFriendly: false,
    outdoorSeating: true,
    smokingPolicy: 'not_allowed',
    menuHighlights: const ['Latte'],
  );
}
