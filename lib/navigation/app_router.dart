import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers/app_provider.dart';
import '../screens/admin_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/cafe_add_screen.dart';
import '../screens/cafe_detail_screen.dart';
import '../screens/cafe_edit_screen.dart';
import '../screens/compare_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/filter_modal_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class _BottomNavShellTokens {
  const _BottomNavShellTokens._();

  static const EdgeInsets navSafeAreaInset = EdgeInsets.fromLTRB(
    AppSpacing.md,
    6,
    AppSpacing.md,
    10,
  );
  static const EdgeInsets navContainerPadding = EdgeInsets.fromLTRB(6, 5, 6, 4);
  static const double navShadowBlur = 18;
  static const Offset navShadowOffset = Offset(0, 8);
}

/// Bridges Riverpod auth/admin state changes into GoRouter refreshes.
///
/// Optimized to only notify on relevant auth and admin status changes,
/// preventing unnecessary route tree rebuilds from unrelated AppShellState updates.
class GoRouterNotifier extends ChangeNotifier {
  GoRouterNotifier(this._ref) {
    _setupAuthListeners();
  }

  final Ref _ref;
  String? _lastUserId;
  bool _lastIsAdmin = false;
  bool _lastIsAuthReady = false;
  bool _lastIsOnboardingCompleted = false;

  void _setupAuthListeners() {
    // Listen to auth readiness changes
    _ref.listen<bool>(
      appShellProvider.select((state) => state.isAuthReady),
      (previous, next) {
        if (previous != next && _lastIsAuthReady != next) {
          _lastIsAuthReady = next;
          notifyListeners();
        }
      },
    );

    // Listen to current user changes (by ID)
    _ref.listen<String?>(
      appShellProvider.select((state) => state.currentUser?.id),
      (previous, next) {
        if (previous != next && _lastUserId != next) {
          _lastUserId = next;
          notifyListeners();
        }
      },
    );

    // Listen to admin status changes only
    _ref.listen<bool>(
      appShellProvider.select((state) => state.isAdmin),
      (previous, next) {
        if (previous != next && _lastIsAdmin != next) {
          _lastIsAdmin = next;
          notifyListeners();
        }
      },
    );

    _ref.listen<bool>(
      appShellProvider.select((state) => state.isOnboardingCompleted),
      (previous, next) {
        if (previous != next && _lastIsOnboardingCompleted != next) {
          _lastIsOnboardingCompleted = next;
          notifyListeners();
        }
      },
    );
  }
}

final routerNotifierProvider = Provider<GoRouterNotifier>((ref) {
  return GoRouterNotifier(ref);
});

const _publicOnlyRoutePaths = <String>{'/auth', '/onboarding'};
const _adminExactRoutePaths = <String>{'/admin', '/cafe-add'};
const _safeExactPostAuthRoutePaths = <String>{
  '/',
  '/explore',
  '/map',
  '/favorites',
  '/profile',
  '/filters',
  '/compare',
  '/settings',
  ..._adminExactRoutePaths,
};

bool _isAdminRoutePath(String path) {
  return _adminExactRoutePaths.contains(path);
}

bool _isKnownSafePostAuthPath(String path) {
  if (_safeExactPostAuthRoutePaths.contains(path)) {
    return true;
  }
  if (path.startsWith('/cafe/') && path.length > '/cafe/'.length) {
    return true;
  }
  if (path.startsWith('/cafe-edit/') && path.length > '/cafe-edit/'.length) {
    return true;
  }
  return false;
}

String _safePostAuthRedirectTarget(String? rawTarget, {required bool isAdmin}) {
  final target = rawTarget?.trim();
  if (target == null || target.isEmpty) {
    return '/';
  }
  final uri = Uri.tryParse(target);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//') ||
      uri.path.contains(r'\') ||
      _publicOnlyRoutePaths.contains(uri.path) ||
      !_isKnownSafePostAuthPath(uri.path)) {
    return '/';
  }
  if (_isAdminRoutePath(uri.path) && !isAdmin) {
    return '/';
  }
  return uri.toString();
}

String? appRouteGuardRedirect(AppShellState shellState, GoRouterState state) {
  final isAuth = shellState.currentUser != null;
  final isAuthRoute = state.matchedLocation == '/auth';
  final isOnboardingRoute = state.matchedLocation == '/onboarding';

  // All main app routes require authentication
  final isPublicRoute = _publicOnlyRoutePaths.contains(state.matchedLocation);
  final isAdminRoute = _isAdminRoutePath(state.matchedLocation);

  // If auth is not ready yet, add small delay or let loading state show
  if (!shellState.isAuthReady) {
    return null;
  }

  // If user is not authenticated, redirect to auth
  if (!isAuth && !isPublicRoute) {
    return Uri(
      path: '/auth',
      queryParameters: {
        'from': state.location,
      },
    ).toString();
  }

  if (isAdminRoute && isAuth && !shellState.isAdmin) {
    if (!shellState.isAdminRoleResolved) {
      return null;
    }
    return '/profile';
  }

  if (isAuth && isAuthRoute) {
    final target = state.queryParameters['from'];
    return _safePostAuthRedirectTarget(target, isAdmin: shellState.isAdmin);
  }

  if (isAuth && shellState.isOnboardingCompleted && isOnboardingRoute) {
    return '/';
  }

  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/auth',
    refreshListenable: notifier,
    redirect: (context, state) {
      final shellState = ref.read(appShellProvider);
      return appRouteGuardRedirect(shellState, state);
    },
    routes: [
      GoRoute(
        path: '/auth',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const AuthScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => _BottomNavShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/explore',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ExploreScreen()),
          ),
          GoRoute(
            path: '/map',
            pageBuilder: (_, state) => NoTransitionPage(
              child: MapScreen(
                preserveInitialSelection:
                    state.queryParameters['focusCafeId']?.isNotEmpty == true,
              ),
            ),
          ),
          GoRoute(
            path: '/favorites',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: FavoritesScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/cafe/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => _CafeDetailRoute(
          cafeId: state.pathParameters['id']!,
          source: state.queryParameters['source'],
        ),
      ),
      GoRoute(
        path: '/filters',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final scopeParam = state.queryParameters['scope'];
          final scope = scopeParam == 'map'
              ? FilterModalScope.map
              : FilterModalScope.explore;
          return FilterModalScreen(scope: scope);
        },
      ),
      GoRoute(
        path: '/compare',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const CompareScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const AdminScreen(),
      ),
      GoRoute(
        path: '/cafe-add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const CafeAddScreen(),
      ),
      GoRoute(
        path: '/cafe-edit/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            CafeEditScreen(cafeId: state.pathParameters['id']!),
      ),
    ],
  );
});

class _BottomNavShell extends ConsumerWidget {
  const _BottomNavShell({required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/explore') return 1;
    if (location == '/map') return 2;
    if (location == '/favorites') return 3;
    if (location == '/profile') return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final location = GoRouterState.of(context).matchedLocation;
    final theme = Theme.of(context);
    final colors = resolveColors(
      ref.watch(themeModeProvider),
      MediaQuery.platformBrightnessOf(context),
    );
    final l10n = context.l10n;
    final compareCount = ref.watch(
      normalizedCompareListProvider.select((list) => list.length),
    );
    final connectivityAsync = ref.watch(connectivityProvider);
    final securityReadinessAsync = ref.watch(securityReadinessProvider);
    final pendingSyncCount = ref.watch(offlinePendingCountProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final showCompareFab =
        location != '/map' && currentUser != null && compareCount > 0;
    final compareCountLabel = compareCount > 9 ? '9+' : '$compareCount';
    final fabBackground = theme.brightness == Brightness.dark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFF181512);
    final fabForeground = colors.primary;
    final navShadowColor = Colors.black.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.26 : 0.08,
    );
    final navBackgroundColor = Color.alphaBlend(
      colors.card
          .withValues(alpha: theme.brightness == Brightness.dark ? 0.94 : 0.98),
      colors.bg,
    );
    final securityReport = securityReadinessAsync.valueOrNull;
    final hasSecurityReadinessWarning =
        isAdmin && (securityReport?.shouldShowRuntimeWarning ?? false);
    final securityBannerMessage =
        securityReport?.message ?? 'Security readiness check failed.';
    final securityBannerColor =
        kReleaseMode ? colors.danger : const Color(0xFFB45309);

    return Scaffold(
      body: Column(
        children: [
          if (connectivityAsync.valueOrNull == false)
            Material(
              color: colors.danger,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: l10n.offlineBannerMessage,
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: colors.card, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            l10n.offlineBannerMessage,
                            style: TextStyle(
                              color: colors.card,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (hasSecurityReadinessWarning)
            Material(
              color: securityBannerColor,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: securityBannerMessage,
                    child: Row(
                      children: [
                        Icon(Icons.gpp_maybe_outlined,
                            color: colors.card, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            securityBannerMessage,
                            style: TextStyle(
                              color: colors.card,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      floatingActionButton: showCompareFab
          ? FloatingActionButton.extended(
              key: const Key('shell-compare-fab'),
              tooltip: l10n.compareSelectedCount(compareCount),
              onPressed: () => context.push('/compare'),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: fabBackground,
              foregroundColor: fabForeground,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CompareFabIconBadge(
                    foreground: fabForeground,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    compareCountLabel,
                    key: const Key('shell-compare-fab-count-text'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          : null,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: _BottomNavShellTokens.navSafeAreaInset,
        child: DecoratedBox(
          key: const Key('shell-bottom-nav-container'),
          decoration: BoxDecoration(
            color: navBackgroundColor,
            borderRadius:
                BorderRadius.circular(BottomChromeTokens.navContainerRadius),
            border: Border.all(
              color: colors.border.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.9 : 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: navShadowColor,
                blurRadius: _BottomNavShellTokens.navShadowBlur,
                offset: _BottomNavShellTokens.navShadowOffset,
              ),
            ],
          ),
          child: Padding(
            padding: _BottomNavShellTokens.navContainerPadding,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(BottomChromeTokens.navInnerRadius),
              child: NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: (index) {
                  if (index == currentIndex) {
                    if (index == 0) {
                      ref.read(homeScrollToTopSignalProvider.notifier).state++;
                      AppLogger.debug(
                        '[NAV_RESELECT] tab=home action=scroll_top',
                        key: 'nav-reselect-home',
                        throttle: Duration.zero,
                      );
                    } else if (index == 1) {
                      ref
                          .read(exploreScrollToTopSignalProvider.notifier)
                          .state++;
                      AppLogger.debug(
                        '[NAV_RESELECT] tab=explore action=scroll_top',
                        key: 'nav-reselect-explore',
                        throttle: Duration.zero,
                      );
                    }
                    return;
                  }
                  switch (index) {
                    case 0:
                      context.go('/');
                      break;
                    case 1:
                      context.go('/explore');
                      break;
                    case 2:
                      context.go('/map');
                      break;
                    case 3:
                      context.go('/favorites');
                      break;
                    case 4:
                      context.go('/profile');
                      break;
                  }
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home_rounded),
                    label: l10n.navHome,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.explore_outlined),
                    selectedIcon: const Icon(Icons.explore_rounded),
                    label: l10n.navExplore,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.map_outlined),
                    selectedIcon: const Icon(Icons.map_rounded),
                    label: l10n.navMap,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.favorite_border),
                    selectedIcon: const Icon(Icons.favorite),
                    label: l10n.navFavorites,
                  ),
                  NavigationDestination(
                    selectedIcon: _NavIconBadge(
                      icon: const Icon(Icons.person_rounded),
                      badgeCount: pendingSyncCount,
                    ),
                    icon: _NavIconBadge(
                      icon: const Icon(Icons.person_outline),
                      badgeCount: pendingSyncCount,
                    ),
                    label: l10n.navProfile,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIconBadge extends StatelessWidget {
  const _NavIconBadge({
    required this.icon,
    required this.badgeCount,
  });

  final Widget icon;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    if (badgeCount <= 0) {
      return icon;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            constraints: const BoxConstraints(minWidth: 16),
            child: Text(
              badgeCount > 9 ? '9+' : '$badgeCount',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareFabIconBadge extends StatelessWidget {
  const _CompareFabIconBadge({
    required this.foreground,
  });

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('shell-compare-fab-icon-badge'),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: foreground.withValues(alpha: 0.92),
        border: Border.all(color: foreground.withValues(alpha: 1), width: 1.4),
      ),
      child: const Icon(
        Icons.compare_arrows_rounded,
        color: Color(0xFF181512),
        size: BottomChromeTokens.compareFabIconSize,
      ),
    );
  }
}

class _CafeDetailRoute extends ConsumerStatefulWidget {
  const _CafeDetailRoute({
    required this.cafeId,
    this.source,
  });

  final String cafeId;
  final String? source;

  @override
  ConsumerState<_CafeDetailRoute> createState() => _CafeDetailRouteState();
}

class _CafeDetailRouteState extends ConsumerState<_CafeDetailRoute> {
  late CafeNotifier _cafeNotifier;

  @override
  void initState() {
    super.initState();
    _cafeNotifier = ref.read(cafeProvider.notifier);
    _schedulePreload();
  }

  @override
  void didUpdateWidget(covariant _CafeDetailRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cafeId != widget.cafeId) {
      _cafeNotifier.cancelCafeDetailLoad(oldWidget.cafeId);
      _schedulePreload();
    }
  }

  void _schedulePreload() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_preload());
      }
    });
  }

  Future<void> _preload() async {
    try {
      await _cafeNotifier.ensureCafeLoaded(widget.cafeId);
    } catch (_) {
      // The screen reads detail error/loading state from Riverpod.
    }
  }

  @override
  void dispose() {
    _cafeNotifier.cancelCafeDetailLoad(widget.cafeId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CafeDetailScreen(
      cafeId: widget.cafeId,
      source: widget.source,
    );
  }
}
