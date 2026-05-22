part of 'app_core_providers.dart';

class PaginatedCafesView {
  const PaginatedCafesView({
    required this.nextPageToken,
    required this.hasMorePages,
    required this.isLoadingMore,
  });

  final String? nextPageToken;
  final bool hasMorePages;
  final bool isLoadingMore;
}

enum CafeCacheStatusKind {
  live,
  freshCached,
  staleCached,
  offlineFallback,
  unavailable,
}

class CafeCacheStatusView {
  const CafeCacheStatusView({
    required this.kind,
    required this.message,
    required this.isRefreshing,
  });

  final CafeCacheStatusKind kind;
  final String message;
  final bool isRefreshing;

  bool get shouldShowBanner =>
      kind == CafeCacheStatusKind.staleCached ||
      kind == CafeCacheStatusKind.offlineFallback ||
      kind == CafeCacheStatusKind.unavailable ||
      (kind == CafeCacheStatusKind.freshCached &&
          message.trim().isNotEmpty &&
          !isRefreshing) ||
      isRefreshing;
}

final cafesProvider = Provider<List<Cafe>>((ref) {
  final cafes = _filterBlockedPublicCafes(
    ref,
    _filterDeletedCafeIdentities(
      ref,
      ref.watch(cafeProvider.select((state) => state.cafes)),
      surface: 'explore',
    ),
    surface: 'explore',
  );
  final favoriteIds = ref.watch(favoriteIdsProvider);
  if (cafes.isEmpty || favoriteIds.isEmpty) {
    return cafes;
  }
  return cafes
      .map(
        (cafe) => _withFavoriteCountFloor(
          cafe,
          favoriteIds,
          source: 'cafes',
        ),
      )
      .toList(growable: false);
});

final homeCafesProvider = Provider<List<Cafe>>((ref) {
  final cafes = _filterBlockedPublicCafes(
    ref,
    _filterDeletedCafeIdentities(
      ref,
      ref.watch(cafeProvider.select((state) => state.homeCafes)),
      surface: 'home',
    ),
    surface: 'home',
  );
  final favoriteIds = ref.watch(favoriteIdsProvider);
  if (cafes.isEmpty || favoriteIds.isEmpty) {
    return cafes;
  }
  return cafes
      .map(
        (cafe) => _withFavoriteCountFloor(
          cafe,
          favoriteIds,
          source: 'home_cafes',
        ),
      )
      .toList(growable: false);
});

final activeFeaturedCafesProvider = Provider<List<Cafe>>((ref) {
  final raw = ref.watch(cafeProvider.select((state) => state.featuredCafes));
  final filtered = _filterBlockedPublicCafes(
    ref,
    _filterDeletedCafeIdentities(
      ref,
      raw,
      surface: 'featured',
    ),
    surface: 'featured',
  );

  var droppedNotFeatured = 0;
  var droppedNotVisible = 0;
  final active = <Cafe>[];
  for (final cafe in filtered) {
    if (!cafe.isFeatured) {
      droppedNotFeatured += 1;
      continue;
    }
    if (!cafe.isVisibleInPublic) {
      droppedNotVisible += 1;
      continue;
    }
    active.add(cafe);
  }

  AppLogger.debug(
    '[FEATURED_PROVIDER_STATE] raw=${raw.length} filtered=${filtered.length} active=${active.length}',
    key: 'featured-provider-state',
    throttle: Duration.zero,
  );
  final droppedTotal = droppedNotFeatured + droppedNotVisible;
  if (droppedTotal > 0) {
    AppLogger.debug(
      '[FEATURED_FILTER_DROP] not_featured=$droppedNotFeatured not_visible=$droppedNotVisible total=$droppedTotal',
      key: 'featured-filter-drop',
      throttle: Duration.zero,
    );
  }

  return List<Cafe>.unmodifiable(active);
});

final deletedCafeIdentityIdsProvider = StateProvider<Set<String>>((ref) {
  return const <String>{};
});

final homeScrollToTopSignalProvider = StateProvider<int>((ref) => 0);
final exploreScrollToTopSignalProvider = StateProvider<int>((ref) => 0);

final searchableCafeCorpusProvider = Provider<List<Cafe>>((ref) {
  final home = ref.watch(homeCafesProvider);
  final featured = ref.watch(activeFeaturedCafesProvider);
  final merged = _dedupeCafeCorpus(<Cafe>[...home, ...featured]);
  AppLogger.debug(
    '[SEARCH_CORPUS] home=${home.length} featured=${featured.length} merged=${home.length + featured.length} deduped=${merged.length}',
    key: 'search-corpus',
    throttle: const Duration(seconds: 2),
  );
  return merged;
});

final cafesByIdsProvider = Provider.family<List<Cafe>, List<String>>((
  ref,
  cafeIds,
) {
  if (cafeIds.isEmpty) {
    return const <Cafe>[];
  }

  final ids =
      cafeIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  if (ids.isEmpty) {
    return const <Cafe>[];
  }

  return ref
      .watch(cafesProvider)
      .where(
          (cafe) => ids.contains(cafe.id) || ids.contains(cafe.placeId ?? ''))
      .toList(growable: false);
});

final currentLocationProvider = Provider<Coordinates?>((ref) {
  return ref.watch(cafeProvider.select((state) => state.currentLocation));
});

final isLocationResolvedProvider = Provider<bool>((ref) {
  return ref.watch(currentLocationProvider) != null;
});

final mapRadiusPresetProvider = Provider<MapRadiusPreset>((ref) {
  return ref.watch(
    cafeProvider.select((state) => state.displayedMapRadiusPreset),
  );
});

final cafeDiscoveryDiagnosticsProvider =
    Provider<CafeDiscoveryDiagnostics?>((ref) {
  return ref.watch(
    cafeProvider.select((state) => state.discoveryDiagnostics),
  );
});

final isRadiusRefreshInFlightProvider = Provider<bool>((ref) {
  return ref
      .watch(cafeProvider.select((state) => state.isRadiusRefreshInFlight));
});

final selectedCafeIdProvider = Provider<String?>((ref) {
  return ref.watch(cafeProvider.select((state) => state.selectedCafeId));
});

final selectedCafeFocusVersionProvider = Provider<int>((ref) {
  return ref.watch(
    cafeProvider.select((state) => state.selectedCafeFocusVersion),
  );
});

final selectedCafeSelectionProvider =
    Provider<({String? cafeId, int focusVersion})>((ref) {
  return (
    cafeId: ref.watch(selectedCafeIdProvider),
    focusVersion: ref.watch(selectedCafeFocusVersionProvider),
  );
});

final cafeSearchScopeKeyProvider = Provider<String?>((ref) {
  return ref.watch(cafeProvider.select((state) => state.cafeSearchScopeKey));
});

final cafeSyncStateProvider = Provider<CafeSyncState>((ref) {
  return ref.watch(cafeProvider.select((state) => state.cafeSyncState));
});

final isCafesLoadingProvider = Provider<bool>((ref) {
  return ref.watch(cafeProvider.select((state) => state.isCafesLoading));
});

final isHomeCafesLoadingProvider = Provider<bool>((ref) {
  return ref.watch(cafeProvider.select((state) => state.isHomeCafesLoading));
});

final isCafesRefreshingProvider = Provider<bool>((ref) {
  return ref.watch(cafeSyncStateProvider) ==
      CafeSyncState.showingCachedWhileRefreshing;
});

final isServingStaleCafeCacheProvider = Provider<bool>((ref) {
  return ref.watch(cafeProvider.select((state) => state.isServingStaleCache));
});

final cafesErrorProvider = Provider<String?>((ref) {
  return ref.watch(cafeProvider.select((state) => state.cafesErrorMessage));
});

final cafesNoticeProvider = Provider<String?>((ref) {
  return ref.watch(cafeProvider.select((state) => state.cafesNoticeMessage));
});

final loadMoreErrorProvider = Provider<String?>((ref) {
  return ref.watch(cafeProvider.select((state) => state.loadMoreErrorMessage));
});

final hasMoreCafePagesProvider = Provider<bool>((ref) {
  return ref.watch(cafeProvider.select((state) => state.hasMorePages));
});

final isLoadingMoreCafesProvider = Provider<bool>((ref) {
  return ref.watch(cafeProvider.select((state) => state.isLoadingMore));
});

final paginatedCafesProvider = Provider<PaginatedCafesView>((ref) {
  return PaginatedCafesView(
    nextPageToken:
        ref.watch(cafeProvider.select((state) => state.nextPageToken)),
    hasMorePages: ref.watch(hasMoreCafePagesProvider),
    isLoadingMore: ref.watch(isLoadingMoreCafesProvider),
  );
});

final filtersProvider = Provider<Filters>((ref) {
  return ref.watch(cafeProvider.select((state) => state.filters));
});

final exploreFiltersProvider = Provider<Filters>((ref) {
  return ref.watch(cafeProvider.select((state) => state.exploreFilters));
});

final mapFiltersProvider = Provider<Filters>((ref) {
  return ref.watch(cafeProvider.select((state) => state.mapFilters));
});

final activeFilterCountProvider = Provider<int>((ref) {
  return ref.watch(filtersProvider).activeCount;
});

final hasActiveFiltersProvider = Provider<bool>((ref) {
  return ref.watch(activeFilterCountProvider) > 0;
});

final filteredCafesProvider = Provider<List<Cafe>>((ref) {
  final cafes = ref.watch(cafesProvider);
  if (cafes.isEmpty) {
    return const <Cafe>[];
  }

  final filters = ref.watch(exploreFiltersProvider);
  final districts = ref.watch(activeDistrictsProvider);
  final filtered = applyFilters(cafes, filters, districts: districts);
  final query = filters.searchQuery?.trim() ?? '';
  if (query.isNotEmpty) {
    AppLogger.debug(
      '[SEARCH_RESULT] query=$query count=${filtered.length} includesFeatured=false',
      key: 'search-result-${query.hashCode.abs()}',
      throttle: Duration.zero,
    );
  }

  AppLogger.debug(
    '[CAFE_DIAG_RENDER] scope=explore baseCount=${cafes.length} filteredCount=${filtered.length} activeFilters=${filters.activeCount}',
    key: 'cafe-diag-render-explore',
    throttle: const Duration(seconds: 2),
  );
  CafeDiscoveryDebugReportRecorder.instance.recordFilterStage(
    base: cafes,
    filtered: filtered,
    scope: 'explore',
    searchQuery: filters.searchQuery,
    activeFilterCount: filters.activeCount,
  );

  return filtered;
});

final exploreCafeResultsProvider = Provider<List<Cafe>>((ref) {
  return ref.watch(filteredCafesProvider);
});

final mapFilteredCafesProvider = Provider<List<Cafe>>((ref) {
  final cafes = ref.watch(cafesProvider);
  if (cafes.isEmpty) {
    return const <Cafe>[];
  }

  final filters = ref.watch(mapFiltersProvider);
  final districts = ref.watch(activeDistrictsProvider);
  final filtered = applyFilters(cafes, filters, districts: districts);

  AppLogger.debug(
    '[CAFE_DIAG_RENDER] scope=map baseCount=${cafes.length} filteredCount=${filtered.length}',
    key: 'cafe-diag-render-map',
    throttle: const Duration(seconds: 2),
  );
  CafeDiscoveryDebugReportRecorder.instance.recordFilterStage(
    base: cafes,
    filtered: filtered,
    scope: 'map',
    searchQuery: filters.searchQuery,
    activeFilterCount: filters.activeCount,
  );

  return filtered;
});

final mapVisibleCafesProvider = Provider<List<Cafe>>((ref) {
  final cafes = ref.watch(mapFilteredCafesProvider);

  final filters = ref.watch(mapFiltersProvider);
  final selectedCafeId = ref.watch(selectedCafeIdProvider);
  if (filters.effectiveDistricts.isNotEmpty) {
    return cafes;
  }

  final center =
      ref.watch(currentLocationProvider) ?? istanbulCenterCoordinates;
  final radiusPreset = ref.watch(mapRadiusPresetProvider);
  final radiusKm = radiusPreset.radiusMeters / 1000.0;

  final visible = cafes
      .where(
        (cafe) =>
            (selectedCafeId != null &&
                (cafe.id == selectedCafeId ||
                    cafe.placeId == selectedCafeId)) ||
            (isWithinIstanbul(cafe.coordinates.lat, cafe.coordinates.lng) &&
                distanceKm(center, cafe.coordinates) <= radiusKm),
      )
      .toList();

  final selectedFallback = _selectedCafeFallback(ref, selectedCafeId);
  if (selectedFallback != null &&
      !_containsCafeIdentity(visible, selectedFallback) &&
      applyFilters(
        [selectedFallback],
        filters,
        districts: ref.read(activeDistrictsProvider),
      ).isNotEmpty) {
    visible.add(selectedFallback);
  }

  if (kVerboseCafeDiagnostics) {
    AppLogger.debug(
      '[CAFE_DIAG_MAP_VISIBLE] baseCount=${cafes.length} radius=${radiusPreset.radiusMeters} visibleCount=${visible.length} center=${center.lat.toStringAsFixed(3)},${center.lng.toStringAsFixed(3)}',
      key: 'cafe-diag-map-visible',
      throttle: const Duration(seconds: 2),
    );
  }
  CafeDiscoveryDebugReportRecorder.instance.recordFinalVisible(
    base: cafes,
    visible: visible,
  );
  CafeDiscoveryDebugReportRecorder.instance
      .logReportToConsole(trigger: 'map_visible_selector');

  return visible;
});

final mapCafeResultsProvider = Provider<List<Cafe>>((ref) {
  return ref.watch(mapVisibleCafesProvider);
});

final featuredCafesProvider = Provider<List<Cafe>>((ref) {
  final featured = ref.watch(activeFeaturedCafesProvider);
  final hydrated = _hydrateFeaturedImagesFromCache(
    featured: featured,
    cacheSources: _featuredHydrationSources(ref),
  );
  AppLogger.debug(
    '[HOME_FEATURED_SOURCE] source=featuredProvider count=${hydrated.length}',
    key: 'home-featured-source',
  );
  AppLogger.debug(
    '[HOME_FEATURED_SOURCE_GUARD] blockedGeneralCorpus=true',
    key: 'home-featured-source-guard',
  );
  if (hydrated.isEmpty) {
    return const <Cafe>[];
  }

  final sorted = [...hydrated]..sort((left, right) {
      final priority = left.featuredPriority.compareTo(right.featuredPriority);
      if (priority != 0) {
        return priority;
      }

      final rating = right.effectiveRating.compareTo(left.effectiveRating);
      if (rating != 0) {
        return rating;
      }

      final name = left.name.toLowerCase().compareTo(right.name.toLowerCase());
      if (name != 0) {
        return name;
      }

      return left.id.compareTo(right.id);
    });
  return List<Cafe>.unmodifiable(sorted);
});

final featuredHydrationRepositoryCafesProvider =
    FutureProvider<List<Cafe>>((ref) async {
  final featured = ref.watch(activeFeaturedCafesProvider);
  if (featured.isEmpty) {
    return const <Cafe>[];
  }

  final localSources = <Cafe>[
    ...ref.watch(cafesProvider),
    ...ref.watch(homeCafesProvider),
    ...ref.watch(mapFilteredCafesProvider),
  ];
  final repository = ref.watch(cafeRepositoryProvider);
  if (localSources.isNotEmpty) {
    repository.rememberCafes(localSources);
  }

  final identifiers = <String>{};
  for (final cafe in featured) {
    identifiers.addAll(_featuredHydrationPlaceIdCandidates(cafe));
    final id = cafe.id.trim();
    if (id.isNotEmpty) {
      identifiers.add(id);
    }
  }
  if (identifiers.isEmpty) {
    return const <Cafe>[];
  }

  final resolved = await repository.getCafesByIds(
    identifiers.toList(growable: false),
    requestTimeout: const Duration(seconds: 6),
  );
  final resolvedMatches = resolved.toList(growable: true);
  final resolvedIndex = _buildFeaturedHydrationIndex(resolvedMatches);
  for (final cafe in featured.take(5)) {
    final matched = _findFeaturedHydrationMatch(cafe, resolvedIndex);
    if (_usableHydrationImageCount(matched?.photoUrls ?? const <String>[]) >
        0) {
      continue;
    }
    final searchResult = await repository.searchCafesByName(
      cafe.name,
      limit: 5,
      requestTimeout: const Duration(seconds: 6),
    );
    if (searchResult.cafes.isEmpty) {
      continue;
    }
    final fallbackKeys = _featuredFallbackKeys(cafe);
    for (final candidate in searchResult.cafes) {
      if (_usableHydrationImageCount(candidate.photoUrls) == 0) {
        continue;
      }
      final placeIds = _featuredHydrationPlaceIdCandidates(cafe);
      final candidatePlaceIds = _featuredHydrationPlaceIdCandidates(candidate);
      final matchesPlaceId =
          placeIds.intersection(candidatePlaceIds).isNotEmpty;
      final matchesFallback = fallbackKeys
          .intersection(_featuredFallbackKeys(candidate))
          .isNotEmpty;
      if (matchesPlaceId || matchesFallback) {
        resolvedMatches.add(candidate);
      }
    }
  }
  return List<Cafe>.unmodifiable(resolvedMatches);
});

final homeSponsoredCafesProvider = Provider<List<Cafe>>((ref) {
  final featuredState = ref.watch(
    cafeProvider.select(
      (state) => (
        loaded: state.hasLoadedFeaturedCafes,
        loading: state.isFeaturedCafesLoading,
      ),
    ),
  );
  final sponsored = ref.watch(featuredCafesProvider).toList();
  AppLogger.debug(
    '[HOME_SPONSORED] loaded=${featuredState.loaded} loading=${featuredState.loading} featuredCount=${sponsored.length} sponsoredCount=${sponsored.length}',
    key: 'home-sponsored-provider',
    throttle: Duration.zero,
  );
  _logFeaturedFinalOutput(
    ref,
    sponsored,
    cacheSources: _featuredHydrationSources(ref),
  );
  if (sponsored.isEmpty) {
    return const <Cafe>[];
  }

  sponsored.sort((left, right) {
    final priority = left.featuredPriority.compareTo(right.featuredPriority);
    if (priority != 0) {
      return priority;
    }

    final rating = right.effectiveRating.compareTo(left.effectiveRating);
    if (rating != 0) {
      return rating;
    }

    final name = left.name.toLowerCase().compareTo(right.name.toLowerCase());
    if (name != 0) {
      return name;
    }

    return left.id.compareTo(right.id);
  });

  return List<Cafe>.unmodifiable(sponsored);
});

List<Cafe> _featuredHydrationSources(Ref ref) {
  final explore = ref.watch(cafesProvider);
  final home = ref.watch(homeCafesProvider);
  final map = ref.watch(mapFilteredCafesProvider);
  final repository =
      ref.watch(featuredHydrationRepositoryCafesProvider).valueOrNull ??
          const <Cafe>[];
  if (explore.isEmpty && home.isEmpty && map.isEmpty && repository.isEmpty) {
    return const <Cafe>[];
  }
  return <Cafe>[...explore, ...home, ...map, ...repository];
}

List<Cafe> _hydrateFeaturedImagesFromCache({
  required List<Cafe> featured,
  required List<Cafe> cacheSources,
}) {
  if (featured.isEmpty) {
    return featured;
  }

  final hydrationIndex = _buildFeaturedHydrationIndex(cacheSources);
  final hydrated = <Cafe>[];
  for (final cafe in featured) {
    final matched = _findFeaturedHydrationMatch(cafe, hydrationIndex);
    final hasFreshGoogleDetailsImages = _hasFeaturedImageRefreshMarker(cafe);
    final mergedImages = _mergeFeaturedImageCandidates(
      cacheImages: matched?.photoUrls ?? const <String>[],
      featuredImages: cafe.photoUrls,
      includeGeneratedFeaturedImages: hasFreshGoogleDetailsImages,
    );
    final hasGeneratedPlacesOnly = cafe.photoUrls.isNotEmpty &&
        cafe.photoUrls.every(isGeneratedPlacesMediaImageUrl);
    if (mergedImages.isEmpty &&
        hasGeneratedPlacesOnly &&
        !hasFreshGoogleDetailsImages) {
      _logFeaturedImageSourceChoice(
        surface: 'featured-hydration',
        cafe: cafe,
        matched: matched,
        selectedImages: mergedImages,
      );
      _logFeaturedMergeProof(
        cafe: cafe,
        matched: matched,
        selectedImages: mergedImages,
      );
      hydrated.add(cafe.copyWith(images: const <String>[]));
      continue;
    }
    if (mergedImages.isEmpty || listEquals(mergedImages, cafe.photoUrls)) {
      _logFeaturedImageSourceChoice(
        surface: 'featured-hydration',
        cafe: cafe,
        matched: matched,
        selectedImages: cafe.photoUrls,
      );
      _logFeaturedMergeProof(
        cafe: cafe,
        matched: matched,
        selectedImages: cafe.photoUrls,
      );
      hydrated.add(cafe);
      continue;
    }

    _logFeaturedImageSourceChoice(
      surface: 'featured-hydration',
      cafe: cafe,
      matched: matched,
      selectedImages: mergedImages,
    );
    _logFeaturedMergeProof(
      cafe: cafe,
      matched: matched,
      selectedImages: mergedImages,
    );
    hydrated.add(cafe.copyWith(images: mergedImages));
  }
  return List<Cafe>.unmodifiable(hydrated);
}

List<String> _mergeFeaturedImageCandidates({
  required List<String> cacheImages,
  required List<String> featuredImages,
  bool includeGeneratedFeaturedImages = false,
}) {
  final merged = <String>[];
  final seen = <String>{};

  void addAll(
    List<String> values, {
    required bool includeGeneratedPlacesMedia,
  }) {
    for (final value in values) {
      final normalized = resolveCafeImageUrl(value);
      normalizeCafeImageUrlsByPriority(
        <String?>[value],
        maxCount: 1,
        includeGeneratedPlacesMedia: includeGeneratedPlacesMedia,
        diagnosticSurface: 'featured-hydration',
      );
      if (normalized == null ||
          isKnownFailedCafeImageUrl(normalized) ||
          !seen.add(normalized)) {
        continue;
      }
      if (!includeGeneratedPlacesMedia &&
          isGeneratedPlacesMediaImageUrl(normalized)) {
        continue;
      }
      merged.add(normalized);
      if (merged.length >= 8) {
        return;
      }
    }
  }

  addAll(cacheImages, includeGeneratedPlacesMedia: false);
  if (merged.length < 8) {
    addAll(
      featuredImages,
      includeGeneratedPlacesMedia: includeGeneratedFeaturedImages,
    );
  }
  return List<String>.unmodifiable(merged);
}

bool _hasFeaturedImageRefreshMarker(Cafe cafe) {
  return cafe.googlePlaceData?.sourceTypes.contains('featured_image_refresh') ??
      false;
}

void _logFeaturedMergeProof({
  required Cafe cafe,
  required Cafe? matched,
  required List<String> selectedImages,
}) {
  if (!kDebugMode || !kVerboseCafeDiagnostics) {
    return;
  }
  final matchedFirst =
      matched?.photoUrls.isEmpty == true ? null : matched?.photoUrls.first;
  final finalFirst = selectedImages.isEmpty ? null : selectedImages.first;
  final finalSource = _featuredMergeFinalSource(
    featured: cafe,
    matched: matched,
    selectedImages: selectedImages,
  );
  AppLogger.debug(
    '[FEATURED_MERGE_PROOF] featuredCafeId=${cafe.id} featuredName="${cafe.name}" featuredGooglePlaceId=${cafe.placeId ?? ''} matchedCacheCafe=${matched != null} matchedCacheCafeId=${matched?.id ?? ''} matchedCachePhotoUrlCount=${matched?.photoUrls.length ?? 0} matchedCacheFirstHost=${_urlHostForProof(matchedFirst)} matchedCacheFirstPathShape=${_urlPathShapeForProof(matchedFirst)} featuredStoredPhotoUrlsCount=${_storedPhotoUrlCount(cafe.photoUrls)} featuredGeneratedPhotoUrlsCount=${_generatedPhotoUrlCount(cafe.photoUrls)} finalResolvedDisplayUrlsCount=${selectedImages.length} finalFirstHost=${_urlHostForProof(finalFirst)} finalFirstPathShape=${_urlPathShapeForProof(finalFirst)} finalFirstGenerated=${isGeneratedPlacesMediaImageUrl(finalFirst)} finalSource=$finalSource',
    key: 'featured-merge-proof-${cafe.id}',
    throttle: Duration.zero,
  );
}

String _featuredMergeFinalSource({
  required Cafe featured,
  required Cafe? matched,
  required List<String> selectedImages,
}) {
  if (selectedImages.isEmpty) {
    return 'fallback';
  }
  final first = selectedImages.first;
  if (_hasFeaturedImageRefreshMarker(featured) &&
      featured.photoUrls
          .map(resolveCafeImageUrl)
          .whereType<String>()
          .contains(first)) {
    return 'google_place_details';
  }
  if (matched != null &&
      matched.photoUrls
          .map(resolveCafeImageUrl)
          .whereType<String>()
          .contains(first)) {
    return 'cache';
  }
  if (isGeneratedPlacesMediaImageUrl(first)) {
    return 'featured_generated';
  }
  if (featured.photoUrls
      .map(resolveCafeImageUrl)
      .whereType<String>()
      .contains(first)) {
    return 'featured_stored';
  }
  return 'fallback';
}

String _urlHostForProof(String? rawUrl) {
  final candidate = resolveCafeImageUrl(rawUrl) ?? rawUrl?.trim();
  if (candidate == null || candidate.isEmpty) {
    return 'none';
  }
  return Uri.tryParse(candidate)?.host.toLowerCase() ?? 'invalid';
}

String _urlPathShapeForProof(String? rawUrl) {
  final candidate = resolveCafeImageUrl(rawUrl) ?? rawUrl?.trim();
  final uri =
      candidate == null || candidate.isEmpty ? null : Uri.tryParse(candidate);
  if (uri == null) {
    return 'none';
  }
  final parts = uri.path.replaceFirst(RegExp(r'^/+'), '').split('/');
  if (parts.length == 6 &&
      parts[0] == 'v1' &&
      parts[1] == 'places' &&
      parts[3] == 'photos' &&
      parts[5] == 'media') {
    return 'v1/places/*/photos/*/media';
  }
  if (parts.length == 5 &&
      parts[0] == 'v1' &&
      parts[1] == 'places' &&
      parts[3] == 'photos') {
    return 'v1/places/*/photos/*';
  }
  if (uri.path.contains('%2F') || uri.path.contains('%2f')) {
    return 'encoded-slashes';
  }
  return 'other';
}

void _logFeaturedFinalOutput(
  Ref ref,
  List<Cafe> featured, {
  required List<Cafe> cacheSources,
}) {
  if (featured.isEmpty || !kVerboseCafeDiagnostics) {
    return;
  }

  final hydrationIndex = _buildFeaturedHydrationIndex(cacheSources);
  for (final cafe in featured) {
    final matched = _findFeaturedHydrationMatch(cafe, hydrationIndex);
    final matchedHasImages = matched?.photoUrls.isNotEmpty == true;
    final resolvedSource = cafe.photoUrls.isEmpty
        ? 'placeholder'
        : (matchedHasImages &&
                cafe.photoUrls.isNotEmpty &&
                cafe.photoUrls.first == matched!.photoUrls.first)
            ? 'cache'
            : 'supabase';
    final first = cafe.photoUrls.isEmpty ? null : cafe.photoUrls.first;
    AppLogger.debug(
      '[FEATURED_FINAL] id=${cafe.id} name=${cafe.name} google_place_id=${cafe.placeId ?? ''} images=${cafe.images.length} storedPhotoUrls=${_storedPhotoUrlCount(cafe.photoUrls)} generatedPhotoUrls=${_generatedPhotoUrlCount(cafe.photoUrls)} resolvedDisplayUrls=${cafe.photoUrls.length} resolvedImageSource=$resolvedSource matchedCacheWithImages=$matchedHasImages selectedSourceType=${cafeImageSourceTypeLabel(first)} ${googlePhotoUrlDiagnosticsForLog(first)}',
      key: 'featured-final-${cafe.id}',
      throttle: Duration.zero,
    );
    AppLogger.debug(
      '[FEATURED_IMAGE_SOURCE_DIAG] cafeId=${cafe.id} cafeName="${cafe.name}" selectedField=resolvedDisplayUrls ${cafeImageSourceDiagnosticsForLog(first)} fromCache=${resolvedSource == 'cache'} fromSupabase=${resolvedSource == 'supabase'}',
      key: 'featured-image-source-diag-${cafe.id}',
      throttle: Duration.zero,
    );
  }
}

void _logFeaturedImageSourceChoice({
  required String surface,
  required Cafe cafe,
  required Cafe? matched,
  required List<String> selectedImages,
}) {
  if (!kDebugMode || !kVerboseCafeDiagnostics) {
    return;
  }
  final selected = selectedImages.isEmpty ? null : selectedImages.first;
  AppLogger.debug(
    '[CAFE_DIAG_PHOTO_SOURCE] surface=$surface cafeId=${cafe.id} cafeName="${cafe.name}" matchedCafeId=${matched?.id ?? ''} matchedByPlaceId=${matched != null && cafe.placeId != null && cafe.placeId == matched.placeId} featuredImageCount=${cafe.photoUrls.length} cacheImageCount=${matched?.photoUrls.length ?? 0} selectedSourceType=${cafeImageSourceTypeLabel(selected)} ${googlePhotoUrlDiagnosticsForLog(selected)}',
    key: 'cafe-diag-photo-source-$surface-${cafe.id}',
    throttle: Duration.zero,
  );
}

int _storedPhotoUrlCount(List<String> urls) {
  return urls.where((url) => !isGeneratedPlacesMediaImageUrl(url)).length;
}

int _generatedPhotoUrlCount(List<String> urls) {
  return urls.where(isGeneratedPlacesMediaImageUrl).length;
}

({
  Map<String, Cafe> byPlaceId,
  Map<String, Cafe> byId,
  Map<String, Cafe> byFallback,
}) _buildFeaturedHydrationIndex(List<Cafe> cafes) {
  final byPlaceId = <String, Cafe>{};
  final byId = <String, Cafe>{};
  final byFallback = <String, Cafe>{};

  for (final cafe in cafes) {
    _upsertFeaturedCandidate(byId, cafe.id, cafe);
    for (final placeId in _featuredHydrationPlaceIdCandidates(cafe)) {
      _upsertFeaturedCandidate(byPlaceId, placeId, cafe);
    }
    for (final fallbackKey in _featuredFallbackKeys(cafe)) {
      _upsertFeaturedCandidate(byFallback, fallbackKey, cafe);
    }
  }

  return (byPlaceId: byPlaceId, byId: byId, byFallback: byFallback);
}

Cafe? _findFeaturedHydrationMatch(
  Cafe cafe,
  ({
    Map<String, Cafe> byPlaceId,
    Map<String, Cafe> byId,
    Map<String, Cafe> byFallback,
  }) index,
) {
  for (final placeId in _featuredHydrationPlaceIdCandidates(cafe)) {
    final byPlaceId = index.byPlaceId[placeId];
    if (byPlaceId != null) {
      return byPlaceId;
    }
  }
  final byId = index.byId[cafe.id];
  if (byId != null) {
    return byId;
  }
  for (final fallbackKey in _featuredFallbackKeys(cafe)) {
    final byFallback = index.byFallback[fallbackKey];
    if (byFallback != null) {
      return byFallback;
    }
  }
  return null;
}

Set<String> _featuredHydrationPlaceIdCandidates(Cafe cafe) {
  final candidates = <String>{};

  void add(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    candidates.add(normalized);
  }

  add(cafe.placeId);
  add(cafe.googlePlaceData?.googlePlaceId);
  if (_looksLikeGooglePlaceId(cafe.id)) {
    add(cafe.id);
  }
  return candidates;
}

bool _looksLikeGooglePlaceId(String value) {
  final normalized = value.trim();
  return normalized.startsWith('ChIJ') ||
      normalized.startsWith('GhIJ') ||
      normalized.startsWith('Ek') ||
      normalized.startsWith('Ei');
}

void _upsertFeaturedCandidate(
  Map<String, Cafe> index,
  String key,
  Cafe candidate,
) {
  final normalizedKey = key.trim();
  if (normalizedKey.isEmpty) {
    return;
  }
  final existing = index[normalizedKey];
  if (existing == null ||
      _usableHydrationImageCount(candidate.photoUrls) >
          _usableHydrationImageCount(existing.photoUrls) ||
      (_usableHydrationImageCount(candidate.photoUrls) ==
              _usableHydrationImageCount(existing.photoUrls) &&
          candidate.photoUrls.length > existing.photoUrls.length)) {
    index[normalizedKey] = candidate;
  }
}

int _usableHydrationImageCount(List<String> urls) {
  return urls.where((url) {
    final normalized = resolveCafeImageUrl(url);
    return normalized != null &&
        !isKnownFailedCafeImageUrl(normalized) &&
        !isGeneratedPlacesMediaImageUrl(normalized);
  }).length;
}

Set<String> _featuredFallbackKeys(Cafe cafe) {
  final normalizedName = normalizeSearchText(cafe.name);
  if (normalizedName.isEmpty) {
    return const <String>{};
  }

  final keys = <String>{};
  void addKey(Iterable<String> parts) {
    final normalizedParts =
        parts.map(normalizeSearchText).where((part) => part.isNotEmpty);
    final key = normalizedParts.join('|');
    if (key != normalizedName && key.startsWith('$normalizedName|')) {
      keys.add(key);
    }
  }

  addKey([normalizedName, cafe.address]);
  addKey([normalizedName, cafe.googlePlaceData?.formattedAddress ?? '']);
  addKey([normalizedName, cafe.district, cafe.neighborhood]);
  addKey([normalizedName, cafe.district]);

  return keys;
}

final homeFeaturedDistrictProvider = Provider<String?>((ref) {
  return ref.watch(cafeProvider.select((state) => state.homeFeaturedDistrict));
});

final homeFeaturedTitleProvider = Provider<String>((ref) {
  final district = ref.watch(homeFeaturedDistrictProvider)?.trim();
  if (district == null || district.isEmpty) {
    return 'Featured cafes';
  }
  return 'Featured cafes in $district';
});

const List<String> _homeDistrictBrowseLabels = <String>[
  'Kadıköy',
  'Beşiktaş',
  'Üsküdar',
  'Şişli',
  'Beyoğlu',
  'Fatih',
  'Bakırköy',
  'Levent',
  'Nişantaşı',
  'Ortaköy',
  'Kağıthane',
  'Taksim',
];

final browseDistrictsProvider = Provider<List<String>>((ref) {
  return List<String>.unmodifiable(_homeDistrictBrowseLabels);
});

final favoritesProvider = Provider<List<String>>((ref) {
  return ref.watch(profileProvider.select((state) => state.favorites));
});

final orderedFavoriteIdsProvider = Provider<List<String>>((ref) {
  final ids = ref.watch(favoritesProvider);
  if (ids.isEmpty) {
    return const <String>[];
  }

  final ordered = <String>[];
  final seen = <String>{};
  for (final rawId in ids) {
    final id = rawId.trim();
    if (id.isEmpty || !seen.add(id)) {
      continue;
    }
    ordered.add(id);
  }
  return List<String>.unmodifiable(ordered);
});

final resolvedFavoriteCafesProvider = FutureProvider<List<Cafe>>((ref) async {
  final ids = ref.watch(orderedFavoriteIdsProvider);
  if (ids.isEmpty) {
    return const <Cafe>[];
  }
  return _resolveSelectedCafesByIds(ref, ids);
});

final favoriteIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(favoritesProvider).toSet();
});

final favoriteCafesProvider = Provider<List<Cafe>>((ref) {
  final orderedIds = ref.watch(orderedFavoriteIdsProvider);
  if (orderedIds.isEmpty) {
    return const <Cafe>[];
  }

  final fallback = ref.watch(cafesByIdsProvider(orderedIds));
  final resolved =
      ref.watch(resolvedFavoriteCafesProvider).valueOrNull ?? const <Cafe>[];

  final favoriteIds = ref.watch(favoriteIdsProvider);
  return _resolveOrderedCafesByIds(
    orderedIds: orderedIds,
    primary: resolved,
    secondary: fallback,
  )
      .map(
        (cafe) => _withFavoriteCountFloor(
          cafe,
          favoriteIds,
          source: 'favorite_cafes',
        ),
      )
      .toList(growable: false);
});

final isCafeFavoritedProvider = Provider.family<bool, String>((ref, cafeId) {
  final normalized = cafeId.trim();
  if (normalized.isEmpty) {
    return false;
  }
  final favoriteIds = ref.watch(favoriteIdsProvider);
  return favoriteIds.contains(normalized);
});

final isFavoritesLoadingProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider.select((state) => state.isFavoritesLoading));
});

final isFavoriteMutationPendingProvider = Provider.family<bool, String>(
  (ref, cafeId) {
    final normalized = cafeId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return ref.watch(
      profileProvider.select(
        (state) => state.favoritePendingIds.contains(normalized),
      ),
    );
  },
);

final hasFavoriteMutationErrorProvider = Provider.family<bool, String>(
  (ref, cafeId) {
    final normalized = cafeId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return ref.watch(
      profileProvider.select(
        (state) => state.favoriteFailedIds.contains(normalized),
      ),
    );
  },
);

final compareListProvider = Provider<List<String>>((ref) {
  return ref.watch(profileProvider.select((state) => state.compareList));
});

final normalizedCompareListProvider = Provider<List<String>>((ref) {
  final compareList = ref.watch(compareListProvider);
  if (compareList.isEmpty) {
    return const <String>[];
  }

  final normalized = <String>[];
  final seen = <String>{};

  for (final rawId in compareList) {
    final cafeId = rawId.trim();
    if (cafeId.isEmpty || !seen.add(cafeId)) {
      continue;
    }
    normalized.add(cafeId);
    if (normalized.length == ProfileNotifier.maxCompareCafes) {
      break;
    }
  }

  return List<String>.unmodifiable(normalized);
});

final comparedCafeIdsProvider = Provider<Set<String>>((ref) {
  final ids = <String>{};
  for (final cafe in ref.watch(comparedCafesProvider)) {
    ids.add(cafe.id);
    final placeId = cafe.placeId?.trim();
    if (placeId != null && placeId.isNotEmpty) {
      ids.add(placeId);
    }
  }
  return ids;
});

final isCafeInCompareListProvider =
    Provider.family<bool, String>((ref, cafeId) {
  return ref.watch(comparedCafeIdsProvider).contains(cafeId.trim());
});

final isCompareListFullProvider = Provider<bool>((ref) {
  return ref.watch(normalizedCompareListProvider).length >=
      ProfileNotifier.maxCompareCafes;
});

final resolvedComparedCafesProvider = FutureProvider<List<Cafe>>((ref) async {
  final compareIds = ref.watch(normalizedCompareListProvider);
  if (compareIds.isEmpty) {
    return const <Cafe>[];
  }

  return _resolveSelectedCafesByIds(ref, compareIds);
});

Future<List<Cafe>> _resolveSelectedCafesByIds(
  Ref ref,
  List<String> orderedIds,
) async {
  final availableCafes = ref.watch(cafesProvider);
  final repository = ref.watch(cafeRepositoryProvider);
  if (availableCafes.isNotEmpty) {
    repository.rememberCafes(availableCafes);
    final resolvedLocal = _resolveOrderedCafesByIds(
      orderedIds: orderedIds,
      primary: availableCafes,
      secondary: const <Cafe>[],
    );
    if (resolvedLocal.length == orderedIds.length) {
      return List<Cafe>.unmodifiable(resolvedLocal);
    }
  }

  return repository.getCafesByIds(orderedIds);
}

final comparedCafesProvider = Provider<List<Cafe>>((ref) {
  final compareList = ref.watch(normalizedCompareListProvider);
  if (compareList.isEmpty) {
    return const <Cafe>[];
  }

  final fallback = ref.watch(cafesByIdsProvider(compareList));
  final resolved =
      ref.watch(resolvedComparedCafesProvider).valueOrNull ?? const <Cafe>[];

  return _resolveOrderedCafesByIds(
    orderedIds: compareList,
    primary: resolved,
    secondary: fallback,
  );
});

final comparedResolvedCafesProvider = Provider.autoDispose<List<Cafe>>((ref) {
  final cafes = ref.watch(comparedCafesProvider);
  if (cafes.isEmpty) {
    return const <Cafe>[];
  }

  return cafes
      .map((cafe) => CafeMergePolicy.applyReviewOverlay(
            cafe,
            ref.watch(paginatedCafeReviewsProvider(cafe.id)).reviews,
          ))
      .toList(growable: false);
});

List<Cafe> _resolveOrderedCafesByIds({
  required List<String> orderedIds,
  required List<Cafe> primary,
  required List<Cafe> secondary,
}) {
  final byId = <String, Cafe>{};

  void index(Iterable<Cafe> cafes) {
    for (final cafe in cafes) {
      byId.putIfAbsent(cafe.id, () => cafe);
      final placeId = cafe.placeId?.trim();
      if (placeId != null && placeId.isNotEmpty) {
        byId.putIfAbsent(placeId, () => cafe);
      }
    }
  }

  index(primary);
  index(secondary);

  final ordered = <Cafe>[];
  final seenCanonical = <String>{};
  for (final id in orderedIds) {
    final cafe = byId[id];
    if (cafe == null) {
      continue;
    }
    final canonical = CafeMergePolicy.canonicalIdentityFor(cafe);
    if (!seenCanonical.add(canonical)) {
      continue;
    }
    ordered.add(cafe);
  }

  return List<Cafe>.unmodifiable(ordered);
}

Cafe _withFavoriteCountFloor(
  Cafe cafe,
  Set<String> favoriteIds, {
  String? source,
}) {
  if (cafe.favoriteCount > 0) {
    return cafe;
  }
  final placeId = cafe.placeId?.trim();
  final isFavorite = favoriteIds.contains(cafe.id) ||
      (placeId != null && placeId.isNotEmpty && favoriteIds.contains(placeId));
  if (!isFavorite) {
    return cafe;
  }
  AppLogger.debug(
    '[FAVORITE_COUNT] source=${source ?? 'unknown'} cafeId=${cafe.id} placeId=${placeId ?? ''} rawCount=${cafe.favoriteCount} resolvedCount=1',
    key: 'favorite-count-floor-${source ?? 'unknown'}-${cafe.id}',
    throttle: Duration.zero,
  );
  return cafe.copyWith(favoriteCount: 1);
}

Cafe? _selectedCafeFallback(Ref ref, String? selectedCafeId) {
  final normalizedId = selectedCafeId?.trim();
  if (normalizedId == null || normalizedId.isEmpty) {
    return null;
  }

  Cafe? findIn(Iterable<Cafe> cafes) {
    for (final cafe in cafes) {
      if (cafe.id == normalizedId || cafe.placeId == normalizedId) {
        return cafe;
      }
    }
    return null;
  }

  return findIn(ref.watch(favoriteCafesProvider)) ??
      findIn(ref.watch(comparedCafesProvider));
}

bool _containsCafeIdentity(Iterable<Cafe> cafes, Cafe target) {
  final targetPlaceId = target.placeId?.trim();
  for (final cafe in cafes) {
    if (cafe.id == target.id ||
        (targetPlaceId != null &&
            targetPlaceId.isNotEmpty &&
            cafe.placeId == targetPlaceId)) {
      return true;
    }
  }
  return false;
}

final selectedCafeProvider = Provider<Cafe?>((ref) {
  final selectedCafeId = ref.watch(selectedCafeIdProvider);
  if (selectedCafeId == null) {
    return null;
  }
  return ref.watch(cafeByIdProvider(selectedCafeId));
});

final currentUserProvider = Provider<CurrentUser?>((ref) {
  return ref.watch(appShellProvider.select((state) => state.currentUser));
});

final isAuthReadyProvider = Provider<bool>((ref) {
  return ref.watch(appShellProvider.select((state) => state.isAuthReady));
});

final isOnboardingCompletedProvider = Provider<bool>((ref) {
  return ref.watch(
    appShellProvider.select((state) => state.isOnboardingCompleted),
  );
});

final themeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(appShellProvider.select((state) => state.themeMode));
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(appShellProvider.select((state) => state.isAdmin));
});

final isAdminRoleResolvedProvider = Provider<bool>((ref) {
  return ref.watch(
    appShellProvider.select((state) => state.isAdminRoleResolved),
  );
});

final adminRoleStatusMessageProvider = Provider<String?>((ref) {
  return ref.watch(
    appShellProvider.select((state) => state.adminRoleStatusMessage),
  );
});

final isSigningOutProvider = Provider<bool>((ref) {
  return ref.watch(appShellProvider.select((state) => state.isSigningOut));
});

final userPreferencesProvider = Provider<List<PreferenceKey>>((ref) {
  return ref.watch(profileProvider.select((state) => state.preferences));
});

final cafeByIdProvider = Provider.family<Cafe?, String>((ref, cafeId) {
  final normalizedId = cafeId.trim();
  if (normalizedId.isEmpty) {
    return null;
  }

  final cafe = ref.watch(
    cafeProvider.select((state) => _findCafeByIdInState(state, normalizedId)),
  );
  if (cafe == null) {
    return null;
  }
  if (cafe.isDeleted || _isDeletedCafeIdentity(ref, cafe)) {
    AppLogger.debug(
      '[DETAIL_DELETED_GUARD] cafeId=$normalizedId reason=is_deleted_or_deleted_at',
      key: 'detail-deleted-guard-selector-$normalizedId',
      throttle: Duration.zero,
    );
    return null;
  }
  return _withFavoriteCountFloor(
    cafe,
    ref.watch(favoriteIdsProvider),
    source: 'cafe_by_id',
  );
});

Cafe? _findCafeByIdInState(CafeState state, String normalizedId) {
  final collections = <List<Cafe>>[
    state.cafes,
    state.homeCafes,
    state.featuredCafes,
  ];
  for (final collection in collections) {
    for (final cafe in collection) {
      if (cafe.id == normalizedId || cafe.placeId == normalizedId) {
        return cafe;
      }
    }
  }
  return null;
}

List<Cafe> _filterDeletedCafeIdentities(
  Ref ref,
  List<Cafe> cafes, {
  required String surface,
}) {
  if (cafes.isEmpty) {
    return cafes;
  }
  final deletedIds = ref.watch(deletedCafeIdentityIdsProvider);
  if (deletedIds.isEmpty && !cafes.any((cafe) => cafe.isDeleted)) {
    return cafes;
  }
  var dropped = 0;
  final filtered = cafes.where((cafe) {
    final drop = cafe.isDeleted || _matchesDeletedIdentity(cafe, deletedIds);
    if (drop) {
      dropped += 1;
    }
    return !drop;
  }).toList(growable: false);
  if (dropped > 0) {
    AppLogger.debug(
      '[CAFE_TOMBSTONE_FILTER] id= placeId= surface=$surface dropped=true count=$dropped',
      key: 'cafe-tombstone-filter-$surface',
      throttle: Duration.zero,
    );
    if (surface == 'explore') {
      AppLogger.debug(
        '[SEARCH_TOMBSTONE_FILTER] query= droppedDeleted=$dropped',
        key: 'search-tombstone-filter',
        throttle: Duration.zero,
      );
    }
  }
  return filtered;
}

List<Cafe> _filterBlockedPublicCafes(
  Ref ref,
  List<Cafe> cafes, {
  required String surface,
}) {
  if (cafes.isEmpty || !cafes.any(isPublicDiscoveryScriptBlockedCafe)) {
    return cafes;
  }
  var dropped = 0;
  final filtered = cafes.where((cafe) {
    final drop = isPublicDiscoveryScriptBlockedCafe(cafe);
    if (drop) {
      dropped += 1;
    }
    return !drop;
  }).toList(growable: false);
  if (dropped > 0) {
    AppLogger.debug(
      '[CAFE_PUBLIC_FILTER] reason=arabic_script_name surface=$surface dropped=$dropped',
      key: 'cafe-public-filter-$surface',
      throttle: Duration.zero,
    );
  }
  return filtered;
}

bool _isDeletedCafeIdentity(Ref ref, Cafe cafe) {
  return _matchesDeletedIdentity(
      cafe, ref.watch(deletedCafeIdentityIdsProvider));
}

bool _matchesDeletedIdentity(Cafe cafe, Set<String> deletedIds) {
  if (deletedIds.isEmpty) {
    return false;
  }
  final placeId = cafe.placeId?.trim();
  return deletedIds.contains(cafe.id.trim()) ||
      (placeId != null && placeId.isNotEmpty && deletedIds.contains(placeId)) ||
      deletedIds.contains(cafe.canonicalIdentityKey) ||
      deletedIds.contains(_searchDedupeKey(cafe));
}

List<Cafe> _dedupeCafeCorpus(List<Cafe> cafes) {
  if (cafes.length < 2) {
    return cafes;
  }
  final byIdentity = <String, Cafe>{};
  var duplicateKeys = 0;
  for (final cafe in cafes) {
    final key = _searchDedupeKey(cafe);
    if (byIdentity.containsKey(key)) {
      duplicateKeys += 1;
    }
    byIdentity[key] = cafe;
  }
  if (duplicateKeys > 0) {
    AppLogger.debug(
      '[CAFE_IDENTITY_DEDUPE] surface=search before=${cafes.length} after=${byIdentity.length} duplicateKeys=$duplicateKeys',
      key: 'admin-cafe-dedupe-shared-corpus',
      throttle: Duration.zero,
    );
  }
  return byIdentity.values.toList(growable: false);
}

String _searchDedupeKey(Cafe cafe) {
  final placeId = cafe.placeId?.trim();
  if (placeId != null && placeId.isNotEmpty) {
    return 'place:$placeId';
  }
  final canonical = cafe.canonicalIdentityKey.trim();
  if (canonical.isNotEmpty) {
    return 'canonical:$canonical';
  }
  return 'fallback:${normalizeSearchText(cafe.name)}|${normalizeSearchText(cafe.district)}|${normalizeSearchText(cafe.neighborhood)}|${normalizeSearchText(cafe.address)}';
}

final isCafeDetailLoadingProvider =
    Provider.family<bool, String>((ref, cafeId) {
  return ref.watch(cafeProvider.select(
    (state) => state.loadingCafeDetailIds.contains(cafeId),
  ));
});

final cafeDetailErrorProvider = Provider.family<String?, String>((ref, cafeId) {
  return ref.watch(cafeProvider.select(
    (state) => state.cafeDetailErrorMessages[cafeId],
  ));
});

final friendRelationshipsProvider = FutureProvider<List<FriendRelationship>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) {
    return const <FriendRelationship>[];
  }
  return ref
      .watch(friendRepositoryProvider)
      .fetchFriendRelationships(currentUser.id);
});

final friendLocationPresenceProvider =
    FutureProvider<List<FriendLocationPresence>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) {
    return const <FriendLocationPresence>[];
  }
  return ref
      .watch(friendRepositoryProvider)
      .fetchFriendPresence(currentUser.id);
});

final visibleFriendMapPresenceProvider =
    Provider<List<FriendLocationPresence>>((ref) {
  final presence = ref.watch(friendLocationPresenceProvider).valueOrNull ??
      const <FriendLocationPresence>[];
  return presence
      .where((item) => item.isVisibleOnMap && item.isFresh)
      .toList(growable: false);
});

final offlinePendingCountProvider = Provider<int>((ref) {
  return ref.watch(offlineSyncProvider.select((state) => state.pendingCount));
});

final offlineDeadLetterCountProvider = Provider<int>((ref) {
  return ref.watch(
    offlineSyncProvider.select((state) => state.deadLetterCount),
  );
});

final shouldShowCachedWhileRefreshingProvider = Provider<bool>((ref) {
  final cafes = ref.watch(cafesProvider);
  if (cafes.isEmpty) {
    return false;
  }

  final syncState = ref.watch(cafeSyncStateProvider);
  final isRefreshing = ref.watch(isCafesLoadingProvider) ||
      syncState == CafeSyncState.showingCachedWhileRefreshing;
  return isRefreshing;
});

final shouldShowEmptyStateProvider = Provider<bool>((ref) {
  final cafes = ref.watch(cafesProvider);
  if (cafes.isNotEmpty) {
    return false;
  }

  if (ref.watch(isCafesLoadingProvider)) {
    return false;
  }

  return ref.watch(cafesErrorProvider) == null;
});

final shouldShowErrorStateProvider = Provider<bool>((ref) {
  if (ref.watch(cafesProvider).isNotEmpty) {
    return false;
  }
  return ref.watch(cafesErrorProvider) != null;
});

final cafeCacheLastUpdatedProvider = Provider<DateTime?>((ref) {
  return ref.watch(cafeProvider.select((state) => state.cafesLastUpdated));
});

final cafeCacheStatusProvider = Provider<CafeCacheStatusView?>((ref) {
  final cafes = ref.watch(cafesProvider);
  if (cafes.isEmpty) {
    return null;
  }

  final isOnline = ref.watch(connectivityServiceProvider).currentlyOnline;
  final isRefreshing = ref.watch(shouldShowCachedWhileRefreshingProvider) ||
      ref.watch(isRadiusRefreshInFlightProvider);
  final isServingStale = ref.watch(isServingStaleCafeCacheProvider);
  final lastUpdated = ref.watch(cafeCacheLastUpdatedProvider);
  final noticeMessage = ref.watch(cafesNoticeProvider)?.trim();

  if (!isOnline) {
    return CafeCacheStatusView(
      kind: CafeCacheStatusKind.offlineFallback,
      message:
          'Offline. Showing cafes last updated ${_relativeCacheAgeLabel(lastUpdated)}.',
      isRefreshing: false,
    );
  }

  if (noticeMessage != null && noticeMessage.isNotEmpty) {
    return CafeCacheStatusView(
      kind: CafeCacheStatusKind.freshCached,
      message: noticeMessage,
      isRefreshing: isRefreshing,
    );
  }

  if (isServingStale) {
    return CafeCacheStatusView(
      kind: CafeCacheStatusKind.staleCached,
      message:
          'Showing cached cafes from ${_relativeCacheAgeLabel(lastUpdated)}.',
      isRefreshing: isRefreshing,
    );
  }

  if (isRefreshing) {
    return const CafeCacheStatusView(
      kind: CafeCacheStatusKind.freshCached,
      message: 'Refreshing cafes in the background.',
      isRefreshing: true,
    );
  }

  return const CafeCacheStatusView(
    kind: CafeCacheStatusKind.live,
    message: 'Cafe list is up to date.',
    isRefreshing: false,
  );
});

final homeCafeCacheStatusProvider = Provider<CafeCacheStatusView?>((ref) {
  final cafes = ref.watch(homeCafesProvider);
  if (cafes.isEmpty) {
    return null;
  }

  final isOnline = ref.watch(connectivityServiceProvider).currentlyOnline;
  final isRefreshing = ref.watch(isHomeCafesLoadingProvider);
  final isServingStale = ref.watch(isServingStaleCafeCacheProvider);
  final lastUpdated = ref.watch(cafeCacheLastUpdatedProvider);
  final noticeMessage = ref.watch(cafesNoticeProvider)?.trim();

  if (!isOnline) {
    return CafeCacheStatusView(
      kind: CafeCacheStatusKind.offlineFallback,
      message:
          'Offline. Showing cafes last updated ${_relativeCacheAgeLabel(lastUpdated)}.',
      isRefreshing: false,
    );
  }

  if (noticeMessage != null && noticeMessage.isNotEmpty) {
    return CafeCacheStatusView(
      kind: CafeCacheStatusKind.freshCached,
      message: noticeMessage,
      isRefreshing: isRefreshing,
    );
  }

  if (isServingStale) {
    return CafeCacheStatusView(
      kind: CafeCacheStatusKind.staleCached,
      message:
          'Showing cached cafes from ${_relativeCacheAgeLabel(lastUpdated)}.',
      isRefreshing: isRefreshing,
    );
  }

  if (isRefreshing) {
    return const CafeCacheStatusView(
      kind: CafeCacheStatusKind.freshCached,
      message: 'Refreshing home cafes in the background.',
      isRefreshing: true,
    );
  }

  return null;
});

String _relativeCacheAgeLabel(DateTime? lastUpdated) {
  if (lastUpdated == null) {
    return 'an unknown time';
  }

  final age = DateTime.now().toUtc().difference(lastUpdated.toUtc());
  if (age.inMinutes < 1) {
    return 'just now';
  }
  if (age.inHours < 1) {
    return '${age.inMinutes} minute${age.inMinutes == 1 ? '' : 's'} ago';
  }
  if (age.inDays < 1) {
    return '${age.inHours} hour${age.inHours == 1 ? '' : 's'} ago';
  }
  return '${age.inDays} day${age.inDays == 1 ? '' : 's'} ago';
}
