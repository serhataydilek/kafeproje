import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({
    super.key,
    required this.colors,
    this.label,
  });

  final AppColors colors;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final announcement = label ?? context.l10n.commonLoading;

    return Center(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: announcement,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: colors.primary,
                  semanticsLabel: announcement,
                ),
                if (label != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    label!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.colors,
    required this.title,
    this.icon = Icons.inbox_outlined,
    this.message,
    this.action,
    this.actions,
    this.hint,
  });

  final AppColors colors;
  final String title;
  final String? message;
  final String? hint;
  final IconData icon;
  final Widget? action;
  final List<Widget>? actions;

  List<Widget> get _actionItems {
    if (actions != null && actions!.isNotEmpty) {
      return actions!;
    }
    if (action != null) {
      return [action!];
    }
    return const <Widget>[];
  }

  @override
  Widget build(BuildContext context) {
    final actionItems = _actionItems;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.chip,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 30, color: colors.mutedText),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (hint != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.chip,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          hint!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.mutedText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (actionItems.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: actionItems,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.colors,
    required this.message,
    this.onRetry,
  });

  final AppColors colors;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return EmptyStateView(
      colors: colors,
      icon: Icons.error_outline,
      title: l10n.errorGenericTitle,
      message: message,
      action: onRetry == null
          ? null
          : FilledButton(
              onPressed: onRetry,
              child: Text(l10n.commonRetry),
            ),
    );
  }
}

class SignInRequiredStateView extends StatelessWidget {
  const SignInRequiredStateView({
    super.key,
    required this.colors,
    required this.onSignIn,
    this.icon = Icons.lock_outline,
    this.message,
  });

  final AppColors colors;
  final VoidCallback onSignIn;
  final IconData icon;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return EmptyStateView(
      colors: colors,
      icon: icon,
      title: l10n.profileGuestTitle,
      message: message,
      action: FilledButton(
        onPressed: onSignIn,
        child: Text(l10n.profileGuestAction),
      ),
    );
  }
}

class InlineRefreshBar extends StatelessWidget {
  const InlineRefreshBar({
    super.key,
    required this.colors,
  });

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.commonRefreshing,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 3,
          child: LinearProgressIndicator(
            color: colors.primary,
            backgroundColor: colors.chip,
          ),
        ),
      ),
    );
  }
}

class CafeCacheStatusBanner extends StatelessWidget {
  const CafeCacheStatusBanner({
    super.key,
    required this.colors,
    required this.status,
  });

  final AppColors colors;
  final CafeCacheStatusView? status;

  @override
  Widget build(BuildContext context) {
    final current = status;
    if (current == null) {
      return const SizedBox.shrink();
    }

    final showMessage = current.kind == CafeCacheStatusKind.staleCached ||
        current.kind == CafeCacheStatusKind.offlineFallback ||
        current.kind == CafeCacheStatusKind.unavailable ||
        (current.kind == CafeCacheStatusKind.freshCached &&
            current.message.trim().isNotEmpty &&
            !current.isRefreshing);
    if (!showMessage && !current.isRefreshing) {
      return const SizedBox.shrink();
    }

    final icon = switch (current.kind) {
      CafeCacheStatusKind.offlineFallback => Icons.cloud_off_rounded,
      CafeCacheStatusKind.staleCached => Icons.history_rounded,
      CafeCacheStatusKind.freshCached => Icons.schedule_rounded,
      CafeCacheStatusKind.unavailable => Icons.warning_amber_rounded,
      CafeCacheStatusKind.live => Icons.sync_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMessage)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: colors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      current.message,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (current.isRefreshing) ...[
          if (showMessage) const SizedBox(height: AppSpacing.sm),
          InlineRefreshBar(colors: colors),
        ],
      ],
    );
  }
}
