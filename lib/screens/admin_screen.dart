import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/state_views.dart';
import '../widgets/admin/admin_logic.dart';
import '../widgets/admin/admin_sections.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key, this.initialTab});

  final AdminTab? initialTab;

  AdminTab _resolveInitialTab(BuildContext context) {
    if (initialTab != null) {
      return initialTab!;
    }
    final tabParam = _safeQueryParam(context, 'tab');
    return adminTabFromQuery(tabParam, fallback: AdminTab.cafes);
  }

  String? _safeQueryParam(BuildContext context, String key) {
    try {
      return GoRouterState.of(context).queryParameters[key];
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final shellState = ref.watch(appShellProvider);
    final adminResolutionState = shellState.adminRoleResolutionState;
    final adminRoleStatusMessage = ref.watch(adminRoleStatusMessageProvider);
    final userCount = ref.watch(
      adminUsersProvider.select((async) => async.valueOrNull?.length ?? 0),
    );
    final cafeCount = ref.watch(
      adminCafeListControllerProvider.select((state) => state.cafes.length),
    );
    const claimsEnabled = bool.fromEnvironment('ENABLE_OWNER_CLAIMS');
    final claimCount = claimsEnabled
        ? ref.watch(
            pendingCafeOwnerClaimsProvider.select(
              (async) => async.valueOrNull?.length ?? 0,
            ),
          )
        : 0;
    final discoveredCount = ref.watch(
      adminDiscoveredCafesProvider.select((cafes) => cafes.length),
    );
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );

    if (adminResolutionState == AdminRoleResolutionState.loading) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: LoadingStateView(
          colors: colors,
          label: context.l10n.commonLoading,
        ),
      );
    }

    if (adminResolutionState != AdminRoleResolutionState.resolvedAdmin) {
      final canRetry = adminResolutionState == AdminRoleResolutionState.failed;
      return AdminBlockedSection(
        colors: colors,
        detailsMessage: canRetry ? adminRoleStatusMessage : null,
        onRetry: canRetry
            ? () {
                unawaited(
                  ref
                      .read(appShellProvider.notifier)
                      .refreshAdminRoleResolution(force: true),
                );
              }
            : null,
      );
    }

    return AdminShell(
      colors: colors,
      userCount: userCount,
      cafeCount: cafeCount,
      claimCount: claimCount,
      discoveredCount: discoveredCount,
      initialTab: _resolveInitialTab(context),
    );
  }
}
