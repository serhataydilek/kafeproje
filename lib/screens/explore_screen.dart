import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_cache_config.dart';
import '../l10n/l10n.dart';
import '../models/index.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/filter_sort.dart';
import '../widgets/cafes/adaptive_cafe_collection.dart';
import '../widgets/cafes/cafe_card.dart';
import '../widgets/layout/adaptive_layout.dart';
import '../widgets/ui/search_bar.dart';
import '../widgets/ui/state_views.dart';
import '../widgets/ui/shimmer_loading.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  SortOption _sortOption = SortOption.topRated;

  List<Cafe>? _cachedVisibleCafes;
  List<Cafe>? _lastWithFilters;
  SortOption? _lastSortOption;
  Coordinates? _lastUserLocation;
  String? _lastSearchQuery;

  List<Cafe> _getVisibleCafes(
    List<Cafe> withFilters,
    Coordinates? userLocation,
    String? searchQuery,
  ) {
    if (withFilters == _lastWithFilters &&
        _sortOption == _lastSortOption &&
        userLocation == _lastUserLocation &&
        searchQuery == _lastSearchQuery &&
        _cachedVisibleCafes != null) {
      return _cachedVisibleCafes!;
    }

    _lastWithFilters = withFilters;
    _lastSortOption = _sortOption;
    _lastUserLocation = userLocation;
    _lastSearchQuery = searchQuery;
    _cachedVisibleCafes = sortCafes(
      withFilters,
      _sortOption,
      userLocation,
      false,
      searchQuery,
    );
    return _cachedVisibleCafes!;
  }

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(cafeProvider.notifier).ensureExploreQueryLoaded());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final q = ref.read(exploreFiltersProvider).searchQuery ?? '';
      if (q.isNotEmpty) {
        _searchCtrl.text = q;
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasActiveSearch(Filters filters) {
    return filters.searchQuery?.trim().isNotEmpty ?? false;
  }

  int _structuredFilterCount(Filters filters) {
    final activeSearchCount = _hasActiveSearch(filters) ? 1 : 0;
    final structuredCount = filters.activeCount - activeSearchCount;
    return structuredCount < 0 ? 0 : structuredCount;
  }

  Future<void> _clearSearchFilter() async {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    final currentFilters = ref.read(exploreFiltersProvider);
    if (!_hasActiveSearch(currentFilters)) {
      return;
    }

    await ref.read(cafeProvider.notifier).setExploreFilters(
          currentFilters.copyWith(searchQuery: () => null),
        );
  }

  Future<void> _resetStructuredFilters(Filters filters) async {
    final hasStructuredFilters = _structuredFilterCount(filters) > 0;
    if (!hasStructuredFilters) {
      return;
    }

    await ref.read(cafeProvider.notifier).setExploreFilters(
          Filters(
            searchQuery:
                _hasActiveSearch(filters) ? filters.searchQuery?.trim() : null,
          ),
        );
  }

  Widget _wrapKeyboardSafeStateView({
    required Widget child,
    required bool keyboardVisible,
  }) {
    if (!keyboardVisible) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: const Key('explore-keyboard-state-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildExploreEmptyState(
    BuildContext context,
    AppColors colors,
    Filters filters,
    bool hasAnyDiscoveryData,
    int compareCount,
  ) {
    final l10n = context.l10n;
    final hasSearch = _hasActiveSearch(filters);
    final structuredCount = _structuredFilterCount(filters);
    final hasStructuredFilters = structuredCount > 0;

    if (hasSearch || hasStructuredFilters) {
      return EmptyStateView(
        colors: colors,
        icon: Icons.search_off,
        title: l10n.exploreEmptyTitle,
        message: compareCount > 0
            ? l10n.exploreEmptyCompareMessage
            : l10n.exploreEmptyMessage,
        hint: hasStructuredFilters
            ? l10n.filterApplyCount(structuredCount)
            : null,
        actions: [
          if (hasSearch)
            OutlinedButton(
              key: const Key('explore-empty-clear-search'),
              onPressed: () => unawaited(_clearSearchFilter()),
              child: Text(l10n.commonClear),
            ),
          if (hasStructuredFilters)
            FilledButton.tonal(
              key: const Key('explore-empty-reset-filters'),
              onPressed: () => unawaited(_resetStructuredFilters(filters)),
              child: Text(l10n.commonReset),
            ),
          if (compareCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Tooltip(
                message: l10n.compareSelectedCount(compareCount),
                child: OutlinedButton.icon(
                  key: const Key('explore-empty-go-compare'),
                  onPressed: () => context.push('/compare'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  ),
                  icon: Icon(Icons.compare_arrows, color: colors.primary),
                  label: Text(
                    l10n.compareSelectedCount(compareCount),
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (!hasAnyDiscoveryData) {
      return EmptyStateView(
        colors: colors,
        icon: Icons.location_searching_rounded,
        title: l10n.homeEmptyTitle,
        message: l10n.homeEmptyMessage,
        actions: [
          FilledButton(
            key: const Key('explore-empty-retry'),
            onPressed: () => ref.read(cafeProvider.notifier).refreshCafes(),
            child: Text(l10n.commonRetry),
          ),
          OutlinedButton(
            key: const Key('explore-empty-open-filters'),
            onPressed: () => context.push('/filters?scope=explore'),
            child: Text(l10n.filterTitle),
          ),
        ],
      );
    }

    return EmptyStateView(
      colors: colors,
      icon: Icons.search_off,
      title: l10n.exploreEmptyTitle,
      message: compareCount > 0
          ? l10n.exploreEmptyCompareMessage
          : l10n.exploreEmptyMessage,
      actions: compareCount > 0
          ? [
              Tooltip(
                message: l10n.compareSelectedCount(compareCount),
                child: OutlinedButton.icon(
                  key: const Key('explore-empty-go-compare-fallback'),
                  onPressed: () => context.push('/compare'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  ),
                  icon: Icon(Icons.compare_arrows, color: colors.primary),
                  label: Text(
                    l10n.compareSelectedCount(compareCount),
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(exploreScrollToTopSignalProvider, (previous, next) {
      if (previous == next || !_scrollController.hasClients) {
        return;
      }
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
    });
    final themeMode = ref.watch(themeModeProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAuthReady = ref.watch(isAuthReadyProvider);
    final hasInitializedDiscovery = ref.watch(
      cafeProvider.select((state) => state.hasInitializedDiscovery),
    );
    final cafes = ref.watch(cafesProvider);
    final filters = ref.watch(exploreFiltersProvider);
    final cafeSyncState = ref.watch(cafeSyncStateProvider);
    final cafesError = ref.watch(cafesErrorProvider);
    final cacheStatus = ref.watch(cafeCacheStatusProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    final compareCount = ref.watch(normalizedCompareListProvider).length;
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final l10n = context.l10n;
    final localizedSorts = sortOptions(l10n);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    final withFilters = ref.watch(exploreCafeResultsProvider);
    final visibleCafes = _getVisibleCafes(
      withFilters,
      currentLocation,
      filters.searchQuery,
    );
    final hasAnyDiscoveryData = cafes.isNotEmpty;
    final isLoading =
        !hasInitializedDiscovery || cafeSyncState == CafeSyncState.loading;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: !isAuthReady
            ? LoadingStateView(colors: colors, label: l10n.commonLoading)
            : currentUser == null
                ? SignInRequiredStateView(
                    colors: colors,
                    icon: Icons.explore_outlined,
                    onSignIn: () => context.go('/auth'),
                  )
                : AdaptivePage(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final layout =
                            AdaptiveLayoutData.fromWidth(constraints.maxWidth);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: keyboardVisible
                                  ? AppSpacing.sm
                                  : layout.sectionSpacing,
                            ),
                            Text(
                              l10n.exploreTitle,
                              style: TextStyle(
                                fontSize: layout.isTablet ? 32 : 28,
                                fontWeight: FontWeight.w800,
                                color: colors.text,
                              ),
                            ),
                            if (cacheStatus != null &&
                                cacheStatus.shouldShowBanner) ...[
                              const SizedBox(height: AppSpacing.sm),
                              CafeCacheStatusBanner(
                                colors: colors,
                                status: cacheStatus,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            AppSearchBar(
                              controller: _searchCtrl,
                              colors: colors,
                              hintText: l10n.homeSearchHint,
                              filterButtonKey:
                                  const Key('explore-filter-button'),
                              filterTooltip: l10n.filterTitle,
                              activeFilterCount: filters.activeCount,
                              onFilterTap: () =>
                                  context.push('/filters?scope=explore'),
                              onClear: () {
                                _searchDebounce?.cancel();
                                final currentFilters =
                                    ref.read(exploreFiltersProvider);
                                if (currentFilters.searchQuery == null) {
                                  return;
                                }
                                ref
                                    .read(cafeProvider.notifier)
                                    .setExploreFilters(
                                      currentFilters.copyWith(
                                        searchQuery: () => null,
                                      ),
                                    );
                              },
                              onChanged: (value) {
                                _searchDebounce?.cancel();
                                _searchDebounce = Timer(
                                  RequestTuningConfig.searchInputDebounce,
                                  () {
                                    final nextQuery = value.trim();
                                    final currentQuery = ref
                                            .read(exploreFiltersProvider)
                                            .searchQuery
                                            ?.trim() ??
                                        '';
                                    if (nextQuery == currentQuery) {
                                      return;
                                    }
                                    ref
                                        .read(cafeProvider.notifier)
                                        .setExploreFilters(
                                          ref
                                              .read(exploreFiltersProvider)
                                              .copyWith(
                                                searchQuery: () =>
                                                    nextQuery.isEmpty
                                                        ? null
                                                        : nextQuery,
                                              ),
                                        );
                                  },
                                );
                              },
                            ),
                            if (!keyboardVisible) ...[
                              SizedBox(height: layout.sectionSpacing / 2),
                              _ExploreSortGroup(
                                colors: colors,
                                wrap: layout.usesWrappedChips,
                                items: localizedSorts
                                    .map(
                                      (item) => (
                                        label: item.label,
                                        active: _sortOption == item.key,
                                        onTap: () {
                                          setState(
                                              () => _sortOption = item.key);
                                          if (item.key == SortOption.nearest &&
                                              currentLocation == null) {
                                            unawaited(
                                              ref
                                                  .read(cafeProvider.notifier)
                                                  .ensureCurrentLocation(),
                                            );
                                          }
                                        },
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                            SizedBox(height: layout.sectionSpacing / 2),
                            Expanded(
                              child: isLoading
                                  ? ShimmerCafeList(colors: colors)
                                  : cafesError != null && cafes.isEmpty
                                      ? _wrapKeyboardSafeStateView(
                                          keyboardVisible: keyboardVisible,
                                          child: ErrorStateView(
                                            colors: colors,
                                            message: cafesError,
                                            onRetry: () => ref
                                                .read(cafeProvider.notifier)
                                                .refreshCafes(),
                                          ),
                                        )
                                      : visibleCafes.isEmpty
                                          ? _wrapKeyboardSafeStateView(
                                              keyboardVisible: keyboardVisible,
                                              child: _buildExploreEmptyState(
                                                context,
                                                colors,
                                                filters,
                                                hasAnyDiscoveryData,
                                                compareCount,
                                              ),
                                            )
                                          : RefreshIndicator(
                                              onRefresh: () => ref
                                                  .read(cafeProvider.notifier)
                                                  .refreshCafes(),
                                              child: AdaptiveCafeCollection(
                                                controller: _scrollController,
                                                colors: colors,
                                                cacheExtent: 480,
                                                itemCount: visibleCafes.length,
                                                padding: EdgeInsets.only(
                                                  bottom:
                                                      layout.sectionSpacing * 2,
                                                ),
                                                itemBuilder: (_, index) {
                                                  final cafe =
                                                      visibleCafes[index];
                                                  return CafeCardListItem(
                                                    key: ValueKey(
                                                        'explore-cafe-${cafe.id}'),
                                                    cafe: cafe,
                                                    onPress: () => context.push(
                                                      '/cafe/${cafe.id}?source=explore',
                                                    ),
                                                    colors: colors,
                                                    surface: 'explore',
                                                  );
                                                },
                                              ),
                                            ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _ExploreSortGroup extends StatelessWidget {
  const _ExploreSortGroup({
    required this.colors,
    required this.wrap,
    required this.items,
  });

  final AppColors colors;
  final bool wrap;
  final List<({String label, bool active, VoidCallback onTap})> items;

  @override
  Widget build(BuildContext context) {
    if (wrap) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: items
            .map(
              (item) => _ExploreSortChip(
                colors: colors,
                label: item.label,
                active: item.active,
                onTap: item.onTap,
              ),
            )
            .toList(growable: false),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, index) {
          final item = items[index];
          return _ExploreSortChip(
            colors: colors,
            label: item.label,
            active: item.active,
            onTap: item.onTap,
          );
        },
      ),
    );
  }
}

class _ExploreSortChip extends StatelessWidget {
  const _ExploreSortChip({
    required this.colors,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final AppColors colors;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: active ? colors.primary : colors.chip,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: active ? colors.primary : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? colors.card : colors.text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
