import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/async_result.dart' as async_result;
import '../../models/index.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../layout/adaptive_layout.dart';
import '../cafes/cafe_image_carousel.dart';
import '../ui/state_views.dart';
import 'admin_logic.dart';

class AdminBlockedSection extends StatelessWidget {
  const AdminBlockedSection({
    super.key,
    required this.colors,
    this.detailsMessage,
    this.onRetry,
    this.retryLabel,
  });

  final AppColors colors;
  final String? detailsMessage;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          margin: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.adminBlockedTitle,
                style: TextStyle(
                  color: colors.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                detailsMessage?.trim().isNotEmpty == true
                    ? detailsMessage!
                    : l10n.adminBlockedMessage,
                style: TextStyle(color: colors.mutedText),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  key: const Key('admin-blocked-retry-button'),
                  onPressed: onRetry,
                  child: Text(
                    (retryLabel?.trim().isNotEmpty == true)
                        ? retryLabel!
                        : l10n.commonRetry,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.colors,
    required this.userCount,
    required this.cafeCount,
    required this.claimCount,
    required this.discoveredCount,
    required this.initialTab,
  });

  final AppColors colors;
  final int userCount;
  final int cafeCount;
  final int claimCount;
  final int discoveredCount;
  final AdminTab initialTab;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late AdminTab _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab &&
        _activeTab != widget.initialTab) {
      _activeTab = widget.initialTab;
    }
  }

  void _selectTab(AdminTab nextTab) {
    setState(() => _activeTab = nextTab);
    try {
      context.go('/admin?tab=${adminTabQueryValue(nextTab)}');
    } catch (_) {
      // Some focused widget tests mount AdminShell without GoRouter.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout =
        AdaptiveLayoutData.fromWidth(MediaQuery.sizeOf(context).width);

    return Scaffold(
      backgroundColor: widget.colors.bg,
      body: SafeArea(
        child: AdaptivePage(
          maxWidth: layout.compareContentMaxWidth(),
          child: FocusTraversalGroup(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: layout.sectionSpacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminHeaderSection(colors: widget.colors),
                  const SizedBox(height: AppSpacing.sm),
                  AdminTabBarSection(
                    colors: widget.colors,
                    activeTab: _activeTab,
                    userCount: widget.userCount,
                    cafeCount: widget.cafeCount,
                    claimCount: widget.claimCount,
                    discoveredCount: widget.discoveredCount,
                    onChanged: _selectTab,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: switch (_activeTab) {
                      AdminTab.users =>
                        AdminUsersSection(colors: widget.colors),
                      AdminTab.cafes => AdminCafesSection(
                          colors: widget.colors,
                          l10n: l10n,
                        ),
                      AdminTab.discovered => AdminDiscoveredCafesSection(
                          colors: widget.colors,
                        ),
                      AdminTab.claims =>
                        AdminOwnerClaimsSection(colors: widget.colors),
                    },
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

class AdminHeaderSection extends StatelessWidget {
  const AdminHeaderSection({
    super.key,
    required this.colors,
  });

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          key: const Key('admin-back-button'),
          onPressed: () {
            final canPop = context.canPop();
            AppLogger.debug(
              '[ADMIN_NAVIGATION] action=${canPop ? 'pop' : 'go_home'} canPop=$canPop',
              key: 'admin-navigation-back',
              throttle: Duration.zero,
            );
            if (canPop) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: Icon(Icons.arrow_back, size: 18, color: colors.text),
          label: Text(
            l10n.commonBack,
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          header: true,
          child: Text(
            l10n.adminTitle,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
        ),
      ],
    );
  }
}

class AdminTabBarSection extends StatelessWidget {
  const AdminTabBarSection({
    super.key,
    required this.colors,
    required this.activeTab,
    required this.userCount,
    required this.cafeCount,
    required this.claimCount,
    required this.discoveredCount,
    required this.onChanged,
  });

  final AppColors colors;
  final AdminTab activeTab;
  final int userCount;
  final int cafeCount;
  final int claimCount;
  final int discoveredCount;
  final ValueChanged<AdminTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String trEn(String tr, String en) =>
        Localizations.localeOf(context).languageCode == 'tr' ? tr : en;
    final savedLabel =
        trEn('Kayitli Kafeler ($cafeCount)', 'Saved Cafes ($cafeCount)');
    final discoveredLabel = trEn(
      'Kesfedilen Kafeler ($discoveredCount)',
      'Discovered Cafes ($discoveredCount)',
    );

    return Row(
      children: [
        Expanded(
          child: _AdminTabButton(
            key: const Key('admin-tab-users'),
            colors: colors,
            label: l10n.adminUsersTab(userCount),
            isActive: activeTab == AdminTab.users,
            onTap: () => onChanged(AdminTab.users),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AdminTabButton(
            key: const Key('admin-tab-cafes'),
            colors: colors,
            label: savedLabel,
            isActive: activeTab == AdminTab.cafes,
            onTap: () => onChanged(AdminTab.cafes),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AdminTabButton(
            key: const Key('admin-tab-claims'),
            colors: colors,
            label: 'Claims ($claimCount)',
            isActive: activeTab == AdminTab.claims,
            onTap: () => onChanged(AdminTab.claims),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AdminTabButton(
            key: const Key('admin-tab-discovered'),
            colors: colors,
            label: discoveredLabel,
            isActive: activeTab == AdminTab.discovered,
            onTap: () => onChanged(AdminTab.discovered),
          ),
        ),
      ],
    );
  }
}

class _AdminTabButton extends StatelessWidget {
  const _AdminTabButton({
    super.key,
    required this.colors,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final AppColors colors;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: Material(
        color: isActive ? colors.primary : colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isActive ? colors.primary : colors.border,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? colors.card : colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminUsersSection extends ConsumerWidget {
  const AdminUsersSection({
    super.key,
    required this.colors,
  });

  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);
    final l10n = context.l10n;

    if (usersAsync.isLoading) {
      return LoadingStateView(colors: colors);
    }

    if (usersAsync.hasError) {
      return ErrorStateView(
        colors: colors,
        message: l10n.errorUserListLoadFailed,
        onRetry: () => ref.invalidate(adminUsersProvider),
      );
    }

    return AdminUserDirectorySection(
      colors: colors,
      users: usersAsync.valueOrNull ?? const <UserProfile>[],
    );
  }
}

class AdminOwnerClaimsSection extends ConsumerWidget {
  const AdminOwnerClaimsSection({
    super.key,
    required this.colors,
  });

  final AppColors colors;

  String _trEn(BuildContext context, String tr, String en) {
    return Localizations.localeOf(context).languageCode == 'tr' ? tr : en;
  }

  bool _isMissingClaimsTable(Object? error) {
    final message = error?.toString().toLowerCase() ?? '';
    if (message.isEmpty) {
      return false;
    }
    return message.contains('cafe_owner_claims') &&
        (message.contains('does not exist') ||
            message.contains('undefined') ||
            message.contains('relation'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const claimsEnabled = bool.fromEnvironment('ENABLE_OWNER_CLAIMS');
    if (!claimsEnabled) {
      return EmptyStateView(
        colors: colors,
        icon: Icons.assignment_ind_rounded,
        title: _trEn(
          context,
          'Sahiplik talepleri kapali',
          'Ownership claims are disabled',
        ),
        message: _trEn(
          context,
          'Kafe sahiplerini Saved Cafes > Edit ekranindaki Kafe Sahibi bolumunden e-posta ile davet edip atayin.',
          'Invite and assign cafe owners by email from Saved Cafes > Edit > Cafe owner.',
        ),
      );
    }

    final claimsAsync = ref.watch(pendingCafeOwnerClaimsProvider);
    if (claimsAsync.isLoading) {
      return LoadingStateView(colors: colors);
    }
    if (claimsAsync.hasError) {
      if (_isMissingClaimsTable(claimsAsync.error)) {
        AppLogger.warn(
          'Cafe owner claims table is missing. Run Supabase migrations.',
          key: 'admin-claims-missing-table',
          throttle: const Duration(minutes: 5),
        );
        return EmptyStateView(
          colors: colors,
          icon: Icons.warning_amber_rounded,
          title: _trEn(
            context,
            'Talep tablosu yok',
            'Claims table missing',
          ),
          message: _trEn(
            context,
            'Cafe owner claims tablosu yok. Supabase migrations calistirin.',
            'Cafe owner claims table is not available. Run Supabase migrations.',
          ),
        );
      }
      return ErrorStateView(
        colors: colors,
        message: _trEn(
          context,
          'Sahiplik talepleri yuklenemedi.',
          'Ownership claims could not be loaded.',
        ),
        onRetry: () => ref.invalidate(pendingCafeOwnerClaimsProvider),
      );
    }

    final reviewState = ref.watch(cafeOwnerClaimAdminControllerProvider);
    final isReviewingClaim = reviewState is async_result.AsyncLoading<void>;
    final claims = claimsAsync.valueOrNull ?? const <CafeOwnerClaim>[];
    if (claims.isEmpty) {
      return EmptyStateView(
        colors: colors,
        title: _trEn(
          context,
          'Bekleyen talep yok',
          'No pending claims',
        ),
        message: _trEn(
          context,
          'Bekleyen sahiplik talebi yok.',
          'No pending ownership claims.',
        ),
      );
    }

    return ListView.separated(
      key: const Key('admin-owner-claims-list'),
      itemCount: claims.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final claim = claims[index];
        final cafe = ref.watch(cafeByIdProvider(claim.cafeId));
        return Container(
          key: ValueKey('admin-owner-claim-${claim.id}'),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cafe?.name ?? claim.businessName,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Cafe: ${cafe?.name ?? claim.cafeId} (${claim.cafeId})',
                style: TextStyle(color: colors.mutedText, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                <String?>[
                  claim.businessName,
                  claim.businessEmail,
                  claim.businessPhone ?? claim.phone,
                  claim.userId,
                ]
                    .whereType<String>()
                    .where((item) => item.isNotEmpty)
                    .join(' - '),
                style: TextStyle(color: colors.mutedText),
              ),
              Text(
                claim.createdAt.toLocal().toString(),
                style: TextStyle(color: colors.mutedText, fontSize: 12),
              ),
              if (claim.note?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  claim.note!,
                  style: TextStyle(color: colors.text),
                ),
              ],
              if (claim.evidenceUrl?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  claim.evidenceUrl!,
                  style: TextStyle(color: colors.text),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  FilledButton.icon(
                    key: ValueKey('admin-owner-claim-approve-${claim.id}'),
                    onPressed: isReviewingClaim
                        ? null
                        : () => _review(context, ref, claim, true),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(_trEn(context, 'Onayla', 'Approve')),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: ValueKey('admin-owner-claim-reject-${claim.id}'),
                    onPressed: isReviewingClaim
                        ? null
                        : () => _review(context, ref, claim, false),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(_trEn(context, 'Reddet', 'Reject')),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    CafeOwnerClaim claim,
    bool approve,
  ) async {
    final result = approve
        ? await ref
            .read(cafeOwnerClaimAdminControllerProvider.notifier)
            .approve(claim.id)
        : await ref
            .read(cafeOwnerClaimAdminControllerProvider.notifier)
            .reject(claim.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? (approve
                  ? _trEn(context, 'Talep onaylandi.', 'Claim approved.')
                  : _trEn(context, 'Talep reddedildi.', 'Claim rejected.'))
              : (result.message ??
                  _trEn(context, 'Islem basarisiz.', 'Action failed.')),
        ),
      ),
    );
  }
}

class AdminUserDirectorySection extends StatefulWidget {
  const AdminUserDirectorySection({
    super.key,
    required this.colors,
    required this.users,
  });

  final AppColors colors;
  final List<UserProfile> users;

  @override
  State<AdminUserDirectorySection> createState() =>
      _AdminUserDirectorySectionState();
}

class _AdminUserDirectorySectionState extends State<AdminUserDirectorySection> {
  final TextEditingController _searchController = TextEditingController();
  AdminUserFilters _filters = const AdminUserFilters();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = filterAdminUsers(widget.users, _filters);
    final layout =
        AdaptiveLayoutData.fromWidth(MediaQuery.sizeOf(context).width);

    return Column(
      children: [
        AdminCafeSearchSection(
          colors: widget.colors,
          controller: _searchController,
          hintText: context.l10n.adminSearchUsers,
          searchQuery: _filters.searchQuery,
          onChanged: (value) {
            setState(() {
              _filters = _filters.copyWith(searchQuery: value);
            });
          },
          onClear: () {
            _searchController.clear();
            setState(() {
              _filters = _filters.copyWith(searchQuery: '');
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        AdminReviewModerationSection(
          colors: widget.colors,
          selectedRole: _filters.roleFilter,
          onRoleSelected: (role) {
            setState(() {
              _filters = _filters.copyWith(roleFilter: role);
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: filteredUsers.isEmpty
              ? EmptyStateView(
                  colors: widget.colors,
                  icon: Icons.search_off,
                  title: context.l10n.adminNoResults,
                )
              : layout.adminColumns() == 1
                  ? ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (_, index) {
                        return AdminMetadataSection(
                          colors: widget.colors,
                          user: filteredUsers[index],
                        );
                      },
                    )
                  : GridView.builder(
                      itemCount: filteredUsers.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                        mainAxisExtent: 150,
                      ),
                      itemBuilder: (_, index) {
                        return AdminMetadataSection(
                          colors: widget.colors,
                          user: filteredUsers[index],
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class AdminCafeSearchSection extends StatelessWidget {
  const AdminCafeSearchSection({
    super.key,
    required this.colors,
    required this.controller,
    required this.hintText,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  final AppColors colors;
  final TextEditingController controller;
  final String hintText;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: colors.text),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: colors.mutedText),
        prefixIcon: Icon(Icons.search, color: colors.mutedText, size: 18),
        suffixIcon: searchQuery.trim().isEmpty
            ? null
            : IconButton(
                key: const Key('admin-user-search-clear'),
                tooltip: l10n.commonClear,
                onPressed: onClear,
                icon: Icon(
                  Icons.close_rounded,
                  color: colors.mutedText,
                  size: 18,
                ),
              ),
        filled: true,
        fillColor: colors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}

class AdminReviewModerationSection extends StatelessWidget {
  const AdminReviewModerationSection({
    super.key,
    required this.colors,
    required this.selectedRole,
    required this.onRoleSelected,
  });

  final AppColors colors;
  final String selectedRole;
  final ValueChanged<String> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: ['all', 'admin', 'cafe_owner', 'user'].map((roleFilter) {
        final label = switch (roleFilter) {
          'all' => l10n.adminRoleAll,
          'admin' => l10n.adminRoleAdmin,
          'cafe_owner' => 'Cafe owner',
          _ => l10n.adminRoleUser,
        };
        final active = selectedRole == roleFilter;
        return ChoiceChip(
          key: Key('admin-role-filter-$roleFilter'),
          label: Text(
            label,
            style: TextStyle(
              color: active ? colors.card : colors.text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          selected: active,
          showCheckmark: false,
          onSelected: (_) => onRoleSelected(roleFilter),
          backgroundColor: colors.chip,
          selectedColor: colors.accent,
          side: BorderSide(color: active ? colors.accent : colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(growable: false),
    );
  }
}

class AdminMetadataSection extends StatelessWidget {
  const AdminMetadataSection({
    super.key,
    required this.colors,
    required this.user,
  });

  final AppColors colors;
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAdminUser = user.role == ProfileRole.admin;

    return Container(
      key: ValueKey('admin-user-${user.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminUserDisplayName(l10n, user),
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (user.username != null)
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          color: colors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isAdminUser ? colors.primarySoft : colors.chip,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isAdminUser ? colors.primary : colors.border,
                  ),
                ),
                child: Text(
                  adminRoleLabel(l10n, user.role),
                  style: TextStyle(
                    color: isAdminUser ? colors.primary : colors.mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          Text(
            user.email,
            style: TextStyle(color: colors.mutedText),
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            'ID: ${user.id}',
            style: TextStyle(color: colors.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class AdminCafesSection extends ConsumerWidget {
  const AdminCafesSection({
    super.key,
    required this.colors,
    required this.l10n,
  });

  final AppColors colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminCafeListControllerProvider);
    if (state.isLoading && state.cafes.isEmpty) {
      return LoadingStateView(colors: colors);
    }

    if (state.errorMessage != null && state.cafes.isEmpty) {
      return ErrorStateView(
        colors: colors,
        message: l10n.errorCafeListLoadFailed,
        onRetry: () =>
            ref.read(adminCafeListControllerProvider.notifier).refresh(),
      );
    }

    return AdminCafeManagementSection(
      colors: colors,
      l10n: l10n,
    );
  }
}

class AdminDiscoveredCafesSection extends ConsumerWidget {
  const AdminDiscoveredCafesSection({
    super.key,
    required this.colors,
  });

  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cafes = ref.watch(adminDiscoveredCafesProvider);
    String trEn(String tr, String en) =>
        Localizations.localeOf(context).languageCode == 'tr' ? tr : en;
    AppLogger.debug(
      '[ADMIN_DISCOVERED_RENDER] count=${cafes.length}',
      key: 'admin-discovered-render',
      throttle: Duration.zero,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                trEn(
                  'Kesfedilen Kafeler (${cafes.length})',
                  'Discovered Cafes (${cafes.length})',
                ),
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const Key('admin-discovered-refresh'),
              onPressed: () => ref.invalidate(adminDiscoveredCafesProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(trEn('Kesfedilenleri yenile', 'Refresh discovered')),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: cafes.isEmpty
              ? EmptyStateView(
                  colors: colors,
                  icon: Icons.travel_explore_rounded,
                  title: 'No discovered cafes',
                  message:
                      'Fetched Google/discovery cafes are already saved or missing Google Place IDs.',
                )
              : ListView.separated(
                  key: const Key('admin-discovered-cafes-list'),
                  itemCount: cafes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    return _AdminDiscoveredCafeCard(
                      colors: colors,
                      cafe: cafes[index],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AdminDiscoveredCafeCard extends ConsumerWidget {
  const _AdminDiscoveredCafeCard({
    required this.colors,
    required this.cafe,
  });

  final AppColors colors;
  final Cafe cafe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeId = cafe.placeId?.trim() ?? '';
    final pendingIds = ref.watch(adminCafeMutationPendingIdsProvider);
    final isPending = pendingIds.contains(placeId);
    final rating = cafe.effectiveRating;
    final reviewCount = cafe.effectiveReviewCount;
    final ratingLabel = reviewCount > 0
        ? '${rating.toStringAsFixed(1)} ($reviewCount)'
        : cafe.effectiveRating > 0
            ? rating.toStringAsFixed(1)
            : 'No rating';

    return Container(
      key: ValueKey(
          'admin-discovered-cafe-${placeId.isEmpty ? cafe.id : placeId}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 96,
              height: 72,
              child: CafeImageCarousel(
                imageUrls: cafe.photoUrls,
                height: 72,
                colors: colors,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                compact: true,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cafe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cafe.district} / ${cafe.neighborhood}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.mutedText, fontSize: 13),
                ),
                if (cafe.address.trim().isNotEmpty)
                  Text(
                    cafe.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.mutedText, fontSize: 12),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _AdminDiscoveredChip(
                      colors: colors,
                      label: ratingLabel,
                    ),
                    _AdminDiscoveredChip(
                      colors: colors,
                      label: 'google_place_id: $placeId',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            key: Key('admin-discovered-import-$placeId'),
            onPressed: isPending
                ? null
                : () async {
                    final result = await ref
                        .read(cafeAdminMutationControllerProvider.notifier)
                        .importDiscoveredCafe(cafe);
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.ok
                              ? 'Cafe imported.'
                              : (result.message ?? 'Import failed.'),
                        ),
                      ),
                    );
                  },
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
            ),
            child: Text(
              isPending ? 'Importing...' : 'Import to Supabase',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDiscoveredChip extends StatelessWidget {
  const _AdminDiscoveredChip({
    required this.colors,
    required this.label,
  });

  final AppColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminCafeManagementSection extends ConsumerStatefulWidget {
  const AdminCafeManagementSection({
    super.key,
    required this.colors,
    required this.l10n,
  });

  final AppColors colors;
  final AppLocalizations l10n;

  @override
  ConsumerState<AdminCafeManagementSection> createState() =>
      _AdminCafeManagementSectionState();
}

class _AdminCafeManagementSectionState
    extends ConsumerState<AdminCafeManagementSection> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final threshold = _scrollController.position.maxScrollExtent - 240;
    if (_scrollController.position.pixels >= threshold) {
      unawaited(ref.read(adminCafeListControllerProvider.notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminCafeListControllerProvider);
    final activeDistricts = ref.watch(activeDistrictsProvider);
    String trEn(String tr, String en) =>
        Localizations.localeOf(context).languageCode == 'tr' ? tr : en;
    if (_searchController.text != state.searchQuery) {
      _searchController.value = TextEditingValue(
        text: state.searchQuery,
        selection: TextSelection.collapsed(offset: state.searchQuery.length),
      );
    }

    final cafes = state.cafes;
    AppLogger.debug(
      '[ADMIN_CAFE_LIST_RENDER] count=${cafes.length} tab=cafes',
      key: 'admin-cafe-list-render',
      throttle: Duration.zero,
    );
    final districtOptions = <String>{
      'all',
      ...activeDistricts.map((district) => district.displayName.trim()),
      ...state.cafes
          .map((cafe) => cafe.district.trim())
          .where((district) => district.isNotEmpty),
    }.toList(growable: false)
      ..sort();

    return Column(
      children: [
        AdminActionsSection(colors: widget.colors, l10n: widget.l10n),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trEn(
                  'Kayitli Kafeler (${cafes.length})',
                  'Saved Cafes (${cafes.length})',
                ),
                key: const Key('admin-supabase-managed-label'),
                style: TextStyle(
                  color: widget.colors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                trEn(
                  'Yalnizca Supabase kayitli kafeler burada gorunur. Kesfedilen Kafeler sekmesinden ice aktarabilirsiniz.',
                  'Only Supabase-saved cafes appear here. Open Discovered Cafes to import fetched cafes.',
                ),
                style: TextStyle(
                  color: widget.colors.mutedText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AdminCafeSearchSection(
          colors: widget.colors,
          controller: _searchController,
          hintText: widget.l10n.homeSearchHint,
          searchQuery: state.searchQuery,
          onChanged: (value) => ref
              .read(adminCafeListControllerProvider.notifier)
              .setSearchQuery(value),
          onClear: () {
            _searchController.clear();
            ref
                .read(adminCafeListControllerProvider.notifier)
                .setSearchQuery('');
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _AdminCafeDistrictFilterSection(
          colors: widget.colors,
          options: districtOptions,
          selectedDistrict: state.districtFilter,
          onSelected: (district) => ref
              .read(adminCafeListControllerProvider.notifier)
              .setDistrictFilter(district),
        ),
        const SizedBox(height: AppSpacing.sm),
        _AdminCafeStatusFilterSection(
          colors: widget.colors,
          selectedStatus: state.statusFilter,
          onSelected: (status) => ref
              .read(adminCafeListControllerProvider.notifier)
              .setStatusFilter(status),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (state.errorMessage != null && cafes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              state.errorMessage!,
              style: TextStyle(
                color: widget.colors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        Expanded(
          child: cafes.isEmpty
              ? EmptyStateView(
                  colors: widget.colors,
                  icon: Icons.search_off,
                  title: widget.l10n.adminNoResults,
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: cafes.length +
                      (state.hasMore || state.isLoadingMore ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index >= cafes.length) {
                      if (state.isLoadingMore) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: widget.colors.primary),
                          ),
                        );
                      }
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: () => ref
                                .read(adminCafeListControllerProvider.notifier)
                                .loadMore(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: widget.colors.primary,
                              side: BorderSide(color: widget.colors.primary),
                            ),
                            child: Text(context.l10n.commonLoadMore),
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AdminPhotoManagementSection(
                        colors: widget.colors,
                        l10n: widget.l10n,
                        cafe: cafes[index],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AdminCafeDistrictFilterSection extends StatelessWidget {
  const _AdminCafeDistrictFilterSection({
    required this.colors,
    required this.options,
    required this.selectedDistrict,
    required this.onSelected,
  });

  final AppColors colors;
  final List<String> options;
  final String selectedDistrict;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: options.map((district) {
          final isAll = district == 'all';
          final isSelected = selectedDistrict == district;
          final label = isAll ? context.l10n.adminRoleAll : district;

          return ChoiceChip(
            key: Key('admin-cafe-district-$district'),
            label: Text(
              label,
              style: TextStyle(
                color: isSelected ? colors.card : colors.text,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(district),
            backgroundColor: colors.chip,
            selectedColor: colors.primary,
            side:
                BorderSide(color: isSelected ? colors.primary : colors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _AdminCafeStatusFilterSection extends StatelessWidget {
  const _AdminCafeStatusFilterSection({
    required this.colors,
    required this.selectedStatus,
    required this.onSelected,
  });

  final AppColors colors;
  final String selectedStatus;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const statuses = <String>['all', 'visible', 'hidden', 'deleted'];

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: statuses.map((status) {
          final isSelected = selectedStatus == status;
          final label = switch (status) {
            'visible' => 'Visible',
            'hidden' => 'Hidden',
            'deleted' => 'Deleted',
            _ => context.l10n.adminRoleAll,
          };

          return ChoiceChip(
            key: Key('admin-cafe-status-$status'),
            label: Text(
              label,
              style: TextStyle(
                color: isSelected ? colors.card : colors.text,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(status),
            backgroundColor: colors.chip,
            selectedColor: colors.accent,
            side: BorderSide(color: isSelected ? colors.accent : colors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(growable: false),
      ),
    );
  }
}

class AdminActionsSection extends ConsumerWidget {
  const AdminActionsSection({
    super.key,
    required this.colors,
    required this.l10n,
  });

  final AppColors colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('admin-add-cafe-button'),
              onPressed: () async {
                await context.push('/cafe-add');
                if (context.mounted) {
                  await ref
                      .read(adminCafeListControllerProvider.notifier)
                      .refresh();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.card,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(
                l10n.adminAddCafe,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: () =>
                ref.read(adminCafeListControllerProvider.notifier).refresh(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              side: BorderSide(color: colors.border),
            ),
            child: Icon(Icons.refresh_rounded, color: colors.text),
          ),
        ],
      ),
    );
  }
}

class AdminPhotoManagementSection extends ConsumerWidget {
  const AdminPhotoManagementSection({
    super.key,
    required this.colors,
    required this.l10n,
    required this.cafe,
  });

  final AppColors colors;
  final AppLocalizations l10n;
  final Cafe cafe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRating = cafe.appRating;
    final appReviewCount = cafe.appReviewCount ?? 0;
    final ratingLabel = appRating != null
        ? '${appRating.toStringAsFixed(1)} ($appReviewCount)'
        : l10n.cafeNoRatingsYet;
    final manualFallbackLabel =
        cafe.adminFallbackRating != null && appRating == null
            ? 'Manual ${cafe.adminFallbackRating!.toStringAsFixed(1)}'
            : null;
    final statusKey = adminCafeStatusKey(cafe);
    final pendingIds = ref.watch(adminCafeMutationPendingIdsProvider);
    final isPending = pendingIds.contains(cafe.id.trim());
    final shouldRestore = statusKey != 'visible';
    final actionLabel = shouldRestore ? 'Restore' : 'Delete';
    final pendingLabel = shouldRestore ? 'Restoring...' : 'Deleting...';
    final statusLabel = switch (statusKey) {
      'deleted' => 'Deleted',
      'hidden' => 'Hidden',
      _ => 'Visible',
    };

    return Container(
      key: ValueKey('admin-cafe-${cafe.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cafe.name,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${districtLabel(l10n, cafe.district)} / ${cafe.neighborhood}',
                  style: TextStyle(color: colors.mutedText),
                ),
                Text(
                  cafe.ownerUserId?.trim().isNotEmpty == true
                      ? 'Owner: ${cafe.ownerUserId!.trim()}'
                      : 'Owner: Unassigned',
                  style: TextStyle(color: colors.mutedText, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.chip,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        adminCafeSourceLabel(cafe),
                        style: TextStyle(
                          color: colors.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusKey == 'visible'
                            ? colors.primarySoft
                            : colors.chip,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: statusKey == 'visible'
                              ? colors.primary
                              : colors.border,
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusKey == 'visible'
                              ? colors.primary
                              : colors.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      ratingLabel,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (manualFallbackLabel != null)
                      Text(
                        manualFallbackLabel,
                        style: TextStyle(
                          color: colors.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OutlinedButton(
                key: Key('admin-cafe-edit-${cafe.id}'),
                onPressed: isPending
                    ? null
                    : () async {
                        await context.push('/cafe-edit/${cafe.id}');
                        if (context.mounted) {
                          await ref
                              .read(adminCafeListControllerProvider.notifier)
                              .refresh();
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accent,
                  side: BorderSide(color: colors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.adminEdit,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                key: Key('admin-cafe-action-${cafe.id}'),
                onPressed: isPending
                    ? null
                    : () async {
                        AppLogger.debug(
                          '[ADMIN_DELETE_TAP] surface=admin_list id=${cafe.id} placeId=${cafe.placeId ?? ''} google_place_id=${cafe.placeId ?? ''} action=${shouldRestore ? 'restore' : 'delete'}',
                          key: 'admin-list-delete-tap-${cafe.id}',
                          throttle: Duration.zero,
                        );
                        AppLogger.debug(
                          '[ADMIN_DELETE_BUTTON] buttonHandlerReached=true surface=admin_list selectedId=${cafe.id} selectedGooglePlaceId=${cafe.placeId ?? ''}',
                          key: 'admin-list-delete-button-${cafe.id}',
                          throttle: Duration.zero,
                        );
                        final notifier = ref
                            .read(cafeAdminMutationControllerProvider.notifier);
                        AppLogger.debug(
                          '[ADMIN_DELETE_CONFIRM] surface=admin_list confirmed=true',
                          key: 'admin-list-delete-confirm-${cafe.id}',
                          throttle: Duration.zero,
                        );
                        final result = shouldRestore
                            ? await notifier.restoreCafe(cafe.id)
                            : await notifier.deleteCafe(cafe.id);
                        if (!context.mounted) {
                          return;
                        }
                        final message = result.ok
                            ? (shouldRestore
                                ? 'Cafe restored.'
                                : 'Cafe deleted.')
                            : (result.message ?? 'Action failed.');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                        if (result.ok && !shouldRestore) {
                          AppLogger.debug(
                            '[ADMIN_ROUTE] tab=cafes source=post_delete',
                            key: 'admin-route-post-delete-${cafe.id}',
                            throttle: Duration.zero,
                          );
                          try {
                            context.go('/admin?tab=cafes');
                          } catch (_) {
                            // Some focused widget tests mount this row without GoRouter.
                          }
                          final location = _safeRouterLocation(context);
                          final stillInRoute = location.contains(cafe.id);
                          notifier.logDeletePostVerify(
                            deletedId: cafe.id,
                            stillInRoute: stillInRoute,
                          );
                        }
                      },
                style: TextButton.styleFrom(
                  foregroundColor:
                      statusKey != 'visible' ? colors.accent : colors.danger,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isPending ? pendingLabel : actionLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              if (isPending)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SizedBox(
                    key: Key('admin-cafe-action-progress-${cafe.id}'),
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        statusKey != 'visible' ? colors.accent : colors.danger,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _safeRouterLocation(BuildContext context) {
  try {
    return GoRouter.of(context).location;
  } catch (_) {
    return '';
  }
}
