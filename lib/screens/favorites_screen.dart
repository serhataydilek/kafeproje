import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/cafes/adaptive_cafe_collection.dart';
import '../widgets/cafes/cafe_card.dart';
import '../widgets/layout/adaptive_layout.dart';
import '../widgets/ui/state_views.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final currentUser = ref.watch(currentUserProvider);
    final favoriteCafes = ref.watch(favoriteCafesProvider);
    final resolvedFavorites = ref.watch(resolvedFavoriteCafesProvider);
    final hasFavorites = ref.watch(
      profileProvider.select((state) => state.favorites.isNotEmpty),
    );
    final isAuthReady = ref.watch(isAuthReadyProvider);
    final isFavoritesLoading = ref.watch(isFavoritesLoadingProvider);
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final l10n = context.l10n;
    final isResolvingFavorites =
        resolvedFavorites.isLoading && hasFavorites && favoriteCafes.isEmpty;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: !isAuthReady
            ? LoadingStateView(
                colors: colors,
                label: l10n.commonLoading,
              )
            : currentUser == null
                ? SignInRequiredStateView(
                    colors: colors,
                    icon: Icons.favorite_border,
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
                            SizedBox(height: layout.sectionSpacing),
                            Text(
                              l10n.favoritesTitle,
                              style: TextStyle(
                                fontSize: layout.isTablet ? 32 : 28,
                                fontWeight: FontWeight.w800,
                                color: colors.text,
                              ),
                            ),
                            SizedBox(height: layout.sectionSpacing),
                            Expanded(
                              child: isFavoritesLoading
                                  ? LoadingStateView(
                                      colors: colors,
                                      label: l10n.favoritesLoading,
                                    )
                                  : isResolvingFavorites
                                      ? LoadingStateView(
                                          colors: colors,
                                          label: l10n.favoritesLoading,
                                        )
                                      : favoriteCafes.isEmpty
                                          ? EmptyStateView(
                                              colors: colors,
                                              icon: Icons.favorite_border,
                                              title: l10n.favoritesEmptyTitle,
                                              message:
                                                  l10n.favoritesEmptyMessage,
                                              action: FilledButton(
                                                onPressed: () =>
                                                    context.go('/explore'),
                                                child: Text(l10n
                                                    .favoritesExploreAction),
                                              ),
                                            )
                                          : AdaptiveCafeCollection(
                                              colors: colors,
                                              cacheExtent: 720,
                                              itemCount: favoriteCafes.length,
                                              padding: EdgeInsets.only(
                                                bottom:
                                                    layout.sectionSpacing * 2,
                                              ),
                                              itemBuilder: (_, index) {
                                                final cafe =
                                                    favoriteCafes[index];
                                                return CafeCardListItem(
                                                  key: ValueKey(
                                                      'favorite-cafe-${cafe.id}'),
                                                  cafe: cafe,
                                                  onPress: () => context.push(
                                                    '/cafe/${cafe.id}?source=favorites',
                                                  ),
                                                  colors: colors,
                                                  surface: 'favorites',
                                                );
                                              },
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
