import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/models/service_result.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/screens/admin_screen.dart';
import 'package:kafeproje/screens/filter_modal_screen.dart';
import 'package:kafeproje/screens/home_screen.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/request_cancellation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_helpers.dart';

class _ResponsiveProfilesService extends ProfilesService {
  _ResponsiveProfilesService(this._profiles)
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
}

class _ResponsiveCafeQueryService extends CafeQueryService {
  _ResponsiveCafeQueryService(this._cafes)
      : super(
          SupabaseClient(
            'https://example.com',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final List<Cafe> _cafes;

  Never _unexpectedCall(String methodName) {
    throw TestFailure(
      '_ResponsiveCafeQueryService.$methodName was called unexpectedly. '
      'Update this fake to match admin screen dependencies.',
    );
  }

  List<Cafe> _filteredCafes({
    String searchQuery = '',
    String district = 'all',
    String status = 'all',
    bool includeDeleted = true,
  }) {
    final normalizedSearch = searchQuery.trim().toLowerCase();
    final normalizedDistrict = district.trim().toLowerCase();
    final normalizedStatus = status.trim().toLowerCase();

    final filtered = _cafes.where((cafe) {
      if (!includeDeleted && cafe.isDeleted) {
        return false;
      }
      if (normalizedSearch.isNotEmpty) {
        final haystack =
            '${cafe.name} ${cafe.address} ${cafe.placeId ?? ''}'.toLowerCase();
        if (!haystack.contains(normalizedSearch)) {
          return false;
        }
      }
      if (normalizedDistrict.isNotEmpty && normalizedDistrict != 'all') {
        if (cafe.district.trim().toLowerCase() != normalizedDistrict) {
          return false;
        }
      }
      switch (normalizedStatus) {
        case 'visible':
          return cafe.isVisibleInPublic;
        case 'hidden':
          return !cafe.isDeleted && !cafe.isVisibleInPublic;
        case 'deleted':
          return cafe.isDeleted;
        case 'all':
        default:
          return true;
      }
    }).toList(growable: false);

    filtered
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
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
    final filtered = _filteredCafes(
      searchQuery: searchQuery,
      district: district,
      status: status,
      includeDeleted: true,
    );
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit < 1 ? 1 : limit;
    final page =
        filtered.skip(safeOffset).take(safeLimit).toList(growable: false);
    final hasMore = safeOffset + page.length < filtered.length;
    return ServiceResult.success(
      data: AdminCafePage(
        cafes: page,
        hasMore: hasMore,
        offset: safeOffset,
        limit: safeLimit,
      ),
    );
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchDiscoverableCafes({
    String? district,
    int limit = 800,
    int offset = 0,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final filtered = _filteredCafes(
      district: district ?? 'all',
      includeDeleted: false,
      status: 'visible',
    );
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit < 1 ? 1 : limit;
    return ServiceResult.success(
      data: filtered.skip(safeOffset).take(safeLimit).toList(growable: false),
    );
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchActiveFeaturedCafes({
    String? district,
    int limit = 40,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final filtered = _filteredCafes(
      district: district ?? 'all',
      includeDeleted: false,
      status: 'visible',
    )
        .where((cafe) => cafe.isActiveFeatured)
        .take(limit)
        .toList(growable: false);
    return ServiceResult.success(data: filtered);
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafesByIds(
    Iterable<String> ids, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final wanted =
        ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    return ServiceResult.success(
      data: _filteredCafes(includeDeleted: includeDeleted).where((cafe) {
        return wanted.contains(cafe.id) || wanted.contains(cafe.placeId ?? '');
      }).toList(growable: false),
    );
  }

  @override
  Future<ServiceResult<List<Cafe>>> searchCafesByName(
    String query, {
    int limit = 20,
    bool includeDeleted = false,
  }) async {
    final filtered = _filteredCafes(
      searchQuery: query,
      includeDeleted: includeDeleted,
    );
    return ServiceResult.success(
      data: filtered.take(limit.clamp(1, 200)).toList(growable: false),
    );
  }

  @override
  Future<ServiceResult<List<Cafe>>> fetchCafesByPlaceIds(
    Iterable<String> placeIds, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final wanted =
        placeIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    return ServiceResult.success(
      data: _filteredCafes(includeDeleted: includeDeleted)
          .where((cafe) => wanted.contains(cafe.placeId ?? ''))
          .toList(growable: false),
    );
  }

  @override
  Future<ServiceResult<Cafe?>> fetchCafeDetails(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    return fetchCafeById(
      cafeId,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
  }

  @override
  Future<ServiceResult<Cafe?>> fetchCafeById(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final normalizedCafeId = cafeId.trim();
    if (normalizedCafeId.isEmpty) {
      _unexpectedCall('fetchCafeById');
    }
    Cafe? found;
    for (final cafe in _cafes) {
      if (cafe.id == normalizedCafeId || cafe.placeId == normalizedCafeId) {
        found = cafe;
        break;
      }
    }
    return ServiceResult.success(data: found);
  }
}

void main() {
  testWidgets('home screen adapts cleanly to tablet widths', (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final cafes = [
      buildTestCafe(id: 'cafe-1', name: 'Cafe One'),
      buildTestCafe(id: 'cafe-2', name: 'Cafe Two'),
      buildTestCafe(id: 'cafe-3', name: 'Cafe Three'),
    ];
    final container = createTestContainer(
      state: buildTestAppShellState(
        cafes: cafes,
        currentUser: testUser,
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      buildTestApp(container: container, child: const HomeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-normal-cafe-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter modal stays usable on tablet widths', (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = createTestContainer(
      state: buildTestAppShellState(
        currentUser: testUser,
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      buildTestApp(
        container: container,
        child: const FilterModalScreen(scope: FilterModalScope.explore),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filters-apply-button')), findsOneWidget);
    expect(find.byKey(const Key('filters-reset-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin screen supports wider layouts without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
      const UserProfile(
        id: 'user-2',
        username: 'bob',
        firstName: 'Bob',
        lastName: 'Mason',
        fullName: 'Bob Mason',
        email: 'bob@example.com',
        role: ProfileRole.admin,
        createdAt: '2024-01-01T00:00:00Z',
      ),
    ];
    final cafes = [
      buildTestCafe(id: 'cafe-1', name: 'Brew Lab'),
      buildTestCafe(id: 'cafe-2', name: 'North Roast'),
    ];
    final container = createTestContainer(
      state: buildTestAppShellState(
        isAdmin: true,
        cafes: cafes,
      ),
      overrides: [
        profilesServiceProvider.overrideWithValue(
          _ResponsiveProfilesService(profiles),
        ),
        cafeQueryServiceProvider.overrideWithValue(
          _ResponsiveCafeQueryService(cafes),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      buildTestApp(container: container, child: const AdminScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin-tab-cafes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin-add-cafe-button')), findsOneWidget);
    expect(find.byKey(const Key('admin-cafe-edit-cafe-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
