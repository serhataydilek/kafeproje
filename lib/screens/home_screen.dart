import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_cache_config.dart';
import '../config/env.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../models/index.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/debouncer.dart';
import '../utils/filter_sort.dart';
import '../utils/app_logger.dart';
import '../widgets/cafes/adaptive_cafe_collection.dart';
import '../widgets/cafes/cafe_card.dart';
import '../widgets/layout/adaptive_layout.dart';
import '../widgets/ui/list_tiles.dart';
import '../widgets/ui/search_bar.dart';
import '../widgets/ui/shimmer_loading.dart';
import '../widgets/ui/state_views.dart';

const int _homeNormalPreviewLimit = 20;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Debouncer _searchDebouncer = Debouncer(
    delay: RequestTuningConfig.searchInputDebounce,
  );
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Stopwatch _homePerfStopwatch = Stopwatch();
  Timer? _deferredHomeRefreshTimer;
  List<Cafe> _suggestions = const <Cafe>[];

  @override
  void initState() {
    super.initState();
    _homePerfStopwatch.start();
    AppLogger.debug(
      '[HOME_INIT] HomeScreen.initState',
      key: 'home-screen-init',
      throttle: Duration.zero,
    );
    AppLogger.debug(
      '[HOME_PERF] stage=init elapsedMs=${_homePerfStopwatch.elapsedMilliseconds}',
      key: 'home-screen-perf-init',
      throttle: Duration.zero,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.debug(
        '[HOME_PERF] stage=firstPaint elapsedMs=${_homePerfStopwatch.elapsedMilliseconds}',
        key: 'home-screen-perf-first-paint',
        throttle: Duration.zero,
      );
    });
    unawaited(_loadHomeProgressively());
  }

  Future<void> _loadHomeProgressively() async {
    final notifier = ref.read(cafeProvider.notifier);
    await notifier.ensureHomeCafeDataLoaded();
    if (!mounted || ref.read(homeCafesProvider).isNotEmpty) {
      return;
    }
    _deferredHomeRefreshTimer?.cancel();
    _deferredHomeRefreshTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted ||
          ref.read(homeCafesProvider).isNotEmpty ||
          ref.read(isHomeCafesLoadingProvider) ||
          !Env.hasGooglePlacesConfig) {
        return;
      }
      unawaited(_runDeferredHomeRefresh());
    });
  }

  Future<void> _runDeferredHomeRefresh() async {
    try {
      await ref
          .read(cafeProvider.notifier)
          .ensureHomeCafeDataLoaded(forceRemote: true);
    } catch (error) {
      AppLogger.warn(
        'Home deferred cafe fetch failed | $error',
        key: 'home-deferred-fetch-failed',
      );
    }
  }

  @override
  void dispose() {
    _deferredHomeRefreshTimer?.cancel();
    _searchDebouncer.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeScrollToTopSignalProvider, (previous, next) {
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
    final isHomeCafesLoading = ref.watch(isHomeCafesLoadingProvider);
    final cacheStatus = ref.watch(homeCafeCacheStatusProvider);
    final cafes = ref.watch(homeCafesProvider);
    final searchCorpus = ref.watch(searchableCafeCorpusProvider);
    final featured = ref.watch(featuredCafesProvider);
    final sponsored = ref.watch(homeSponsoredCafesProvider);
    final normalHomeCafes = excludeSponsoredHomeCafes(cafes, sponsored);
    final normalHomePreview =
        normalHomeCafes.take(_homeNormalPreviewLimit).toList(growable: false);
    final excludedSponsoredCount = cafes.length - normalHomeCafes.length;
    final browseDistricts = ref.watch(browseDistrictsProvider);
    final featuredState = ref.watch(
      cafeProvider.select(
        (state) => (
          loaded: state.hasLoadedFeaturedCafes,
          loading: state.isFeaturedCafesLoading,
          homeLoaded: state.hasLoadedHomeCafes,
        ),
      ),
    );
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final l10n = context.l10n;
    final categoryChips = categoryChipLabels(l10n);
    final hasActiveSearchInput = _searchController.text.trim().isNotEmpty;
    final hasVisibleHomeContent =
        cafes.isNotEmpty || featured.isNotEmpty || sponsored.isNotEmpty;
    final showBlockingLoader =
        isHomeCafesLoading && cafes.isEmpty && sponsored.isEmpty;
    if (kVerboseCafeDiagnostics) {
      AppLogger.debug(
        '[HOME_SPONSORED_RENDER] source=activeFeaturedCafesProvider count=${sponsored.length} featuredLoaded=${featuredState.loaded} featuredLoading=${featuredState.loading} rawFeatured=${featured.length} homeCafes=${cafes.length} showBlockingLoader=$showBlockingLoader',
        key: 'home-sponsored-render',
        throttle: Duration.zero,
      );
    }
    final hideDuplicateFeaturedSection =
        isDuplicateHomeFeaturedSection(sponsored, featured);
    if (hideDuplicateFeaturedSection && kVerboseCafeDiagnostics) {
      AppLogger.debug(
        '[HOME_FEATURED_DUPLICATE_GUARD] hidden=true reason=same_ids sponsoredCount=${sponsored.length} featuredCount=${featured.length}',
        key: 'home-featured-duplicate-guard',
        throttle: Duration.zero,
      );
      AppLogger.debug(
        '[HOME_DUPLICATE_GUARD] hiddenDuplicateFeatured=true reason=same_source_as_sponsored',
        key: 'home-duplicate-guard',
        throttle: Duration.zero,
      );
    }
    final showFeaturedSection =
        featured.isNotEmpty && !hideDuplicateFeaturedSection;
    final showFeaturedEmptyState =
        featured.isEmpty && sponsored.isEmpty && !hideDuplicateFeaturedSection;
    final showNormalLoadingState =
        isHomeCafesLoading && normalHomeCafes.isEmpty;
    final showNormalEmptyState = !showNormalLoadingState &&
        normalHomeCafes.isEmpty &&
        (showFeaturedEmptyState ||
            (sponsored.isNotEmpty && featuredState.homeLoaded));
    final featuredReason = showFeaturedSection
        ? 'count>0'
        : (hideDuplicateFeaturedSection
            ? 'duplicate_of_sponsored'
            : (featuredState.loading
                ? 'loading'
                : (featuredState.loaded ? 'empty' : 'not_loaded')));
    if (kVerboseCafeDiagnostics) {
      AppLogger.debug(
        '[HOME_FEATURED_RENDER] visible=$showFeaturedSection reason=$featuredReason featuredCount=${featured.length} featuredLoaded=${featuredState.loaded} featuredLoading=${featuredState.loading}',
        key: 'home-featured-render',
        throttle: Duration.zero,
      );
      AppLogger.debug(
        '[HOME_NORMAL_SECTION_RENDER] source=homeCafes count=${normalHomeCafes.length} rendered=${normalHomePreview.length} excludedSponsored=$excludedSponsoredCount',
        key: 'home-normal-section-render',
        throttle: Duration.zero,
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: showBlockingLoader
            ? ShimmerCafeList(colors: colors)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final layout =
                      AdaptiveLayoutData.fromWidth(constraints.maxWidth);
                  return AdaptivePage(
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        vertical: layout.sectionSpacing,
                      ),
                      children: [
                        Text(
                          l10n.homeTitle,
                          style: TextStyle(
                            fontSize: layout.isTablet ? 32 : 28,
                            fontWeight: FontWeight.w800,
                            color: colors.text,
                          ),
                        ),
                        if (isHomeCafesLoading && hasVisibleHomeContent) ...[
                          const SizedBox(height: AppSpacing.xs),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: SizedBox(
                              key: const Key(
                                  'home-background-refresh-indicator'),
                              height: 3,
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                color: colors.primary,
                                backgroundColor:
                                    colors.primary.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ],
                        if (cacheStatus != null &&
                            cacheStatus.shouldShowBanner) ...[
                          SizedBox(height: layout.sectionSpacing / 2),
                          CafeCacheStatusBanner(
                            colors: colors,
                            status: cacheStatus,
                          ),
                        ],
                        SizedBox(height: layout.sectionSpacing),
                        AppSearchBar(
                          controller: _searchController,
                          colors: colors,
                          hintText: l10n.homeSearchHint,
                          textInputAction: TextInputAction.search,
                          filterButtonKey: const Key('home-filter-button'),
                          filterTooltip: l10n.filterTitle,
                          onFilterTap: () =>
                              context.push('/filters?scope=explore'),
                          onClear: () {
                            setState(() {
                              _suggestions = const <Cafe>[];
                            });
                          },
                          onChanged: (value) {
                            _searchDebouncer(() {
                              if (!mounted) {
                                return;
                              }
                              final query = value.trim();
                              setState(() {
                                _suggestions = query.isEmpty
                                    ? const <Cafe>[]
                                    : searchCafes(searchCorpus, query)
                                        .take(5)
                                        .toList(growable: false);
                              });
                            });
                          },
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              ref.read(cafeProvider.notifier).setExploreFilters(
                                    Filters(
                                      searchQuery: value.trim(),
                                    ),
                                  );
                              context.go('/explore');
                            }
                          },
                        ),
                        if (hasActiveSearchInput && _suggestions.isEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          EmptyStateView(
                            key: const Key('home-search-empty-state'),
                            colors: colors,
                            icon: Icons.manage_search_rounded,
                            title: l10n.exploreEmptyTitle,
                            message: l10n.exploreEmptyMessage,
                            actions: [
                              OutlinedButton(
                                key: const Key('home-search-empty-clear'),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(
                                    () => _suggestions = const <Cafe>[],
                                  );
                                },
                                child: Text(l10n.commonClear),
                              ),
                              FilledButton.tonal(
                                key: const Key('home-search-empty-explore'),
                                onPressed: () {
                                  final query = _searchController.text.trim();
                                  if (query.isEmpty) {
                                    return;
                                  }
                                  ref
                                      .read(cafeProvider.notifier)
                                      .setExploreFilters(
                                        Filters(searchQuery: query),
                                      );
                                  context.go('/explore');
                                },
                                child: Text(l10n.homeViewAll),
                              ),
                            ],
                          ),
                        ],
                        if (_suggestions.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: colors.border),
                            ),
                            child: Column(
                              children: [
                                for (final cafe in _suggestions)
                                  ListTile(
                                    dense: true,
                                    leading: Icon(
                                      Icons.search,
                                      size: 18,
                                      color: colors.primary,
                                    ),
                                    title: Text(
                                      cafe.name,
                                      style: TextStyle(
                                        color: colors.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      cafeLocationSummary(l10n, cafe),
                                      style: TextStyle(color: colors.mutedText),
                                    ),
                                    onTap: () {
                                      _searchController.text = cafe.name;
                                      setState(
                                        () => _suggestions = const <Cafe>[],
                                      );
                                      ref
                                          .read(cafeProvider.notifier)
                                          .setExploreFilters(
                                            Filters(searchQuery: cafe.name),
                                          );
                                      context.go('/explore');
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (sponsored.isNotEmpty) ...[
                          SizedBox(height: layout.sectionSpacing),
                          _SponsoredSectionTitle(
                            colors: colors,
                            title: l10n.homeSponsoredCafes,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AdaptiveCafeCollection(
                            colors: colors,
                            itemCount: sponsored.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (_, index) {
                              final cafe = sponsored[index];
                              final label = cafe.featuredLabel?.trim();
                              return CafeCardListItem(
                                key: ValueKey('home-sponsored-${cafe.id}'),
                                cafe: cafe,
                                onPress: () => context.push('/cafe/${cafe.id}'),
                                colors: colors,
                                surface: 'home-sponsored',
                                sponsoredLabel: label == null || label.isEmpty
                                    ? l10n.homeSponsoredBadge
                                    : label,
                              );
                            },
                          ),
                        ],
                        if (browseDistricts.isNotEmpty) ...[
                          SizedBox(height: layout.sectionSpacing),
                          AppSectionTitle(
                            colors: colors,
                            title: _districtSectionTitle(context),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _HomeChipGroup(
                            colors: colors,
                            wrap: layout.usesWrappedChips,
                            labels: browseDistricts.take(10).map((district) {
                              return (
                                label: districtLabel(l10n, district),
                                onTap: () => unawaited(
                                      _openDistrictResults(district),
                                    ),
                              );
                            }).toList(growable: false),
                          ),
                        ],
                        SizedBox(height: layout.sectionSpacing),
                        AppSectionTitle(
                          colors: colors,
                          title: l10n.homeCategories,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _HomeChipGroup(
                          colors: colors,
                          wrap: layout.usesWrappedChips,
                          labels: categoryChips
                              .map(
                                (label) => (
                                  label: label,
                                  onTap: () =>
                                      _applyCategoryFilter(label, l10n),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        if (normalHomeCafes.isNotEmpty ||
                            showNormalLoadingState ||
                            showNormalEmptyState) ...[
                          SizedBox(height: layout.sectionSpacing),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppSectionTitle(
                                colors: colors,
                                title: l10n.favoritesExploreAction,
                              ),
                              Tooltip(
                                message: l10n.homeViewAll,
                                child: Semantics(
                                  button: true,
                                  label: l10n.homeViewAll,
                                  child: GestureDetector(
                                    onTap: () => context.go('/explore'),
                                    child: Text(
                                      l10n.homeViewAll,
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (showNormalLoadingState)
                            LoadingStateView(
                              key: const Key('home-normal-loading-state'),
                              colors: colors,
                              label: l10n.commonLoading,
                            )
                          else if (normalHomeCafes.isEmpty)
                            EmptyStateView(
                              colors: colors,
                              icon: Icons.search_off,
                              title: l10n.homeEmptyTitle,
                              message: l10n.homeEmptyMessage,
                              actions: [
                                FilledButton(
                                  key: const Key('home-featured-retry-button'),
                                  onPressed: () => ref
                                      .read(cafeProvider.notifier)
                                      .ensureHomeCafeDataLoaded(
                                        forceRemote: true,
                                      ),
                                  child: Text(l10n.commonRetry),
                                ),
                                OutlinedButton(
                                  key:
                                      const Key('home-featured-explore-button'),
                                  onPressed: () => context.go('/explore'),
                                  child: Text(l10n.homeViewAll),
                                ),
                              ],
                            )
                          else
                            AdaptiveCafeCollection(
                              colors: colors,
                              itemCount: normalHomePreview.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (_, index) {
                                final cafe = normalHomePreview[index];
                                return CafeCardListItem(
                                  key: ValueKey('home-normal-${cafe.id}'),
                                  cafe: cafe,
                                  onPress: () =>
                                      context.push('/cafe/${cafe.id}'),
                                  colors: colors,
                                  surface: 'home',
                                );
                              },
                            ),
                        ],
                        SizedBox(height: layout.sectionSpacing * 2),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _districtSectionTitle(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode.toLowerCase() == 'tr') {
      return 'Ilcelere Gore Kesfet';
    }
    return 'Browse by District';
  }

  Future<void> _openDistrictResults(String district) async {
    final notifier = ref.read(cafeProvider.notifier);
    final districtFilters = Filters(district: district);
    await notifier.setExploreFilters(districtFilters);
    if (!mounted) {
      return;
    }
    context.go('/explore');
  }

  void _applyCategoryFilter(String category, AppLocalizations l10n) {
    final notifier = ref.read(cafeProvider.notifier);
    Filters next = Filters.empty;

    if (category == l10n.categoryStudy) {
      next = next.copyWith(studyFriendly: () => true);
    } else if (category == l10n.categoryBestCoffee) {
      next = next.copyWith(minRating: () => 4.5);
    } else if (category == l10n.categoryAffordable) {
      next = next.copyWith(priceLevel: () => PriceLevel.cheap);
    } else if (category == l10n.categoryQuiet) {
      next = next.copyWith(
        quietnessLevel: () => QuietnessLevel.quiet,
      );
    } else if (category == l10n.categoryOutdoor) {
      next = next.copyWith(outdoorSeating: () => true);
    } else if (category == l10n.categoryAesthetic) {
      next = next.copyWith(minRating: () => 4.5);
    }
    notifier.setExploreFilters(next);
    context.go('/explore');
  }
}

bool isDuplicateHomeFeaturedSection(
  Iterable<Cafe> sponsoredCafes,
  Iterable<Cafe> featuredCafes,
) {
  final sponsoredIds = _homeSectionCafeIds(sponsoredCafes);
  final featuredIds = _homeSectionCafeIds(featuredCafes);
  if (sponsoredIds.isEmpty || featuredIds.isEmpty) {
    return false;
  }
  return featuredIds.every(sponsoredIds.contains);
}

List<Cafe> excludeSponsoredHomeCafes(
  Iterable<Cafe> homeCafes,
  Iterable<Cafe> sponsoredCafes,
) {
  final sponsoredIds = _homeSectionCafeIds(sponsoredCafes);
  final sponsoredPlaceIds = _homeSectionCafePlaceIds(sponsoredCafes);
  if (sponsoredIds.isEmpty && sponsoredPlaceIds.isEmpty) {
    return List<Cafe>.unmodifiable(homeCafes);
  }

  return List<Cafe>.unmodifiable(
    homeCafes.where((cafe) {
      final id = cafe.id.trim();
      if (id.isNotEmpty && sponsoredIds.contains(id)) {
        return false;
      }
      final placeId = cafe.placeId?.trim();
      if (placeId != null &&
          placeId.isNotEmpty &&
          sponsoredPlaceIds.contains(placeId)) {
        return false;
      }
      return true;
    }),
  );
}

Set<String> _homeSectionCafeIds(Iterable<Cafe> cafes) {
  return cafes
      .map((cafe) => cafe.id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
}

Set<String> _homeSectionCafePlaceIds(Iterable<Cafe> cafes) {
  return cafes
      .map((cafe) => cafe.placeId?.trim())
      .whereType<String>()
      .where((placeId) => placeId.isNotEmpty)
      .toSet();
}

class _SponsoredSectionTitle extends StatelessWidget {
  const _SponsoredSectionTitle({
    required this.colors,
    required this.title,
  });

  final AppColors colors;
  final String title;

  @override
  Widget build(BuildContext context) {
    const sponsoredGold = Color(0xFFC6A15B);
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sponsoredGold.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: sponsoredGold.withValues(alpha: 0.38)),
          ),
          child: const Icon(
            Icons.star_rounded,
            size: 17,
            color: sponsoredGold,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppSectionTitle(
            colors: colors,
            title: title,
          ),
        ),
      ],
    );
  }
}

class _HomeChipGroup extends StatelessWidget {
  const _HomeChipGroup({
    required this.colors,
    required this.wrap,
    required this.labels,
  });

  final AppColors colors;
  final bool wrap;
  final List<({String label, VoidCallback onTap})> labels;

  @override
  Widget build(BuildContext context) {
    if (wrap) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: labels
            .map(
              (item) => _HomeChip(
                colors: colors,
                label: item.label,
                onTap: item.onTap,
              ),
            )
            .toList(growable: false),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, index) {
          final item = labels[index];
          return _HomeChip(
            colors: colors,
            label: item.label,
            onTap: item.onTap,
          );
        },
      ),
    );
  }
}

class _HomeChip extends StatelessWidget {
  const _HomeChip({
    required this.colors,
    required this.label,
    required this.onTap,
  });

  final AppColors colors;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.chip,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
