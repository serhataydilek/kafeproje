import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kafeproje/l10n/app_localizations.dart';
import 'package:kafeproje/models/cafe_cache.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/repositories/cafe_repository.dart';
import 'package:kafeproje/services/connectivity_service.dart';
import 'package:kafeproje/theme/app_theme.dart';
import 'package:kafeproje/utils/request_cancellation.dart';

const testUser = CurrentUser(
  id: 'user-1',
  email: 'user@example.com',
  name: 'Test User',
);

class TestAppShellState extends AppShellState {
  const TestAppShellState({
    super.startupStatus = AppStartupStatus.ready,
    super.themeMode = AppThemeMode.light,
    super.currentUser = testUser,
    super.isAuthReady = true,
    super.isOnboardingCompleted = false,
    super.isAdmin = false,
    super.isAdminRoleResolved = true,
    super.adminRoleStatusMessage,
    super.isSigningOut = false,
    this.cafeState = const CafeState(),
    this.profileState = const ProfileState(),
    this.friendsState = const FriendsState(),
    this.offlineSyncState = const OfflineSyncState(),
  });

  final CafeState cafeState;
  final ProfileState profileState;
  final FriendsState friendsState;
  final OfflineSyncState offlineSyncState;
}

Cafe buildTestCafe({
  required String id,
  required String name,
  String district = 'Kadikoy',
  String neighborhood = 'Moda',
  double rating = 4.5,
  Object priceLevel = '\$\$',
  Object wifiQuality = 'Strong',
  Object outletAvailability = 'High',
  Object quietnessLevel = 'Quiet',
  double ambianceScore = 4.6,
  double seatingComfort = 4.4,
  bool studyFriendly = true,
  bool petFriendly = false,
  bool outdoorSeating = false,
  Object smokingPolicy = 'not_allowed',
  List<String> images = const [],
  List<String> tags = const ['Coffee', 'Study'],
}) {
  return Cafe(
    id: id,
    name: name,
    category: CafeCategory.normalCafe,
    district: district,
    neighborhood: neighborhood,
    address: '$neighborhood, $district',
    rating: rating,
    reviewCount: 120,
    priceLevel: priceLevel,
    tags: tags,
    images: images,
    description: '$name description',
    openingHours: const [],
    wifiQuality: wifiQuality,
    outletAvailability: outletAvailability,
    quietnessLevel: quietnessLevel,
    ambianceScore: ambianceScore,
    studyFriendly: studyFriendly,
    petFriendly: petFriendly,
    outdoorSeating: outdoorSeating,
    menuHighlights: const ['Latte'],
    seatingComfort: seatingComfort,
    openNow: true,
    smokingPolicy: smokingPolicy,
    coordinates: Coordinates(
      lat: 41.0 + id.length / 1000,
      lng: 29.0 + id.length / 1000,
    ),
  );
}

TestAppShellState buildTestAppShellState({
  List<Cafe> cafes = const [],
  List<Cafe>? homeCafes,
  List<Cafe> featuredCafes = const [],
  Coordinates? currentLocation,
  List<String> favorites = const [],
  List<String> compareList = const [],
  Filters filters = Filters.empty,
  Filters? exploreFilters,
  Filters? mapFilters,
  bool isAuthReady = true,
  bool isCafesLoading = false,
  bool isFavoritesLoading = false,
  bool isAdmin = false,
  bool? isAdminRoleResolved,
  String? adminRoleStatusMessage,
  CurrentUser? currentUser = testUser,
  AppThemeMode themeMode = AppThemeMode.light,
  String? cafesErrorMessage,
  String? cafesNoticeMessage,
  String? loadMoreErrorMessage,
  String? nextPageToken,
  bool hasMorePages = false,
  bool isLoadingMore = false,
  CafeSyncState cafeSyncState = CafeSyncState.ready,
  bool hasInitializedDiscovery = true,
  bool isRadiusRefreshInFlight = false,
  bool isServingStaleCache = false,
  DateTime? cafesLastUpdated,
  String? selectedCafeId,
  int selectedCafeFocusVersion = 0,
  MapRadiusPreset mapRadiusPreset = MapRadiusPreset.defaultPreset,
}) {
  final resolvedAdminRole = isAdminRoleResolved ?? (currentUser != null);

  return TestAppShellState(
    themeMode: themeMode,
    currentUser: currentUser,
    isAuthReady: isAuthReady,
    isAdmin: isAdmin,
    isAdminRoleResolved: resolvedAdminRole,
    adminRoleStatusMessage: adminRoleStatusMessage,
    cafeState: CafeState(
      cafes: cafes,
      homeCafes: homeCafes ?? cafes,
      hasLoadedHomeCafes: (homeCafes ?? cafes).isNotEmpty,
      featuredCafes: featuredCafes,
      hasLoadedFeaturedCafes: featuredCafes.isNotEmpty,
      currentLocation: currentLocation,
      hasInitializedDiscovery: hasInitializedDiscovery,
      isCafesLoading: isCafesLoading,
      isRadiusRefreshInFlight: isRadiusRefreshInFlight,
      isServingStaleCache: isServingStaleCache,
      cafesErrorMessage: cafesErrorMessage,
      cafesNoticeMessage: cafesNoticeMessage,
      cafesLastUpdated: cafesLastUpdated,
      filters: filters,
      exploreFilters: exploreFilters ?? filters,
      mapFilters: mapFilters ?? Filters.empty,
      nextPageToken: nextPageToken,
      hasMorePages: hasMorePages,
      isLoadingMore: isLoadingMore,
      loadMoreErrorMessage: loadMoreErrorMessage,
      cafeSyncState: cafeSyncState,
      selectedCafeId: selectedCafeId,
      selectedCafeFocusVersion: selectedCafeFocusVersion,
      mapRadiusPreset: mapRadiusPreset,
      displayedMapRadiusPreset: mapRadiusPreset,
    ),
    profileState: ProfileState(
      favorites: favorites,
      isFavoritesLoading: isFavoritesLoading,
      compareList: compareList,
    ),
  );
}

List<Override> testStateOverrides(AppShellState state) {
  final testState = state is TestAppShellState ? state : null;
  return [
    appShellProvider.overrideWith(
      (ref) => AppShellNotifier.test(ref, initialState: state),
    ),
    cafeProvider.overrideWith(
      (ref) => CafeNotifier.test(
        ref,
        initialState: testState?.cafeState ?? const CafeState(),
      ),
    ),
    profileProvider.overrideWith(
      (ref) => ProfileNotifier.test(
        ref,
        initialState: testState?.profileState ?? const ProfileState(),
      ),
    ),
    friendsProvider.overrideWith(
      (ref) => FriendsNotifier.test(
        ref,
        initialState: testState?.friendsState ?? const FriendsState(),
      ),
    ),
    offlineSyncProvider.overrideWith(
      (ref) => OfflineSyncNotifier.test(
        ref,
        initialState: testState?.offlineSyncState ?? const OfflineSyncState(),
      ),
    ),
  ];
}

CafeState testCafeState(AppShellState state) {
  if (state case TestAppShellState(:final cafeState)) {
    return cafeState;
  }
  return const CafeState();
}

ProfileState testProfileState(AppShellState state) {
  if (state case TestAppShellState(:final profileState)) {
    return profileState;
  }
  return const ProfileState();
}

FriendsState testFriendsState(AppShellState state) {
  if (state case TestAppShellState(:final friendsState)) {
    return friendsState;
  }
  return const FriendsState();
}

OfflineSyncState testOfflineSyncState(AppShellState state) {
  if (state case TestAppShellState(:final offlineSyncState)) {
    return offlineSyncState;
  }
  return const OfflineSyncState();
}

ProviderContainer createTestContainer({
  required AppShellState state,
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      ...testStateOverrides(state),
      connectivityServiceProvider.overrideWith((ref) {
        final service = TestConnectivityService(initiallyOnline: true);
        ref.onDispose(() {
          unawaited(service.dispose());
        });
        return service;
      }),
      ...overrides,
    ],
  );
}

Widget buildTestApp({
  required ProviderContainer container,
  required Widget child,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('tr')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

Widget buildTestRouterApp({
  required ProviderContainer container,
  required GoRouter router,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('tr')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

final transparentImageProvider = MemoryImage(
  Uint8List.fromList(const <int>[
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
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]),
);

class FakeCafeRepository extends CafeRepository {
  FakeCafeRepository({
    required Future<CafeRepositoryResult> Function(String? pageToken) onFetch,
    Future<CafeRepositoryResult> Function({
      String? pageToken,
      double? lat,
      double? lng,
      String? district,
      int radius,
      bool seedOnly,
      String? discoveryCacheKey,
    })? onFetchRequest,
    Future<CafeListCacheSnapshot?> Function(String cacheKey)?
        onLoadCachedCafeList,
    Future<Cafe?> Function(String cafeId, List<Cafe> fallback)?
        onLoadCachedCafeDetail,
    Future<Cafe?> Function(
      String cafeId,
      List<Cafe> fallback,
      RequestCancellationToken? cancellationToken,
    )? onFetchCafeDetails,
    Future<CafeRepositoryResult> Function(String query)? onSearchCafesByName,
    Future<List<Cafe>> Function()? onFetchFeaturedCafes,
    Future<List<Cafe>> Function(Iterable<Cafe> featuredCafes)?
        onHydrateFeaturedGoogleRatingMetadata,
    Future<List<Cafe>> Function(List<String> cafeIds)? onGetCafesByIds,
    Future<void> Function(
      String cacheKey,
      List<Cafe> cafes,
      String? nextPageToken,
    )? onSaveCafeListSnapshot,
  })  : _onFetch = onFetch,
        _onFetchRequest = onFetchRequest,
        _onLoadCachedCafeList = onLoadCachedCafeList,
        _onLoadCachedCafeDetail = onLoadCachedCafeDetail,
        _onFetchCafeDetails = onFetchCafeDetails,
        _onSearchCafesByName = onSearchCafesByName,
        _onFetchFeaturedCafes = onFetchFeaturedCafes,
        _onHydrateFeaturedGoogleRatingMetadata =
            onHydrateFeaturedGoogleRatingMetadata,
        _onGetCafesByIds = onGetCafesByIds,
        _onSaveCafeListSnapshot = onSaveCafeListSnapshot,
        super(null);

  final Future<CafeRepositoryResult> Function(String? pageToken) _onFetch;
  final Future<CafeRepositoryResult> Function({
    String? pageToken,
    double? lat,
    double? lng,
    String? district,
    int radius,
    bool seedOnly,
    String? discoveryCacheKey,
  })? _onFetchRequest;
  final Future<CafeListCacheSnapshot?> Function(String cacheKey)?
      _onLoadCachedCafeList;
  final Future<Cafe?> Function(String cafeId, List<Cafe> fallback)?
      _onLoadCachedCafeDetail;
  final Future<Cafe?> Function(
    String cafeId,
    List<Cafe> fallback,
    RequestCancellationToken? cancellationToken,
  )? _onFetchCafeDetails;
  final Future<CafeRepositoryResult> Function(String query)?
      _onSearchCafesByName;
  final Future<List<Cafe>> Function()? _onFetchFeaturedCafes;
  final Future<List<Cafe>> Function(Iterable<Cafe> featuredCafes)?
      _onHydrateFeaturedGoogleRatingMetadata;
  final Future<List<Cafe>> Function(List<String> cafeIds)? _onGetCafesByIds;
  final Future<void> Function(
    String cacheKey,
    List<Cafe> cafes,
    String? nextPageToken,
  )? _onSaveCafeListSnapshot;
  final Map<String, Cafe> _rememberedCafes = <String, Cafe>{};

  @override
  Future<CafeRepositoryResult> fetchDiscoverableCafes({
    String? pageToken,
    double? lat,
    double? lng,
    String? district,
    int radius = 5000,
    bool seedOnly = false,
    bool bypassRateLimit = false,
    String? discoveryCacheKey,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    final requestCallback = _onFetchRequest;
    if (requestCallback != null) {
      return requestCallback(
        pageToken: pageToken,
        lat: lat,
        lng: lng,
        district: district,
        radius: radius,
        seedOnly: seedOnly,
        discoveryCacheKey: discoveryCacheKey,
      );
    }
    return _onFetch(pageToken);
  }

  @override
  Future<CafeRepositoryResult> fetchCafes({
    String? pageToken,
    double? lat,
    double? lng,
    String? district,
    int radius = 5000,
    bool seedOnly = false,
    bool bypassRateLimit = false,
    String? discoveryCacheKey,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    return fetchDiscoverableCafes(
      pageToken: pageToken,
      lat: lat,
      lng: lng,
      district: district,
      radius: radius,
      seedOnly: seedOnly,
      bypassRateLimit: bypassRateLimit,
      discoveryCacheKey: discoveryCacheKey,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
  }

  @override
  Future<List<Cafe>> fetchFeaturedCafes({
    int limit = 40,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    final callback = _onFetchFeaturedCafes;
    if (callback == null) {
      return const <Cafe>[];
    }
    return callback();
  }

  @override
  Future<List<Cafe>> hydrateFeaturedGoogleRatingMetadata(
    Iterable<Cafe> featuredCafes, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    final callback = _onHydrateFeaturedGoogleRatingMetadata;
    if (callback == null) {
      return Future<List<Cafe>>.value(const <Cafe>[]);
    }
    return callback(featuredCafes);
  }

  @override
  void rememberCafes(Iterable<Cafe> cafes) {
    for (final cafe in cafes) {
      _rememberedCafes[cafe.id] = cafe;
      final placeId = cafe.placeId?.trim();
      if (placeId != null && placeId.isNotEmpty) {
        _rememberedCafes[placeId] = cafe;
      }
    }
  }

  @override
  Future<CafeListCacheSnapshot?> loadCachedCafeList({
    required String cacheKey,
  }) async {
    final callback = _onLoadCachedCafeList;
    if (callback == null) {
      return null;
    }
    return callback(cacheKey);
  }

  @override
  Future<Cafe?> loadCachedCafeDetail(
    String cafeId, {
    List<Cafe> fallback = const [],
  }) async {
    final callback = _onLoadCachedCafeDetail;
    if (callback == null) {
      return null;
    }
    return callback(cafeId, fallback);
  }

  @override
  Future<void> saveCafeListSnapshot(
    String cacheKey,
    List<Cafe> cafes, {
    String? nextPageToken,
  }) async {
    final callback = _onSaveCafeListSnapshot;
    if (callback == null) {
      return;
    }
    await callback(cacheKey, cafes, nextPageToken);
  }

  @override
  Future<Cafe?> fetchCafeDetails(
    String cafeId, {
    List<Cafe> fallback = const [],
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    final callback = _onFetchCafeDetails;
    if (callback == null) {
      return super.fetchCafeDetails(
        cafeId,
        fallback: fallback,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );
    }
    return callback(cafeId, fallback, cancellationToken);
  }

  @override
  Future<CafeRepositoryResult> searchCafesByName(
    String query, {
    int limit = 20,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    final callback = _onSearchCafesByName;
    if (callback == null) {
      return super.searchCafesByName(
        query,
        limit: limit,
        requestTimeout: requestTimeout,
        cancellationToken: cancellationToken,
      );
    }
    return callback(query);
  }

  @override
  Future<List<Cafe>> getCafesByIds(
    List<String> cafeIds, {
    bool includeDeleted = false,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) {
    final callback = _onGetCafesByIds;
    if (callback != null) {
      return callback(cafeIds);
    }
    final cafes = <Cafe>[];
    final seen = <String>{};
    for (final id in cafeIds) {
      final cafe = _rememberedCafes[id.trim()];
      if (cafe == null || !seen.add(cafe.id)) {
        continue;
      }
      cafes.add(cafe);
    }
    return Future.value(cafes);
  }
}

class TestConnectivityService extends ConnectivityService {
  TestConnectivityService({required bool initiallyOnline})
      : _currentlyOnline = initiallyOnline;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _currentlyOnline;

  @override
  bool get currentlyOnline => _currentlyOnline;

  @override
  Stream<bool> get isOnline async* {
    yield _currentlyOnline;
    yield* _controller.stream;
  }

  void emit(bool isOnline) {
    _currentlyOnline = isOnline;
    _controller.add(isOnline);
  }

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
