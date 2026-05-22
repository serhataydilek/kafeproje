import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kafeproje/constants/error_codes.dart';
import 'package:kafeproje/l10n/app_localizations.dart';
import 'package:kafeproje/models/async_result.dart' as async_result;
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/models/service_result.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'package:kafeproje/screens/admin_screen.dart';
import 'package:kafeproje/screens/cafe_edit_screen.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/filter_sort.dart';
import 'package:kafeproje/utils/request_cancellation.dart';
import 'package:kafeproje/utils/service_error.dart';
import 'package:kafeproje/utils/text_normalization.dart';
import 'package:kafeproje/widgets/admin/admin_logic.dart';
import 'package:kafeproje/widgets/ui/state_views.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_helpers.dart';

Finder _textFieldIn(Key key) {
  return find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextField),
  );
}

String _textFieldText(WidgetTester tester, Key key) {
  return tester.widget<TextField>(_textFieldIn(key)).controller?.text ?? '';
}

Future<void> _scrollEditFormUntilFound(
    WidgetTester tester, Finder finder) async {
  for (var attempts = 0;
      attempts < 10 && finder.evaluate().isEmpty;
      attempts++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
  }
}

class _FakeProfilesService extends ProfilesService {
  _FakeProfilesService(this._profiles)
      : super(
          SupabaseClient(
            'https://example.com',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final List<UserProfile> _profiles;

  @override
  Future<ServiceResult<List<UserProfile>>> fetchProfiles() async {
    return ServiceResult.success(data: _profiles);
  }

  @override
  Future<ServiceResult<UserProfile?>> fetchProfileById(String userId) async {
    for (final profile in _profiles) {
      if (profile.id == userId) {
        return ServiceResult.success(data: profile);
      }
    }
    return ServiceResult.failure(
      message: 'Profile not found.',
      errorType: ServiceErrorType.notFound,
    );
  }
}

class _DelayedProfilesService extends ProfilesService {
  _DelayedProfilesService(this._profiles, this.delay)
      : super(
          SupabaseClient(
            'https://example.com',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final List<UserProfile> _profiles;
  final Duration delay;

  @override
  Future<ServiceResult<List<UserProfile>>> fetchProfiles() async {
    await Future<void>.delayed(delay);
    return ServiceResult.success(data: _profiles);
  }
}

typedef _FetchAdminCafesHandler = Future<ServiceResult<AdminCafePage>>
    Function({
  required String searchQuery,
  required String district,
  required String status,
  required int limit,
  required int offset,
  Duration? requestTimeout,
  RequestCancellationToken? cancellationToken,
});

class _FakeCafeQueryService extends CafeQueryService {
  _FakeCafeQueryService(
    this._cafes, {
    this.throwOnDiscoverableFetch = false,
    this.onFetchAdminCafes,
  }) : super(
          SupabaseClient(
            'https://example.com',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final List<Cafe> _cafes;
  final bool throwOnDiscoverableFetch;
  final _FetchAdminCafesHandler? onFetchAdminCafes;
  int fetchDiscoverableCallCount = 0;
  int fetchAdminCallCount = 0;

  @override
  Future<ServiceResult<List<Cafe>>> fetchDiscoverableCafes({
    String? district,
    int limit = 800,
    int offset = 0,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    fetchDiscoverableCallCount += 1;
    if (throwOnDiscoverableFetch) {
      return ServiceResult.failure(
        message: 'Discoverable fetch should not be used in admin flow.',
      );
    }

    final normalizedDistrict = district?.trim();
    final filtered = _cafes
        .where((cafe) {
          if (!cafe.isVisibleInPublic) {
            return false;
          }
          if (normalizedDistrict == null || normalizedDistrict.isEmpty) {
            return true;
          }
          return cafe.district.toLowerCase() ==
              normalizedDistrict.toLowerCase();
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
    final normalizedDistrict = district?.trim();
    final filtered = _cafes
        .where((cafe) => cafe.isActiveFeatured)
        .where((cafe) {
          if (normalizedDistrict == null || normalizedDistrict.isEmpty) {
            return true;
          }
          return cafe.district.toLowerCase() ==
              normalizedDistrict.toLowerCase();
        })
        .take(limit)
        .toList(growable: false);
    return ServiceResult.success(data: filtered);
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafes() async {
    return ServiceResult.success(data: _cafes);
  }

  @override
  Future<ServiceResult<AdminCafePage>> fetchAdminCafes({
    String searchQuery = '',
    String district = 'all',
    String status = 'all',
    int limit = 60,
    int offset = 0,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    fetchAdminCallCount += 1;
    final handler = onFetchAdminCafes;
    if (handler != null) {
      return handler(
        searchQuery: searchQuery,
        district: district,
        status: status,
        limit: limit,
        offset: offset,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );
    }

    final q = searchQuery.trim().toLowerCase();
    final d = district.trim().toLowerCase();
    final filtered = _cafes.where((cafe) {
      if (q.isNotEmpty &&
          !cafe.name.toLowerCase().contains(q) &&
          !cafe.district.toLowerCase().contains(q) &&
          !cafe.neighborhood.toLowerCase().contains(q)) {
        return false;
      }
      if (d.isNotEmpty && d != 'all' && cafe.district.toLowerCase() != d) {
        return false;
      }
      if (status == 'visible' && !cafe.isVisibleInPublic) {
        return false;
      }
      if (status == 'hidden' && (cafe.isDeleted || cafe.isVisibleInPublic)) {
        return false;
      }
      if (status == 'deleted' && !cafe.isDeleted) {
        return false;
      }
      if (status == 'all' && cafe.isDeleted) {
        return false;
      }
      return true;
    }).toList(growable: false);

    final page = filtered.skip(offset).take(limit).toList(growable: false);
    final hasMore = offset + page.length < filtered.length;
    return ServiceResult.success(
      data: AdminCafePage(
        cafes: page,
        hasMore: hasMore,
        offset: offset,
        limit: limit,
      ),
    );
  }

  @override
  Future<ServiceResult<Cafe?>> fetchCafeDetails(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    for (final cafe in _cafes) {
      if (cafe.id == cafeId || cafe.placeId == cafeId) {
        return ServiceResult.success(data: cafe);
      }
    }
    return ServiceResult.success(data: null);
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
}

class _FakeCafeCommandService extends CafeCommandService {
  _FakeCafeCommandService(
    this._cafesById,
    this.onUpdate, {
    this.onSoftDelete,
    this.onRestore,
    this.onAdd,
  }) : super(
          SupabaseClient(
            'https://example.com',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final Map<String, Cafe> _cafesById;
  final void Function(String cafeId, CafeAdminUpdateInput input) onUpdate;
  final Future<ServiceResult<Cafe>> Function(
    String cafeId,
    String? externalPlaceId,
    String? deletedBy,
  )? onSoftDelete;
  final Future<ServiceResult<Cafe>> Function(String cafeId)? onRestore;
  final void Function(Cafe cafe)? onAdd;

  int softDeleteCallCount = 0;
  int restoreCallCount = 0;
  int addCallCount = 0;
  CafeAdminUpdateInput? lastAddInput;

  String? _resolveCafeKey(String cafeId, String? externalPlaceId) {
    final normalizedCafeId = cafeId.trim();
    if (_cafesById.containsKey(normalizedCafeId)) {
      return normalizedCafeId;
    }

    final normalizedExternalPlaceId = externalPlaceId?.trim();
    if (normalizedExternalPlaceId != null &&
        normalizedExternalPlaceId.isNotEmpty) {
      for (final entry in _cafesById.entries) {
        if (entry.value.placeId?.trim() == normalizedExternalPlaceId) {
          return entry.key;
        }
      }
    }

    for (final entry in _cafesById.entries) {
      if (entry.value.placeId?.trim() == normalizedCafeId) {
        return entry.key;
      }
    }

    return null;
  }

  @override
  Future<ServiceResult<Cafe>> updateCafeByAdmin(
    String cafeId,
    CafeAdminUpdateInput input,
  ) async {
    onUpdate(cafeId, input);
    final resolvedKey = _resolveCafeKey(cafeId, null) ?? cafeId;
    final current = _cafesById[resolvedKey];
    final updated =
        (current ?? buildTestCafe(id: resolvedKey, name: 'Updated Cafe'))
            .copyWith(
      name: input.name ?? current?.name,
      district: input.district ?? current?.district,
      neighborhood: input.neighborhood ?? current?.neighborhood,
      address: input.address ?? current?.address,
      description: input.description ?? current?.description,
      tags: input.tags ?? current?.tags,
      images: input.images ?? current?.images,
      priceLevel: input.priceLevel,
      wifiQuality: input.wifiQuality,
      outletAvailability: input.outletAvailability,
      quietnessLevel: input.quietnessLevel,
      studyFriendly: input.studyFriendly,
      petFriendly: input.petFriendly,
      outdoorSeating: input.outdoorSeating,
      smokingPolicy: input.smokingPolicy,
      openingHours: input.openingHours,
      isFeatured: input.isFeatured,
      featuredPriority: input.featuredPriority,
      featuredUntil: input.clearFeaturedUntil
          ? () => null
          : input.featuredUntil == null
              ? null
              : () => input.featuredUntil,
      featuredLabel: input.featuredLabel == null
          ? null
          : () => input.featuredLabel?.trim().isEmpty == true
              ? null
              : input.featuredLabel?.trim(),
    );
    _cafesById[resolvedKey] = updated;
    return ServiceResult.success(data: updated);
  }

  @override
  Future<ServiceResult<Cafe>> addCafe(CafeAdminUpdateInput input) async {
    addCallCount += 1;
    lastAddInput = input;
    final placeId = input.googlePlaceId?.trim();
    if (placeId != null && placeId.isNotEmpty) {
      final duplicate = _cafesById.values.any(
        (cafe) => cafe.placeId?.trim() == placeId,
      );
      if (duplicate) {
        return ServiceResult.failure(
          message: 'Cafe already exists in Supabase.',
          errorCode: AppErrorCode.dataConflict,
          errorType: ServiceErrorType.conflict,
        );
      }
    }
    final id = 'imported-$addCallCount';
    final imported = buildTestCafe(
      id: id,
      name: input.name ?? 'Imported Cafe',
      district: input.district ?? 'Kadikoy',
      neighborhood: input.neighborhood ?? '',
      images: input.images ?? const <String>[],
    ).copyWith(
      address: input.address,
      placeId: placeId,
      isDeleted: input.isDeleted ?? false,
      ownerApprovalStatus: input.ownerApprovalStatus,
      isFeatured: input.isFeatured ?? false,
    );
    _cafesById[id] = imported;
    onAdd?.call(imported);
    return ServiceResult.success(data: imported);
  }

  @override
  Future<ServiceResult<Cafe>> softDeleteCafe({
    required String cafeId,
    String? externalPlaceId,
    String? deletedBy,
  }) async {
    softDeleteCallCount += 1;
    if (onSoftDelete != null) {
      return onSoftDelete!(cafeId, externalPlaceId, deletedBy);
    }

    final key = _resolveCafeKey(cafeId, externalPlaceId);
    if (key == null) {
      return ServiceResult.failure(
        message: 'Cafe row not found for delete.',
      );
    }

    final current = _cafesById[key]!;
    final updated = current.copyWith(
      isDeleted: true,
      ownerApprovalStatus: 'approved',
    );
    _cafesById[key] = updated;
    return ServiceResult.success(data: updated);
  }

  @override
  Future<ServiceResult<Cafe>> restoreCafe({required String cafeId}) async {
    restoreCallCount += 1;
    if (onRestore != null) {
      return onRestore!(cafeId);
    }

    final key = _resolveCafeKey(cafeId, null);
    if (key == null) {
      return ServiceResult.failure(
        message: 'Cafe row not found for restore.',
      );
    }

    final current = _cafesById[key]!;
    final updated = current.copyWith(
      isDeleted: false,
      ownerApprovalStatus: 'approved',
    );
    _cafesById[key] = updated;
    return ServiceResult.success(data: updated);
  }
}

void main() {
  group('admin screen', () {
    testWidgets(
      'shows blocked state for non-admin users',
      (tester) async {
        final container = createTestContainer(
          state: buildTestAppShellState(isAdmin: false),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(initialTab: AdminTab.users),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('admin-back-button')), findsNothing);
        expect(find.text('Access denied'), findsOneWidget);
      },
    );

    testWidgets(
      'normal users and cafe owners cannot access discovered import',
      (tester) async {
        final discovered = buildTestCafe(
          id: 'google-only-1',
          name: 'Google Only Cafe',
        ).copyWith(placeId: 'place-google-only-1');
        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: false,
            cafes: [discovered],
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(const [
                UserProfile(
                  id: 'owner-1',
                  username: 'owner',
                  firstName: 'Cafe',
                  lastName: 'Owner',
                  fullName: 'Cafe Owner',
                  email: 'owner@example.com',
                  role: ProfileRole.cafeOwner,
                  createdAt: '2024-01-01T00:00:00Z',
                ),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(initialTab: AdminTab.discovered),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('admin-tab-discovered')), findsNothing);
        expect(find.text('Google Only Cafe'), findsNothing);
        expect(find.text('Access denied'), findsOneWidget);
      },
    );

    testWidgets(
      'admin sees discovered cafes tab and excludes already saved cafes',
      (tester) async {
        final saved = buildTestCafe(
          id: 'saved-1',
          name: 'Saved Cafe',
        ).copyWith(placeId: 'place-saved-1');
        final unsaved = buildTestCafe(
          id: 'google-only-2',
          name: 'Unsaved Discovery',
          images: const ['https://example.com/discovered.jpg'],
        ).copyWith(placeId: 'place-unsaved-2');
        final savedRows = <Cafe>[saved];
        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: [saved, unsaved],
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(const []),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(savedRows),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(initialTab: AdminTab.discovered),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('admin-tab-discovered')), findsOneWidget);
        expect(find.text('Unsaved Discovery'), findsOneWidget);
        expect(find.text('Saved Cafe'), findsNothing);
        expect(
          find.byKey(const Key('admin-discovered-import-place-unsaved-2')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'admin imports discovered cafe once and moves it to admin cafes',
      (tester) async {
        final discovered = buildTestCafe(
          id: 'google-only-3',
          name: 'Importable Discovery',
          images: const ['https://example.com/importable.jpg'],
        ).copyWith(placeId: 'place-importable-3');
        final savedRows = <Cafe>[];
        final savedById = <String, Cafe>{};
        late _FakeCafeCommandService commandService;
        commandService = _FakeCafeCommandService(
          savedById,
          (_, __) {},
          onAdd: savedRows.add,
        );
        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: [discovered],
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(const []),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(savedRows),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(initialTab: AdminTab.discovered),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('admin-discovered-import-place-importable-3')),
        );
        await tester.pumpAndSettle();

        expect(commandService.addCallCount, 1);
        expect(
            commandService.lastAddInput?.googlePlaceId, 'place-importable-3');
        expect(commandService.lastAddInput?.ownerUserId, isNull);
        expect(
          commandService.lastAddInput?.images,
          ['https://example.com/importable.jpg'],
        );
        expect(commandService.lastAddInput?.isDeleted, isFalse);
        expect(commandService.lastAddInput?.isFeatured, isFalse);
        expect(savedRows.single.placeId, 'place-importable-3');
        expect(
          find.byKey(const Key('admin-discovered-import-place-importable-3')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();

        expect(find.text('Importable Discovery'), findsOneWidget);
        expect(commandService.addCallCount, 1);
      },
    );

    testWidgets(
      'saved cafes load more when additional admin rows exist',
      (tester) async {
        final allCafes = List.generate(
          65,
          (index) => buildTestCafe(
            id: 'admin-cafe-$index',
            name: 'Admin Cafe $index',
          ).copyWith(placeId: 'place-admin-$index'),
        );
        final container = createTestContainer(
          state: buildTestAppShellState(isAdmin: true),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(const []),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(
                allCafes,
                onFetchAdminCafes: ({
                  required String searchQuery,
                  required String district,
                  required String status,
                  required int limit,
                  required int offset,
                  Duration? requestTimeout,
                  RequestCancellationToken? cancellationToken,
                }) async {
                  final page = allCafes
                      .skip(offset)
                      .take(limit)
                      .toList(growable: false);
                  final hasMore = offset + page.length < allCafes.length;
                  return ServiceResult.success(
                    data: AdminCafePage(
                      cafes: page,
                      hasMore: hasMore,
                      offset: offset,
                      limit: limit,
                    ),
                  );
                },
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(initialTab: AdminTab.cafes),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Admin Cafe 0'), findsOneWidget);
        expect(find.text('Admin Cafe 64'), findsNothing);
        expect(find.text('Load more'), findsOneWidget);

        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();

        expect(find.text('Admin Cafe 64'), findsOneWidget);
      },
    );

    testWidgets(
      'discovered cafes aggregate across cache and featured sources',
      (tester) async {
        final cached = buildTestCafe(
          id: 'cache-1',
          name: 'Cached Discovery',
          images: const ['https://example.com/cache.jpg'],
        ).copyWith(placeId: 'place-cache-1');
        final home = buildTestCafe(
          id: 'home-1',
          name: 'Home Discovery',
          images: const ['https://example.com/home.jpg'],
        ).copyWith(placeId: 'place-home-1');
        final featured = buildTestCafe(
          id: 'featured-1',
          name: 'Featured Discovery',
        ).copyWith(
          placeId: 'place-featured-1',
          isFeatured: true,
          ownerApprovalStatus: 'approved',
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: [cached],
            homeCafes: [home],
            featuredCafes: [featured],
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(const []),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(const []),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(initialTab: AdminTab.discovered),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cached Discovery'), findsOneWidget);
        expect(find.text('Home Discovery'), findsOneWidget);
        expect(find.text('Featured Discovery'), findsOneWidget);
      },
    );

    test(
      'duplicate discovered import is prevented for existing Supabase cafes',
      () async {
        final saved = buildTestCafe(
          id: 'saved-dup',
          name: 'Saved Duplicate',
        ).copyWith(placeId: 'place-dup-1');
        final discovered = buildTestCafe(
          id: 'dup-discovered',
          name: 'Duplicate Discovery',
        ).copyWith(placeId: 'place-dup-1');
        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: [discovered],
          ),
          overrides: [
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService([saved]),
            ),
            cafeCommandServiceProvider.overrideWithValue(
              _FakeCafeCommandService({saved.id: saved}, (_, __) {}),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(cafeAdminMutationControllerProvider.notifier)
            .importDiscoveredCafe(discovered);

        expect(result.ok, isFalse);
        expect(result.errorType, ServiceErrorType.conflict);
      },
    );

    testWidgets(
      'shows loading state while profiles are still loading',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Stone',
            fullName: 'Alice Stone',
            email: 'alice@example.com',
            role: ProfileRole.user,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _DelayedProfilesService(
                profiles,
                const Duration(milliseconds: 200),
              ),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(initialTab: AdminTab.users),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.text('Alice Stone'), findsOneWidget);
      },
    );

    testWidgets(
      'unresolved admin role can recover to admin UI without downgrade',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice-admin',
            firstName: 'Alice',
            lastName: 'Admin',
            fullName: 'Alice Admin',
            email: 'alice.admin@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: false,
            isAdminRoleResolved: false,
            adminRoleStatusMessage: null,
            cafes: cafes,
            currentUser: testUser,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(initialTab: AdminTab.users),
          ),
        );
        await tester.pump();

        expect(find.byType(LoadingStateView), findsOneWidget);
        expect(find.byKey(const Key('admin-tab-users')), findsNothing);

        await container
            .read(appShellProvider.notifier)
            .refreshAdminRoleResolution(force: true);
        await tester.pumpAndSettle();

        expect(find.byType(LoadingStateView), findsNothing);
        expect(find.byKey(const Key('admin-tab-users')), findsOneWidget);
      },
    );

    testWidgets(
      'exposes clear search and cafe action buttons',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Stone',
            fullName: 'Alice Stone',
            email: 'alice@example.com',
            role: ProfileRole.user,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(initialTab: AdminTab.users),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('admin-back-button')), findsOneWidget);
        expect(find.byKey(const Key('admin-tab-users')), findsOneWidget);
        expect(find.byKey(const Key('admin-tab-cafes')), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'alice');
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('admin-user-search-clear')), findsOneWidget);

        await tester.tap(find.byKey(const Key('admin-user-search-clear')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('admin-user-search-clear')), findsNothing);

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('admin-add-cafe-button')), findsOneWidget);
        expect(find.byKey(const Key('admin-cafe-edit-cafe-1')), findsOneWidget);
        expect(find.byKey(const Key('admin-supabase-managed-label')),
            findsOneWidget);
        expect(find.text('Saved Cafes (1)'), findsOneWidget);
      },
    );

    testWidgets(
      'admin back button at root route goes home without GoRouter pop error',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'admin-1',
            username: 'admin',
            firstName: 'Admin',
            lastName: 'User',
            fullName: 'Admin User',
            email: 'admin@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [buildTestCafe(id: 'cafe-1', name: 'Brew Lab')];
        final container = createTestContainer(
          state: buildTestAppShellState(isAdmin: true, cafes: cafes),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          initialLocation: '/admin',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Home Route')),
            ),
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestRouterApp(container: container, router: router),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-back-button')));
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(exception?.toString(), isNot(contains('nothing to pop')));
        expect(find.text('Home Route'), findsOneWidget);
      },
    );

    testWidgets(
      'admin with no tab defaults to cafe management',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'admin-1',
            username: 'admin',
            firstName: 'Admin',
            lastName: 'User',
            fullName: 'Admin User',
            email: 'admin@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [buildTestCafe(id: 'cafe-1', name: 'Brew Lab')];
        final container = createTestContainer(
          state: buildTestAppShellState(isAdmin: true, cafes: cafes),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('admin-add-cafe-button')), findsOneWidget);
        expect(find.byKey(const Key('admin-cafe-edit-cafe-1')), findsOneWidget);
        expect(find.text('Admin User'), findsNothing);
      },
    );

    testWidgets(
      'admin list delete remains on cafes tab route',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'admin-1',
            username: 'admin',
            firstName: 'Admin',
            lastName: 'User',
            fullName: 'Admin User',
            email: 'admin@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafe = buildTestCafe(id: 'delete-cafe', name: 'Delete Cafe');
        final queryService = _FakeCafeQueryService([cafe]);
        final commandService = _FakeCafeCommandService(
          <String, Cafe>{cafe.id: cafe},
          (_, __) {},
        );
        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: [cafe],
            currentUser: testUser,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(queryService),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          initialLocation: '/admin',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Home Route')),
            ),
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestRouterApp(container: container, router: router),
        );
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const Key('admin-cafe-action-delete-cafe')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(commandService.softDeleteCallCount, 1);
        expect(router.location, '/admin?tab=cafes');
        expect(find.byKey(const Key('admin-tab-cafes')), findsOneWidget);
        expect(find.byKey(const Key('admin-add-cafe-button')), findsOneWidget);
      },
    );

    testWidgets(
      'renders fallback copy for incomplete user rows',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-2',
            username: null,
            firstName: '',
            lastName: '',
            fullName: '',
            email: 'unknown@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(initialTab: AdminTab.users),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unnamed user'), findsOneWidget);
        expect(find.text('unknown@example.com'), findsOneWidget);
      },
    );

    testWidgets(
      'cafes tab search, district filter, edit, and save flow works end-to-end',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Stone',
            fullName: 'Alice Stone',
            email: 'alice@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab', district: 'Kadikoy'),
          buildTestCafe(
              id: 'cafe-2', name: 'North Roast', district: 'Besiktas'),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};

        String? updatedCafeId;
        CafeAdminUpdateInput? updatedInput;

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(
              _FakeCafeCommandService(
                cafesById,
                (cafeId, input) {
                  updatedCafeId = cafeId;
                  updatedInput = input;
                },
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          initialLocation: '/admin',
          routes: [
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminScreen(),
            ),
            GoRoute(
              path: '/cafe-edit/:id',
              builder: (_, state) => CafeEditScreen(
                cafeId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/cafe-add',
              builder: (_, __) => const SizedBox.shrink(),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestRouterApp(container: container, router: router),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('admin-cafe-edit-cafe-1')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('admin-cafe-edit-cafe-2')),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.byKey(const Key('admin-cafe-edit-cafe-2')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byType(TextField).first,
          -120,
          scrollable: find.byType(Scrollable).last,
        );

        await tester.enterText(find.byType(TextField).first, 'North');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('admin-cafe-edit-cafe-2')), findsOneWidget);
        expect(find.byKey(const Key('admin-cafe-edit-cafe-1')), findsNothing);

        await tester.tap(find.byKey(const Key('admin-user-search-clear')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-cafe-district-Kadikoy')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('admin-cafe-edit-cafe-1')), findsOneWidget);
        expect(find.byKey(const Key('admin-cafe-edit-cafe-2')), findsNothing);

        await tester.tap(find.byKey(const Key('admin-cafe-edit-cafe-1')));
        await tester.pumpAndSettle();

        expect(find.byType(CafeEditScreen), findsOneWidget);

        await tester.enterText(
            find.byType(TextField).first, 'Brew Lab Updated');
        await tester.pumpAndSettle();

        await _scrollEditFormUntilFound(
          tester,
          find.byKey(const Key('admin-save-action')),
        );
        await tester.tap(find.byKey(const Key('admin-save-action')));
        await tester.pumpAndSettle();

        expect(updatedCafeId, 'cafe-1');
        expect(updatedInput?.name, 'Brew Lab Updated');
        expect(find.byType(AdminScreen), findsOneWidget);
      },
    );

    testWidgets(
      'cafe edit allows empty description and keeps a single save action',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Stone',
            fullName: 'Alice Stone',
            email: 'alice@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab')
              .copyWith(description: ''),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};

        CafeAdminUpdateInput? updatedInput;

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(
              _FakeCafeCommandService(
                cafesById,
                (_, input) => updatedInput = input,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          initialLocation: '/admin',
          routes: [
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminScreen(),
            ),
            GoRoute(
              path: '/cafe-edit/:id',
              builder: (_, state) => CafeEditScreen(
                cafeId: state.pathParameters['id']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestRouterApp(container: container, router: router),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('admin-cafe-edit-cafe-1')));
        await tester.pumpAndSettle();

        expect(find.byType(CafeEditScreen), findsOneWidget);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CafeEditScreen)),
        )!;
        expect(find.widgetWithText(TextButton, l10n.commonSave), findsNothing);

        await _scrollEditFormUntilFound(
          tester,
          find.byKey(const Key('admin-description-input')),
        );

        await tester.enterText(
          _textFieldIn(const Key('admin-description-input')),
          '',
        );
        await tester.pumpAndSettle();

        await _scrollEditFormUntilFound(
          tester,
          find.byKey(const Key('admin-save-action')),
        );

        await tester.tap(find.byKey(const Key('admin-save-action')));
        await tester.pumpAndSettle();

        expect(updatedInput, isNotNull);
        expect(updatedInput?.description, '');
        expect(find.byType(AdminScreen), findsOneWidget);
      },
    );

    testWidgets(
      'cafe edit hydrates and submits featured placement fields',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Stone',
            fullName: 'Alice Stone',
            email: 'alice@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafe = buildTestCafe(id: 'cafe-1', name: 'Brew Lab').copyWith(
          isFeatured: true,
          featuredPriority: 3,
          featuredUntil: () => DateTime.utc(2099, 2, 3),
          featuredLabel: () => 'Sponsored',
        );
        final cafes = [cafe];
        final cafesById = {cafe.id: cafe};

        String? updatedCafeId;
        CafeAdminUpdateInput? updatedInput;

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(
              _FakeCafeCommandService(
                cafesById,
                (cafeId, input) {
                  updatedCafeId = cafeId;
                  updatedInput = input;
                },
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          initialLocation: '/admin',
          routes: [
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminScreen(),
            ),
            GoRoute(
              path: '/cafe-edit/:id',
              builder: (_, state) => CafeEditScreen(
                cafeId: state.pathParameters['id']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestRouterApp(container: container, router: router),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('admin-cafe-edit-cafe-1')));
        await tester.pumpAndSettle();
        await _scrollEditFormUntilFound(
          tester,
          find.byKey(const Key('admin-featured-priority-input')),
        );

        final featuredSwitch = tester.widget<Switch>(
          find.descendant(
            of: find.byKey(const Key('admin-featured-toggle')),
            matching: find.byType(Switch),
          ),
        );
        expect(featuredSwitch.value, isTrue);
        expect(
          _textFieldText(tester, const Key('admin-featured-priority-input')),
          '3',
        );
        expect(
          _textFieldText(tester, const Key('admin-featured-until-input')),
          '2099-02-03',
        );
        expect(
          _textFieldText(tester, const Key('admin-featured-label-input')),
          'Sponsored',
        );

        await tester.enterText(
          _textFieldIn(const Key('admin-featured-priority-input')),
          '11',
        );
        await tester.enterText(
          _textFieldIn(const Key('admin-featured-until-input')),
          '2099-04-05',
        );
        await tester.enterText(
          _textFieldIn(const Key('admin-featured-label-input')),
          '   ',
        );
        await tester.pumpAndSettle();

        await _scrollEditFormUntilFound(
          tester,
          find.byKey(const Key('admin-save-action')),
        );
        await tester.tap(find.byKey(const Key('admin-save-action')));
        await tester.pumpAndSettle();

        expect(updatedCafeId, 'cafe-1');
        expect(updatedInput?.isFeatured, isTrue);
        expect(updatedInput?.featuredPriority, 11);
        expect(updatedInput?.featuredUntil, DateTime.utc(2099, 4, 5));
        expect(updatedInput?.toRow()['is_featured'], isTrue);
        expect(updatedInput?.toRow(), isNot(contains('featured_label')));
        expect(find.byType(AdminScreen), findsOneWidget);
      },
    );

    testWidgets(
      'cafe edit rejects invalid featured expiration dates before submit',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Stone',
            fullName: 'Alice Stone',
            email: 'alice@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [buildTestCafe(id: 'cafe-1', name: 'Brew Lab')];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        CafeAdminUpdateInput? updatedInput;

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(
              _FakeCafeCommandService(
                cafesById,
                (_, input) => updatedInput = input,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          initialLocation: '/admin',
          routes: [
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminScreen(),
            ),
            GoRoute(
              path: '/cafe-edit/:id',
              builder: (_, state) => CafeEditScreen(
                cafeId: state.pathParameters['id']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestRouterApp(container: container, router: router),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('admin-cafe-edit-cafe-1')));
        await tester.pumpAndSettle();
        await _scrollEditFormUntilFound(
          tester,
          find.byKey(const Key('admin-featured-until-input')),
        );

        await tester.enterText(
          _textFieldIn(const Key('admin-featured-until-input')),
          '2099-13-40',
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Use YYYY-MM-DD for featured expiration.'),
          findsOneWidget,
        );

        await _scrollEditFormUntilFound(
          tester,
          find.byKey(const Key('admin-save-action')),
        );
        await tester.tap(find.byKey(const Key('admin-save-action')));
        await tester.pumpAndSettle();

        expect(updatedInput, isNull);
        expect(find.byType(CafeEditScreen), findsOneWidget);
      },
    );

    testWidgets(
      'cafe edit delete resolves target from loaded detail and reaches mutation',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Stone',
            fullName: 'Alice Stone',
            email: 'alice@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final adminListRow = buildTestCafe(
          id: 'db-cafe-1',
          name: 'Mapped Delete Cafe',
        );
        final detailCafe = buildTestCafe(
          id: 'db-cafe-1',
          name: 'Mapped Delete Cafe',
        ).copyWith(placeId: 'short_place_1');

        String? capturedDeleteCafeId;
        String? capturedExternalPlaceId;
        final queryService = _FakeCafeQueryService(
          [detailCafe],
          onFetchAdminCafes: ({
            required String searchQuery,
            required String district,
            required String status,
            required int limit,
            required int offset,
            Duration? requestTimeout,
            RequestCancellationToken? cancellationToken,
          }) async {
            return ServiceResult.success(
              data: AdminCafePage(
                cafes: [adminListRow],
                hasMore: false,
                offset: offset,
                limit: limit,
              ),
            );
          },
        );
        final commandService = _FakeCafeCommandService(
          <String, Cafe>{detailCafe.id: detailCafe},
          (_, __) {},
          onSoftDelete: (cafeId, externalPlaceId, deletedBy) async {
            capturedDeleteCafeId = cafeId;
            capturedExternalPlaceId = externalPlaceId;
            if (externalPlaceId != 'short_place_1') {
              return ServiceResult.failure(
                message: 'Place id is required to resolve delete target.',
              );
            }
            return ServiceResult.success(
              data: detailCafe.copyWith(isDeleted: true),
            );
          },
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: const <Cafe>[],
            currentUser: testUser,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(queryService),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          initialLocation: '/admin',
          routes: [
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminScreen(),
            ),
            GoRoute(
              path: '/cafe-edit/:id',
              builder: (_, state) => CafeEditScreen(
                cafeId: state.pathParameters['id']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestRouterApp(container: container, router: router),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('admin-cafe-edit-db-cafe-1')));
        await tester.pumpAndSettle();

        await _scrollEditFormUntilFound(
          tester,
          find.widgetWithText(TextButton, 'Delete Cafe'),
        );
        await tester
            .ensureVisible(find.widgetWithText(TextButton, 'Delete Cafe'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete Cafe'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(capturedDeleteCafeId, 'db-cafe-1');
        expect(capturedExternalPlaceId, 'short_place_1');
        expect(commandService.softDeleteCallCount, 1);
      },
    );

    testWidgets(
      'cafe edit delete removes the correct cafe from visible projections',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Stone',
            fullName: 'Alice Stone',
            email: 'alice@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final visibleCafe = buildTestCafe(
          id: 'visible-google-1',
          name: 'Projection Delete Cafe',
        ).copyWith(placeId: 'short_place_projection');
        final detailCafe = buildTestCafe(
          id: 'db-cafe-projection',
          name: 'Projection Delete Cafe',
        ).copyWith(placeId: 'short_place_projection');
        final otherCafe = buildTestCafe(
          id: 'other-cafe',
          name: 'Other Cafe',
        );

        final queryService = _FakeCafeQueryService(
          [detailCafe],
          onFetchAdminCafes: ({
            required String searchQuery,
            required String district,
            required String status,
            required int limit,
            required int offset,
            Duration? requestTimeout,
            RequestCancellationToken? cancellationToken,
          }) async {
            return ServiceResult.success(
              data: AdminCafePage(
                cafes: [detailCafe, otherCafe],
                hasMore: false,
                offset: offset,
                limit: limit,
              ),
            );
          },
        );
        final commandService = _FakeCafeCommandService(
          <String, Cafe>{detailCafe.id: detailCafe},
          (_, __) {},
          onSoftDelete: (cafeId, externalPlaceId, deletedBy) async {
            return ServiceResult.success(
              data: detailCafe.copyWith(isDeleted: true),
            );
          },
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: [visibleCafe, otherCafe],
            homeCafes: [visibleCafe, otherCafe],
            featuredCafes: [visibleCafe],
            favorites: ['visible-google-1', 'short_place_projection'],
            compareList: ['visible-google-1', 'short_place_projection'],
            currentUser: testUser,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(queryService),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            cafeRepositoryProvider.overrideWithValue(
              FakeCafeRepository(
                onFetch: (_) async => CafeRepositoryResult(
                  cafes: [otherCafe],
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
                    CafeRepositoryResult(
                  cafes: [otherCafe],
                  usedRemote: true,
                ),
                onFetchFeaturedCafes: () async => const <Cafe>[],
              ),
            ),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          initialLocation: '/admin',
          routes: [
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminScreen(),
            ),
            GoRoute(
              path: '/cafe-edit/:id',
              builder: (_, state) => CafeEditScreen(
                cafeId: state.pathParameters['id']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestRouterApp(container: container, router: router),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('admin-cafe-edit-db-cafe-projection')),
        );
        await tester.pumpAndSettle();

        await _scrollEditFormUntilFound(
          tester,
          find.widgetWithText(TextButton, 'Delete Cafe'),
        );
        await tester
            .ensureVisible(find.widgetWithText(TextButton, 'Delete Cafe'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete Cafe'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(seconds: 1));

        expect(
          container.read(cafesProvider).map((cafe) => cafe.id),
          isNot(contains('visible-google-1')),
        );
        expect(
          container.read(homeCafesProvider).map((cafe) => cafe.id),
          isNot(contains('visible-google-1')),
        );
        expect(
          container.read(cafesProvider).map((cafe) => cafe.id),
          contains('other-cafe'),
        );
        expect(
          container.read(cafeProvider).featuredCafes.map((cafe) => cafe.id),
          isNot(contains('visible-google-1')),
        );
        expect(
          container.read(adminCafesProvider).map((cafe) => cafe.id),
          isNot(contains('db-cafe-projection')),
        );
        expect(container.read(favoriteIdsProvider), isEmpty);
        expect(container.read(normalizedCompareListProvider), isEmpty);
        expect(find.byType(CafeEditScreen), findsNothing);
        expect(find.byType(AdminScreen), findsOneWidget);
      },
    );

    testWidgets(
      'blocks destructive actions when security readiness is unhealthy',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Stone',
            fullName: 'Alice Stone',
            email: 'alice@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {},
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: false,
                checkAvailable: true,
                rlsEnabled: false,
                hasAdminInsertPolicy: false,
                hasAdminUpdatePolicy: false,
                message: 'RLS readiness failed in test.',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-cafe-action-cafe-1')));
        await tester.pumpAndSettle();

        expect(commandService.softDeleteCallCount, 0);
        expect(find.text('RLS readiness failed in test.'), findsOneWidget);
      },
    );

    test(
      'delete remains blocked when target cannot be resolved safely',
      () async {
        String? capturedExternalPlaceId;
        final survivor = buildTestCafe(id: 'survivor-cafe', name: 'Survivor');
        final commandService = _FakeCafeCommandService(
          const <String, Cafe>{},
          (_, __) {},
          onSoftDelete: (cafeId, externalPlaceId, deletedBy) async {
            capturedExternalPlaceId = externalPlaceId;
            return ServiceResult.failure(
              message:
                  'Delete target could not be resolved. Use an exact cafe id or place id.',
              errorType: ServiceErrorType.notFound,
            );
          },
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            isAdminRoleResolved: true,
            cafes: [survivor],
            homeCafes: [survivor],
            currentUser: testUser,
          ),
          overrides: [
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(const <Cafe>[]),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier =
            container.read(cafeAdminMutationControllerProvider.notifier);
        final result = await notifier.deleteCafe('unsafe-short-id');

        expect(result.ok, isFalse);
        expect(result.errorType, ServiceErrorType.notFound);
        expect(capturedExternalPlaceId, isNull);
        expect(
          container.read(cafesProvider).map((cafe) => cafe.id),
          contains('survivor-cafe'),
        );
        expect(
          container.read(homeCafesProvider).map((cafe) => cafe.id),
          contains('survivor-cafe'),
        );
      },
    );

    testWidgets(
      'shows pending state and disables only targeted row while delete is in flight',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Stone',
            fullName: 'Alice Stone',
            email: 'alice@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
          buildTestCafe(id: 'cafe-2', name: 'North Roast'),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        final pendingDelete = Completer<ServiceResult<Cafe>>();
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {},
          onSoftDelete: (cafeId, externalPlaceId, deletedBy) {
            return pendingDelete.future;
          },
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-cafe-action-cafe-1')));
        await tester.pump();

        expect(
          find.byKey(const Key('admin-cafe-action-progress-cafe-1')),
          findsOneWidget,
        );

        final row1Button = tester.widget<TextButton>(
          find.byKey(const Key('admin-cafe-action-cafe-1')),
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('admin-cafe-action-cafe-2')),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        final row2Button = tester.widget<TextButton>(
          find.byKey(const Key('admin-cafe-action-cafe-2')),
        );

        expect(row1Button.onPressed, isNull);
        expect(row2Button.onPressed, isNotNull);

        pendingDelete.complete(
          ServiceResult.success(
            data: cafesById['cafe-1']!.copyWith(isDeleted: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(commandService.softDeleteCallCount, 1);
      },
    );

    test(
      'controller suppresses duplicate delete while same cafe mutation is in flight',
      () async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {},
          onSoftDelete: (cafeId, externalPlaceId, deletedBy) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return ServiceResult.failure(message: 'simulated delete failure');
          },
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controllerSub = container.listen<async_result.AsyncResult<void>>(
          cafeAdminMutationControllerProvider,
          (_, __) {},
          fireImmediately: true,
        );
        addTearDown(controllerSub.close);

        final notifier =
            container.read(cafeAdminMutationControllerProvider.notifier);
        final firstFuture = notifier.deleteCafe('cafe-1');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final second = await notifier.deleteCafe('cafe-1');
        final first = await firstFuture;

        expect(first.ok, false);
        expect(second.ok, false);
        expect(second.message, contains('already in progress'));
        expect(commandService.softDeleteCallCount, 1);
        expect(container.read(adminCafeMutationPendingIdsProvider), isEmpty);
      },
    );

    test(
      'controller blocks delete when authenticated user is not admin',
      () async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {},
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: false,
            isAdminRoleResolved: true,
            cafes: cafes,
            currentUser: testUser,
          ),
          overrides: [
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier =
            container.read(cafeAdminMutationControllerProvider.notifier);
        final result = await notifier.deleteCafe('cafe-1');

        expect(result.ok, isFalse);
        expect(result.errorType, ServiceErrorType.auth);
        expect(result.message, contains('Admin privileges are required'));
        expect(commandService.softDeleteCallCount, 0);
      },
    );

    test(
      'controller blocks delete with specific message when admin role is unresolved',
      () async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {},
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: false,
            isAdminRoleResolved: false,
            adminRoleStatusMessage:
                'Admin status could not be verified because profile lookup failed due to network/connectivity.',
            cafes: cafes,
            currentUser: testUser,
          ),
          overrides: [
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier =
            container.read(cafeAdminMutationControllerProvider.notifier);
        final result = await notifier.deleteCafe('cafe-1');

        expect(result.ok, isFalse);
        expect(result.errorType, ServiceErrorType.unavailable);
        expect(result.message, contains('Admin status could not be verified'));
        expect(commandService.softDeleteCallCount, 0);
      },
    );

    test(
      'controller revalidates unresolved admin role and reaches delete mutation',
      () async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {},
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: false,
            isAdminRoleResolved: false,
            adminRoleStatusMessage:
                'Admin status could not be verified because profile lookup timed out.',
            cafes: cafes,
            currentUser: testUser,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService([
                const UserProfile(
                  id: 'user-1',
                  username: 'admin-user',
                  firstName: 'Admin',
                  lastName: 'User',
                  fullName: 'Admin User',
                  email: 'admin@example.com',
                  role: ProfileRole.admin,
                  createdAt: '2024-01-01T00:00:00Z',
                ),
              ]),
            ),
            cafeRepositoryProvider.overrideWithValue(
              FakeCafeRepository(
                onFetch: (_) async => const CafeRepositoryResult(
                    cafes: <Cafe>[], usedRemote: true),
                onFetchFeaturedCafes: () async => const <Cafe>[],
              ),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier =
            container.read(cafeAdminMutationControllerProvider.notifier);
        final result = await notifier.deleteCafe('cafe-1');

        expect(result.ok, isTrue);
        expect(commandService.softDeleteCallCount, 1);
        expect(
          container.read(cafesProvider).map((cafe) => cafe.id),
          isNot(contains('cafe-1')),
        );
        expect(
          container.read(homeCafesProvider).map((cafe) => cafe.id),
          isNot(contains('cafe-1')),
        );
      },
    );

    test(
      'successful delete removes cafe from sponsored home projection',
      () async {
        final sponsoredCafe = buildTestCafe(
          id: 'sponsored-delete',
          name: 'Sponsored Delete',
        ).copyWith(
          isFeatured: true,
          featuredPriority: 100,
          featuredUntil: () => DateTime.utc(2035, 1, 1),
        );
        final cafesById = {sponsoredCafe.id: sponsoredCafe};
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {},
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            isAdminRoleResolved: true,
            cafes: [sponsoredCafe],
            homeCafes: [sponsoredCafe],
            featuredCafes: [sponsoredCafe],
            currentUser: testUser,
          ),
          overrides: [
            cafeRepositoryProvider.overrideWithValue(
              FakeCafeRepository(
                onFetch: (_) async => const CafeRepositoryResult(
                  cafes: <Cafe>[],
                  usedRemote: true,
                ),
                onFetchFeaturedCafes: () async => const <Cafe>[],
              ),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
          contains('sponsored-delete'),
        );

        final result = await container
            .read(cafeAdminMutationControllerProvider.notifier)
            .deleteCafe('sponsored-delete');

        expect(result.ok, isTrue);
        expect(commandService.softDeleteCallCount, 1);
        expect(
          container.read(homeSponsoredCafesProvider).map((cafe) => cafe.id),
          isNot(contains('sponsored-delete')),
        );
        expect(
          container.read(cafesProvider).map((cafe) => cafe.id),
          isNot(contains('sponsored-delete')),
        );
      },
    );

    testWidgets(
      'admin UI delete forwards placeId mapping and removes row when discovery cache has no match',
      (tester) async {
        final profiles = [
          const UserProfile(
            id: 'user-1',
            username: 'admin-user',
            firstName: 'Admin',
            lastName: 'User',
            fullName: 'Admin User',
            email: 'admin@example.com',
            role: ProfileRole.admin,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ];

        final adminListRows = <Cafe>[
          buildTestCafe(id: 'place_short_123', name: 'Needs Place Mapping')
              .copyWith(placeId: 'place_short_123'),
          buildTestCafe(id: 'place_short_456', name: 'Still Listed')
              .copyWith(placeId: 'place_short_456'),
        ];

        final queryService = _FakeCafeQueryService(
          const <Cafe>[],
          onFetchAdminCafes: ({
            required String searchQuery,
            required String district,
            required String status,
            required int limit,
            required int offset,
            Duration? requestTimeout,
            RequestCancellationToken? cancellationToken,
          }) async {
            final page = adminListRows.skip(offset).take(limit).toList();
            final hasMore = offset + page.length < adminListRows.length;
            return ServiceResult.success(
              data: AdminCafePage(
                cafes: page,
                hasMore: hasMore,
                offset: offset,
                limit: limit,
              ),
            );
          },
        );

        String? capturedExternalPlaceId;
        final commandService = _FakeCafeCommandService(
          const <String, Cafe>{},
          (_, __) {},
          onSoftDelete: (cafeId, externalPlaceId, deletedBy) async {
            capturedExternalPlaceId = externalPlaceId;
            if (externalPlaceId == null || externalPlaceId.trim().isEmpty) {
              return ServiceResult.failure(
                message: 'Place id is required to resolve delete target.',
              );
            }

            final index = adminListRows.indexWhere(
              (cafe) => cafe.placeId == externalPlaceId,
            );
            if (index < 0) {
              return ServiceResult.failure(message: 'Target row not found.');
            }

            final deleted = adminListRows.removeAt(index).copyWith(
                  isDeleted: true,
                );
            return ServiceResult.success(data: deleted);
          },
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            isAdminRoleResolved: true,
            cafes: const <Cafe>[],
            currentUser: testUser,
          ),
          overrides: [
            profilesServiceProvider.overrideWithValue(
              _FakeProfilesService(profiles),
            ),
            cafeQueryServiceProvider.overrideWithValue(queryService),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildTestApp(
            container: container,
            child: const AdminScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('admin-tab-cafes')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('admin-cafe-action-place_short_123')),
          findsOneWidget,
        );

        await tester
            .tap(find.byKey(const Key('admin-cafe-action-place_short_123')));
        await tester.pumpAndSettle();

        expect(capturedExternalPlaceId, 'place_short_123');
        expect(
          find.byKey(const Key('admin-cafe-action-place_short_123')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('admin-cafe-action-place_short_456')),
          findsOneWidget,
        );
      },
    );

    test(
      'controller blocks update when security readiness is unhealthy',
      () async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        var updateCalled = false;
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {
            updateCalled = true;
          },
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            isAdminRoleResolved: true,
            cafes: cafes,
            currentUser: testUser,
          ),
          overrides: [
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: false,
                checkAvailable: true,
                rlsEnabled: false,
                hasAdminInsertPolicy: false,
                hasAdminUpdatePolicy: false,
                message: 'RLS readiness failed in test.',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier =
            container.read(cafeAdminMutationControllerProvider.notifier);
        final result = await notifier.updateCafe(
          'cafe-1',
          const CafeAdminUpdateInput(name: 'Updated Name'),
        );

        expect(result.ok, isFalse);
        expect(result.message, contains('RLS readiness failed in test.'));
        expect(updateCalled, isFalse);
      },
    );

    test(
      'controller allows update when readiness probe failure is transient',
      () async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        var updateCalled = false;
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {
            updateCalled = true;
          },
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            isAdminRoleResolved: true,
            cafes: cafes,
            currentUser: testUser,
          ),
          overrides: [
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: false,
                checkAvailable: false,
                rlsEnabled: false,
                hasAdminInsertPolicy: false,
                hasAdminUpdatePolicy: false,
                message: 'Readiness probe timed out.',
                failureType: ServiceErrorType.timeout,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier =
            container.read(cafeAdminMutationControllerProvider.notifier);
        final result = await notifier.updateCafe(
          'cafe-1',
          const CafeAdminUpdateInput(name: 'Updated Name'),
        );

        expect(result.ok, isTrue);
        expect(updateCalled, isTrue);
      },
    );

    test(
      'controller update saves featured fields when cafe id is a place id',
      () async {
        const placeId = 'ChIJPlaceIdForAdminUpdate';
        final cafe = buildTestCafe(id: 'cafe-1', name: 'Brew Lab').copyWith(
          placeId: placeId,
        );
        final cafes = [cafe];
        final cafesById = {for (final item in cafes) item.id: item};
        String? capturedCafeId;
        final commandService = _FakeCafeCommandService(
          cafesById,
          (cafeId, _) {
            capturedCafeId = cafeId;
          },
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            isAdminRoleResolved: true,
            cafes: cafes,
            currentUser: testUser,
          ),
          overrides: [
            cafeRepositoryProvider.overrideWithValue(
              FakeCafeRepository(
                onFetch: (_) async => CafeRepositoryResult(
                  cafes: cafesById.values.toList(growable: false),
                  usedRemote: true,
                ),
                onFetchFeaturedCafes: () async => cafesById.values
                    .where((cafe) => cafe.isActiveFeatured)
                    .toList(growable: false),
              ),
            ),
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier =
            container.read(cafeAdminMutationControllerProvider.notifier);
        final result = await notifier.updateCafe(
          placeId,
          const CafeAdminUpdateInput(
            name: 'Brew Lab Updated',
            isFeatured: true,
            featuredPriority: 7,
          ),
        );

        expect(result.ok, isTrue);
        expect(capturedCafeId, placeId);
        expect(cafesById['cafe-1']?.name, 'Brew Lab Updated');
        expect(cafesById['cafe-1']?.isFeatured, isTrue);
        expect(cafesById['cafe-1']?.featuredPriority, 7);

        await container.read(cafeProvider.notifier).refreshCafes();
        final sponsored = container.read(homeSponsoredCafesProvider);
        expect(sponsored.map((cafe) => cafe.id), contains('cafe-1'));
      },
    );

    test(
      'controller fails delete safely when target has no exact id or place id match',
      () async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {},
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier =
            container.read(cafeAdminMutationControllerProvider.notifier);
        final result = await notifier.deleteCafe('Brew Lab');

        expect(result.ok, false);
        expect(result.message, contains('not found'));
        expect(commandService.softDeleteCallCount, 1);
      },
    );

    test(
      'controller suppresses duplicate restore while same cafe mutation is in flight',
      () async {
        final cafes = [
          buildTestCafe(id: 'cafe-1', name: 'Brew Lab')
              .copyWith(isDeleted: true),
        ];
        final cafesById = {for (final cafe in cafes) cafe.id: cafe};
        final commandService = _FakeCafeCommandService(
          cafesById,
          (_, __) {},
          onRestore: (cafeId) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return ServiceResult.failure(message: 'simulated restore failure');
          },
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: cafes,
          ),
          overrides: [
            cafeQueryServiceProvider.overrideWithValue(
              _FakeCafeQueryService(cafes),
            ),
            cafeCommandServiceProvider.overrideWithValue(commandService),
            securityReadinessProvider.overrideWith(
              (ref) async => const SecurityReadinessReport(
                isReady: true,
                checkAvailable: true,
                rlsEnabled: true,
                hasAdminInsertPolicy: true,
                hasAdminUpdatePolicy: true,
                message: 'ok',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controllerSub = container.listen<async_result.AsyncResult<void>>(
          cafeAdminMutationControllerProvider,
          (_, __) {},
          fireImmediately: true,
        );
        addTearDown(controllerSub.close);

        final notifier =
            container.read(cafeAdminMutationControllerProvider.notifier);
        final firstFuture = notifier.restoreCafe('cafe-1');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final second = await notifier.restoreCafe('cafe-1');
        final first = await firstFuture;

        expect(first.ok, false);
        expect(second.ok, false);
        expect(second.message, contains('already in progress'));
        expect(commandService.restoreCallCount, 1);
        expect(container.read(adminCafeMutationPendingIdsProvider), isEmpty);
      },
    );

    test(
      'admin list controller uses admin query path and can surface hidden/deleted cafes',
      () async {
        final cafes = [
          buildTestCafe(id: 'cafe-visible', name: 'Visible Cafe').copyWith(
            ownerApprovalStatus: 'approved',
            isDeleted: false,
            isFeatured: false,
          ),
          buildTestCafe(id: 'cafe-hidden', name: 'Hidden Cafe').copyWith(
            ownerApprovalStatus: 'pending',
            isDeleted: false,
            isFeatured: true,
          ),
          buildTestCafe(id: 'cafe-deleted', name: 'Deleted Cafe').copyWith(
            ownerApprovalStatus: 'approved',
            isDeleted: true,
            isFeatured: true,
          ),
        ];
        final queryService = _FakeCafeQueryService(
          cafes,
          throwOnDiscoverableFetch: true,
        );

        final container = createTestContainer(
          state: buildTestAppShellState(
            isAdmin: true,
            cafes: const <Cafe>[],
          ),
          overrides: [
            cafeQueryServiceProvider.overrideWithValue(queryService),
          ],
        );
        addTearDown(container.dispose);

        final controllerSub = container.listen<AdminCafeListState>(
          adminCafeListControllerProvider,
          (_, __) {},
          fireImmediately: true,
        );
        addTearDown(controllerSub.close);

        final notifier =
            container.read(adminCafeListControllerProvider.notifier);
        await notifier.refresh();

        expect(queryService.fetchDiscoverableCallCount, 0);
        expect(queryService.fetchAdminCallCount, greaterThanOrEqualTo(1));
        final allRows = container.read(adminCafeListControllerProvider).cafes;
        expect(allRows, hasLength(2));
        expect(allRows.map((cafe) => cafe.id), contains('cafe-visible'));
        expect(allRows.map((cafe) => cafe.id), contains('cafe-hidden'));
        expect(allRows.map((cafe) => cafe.id), isNot(contains('cafe-deleted')));

        await notifier.setStatusFilter('hidden');
        final hiddenRows =
            container.read(adminCafeListControllerProvider).cafes;
        expect(hiddenRows, hasLength(1));
        expect(hiddenRows.single.id, 'cafe-hidden');

        await notifier.setStatusFilter('deleted');
        final deletedRows =
            container.read(adminCafeListControllerProvider).cafes;
        expect(deletedRows, hasLength(1));
        expect(deletedRows.single.id, 'cafe-deleted');
      },
    );

    test('admin cafe list controller does not read public home providers', () {
      final source = File('lib/providers/app_services.dart').readAsStringSync();
      final controllerStart = source.indexOf('class AdminCafeListController');
      final controllerEnd = source.indexOf(
        'final cafeAdminMutationControllerProvider',
        controllerStart,
      );
      final controllerBlock = source.substring(controllerStart, controllerEnd);

      expect(controllerBlock, contains('service.fetchAdminCafes'));
      expect(controllerBlock, isNot(contains('activeFeaturedCafesProvider')));
      expect(controllerBlock, isNot(contains('homeSponsoredCafesProvider')));
      expect(controllerBlock, isNot(contains('homeCafesProvider')));
    });

    test(
        'deleted cafe identity is filtered from home detail explore and search',
        () {
      final staleGoogleCafe =
          buildTestCafe(id: 'google-fig', name: 'Fig Coffee')
              .copyWith(placeId: 'fig-place');
      final otherCafe = buildTestCafe(id: 'other-cafe', name: 'Other Cafe');
      final container = createTestContainer(
        state: buildTestAppShellState(
          isAdmin: true,
          cafes: [staleGoogleCafe, otherCafe],
          homeCafes: [staleGoogleCafe, otherCafe],
          featuredCafes: [staleGoogleCafe.copyWith(isFeatured: true)],
          exploreFilters: const Filters(searchQuery: 'fig'),
        ),
      );
      addTearDown(container.dispose);

      expect(
        container.read(homeCafesProvider).map((cafe) => cafe.id),
        contains('google-fig'),
      );
      expect(container.read(cafeByIdProvider('fig-place'))?.id, 'google-fig');
      expect(
        searchCafes(container.read(searchableCafeCorpusProvider), 'fig'),
        isNotEmpty,
      );

      container.read(deletedCafeIdentityIdsProvider.notifier).state = {
        'google-fig',
        'fig-place',
        staleGoogleCafe.canonicalIdentityKey,
      };

      expect(
        container.read(homeCafesProvider).map((cafe) => cafe.id),
        isNot(contains('google-fig')),
      );
      expect(container.read(cafeByIdProvider('fig-place')), isNull);
      expect(
        container.read(exploreCafeResultsProvider).map((cafe) => cafe.id),
        isNot(contains('google-fig')),
      );
      expect(
        searchCafes(container.read(searchableCafeCorpusProvider), 'fig'),
        isEmpty,
      );
    });

    test('search corpus includes and dedupes active featured cafes', () {
      final homeFig = buildTestCafe(id: 'home-fig', name: 'Fig Coffee')
          .copyWith(placeId: 'fig-place');
      final featuredFig =
          buildTestCafe(id: 'featured-fig', name: 'Fig Coffee').copyWith(
        placeId: 'fig-place',
        isFeatured: true,
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          isAdmin: true,
          cafes: const <Cafe>[],
          homeCafes: [homeFig],
          featuredCafes: [featuredFig],
        ),
      );
      addTearDown(container.dispose);

      final corpus = container.read(searchableCafeCorpusProvider);
      final results = searchCafes(corpus, 'fig');

      expect(corpus, hasLength(1));
      expect(results, hasLength(1));
      expect(results.single.placeId, 'fig-place');
    });

    test('Arabic-script cached rows are filtered from public projections', () {
      const arabicName =
          '\u0645\u0642\u0647\u0649 \u0627\u0644\u0642\u0647\u0648\u0629';
      final arabicCafe =
          buildTestCafe(id: 'arabic-google', name: arabicName).copyWith(
        placeId: 'arabic-place',
      );
      final normalCafe = buildTestCafe(id: 'normal-cafe', name: 'Normal Cafe');
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [arabicCafe, normalCafe],
          homeCafes: [arabicCafe, normalCafe],
          exploreFilters: const Filters(searchQuery: 'm'),
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(homeCafesProvider).map((cafe) => cafe.id),
          isNot(contains('arabic-google')));
      expect(container.read(cafesProvider).map((cafe) => cafe.id),
          isNot(contains('arabic-google')));
      expect(
          container.read(searchableCafeCorpusProvider).map((cafe) => cafe.id),
          isNot(contains('arabic-google')));
    });

    test(
        'admin override allows Arabic-script Supabase row in public projection',
        () {
      const arabicName =
          '\u0645\u0642\u0647\u0649 \u0627\u0644\u0642\u0647\u0648\u0629';
      final overriddenCafe =
          buildTestCafe(id: 'arabic-approved', name: arabicName).copyWith(
        tags: const ['admin_allow_cafe'],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [overriddenCafe],
          homeCafes: [overriddenCafe],
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(homeCafesProvider).map((cafe) => cafe.id),
          contains('arabic-approved'));
      expect(container.read(cafesProvider).map((cafe) => cafe.id),
          contains('arabic-approved'));
    });

    test('delete cleanup removes Google-only cafe by fallback identity', () {
      final figOne = buildTestCafe(
        id: 'google-fig-one',
        name: 'Fig Coffee Cocktail',
        district: 'Besiktas',
        neighborhood: 'Akaretler',
      ).copyWith(address: 'Akaretler');
      final figTwo = buildTestCafe(
        id: 'google-fig-two',
        name: 'Fig Coffee Cocktail',
        district: 'Besiktas',
        neighborhood: 'Akaretler',
      ).copyWith(address: 'Akaretler');
      final fallback =
          'fallback:${normalizeSearchText(figOne.name)}|${normalizeSearchText(figOne.district)}|${normalizeSearchText(figOne.neighborhood)}|${normalizeSearchText(figOne.address)}';
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [figOne, figTwo],
          homeCafes: [figOne, figTwo],
        ),
      );
      addTearDown(container.dispose);

      final removed = container
          .read(cafeProvider.notifier)
          .removeCafesByIdentity({fallback});

      expect(removed.removedCafes, 2);
      expect(removed.removedHome, 2);
      expect(container.read(cafesProvider), isEmpty);
      expect(container.read(homeCafesProvider), isEmpty);
    });

    test('admin list dedupes duplicate Fig rows by fallback identity',
        () async {
      final figOne = buildTestCafe(
        id: 'fig-uuid',
        name: 'Fig Coffee Cocktail',
        district: 'Besiktas',
        neighborhood: 'Akaretler',
      ).copyWith(address: 'Akaretler');
      final figTwo = buildTestCafe(
        id: 'fig-slug',
        name: 'Fig Coffee Cocktail',
        district: 'Besiktas',
        neighborhood: 'Akaretler',
      ).copyWith(address: 'Akaretler');
      final queryService = _FakeCafeQueryService([figOne, figTwo]);
      final container = createTestContainer(
        state: buildTestAppShellState(isAdmin: true),
        overrides: [
          cafeQueryServiceProvider.overrideWithValue(queryService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(adminCafeListControllerProvider.notifier).refresh();

      final rows = container.read(adminCafeListControllerProvider).cafes;
      expect(rows, hasLength(1));
      expect(rows.single.name, 'Fig Coffee Cocktail');
    });

    test('admin cafe search debounces rapid query edits', () async {
      final requestedQueries = <String>[];
      final queryService = _FakeCafeQueryService(
        [
          buildTestCafe(id: 'cafe-initial', name: 'Initial Cafe'),
          buildTestCafe(id: 'cafe-final', name: 'Final Cafe'),
        ],
        onFetchAdminCafes: ({
          required searchQuery,
          required district,
          required status,
          required limit,
          required offset,
          requestTimeout,
          cancellationToken,
        }) async {
          requestedQueries.add(searchQuery);
          final cafes = searchQuery == 'Final'
              ? [buildTestCafe(id: 'cafe-final', name: 'Final Cafe')]
              : [buildTestCafe(id: 'cafe-initial', name: 'Initial Cafe')];
          return ServiceResult.success(
            data: AdminCafePage(
              cafes: cafes,
              hasMore: false,
              offset: offset,
              limit: limit,
            ),
          );
        },
      );
      final container = createTestContainer(
        state: buildTestAppShellState(isAdmin: true),
        overrides: [
          cafeQueryServiceProvider.overrideWithValue(queryService),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen<AdminCafeListState>(
        adminCafeListControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      final notifier = container.read(adminCafeListControllerProvider.notifier);
      await notifier.refresh();
      requestedQueries.clear();

      final first = notifier.setSearchQuery('F');
      final second = notifier.setSearchQuery('Fi');
      final third = notifier.setSearchQuery('Final');
      await Future.wait([first, second]);

      expect(requestedQueries, isEmpty);
      await third;

      expect(requestedQueries, ['Final']);
      expect(
        container.read(adminCafeListControllerProvider).cafes.single.id,
        'cafe-final',
      );
    });

    test('stale admin cafe responses cannot overwrite newer filters', () async {
      final firstRequest = Completer<ServiceResult<AdminCafePage>>();
      final secondRequest = Completer<ServiceResult<AdminCafePage>>();
      var requestCount = 0;
      final queryService = _FakeCafeQueryService(
        const [],
        onFetchAdminCafes: ({
          required searchQuery,
          required district,
          required status,
          required limit,
          required offset,
          requestTimeout,
          cancellationToken,
        }) {
          requestCount += 1;
          return requestCount == 1 ? firstRequest.future : secondRequest.future;
        },
      );
      final container = createTestContainer(
        state: buildTestAppShellState(isAdmin: true),
        overrides: [
          cafeQueryServiceProvider.overrideWithValue(queryService),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen<AdminCafeListState>(
        adminCafeListControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      final notifier = container.read(adminCafeListControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final filterFuture = notifier.setStatusFilter('hidden');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(requestCount, 2);

      secondRequest.complete(
        ServiceResult.success(
          data: AdminCafePage(
            cafes: [buildTestCafe(id: 'newer', name: 'Newer Hidden Cafe')],
            hasMore: false,
            offset: 0,
            limit: 60,
          ),
        ),
      );
      await filterFuture;
      expect(
        container.read(adminCafeListControllerProvider).cafes.single.id,
        'newer',
      );

      firstRequest.complete(
        ServiceResult.success(
          data: AdminCafePage(
            cafes: [buildTestCafe(id: 'stale', name: 'Stale Cafe')],
            hasMore: false,
            offset: 0,
            limit: 60,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(adminCafeListControllerProvider).cafes.single.id,
        'newer',
      );
    });

    test('debounced admin filters reset pagination to the first page',
        () async {
      final offsets = <int>[];
      final queries = <String>[];
      final queryService = _FakeCafeQueryService(
        const [],
        onFetchAdminCafes: ({
          required searchQuery,
          required district,
          required status,
          required limit,
          required offset,
          requestTimeout,
          cancellationToken,
        }) async {
          offsets.add(offset);
          queries.add(searchQuery);
          final cafes = List<Cafe>.generate(
            searchQuery.isEmpty ? limit : 1,
            (index) => buildTestCafe(
              id: '${searchQuery.isEmpty ? 'page' : 'filtered'}-$offset-$index',
              name: '${searchQuery.isEmpty ? 'Page' : 'Filtered'} $index',
            ),
            growable: false,
          );
          return ServiceResult.success(
            data: AdminCafePage(
              cafes: cafes,
              hasMore: searchQuery.isEmpty && offset == 0,
              offset: offset,
              limit: limit,
            ),
          );
        },
      );
      final container = createTestContainer(
        state: buildTestAppShellState(isAdmin: true),
        overrides: [
          cafeQueryServiceProvider.overrideWithValue(queryService),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen<AdminCafeListState>(
        adminCafeListControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      final notifier = container.read(adminCafeListControllerProvider.notifier);
      await notifier.refresh();
      await notifier.loadMore();

      expect(offsets.last, 60);
      offsets.clear();
      queries.clear();
      await notifier.setSearchQuery('Filtered');

      expect(offsets, [0]);
      expect(queries, ['Filtered']);
      final state = container.read(adminCafeListControllerProvider);
      expect(state.offset, 1);
      expect(state.cafes.single.id, 'filtered-0-0');
      expect(state.hasMore, isFalse);
    });
  });
}
