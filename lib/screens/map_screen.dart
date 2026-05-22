import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/app_cache_config.dart';
import '../config/env.dart';
import '../l10n/l10n.dart';
import '../models/cafe_cache.dart';
import '../models/index.dart';
import '../providers/app_provider.dart';
import '../services/app_image_cache_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/cafe_media.dart';
import '../utils/istanbul_region.dart';
import '../utils/map_filter_state.dart';
import '../utils/lru_cache.dart';
import '../widgets/cafes/cafe_empty_state_card.dart';
import '../widgets/cafes/map_bottom_overlay.dart';
import '../widgets/layout/adaptive_layout.dart';
import '../widgets/ui/state_views.dart';

typedef MapLayerBuilder = Widget Function(
  BuildContext context,
  List<Cafe> cafes,
  String? selectedCafeId,
  ValueChanged<String> onTapMarker,
  VoidCallback onTapMap,
);

typedef CafeImageProviderBuilder = ImageProvider<Object> Function(String url);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    super.key,
    this.mapLayerBuilder,
    this.imageProviderBuilder,
    this.hasMapsConfigOverride,
    this.preserveInitialSelection = false,
  });

  final MapLayerBuilder? mapLayerBuilder;
  final CafeImageProviderBuilder? imageProviderBuilder;
  final bool? hasMapsConfigOverride;
  final bool preserveInitialSelection;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LruCache<String, _CachedCafePhotoProviders> _photoProvidersByCafeId =
      LruCache<String, _CachedCafePhotoProviders>(
    maxSize: RequestTuningConfig.photoProviderMemoryEntries,
    defaultTtl: RequestTuningConfig.photoProviderMemoryTtl,
  );
  CameraPosition? _cachedInitialCameraPosition;
  CameraPosition? _lastKnownCameraPosition;
  CameraPosition? _pendingCameraPosition;
  CameraPosition? _pendingDeviceCameraPosition;
  bool _didRestoreCachedSelection = false;
  bool _isOpeningWithCleanSelection = true;
  int _lastPreparedCafeFocusVersion = -1;
  int _lastAnimatedCafeFocusVersion = -1;
  ProviderSubscription<({String? cafeId, int focusVersion})>?
      _selectedCafeSelectionSub;
  ProviderSubscription<List<Cafe>>? _mapVisibleCafesSub;

  static const CameraPosition _istanbulCenter = CameraPosition(
    target: LatLng(
      istanbulCenterLat,
      istanbulCenterLng,
    ),
    zoom: 12,
  );
  static final CameraTargetBounds _istanbulBounds = CameraTargetBounds(
    LatLngBounds(
      southwest: const LatLng(istanbulSouthwestLat, istanbulSouthwestLng),
      northeast: const LatLng(istanbulNortheastLat, istanbulNortheastLng),
    ),
  );

  @override
  void initState() {
    super.initState();
    Future<void>(() {
      if (!mounted) {
        return;
      }
      if (!widget.preserveInitialSelection) {
        ref.read(cafeProvider.notifier).clearSelectedCafe();
      }
      if (mounted) {
        setState(() {
          _isOpeningWithCleanSelection = false;
        });
      }
    });
    _selectedCafeSelectionSub =
        ref.listenManual<({String? cafeId, int focusVersion})>(
      selectedCafeSelectionProvider,
      (_, next) {
        unawaited(
          _synchronizeSelectedCafe(
            ref.read(mapCafeResultsProvider),
            next,
          ),
        );
      },
    );
    _mapVisibleCafesSub = ref.listenManual<List<Cafe>>(
      mapCafeResultsProvider,
      (_, next) {
        unawaited(
          _synchronizeSelectedCafe(
            next,
            ref.read(selectedCafeSelectionProvider),
          ),
        );
      },
    );
    _loadCachedMapView();
    unawaited(ref.read(cafeProvider.notifier).ensureMapQueryLoaded());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_determinePosition());
    });
  }

  Future<void> _loadCachedMapView() async {
    MapViewCacheSnapshot? snapshot;
    try {
      snapshot = await ref.read(cafeProvider.notifier).loadPersistedMapView();
    } catch (_) {
      return;
    }

    if (!mounted || snapshot == null) {
      return;
    }

    final cachedCamera = CameraPosition(
      target: LatLng(snapshot.lat, snapshot.lng),
      zoom: snapshot.zoom,
    );
    setState(() {
      _cachedInitialCameraPosition = cachedCamera;
      _lastKnownCameraPosition = cachedCamera;
    });

    _didRestoreCachedSelection = false;
  }

  Future<void> _determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (ref.read(selectedCafeIdProvider) != null) {
        return;
      }

      final targetCamera = CameraPosition(
        target: isWithinIstanbul(position.latitude, position.longitude)
            ? LatLng(position.latitude, position.longitude)
            : _istanbulCenter.target,
        zoom: 14,
      );
      _pendingDeviceCameraPosition = targetCamera;
      _lastKnownCameraPosition ??= targetCamera;

      if (!_controller.isCompleted) {
        return;
      }

      final mapController = await _controller.future;
      unawaited(mapController.animateCamera(
        CameraUpdate.newCameraPosition(targetCamera),
      ));
      _pendingDeviceCameraPosition = null;
    } catch (_) {
      // Ignore location fetch errors.
    }
  }

  List<ImageProvider<Object>> _photoProvidersFor(Cafe cafe) {
    final imageUrls = cafe.photoUrls
        .map(
          (rawUrl) => resolveCafeImageUrl(
            rawUrl,
            maxWidthPx: CafeImageVariant.mapPreview.requestWidthPx,
          ),
        )
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .take(5)
        .toList(growable: false);
    final cached = _photoProvidersByCafeId.get(cafe.id);
    if (cached != null && listEquals(cached.imageUrls, imageUrls)) {
      return cached.providers;
    }

    final providers = imageUrls
        .map<ImageProvider<Object>>(
          (sizedUrl) =>
              widget.imageProviderBuilder?.call(sizedUrl) ??
              CachedNetworkImageProvider(
                sizedUrl,
                cacheManager: AppImageCacheManager.instance,
                cacheKey: sizedUrl,
                maxWidth: CafeImageVariant.mapPreview.decodeWidthPx,
                maxHeight: CafeImageVariant.mapPreview.decodeHeightPx,
              ),
        )
        .take(5)
        .toList(growable: false);
    _photoProvidersByCafeId.put(
      cafe.id,
      _CachedCafePhotoProviders(
        imageUrls: imageUrls,
        providers: providers,
      ),
    );

    if (providers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(precacheImage(providers.first, context));
        }
      });
    }

    return providers;
  }

  Future<void> _synchronizeSelectedCafe(
    List<Cafe> cafes,
    ({String? cafeId, int focusVersion}) selection,
  ) async {
    final cafeId = selection.cafeId;
    if (_isOpeningWithCleanSelection) {
      return;
    }
    if (cafeId == null) {
      return;
    }

    final cafe = _findCafeById(cafes, cafeId);
    if (cafe == null) {
      return;
    }

    if (_lastPreparedCafeFocusVersion != selection.focusVersion) {
      _photoProvidersFor(cafe);
      _lastPreparedCafeFocusVersion = selection.focusVersion;
    }

    if (!_controller.isCompleted) {
      return;
    }

    if (_lastAnimatedCafeFocusVersion == selection.focusVersion) {
      return;
    }

    final controller = await _controller.future;
    final latestSelection = ref.read(selectedCafeSelectionProvider);
    if (latestSelection.focusVersion != selection.focusVersion ||
        latestSelection.cafeId != cafeId) {
      return;
    }

    final latestCafe = _findCafeById(ref.read(mapCafeResultsProvider), cafeId);
    if (latestCafe == null ||
        !_hasUsableMapCoordinates(latestCafe.coordinates)) {
      return;
    }

    _lastAnimatedCafeFocusVersion = selection.focusVersion;
    final target = LatLng(
      latestCafe.coordinates.lat,
      latestCafe.coordinates.lng,
    );

    AppLogger.debug(
      '[CAFE_DIAG_MARKER] selectedCafeId=$cafeId focusVersion=${selection.focusVersion} lat=${latestCafe.coordinates.lat.toStringAsFixed(6)} lng=${latestCafe.coordinates.lng.toStringAsFixed(6)}',
      key: 'cafe-diag-marker',
      throttle: Duration.zero,
    );

    unawaited(controller.animateCamera(
      CameraUpdate.newLatLng(target),
    ));
  }

  void _selectCafe(String cafeId) {
    ref.read(cafeProvider.notifier).selectCafeForMap(cafeId);
    unawaited(_persistMapView(selectedCafeId: cafeId));
  }

  void _clearSelection() {
    ref.read(cafeProvider.notifier).clearSelectedCafe();
    unawaited(_persistMapView(selectedCafeId: null));
  }

  void _syncCurrentSelection() {
    unawaited(
      _synchronizeSelectedCafe(
        ref.read(mapCafeResultsProvider),
        ref.read(selectedCafeSelectionProvider),
      ),
    );
  }

  void _handleCameraMove(CameraPosition position) {
    _pendingCameraPosition = position;
  }

  void _handleCameraIdle() {
    final position = _pendingCameraPosition;
    if (position == null) {
      return;
    }
    _lastKnownCameraPosition = position;
    _pendingCameraPosition = null;
    unawaited(
      _persistMapView(
        selectedCafeId: ref.read(selectedCafeIdProvider),
      ),
    );
  }

  Future<void> _persistMapView({String? selectedCafeId}) async {
    final camera = _pendingCameraPosition ?? _lastKnownCameraPosition;
    if (camera == null) {
      return;
    }

    try {
      await ref.read(cafeProvider.notifier).persistMapView(
            lat: camera.target.latitude,
            lng: camera.target.longitude,
            zoom: camera.zoom,
            selectedCafeId: selectedCafeId,
          );
    } catch (_) {
      // Ignore cache persistence failures so map interactions remain usable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAuthReady = ref.watch(isAuthReadyProvider);
    final hasInitializedDiscovery = ref.watch(
      cafeProvider.select((state) => state.hasInitializedDiscovery),
    );
    final isCafesLoading = ref.watch(isCafesLoadingProvider);
    final filters = ref.watch(mapFiltersProvider);
    final cafeSyncState = ref.watch(cafeSyncStateProvider);
    final cafesError = ref.watch(cafesErrorProvider);
    final cacheStatus = ref.watch(cafeCacheStatusProvider);
    final filteredCafes = ref.watch(mapFilteredCafesProvider);
    final mapVisibleCafes = ref.watch(mapCafeResultsProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    final mapRadiusPreset = ref.watch(mapRadiusPresetProvider);
    final discoveryDiagnostics = ref.watch(cafeDiscoveryDiagnosticsProvider);
    final isRadiusRefreshInFlight = ref.watch(isRadiusRefreshInFlightProvider);
    final selectedCafeSelection = ref.watch(selectedCafeSelectionProvider);
    final effectiveSelectedCafeSelection = _isOpeningWithCleanSelection
        ? (
            cafeId: null,
            focusVersion: selectedCafeSelection.focusVersion,
          )
        : selectedCafeSelection;
    final compareCount = ref.watch(
      normalizedCompareListProvider.select((list) => list.length),
    );
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final layout =
        AdaptiveLayoutData.fromWidth(MediaQuery.sizeOf(context).width);
    final l10n = context.l10n;
    final hasMapsConfig =
        widget.hasMapsConfigOverride ?? Env.hasGoogleMapsConfig;
    final isLoading = cafeSyncState == CafeSyncState.loading;
    final showBlockingLoader =
        (!hasInitializedDiscovery || isLoading || isCafesLoading) &&
            filteredCafes.isEmpty;

    final selectedCafe = _findCafeById(
      mapVisibleCafes,
      effectiveSelectedCafeSelection.cafeId,
    );
    if (_didRestoreCachedSelection &&
        !isLoading &&
        effectiveSelectedCafeSelection.cafeId != null &&
        selectedCafe == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(cafeProvider.notifier).clearSelectedCafe();
      });
      _didRestoreCachedSelection = false;
    } else if (_didRestoreCachedSelection && selectedCafe != null) {
      _didRestoreCachedSelection = false;
    }
    final filterResultState = resolveMapFilterResultState(
      allCafes: filteredCafes,
      filteredCafes: mapVisibleCafes,
      filters: filters,
    );
    final hasDistrictSelection = filters.effectiveDistricts.isNotEmpty;
    final nearbyRadiusCenter = currentLocation ?? istanbulCenterCoordinates;
    final nearbyRadiusMeters = mapRadiusPreset.radiusMeters;
    final isNearbyRadiusEmpty = !hasDistrictSelection &&
        filteredCafes.isNotEmpty &&
        mapVisibleCafes.isEmpty;
    final showMapEmptyOverlay =
        filterResultState == MapFilterResultState.noResultsForFilters ||
            isNearbyRadiusEmpty ||
            (filterResultState == MapFilterResultState.noData &&
                cafeSyncState == CafeSyncState.empty &&
                !isCafesLoading);
    final diagnosticsCenter = _diagnosticQuadrantCenter(currentLocation);
    final quadrantCounts = _buildQuadrantCounts(
      cafes: mapVisibleCafes,
      center: diagnosticsCenter,
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: !isAuthReady
            ? LoadingStateView(colors: colors, label: l10n.commonLoading)
            : currentUser == null
                ? SignInRequiredStateView(
                    colors: colors,
                    icon: Icons.map_outlined,
                    onSignIn: () => context.go('/auth'),
                  )
                : !hasMapsConfig
                    ? EmptyStateView(
                        colors: colors,
                        icon: Icons.map_outlined,
                        title: l10n.navMap,
                        message: l10n.mapUnavailableMessage,
                      )
                    : showBlockingLoader
                        ? LoadingStateView(
                            colors: colors,
                            label: l10n.mapPreparing,
                          )
                        : cafesError != null && filteredCafes.isEmpty
                            ? ErrorStateView(
                                colors: colors,
                                message: cafesError,
                                onRetry: () => ref
                                    .read(cafeProvider.notifier)
                                    .refreshCafes(),
                              )
                            : Stack(
                                children: [
                                  Positioned.fill(
                                    child: widget.mapLayerBuilder?.call(
                                          context,
                                          mapVisibleCafes,
                                          effectiveSelectedCafeSelection.cafeId,
                                          _selectCafe,
                                          _clearSelection,
                                        ) ??
                                        _MapLayer(
                                          cafes: mapVisibleCafes,
                                          selectedCafeId:
                                              effectiveSelectedCafeSelection
                                                  .cafeId,
                                          initialCameraPosition:
                                              _cachedInitialCameraPosition ??
                                                  _istanbulCenter,
                                          onMapCreated: (controller) {
                                            if (!_controller.isCompleted) {
                                              _controller.complete(controller);
                                            }
                                            final cachedCamera =
                                                _cachedInitialCameraPosition;
                                            if (cachedCamera != null) {
                                              controller.moveCamera(
                                                CameraUpdate.newCameraPosition(
                                                  cachedCamera,
                                                ),
                                              );
                                            } else {
                                              final pendingDeviceCamera =
                                                  _pendingDeviceCameraPosition;
                                              if (pendingDeviceCamera != null) {
                                                controller.moveCamera(
                                                  CameraUpdate
                                                      .newCameraPosition(
                                                    pendingDeviceCamera,
                                                  ),
                                                );
                                                _pendingDeviceCameraPosition =
                                                    null;
                                              }
                                            }
                                            _syncCurrentSelection();
                                          },
                                          onCameraMove: _handleCameraMove,
                                          onCameraIdle: _handleCameraIdle,
                                          onTapMap: _clearSelection,
                                          onTapMarker: _selectCafe,
                                          cameraTargetBounds: _istanbulBounds,
                                          nearbyRadiusCenter:
                                              hasDistrictSelection
                                                  ? null
                                                  : nearbyRadiusCenter,
                                          nearbyRadiusMeters:
                                              hasDistrictSelection
                                                  ? null
                                                  : nearbyRadiusMeters,
                                          nearbyRadiusColor: colors.primary,
                                        ),
                                  ),
                                  if (showMapEmptyOverlay)
                                    Positioned(
                                      key: const Key('map-empty-overlay'),
                                      top: layout.horizontalPadding,
                                      left: layout.horizontalPadding,
                                      right: layout.horizontalPadding,
                                      child: CafeEmptyStateCard(
                                        colors: colors,
                                        icon: Icons.travel_explore_rounded,
                                        title: l10n.mapEmptyTitle,
                                        message: isNearbyRadiusEmpty
                                            ? l10n.mapNearbyEmptyMessage
                                            : filterResultState ==
                                                    MapFilterResultState
                                                        .noResultsForFilters
                                                ? l10n
                                                    .mapNoResultsForFiltersMessage
                                                : l10n
                                                    .mapDataUnavailableOverlayMessage,
                                        actionLabel: filters.activeCount > 0
                                            ? l10n.commonReset
                                            : null,
                                        onAction: filters.activeCount > 0
                                            ? () => ref
                                                .read(cafeProvider.notifier)
                                                .resetMapFilters()
                                            : null,
                                      ),
                                    ),
                                  if (kDebugMode)
                                    Positioned(
                                      top: layout.horizontalPadding,
                                      left: layout.horizontalPadding,
                                      child: IgnorePointer(
                                        child: _MapDiagnosticsCard(
                                          colors: colors,
                                          radiusMeters:
                                              mapRadiusPreset.radiusMeters,
                                          visibleCafeCount:
                                              mapVisibleCafes.length,
                                          filteredCafeCount:
                                              filteredCafes.length,
                                          rawFetchedCount: discoveryDiagnostics
                                              ?.rawFetchedCount,
                                          classifierRejectedCount:
                                              discoveryDiagnostics
                                                  ?.rejectedByClassifierCount,
                                          dedupeRejectedCount:
                                              discoveryDiagnostics
                                                  ?.rejectedByDedupeCount,
                                          quadrantCounts: quadrantCounts,
                                        ),
                                      ),
                                    ),
                                  if (cacheStatus != null &&
                                      cacheStatus.shouldShowBanner &&
                                      !isRadiusRefreshInFlight)
                                    Positioned(
                                      top: 0,
                                      left: layout.horizontalPadding,
                                      right: layout.horizontalPadding,
                                      child: IgnorePointer(
                                        child: CafeCacheStatusBanner(
                                          colors: colors,
                                          status: cacheStatus,
                                        ),
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: MapBottomOverlay(
                                      colors: colors,
                                      filtersActiveCount: filters.activeCount,
                                      compareCount: compareCount,
                                      selectedCafe: selectedCafe,
                                      radiusPreset: mapRadiusPreset,
                                      isRadiusEnabled: !hasDistrictSelection,
                                      isRadiusRefreshing:
                                          isRadiusRefreshInFlight,
                                      onLocate: _determinePosition,
                                      onSelectRadiusPreset: (preset) {
                                        if (ref
                                            .read(mapFiltersProvider)
                                            .effectiveDistricts
                                            .isNotEmpty) {
                                          return;
                                        }
                                        ref
                                            .read(cafeProvider.notifier)
                                            .setMapRadiusPreset(preset);
                                      },
                                      onOpenFilters: () =>
                                          context.push('/filters?scope=map'),
                                      onOpenCompare: () =>
                                          context.push('/compare'),
                                      onOpenDetails: selectedCafe == null
                                          ? null
                                          : () => context.push(
                                                '/cafe/${selectedCafe.id}?source=map',
                                              ),
                                      onCloseSelectedCafe: _clearSelection,
                                    ),
                                  ),
                                ],
                              ),
      ),
    );
  }

  LatLng _diagnosticQuadrantCenter(Coordinates? currentLocation) {
    final camera = _pendingCameraPosition ??
        _lastKnownCameraPosition ??
        _cachedInitialCameraPosition;
    if (camera != null) {
      return camera.target;
    }
    final fallback = currentLocation ?? istanbulCenterCoordinates;
    return LatLng(fallback.lat, fallback.lng);
  }

  _MapQuadrantCounts _buildQuadrantCounts({
    required List<Cafe> cafes,
    required LatLng center,
  }) {
    var topLeft = 0;
    var topRight = 0;
    var bottomLeft = 0;
    var bottomRight = 0;

    for (final cafe in cafes) {
      final isTop = cafe.coordinates.lat >= center.latitude;
      final isRight = cafe.coordinates.lng >= center.longitude;
      if (isTop && isRight) {
        topRight += 1;
      } else if (isTop && !isRight) {
        topLeft += 1;
      } else if (!isTop && isRight) {
        bottomRight += 1;
      } else {
        bottomLeft += 1;
      }
    }

    return _MapQuadrantCounts(
      topLeft: topLeft,
      topRight: topRight,
      bottomLeft: bottomLeft,
      bottomRight: bottomRight,
    );
  }

  @override
  void dispose() {
    _selectedCafeSelectionSub?.close();
    _mapVisibleCafesSub?.close();
    _photoProvidersByCafeId.clear();
    super.dispose();
  }
}

class _MapLayer extends StatefulWidget {
  const _MapLayer({
    required this.cafes,
    required this.selectedCafeId,
    required this.initialCameraPosition,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.onTapMap,
    required this.onTapMarker,
    required this.cameraTargetBounds,
    required this.nearbyRadiusCenter,
    required this.nearbyRadiusMeters,
    required this.nearbyRadiusColor,
  });

  final List<Cafe> cafes;
  final String? selectedCafeId;
  final CameraPosition initialCameraPosition;
  final ValueChanged<GoogleMapController> onMapCreated;
  final ValueChanged<CameraPosition> onCameraMove;
  final VoidCallback onCameraIdle;
  final VoidCallback onTapMap;
  final ValueChanged<String> onTapMarker;
  final CameraTargetBounds cameraTargetBounds;
  final Coordinates? nearbyRadiusCenter;
  final int? nearbyRadiusMeters;
  final Color nearbyRadiusColor;

  @override
  State<_MapLayer> createState() => _MapLayerState();
}

class _MapLayerState extends State<_MapLayer> {
  static const int _markerBatchSize = 24;
  static const Duration _markerBatchDelay = Duration(milliseconds: 18);

  Map<String, Marker> _markersById = const <String, Marker>{};
  late final BitmapDescriptor _selectedIcon;
  late final BitmapDescriptor _unselectedIcon;
  Timer? _markerBatchTimer;
  int _markerBatchGeneration = 0;

  Set<Circle> get _nearbyRadiusCircles {
    final center = widget.nearbyRadiusCenter;
    final radiusMeters = widget.nearbyRadiusMeters;
    if (center == null || radiusMeters == null || radiusMeters <= 0) {
      return const <Circle>{};
    }

    return <Circle>{
      Circle(
        circleId: const CircleId('map-nearby-radius'),
        center: LatLng(center.lat, center.lng),
        radius: radiusMeters.toDouble(),
        strokeWidth: 1,
        strokeColor: widget.nearbyRadiusColor.withValues(alpha: 0.38),
        fillColor: widget.nearbyRadiusColor.withValues(alpha: 0.10),
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    _selectedIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueRed,
    );
    _unselectedIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueOrange,
    );
    _rebuildMarkers();
  }

  @override
  void didUpdateWidget(covariant _MapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCafeList(widget.cafes, oldWidget.cafes)) {
      _rebuildMarkers();
      return;
    }

    if (widget.selectedCafeId != oldWidget.selectedCafeId) {
      _updateSelectedMarkers(
        previousSelectedCafeId: oldWidget.selectedCafeId,
        nextSelectedCafeId: widget.selectedCafeId,
      );
    }
  }

  void _rebuildMarkers() {
    final cafesByCoordinateBucket = <String, List<Cafe>>{};
    for (final cafe in widget.cafes) {
      if (!_hasUsableMapCoordinates(cafe.coordinates)) {
        continue;
      }
      cafesByCoordinateBucket
          .putIfAbsent(_coordinateBucketKey(cafe.coordinates), () => <Cafe>[])
          .add(cafe);
    }

    final nextMarkersById = <String, Marker>{};
    for (final bucket in cafesByCoordinateBucket.values) {
      bucket.sort((left, right) => left.id.compareTo(right.id));
      for (var index = 0; index < bucket.length; index++) {
        final cafe = bucket[index];
        final markerPosition = _spreadMarkerPosition(
          cafe.coordinates,
          spreadIndex: index,
          spreadTotal: bucket.length,
        );
        nextMarkersById[cafe.id] = _buildMarker(
          cafe,
          position: markerPosition,
          isSelected: _matchesSelectedCafe(cafe, widget.selectedCafeId),
        );
      }
    }

    _applyMarkerUpdate(nextMarkersById);
  }

  void _updateSelectedMarkers({
    required String? previousSelectedCafeId,
    required String? nextSelectedCafeId,
  }) {
    if (previousSelectedCafeId == nextSelectedCafeId) {
      return;
    }
    if (_markerBatchTimer != null) {
      _cancelMarkerBatch();
      _rebuildMarkers();
      return;
    }

    final previousCafe = _findCafeById(widget.cafes, previousSelectedCafeId);
    final nextCafe = _findCafeById(widget.cafes, nextSelectedCafeId);
    if (previousCafe == null && nextCafe == null) {
      return;
    }

    final updatedMarkersById = Map<String, Marker>.from(_markersById);
    if (previousCafe != null) {
      updatedMarkersById[previousCafe.id] = _buildMarker(
        previousCafe,
        position: _spreadPositionForCafe(previousCafe),
        isSelected: false,
      );
    }
    if (nextCafe != null) {
      updatedMarkersById[nextCafe.id] = _buildMarker(
        nextCafe,
        position: _spreadPositionForCafe(nextCafe),
        isSelected: true,
      );
    }

    if (mapEquals(_markersById, updatedMarkersById)) {
      return;
    }

    setState(() {
      _markersById = updatedMarkersById;
    });
  }

  void _applyMarkerUpdate(Map<String, Marker> nextMarkersById) {
    if (mapEquals(_markersById, nextMarkersById)) {
      return;
    }

    final entries = nextMarkersById.entries.toList(growable: false);
    final shouldStage = _markersById.isEmpty &&
        widget.selectedCafeId == null &&
        entries.length > _markerBatchSize;
    if (!shouldStage) {
      _cancelMarkerBatch();
      setState(() {
        _markersById = nextMarkersById;
      });
      return;
    }

    _cancelMarkerBatch();
    final generation = ++_markerBatchGeneration;
    var nextIndex = 0;

    void publishNextBatch() {
      if (!mounted || generation != _markerBatchGeneration) {
        return;
      }

      final endIndex = math.min(nextIndex + _markerBatchSize, entries.length);
      final stagedMarkers = <String, Marker>{
        for (final entry in entries.take(endIndex)) entry.key: entry.value,
      };
      setState(() {
        _markersById = stagedMarkers;
      });

      nextIndex = endIndex;
      if (nextIndex >= entries.length) {
        _markerBatchTimer = null;
        return;
      }

      _markerBatchTimer = Timer(_markerBatchDelay, publishNextBatch);
    }

    publishNextBatch();
  }

  void _cancelMarkerBatch() {
    _markerBatchGeneration += 1;
    _markerBatchTimer?.cancel();
    _markerBatchTimer = null;
  }

  Marker _buildMarker(
    Cafe cafe, {
    required LatLng position,
    required bool isSelected,
  }) {
    return Marker(
      markerId: MarkerId(cafe.id),
      position: position,
      icon: isSelected ? _selectedIcon : _unselectedIcon,
      onTap: () => widget.onTapMarker(cafe.id),
    );
  }

  bool _matchesSelectedCafe(Cafe cafe, String? selectedCafeId) {
    if (selectedCafeId == null) {
      return false;
    }
    if (cafe.id == selectedCafeId) {
      return true;
    }
    final placeId = cafe.placeId?.trim();
    return placeId != null && placeId.isNotEmpty && placeId == selectedCafeId;
  }

  String _coordinateBucketKey(Coordinates coordinates) {
    return '${coordinates.lat.toStringAsFixed(5)}|${coordinates.lng.toStringAsFixed(5)}';
  }

  LatLng _spreadPositionForCafe(Cafe targetCafe) {
    final bucket = widget.cafes
        .where(
          (cafe) =>
              _hasUsableMapCoordinates(cafe.coordinates) &&
              _coordinateBucketKey(cafe.coordinates) ==
                  _coordinateBucketKey(targetCafe.coordinates),
        )
        .toList(growable: false)
      ..sort((left, right) => left.id.compareTo(right.id));
    final index = bucket.indexWhere((cafe) => cafe.id == targetCafe.id);
    return _spreadMarkerPosition(
      targetCafe.coordinates,
      spreadIndex: index < 0 ? 0 : index,
      spreadTotal: bucket.isEmpty ? 1 : bucket.length,
    );
  }

  LatLng _spreadMarkerPosition(
    Coordinates coordinates, {
    required int spreadIndex,
    required int spreadTotal,
  }) {
    if (spreadTotal <= 1) {
      return LatLng(coordinates.lat, coordinates.lng);
    }

    final ring = spreadIndex ~/ 8;
    final angle = (2 * math.pi * spreadIndex) / spreadTotal;
    final radiusMeters = 10.0 + (ring * 6.0);
    final latOffset = (radiusMeters * math.sin(angle)) / 111320.0;
    final cosLat =
        math.cos(coordinates.lat * math.pi / 180).abs().clamp(0.2, 1.0);
    final lngOffset = (radiusMeters * math.cos(angle)) / (111320.0 * cosLat);

    return LatLng(
      coordinates.lat + latOffset,
      coordinates.lng + lngOffset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: widget.initialCameraPosition,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        buildingsEnabled: false,
        indoorViewEnabled: false,
        trafficEnabled: false,
        tiltGesturesEnabled: false,
        cameraTargetBounds: widget.cameraTargetBounds,
        markers: _markersById.values.toSet(),
        circles: _nearbyRadiusCircles,
        onMapCreated: widget.onMapCreated,
        onCameraMove: widget.onCameraMove,
        onCameraIdle: widget.onCameraIdle,
        onTap: (_) => widget.onTapMap(),
      ),
    );
  }

  @override
  void dispose() {
    _cancelMarkerBatch();
    super.dispose();
  }
}

Cafe? _findCafeById(List<Cafe> cafes, String? cafeId) {
  if (cafeId == null) {
    return null;
  }

  for (final cafe in cafes) {
    if (cafe.id == cafeId || cafe.placeId == cafeId) {
      return cafe;
    }
  }

  return null;
}

bool _sameCafeList(List<Cafe> left, List<Cafe> right) {
  if (identical(left, right)) {
    return true;
  }

  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index++) {
    if (left[index].id != right[index].id) {
      return false;
    }
  }

  return true;
}

const Coordinates _unknownMapCoordinates = Coordinates(
  lat: 41.0082,
  lng: 28.9784,
);

bool _hasUsableMapCoordinates(Coordinates coordinates) {
  final lat = coordinates.lat;
  final lng = coordinates.lng;
  if (!lat.isFinite || !lng.isFinite) {
    return false;
  }

  if (lat.abs() > 90 || lng.abs() > 180) {
    return false;
  }

  return coordinates != _unknownMapCoordinates;
}

class _CachedCafePhotoProviders {
  const _CachedCafePhotoProviders({
    required this.imageUrls,
    required this.providers,
  });

  final List<String> imageUrls;
  final List<ImageProvider<Object>> providers;
}

class _MapQuadrantCounts {
  const _MapQuadrantCounts({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  final int topLeft;
  final int topRight;
  final int bottomLeft;
  final int bottomRight;
}

class _MapDiagnosticsCard extends StatelessWidget {
  const _MapDiagnosticsCard({
    required this.colors,
    required this.radiusMeters,
    required this.visibleCafeCount,
    required this.filteredCafeCount,
    required this.rawFetchedCount,
    required this.classifierRejectedCount,
    required this.dedupeRejectedCount,
    required this.quadrantCounts,
  });

  final AppColors colors;
  final int radiusMeters;
  final int visibleCafeCount;
  final int filteredCafeCount;
  final int? rawFetchedCount;
  final int? classifierRejectedCount;
  final int? dedupeRejectedCount;
  final _MapQuadrantCounts quadrantCounts;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: DefaultTextStyle(
          style: TextStyle(
            color: colors.text,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Map Debug',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text('radius: ${radiusMeters}m'),
              Text('visible: $visibleCafeCount | filtered: $filteredCafeCount'),
              Text('raw fetched: ${rawFetchedCount ?? '-'}'),
              Text('classifier rejected: ${classifierRejectedCount ?? '-'}'),
              Text('dedupe rejected: ${dedupeRejectedCount ?? '-'}'),
              const SizedBox(height: 4),
              Text(
                'quadrants TL:${quadrantCounts.topLeft} TR:${quadrantCounts.topRight}',
              ),
              Text(
                'quadrants BL:${quadrantCounts.bottomLeft} BR:${quadrantCounts.bottomRight}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
