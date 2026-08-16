import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class _CafePrimaryActionTokens {
  const _CafePrimaryActionTokens._();

  static const double outerRadius = 16;
  static const double innerRadius = 14;
  static const EdgeInsets outerPadding = EdgeInsets.all(6);
  static const EdgeInsets compactButtonPadding = EdgeInsets.symmetric(
    horizontal: 9,
    vertical: 8,
  );
  static const EdgeInsets wideButtonPadding = EdgeInsets.symmetric(
    horizontal: 11,
    vertical: 9,
  );
}

class CafePrimaryActions extends StatelessWidget {
  const CafePrimaryActions({
    super.key,
    required this.colors,
    required this.isFavorite,
    this.isFavoritePending = false,
    this.hasFavoriteError = false,
    required this.inCompare,
    required this.favoriteLabel,
    required this.compareLabel,
    required this.onFavorite,
    required this.onCompare,
    this.leadingAction,
  });

  final AppColors colors;
  final bool isFavorite;
  final bool isFavoritePending;
  final bool hasFavoriteError;
  final bool inCompare;
  final String favoriteLabel;
  final String compareLabel;
  final VoidCallback onFavorite;
  final VoidCallback onCompare;
  final CafePrimaryLeadingAction? leadingAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.94),
        borderRadius:
            BorderRadius.circular(_CafePrimaryActionTokens.outerRadius),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: _CafePrimaryActionTokens.outerPadding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useVerticalButtons = constraints.maxWidth < 360;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leadingAction != null) ...[
                  _WideActionButton(
                    colors: colors,
                    label: leadingAction!.label,
                    subtitle: leadingAction!.subtitle,
                    icon: leadingAction!.icon,
                    accentColor: leadingAction!.accentColor ?? colors.primary,
                    isPrimary: true,
                    onTap: leadingAction!.onTap,
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                ],
                if (useVerticalButtons) ...[
                  _CompactActionButton(
                    colors: colors,
                    active: isFavorite,
                    pending: isFavoritePending,
                    hasError: hasFavoriteError,
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: favoriteLabel,
                    accentColor: colors.primary,
                    onTap: onFavorite,
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  _CompactActionButton(
                    colors: colors,
                    active: inCompare,
                    icon: Icons.compare_arrows_rounded,
                    label: compareLabel,
                    accentColor: colors.accent,
                    onTap: onCompare,
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: _CompactActionButton(
                          colors: colors,
                          active: isFavorite,
                          pending: isFavoritePending,
                          hasError: hasFavoriteError,
                          icon: isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: favoriteLabel,
                          accentColor: colors.primary,
                          onTap: onFavorite,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Expanded(
                        child: _CompactActionButton(
                          colors: colors,
                          active: inCompare,
                          icon: Icons.compare_arrows_rounded,
                          label: compareLabel,
                          accentColor: colors.accent,
                          onTap: onCompare,
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CafePrimaryLeadingAction {
  const CafePrimaryLeadingAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.accentColor,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accentColor;
}

class _WideActionButton extends StatelessWidget {
  const _WideActionButton({
    required this.colors,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isPrimary,
    required this.onTap,
  });

  final AppColors colors;
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? onColor(accentColor) : colors.text;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius:
                BorderRadius.circular(_CafePrimaryActionTokens.innerRadius),
            child: Ink(
              padding: _CafePrimaryActionTokens.wideButtonPadding,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(_CafePrimaryActionTokens.innerRadius),
                color: accentColor,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: foreground, size: 18),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: foreground.withValues(alpha: 0.9),
                    size: 15,
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

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.colors,
    required this.active,
    this.pending = false,
    this.hasError = false,
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  final AppColors colors;
  final bool active;
  final bool pending;
  final bool hasError;
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final safeAccent = hasError ? colors.danger : accentColor;
    final background = active
        ? Color.alphaBlend(
            safeAccent.withValues(alpha: 0.16),
            colors.card,
          )
        : hasError
            ? colors.danger.withValues(alpha: 0.1)
            : colors.bg.withValues(alpha: 0.52);
    final foreground = hasError
        ? colors.danger
        : active
            ? safeAccent
            : colors.text;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: active,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: pending ? null : onTap,
            borderRadius:
                BorderRadius.circular(_CafePrimaryActionTokens.innerRadius),
            child: Ink(
              padding: _CafePrimaryActionTokens.compactButtonPadding,
              decoration: BoxDecoration(
                color: background,
                borderRadius:
                    BorderRadius.circular(_CafePrimaryActionTokens.innerRadius),
                border: Border.all(
                  color: hasError
                      ? colors.danger
                      : active
                          ? safeAccent.withValues(alpha: 0.28)
                          : colors.border,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: safeAccent.withValues(alpha: 0.08),
                          blurRadius: 9,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: active
                          ? safeAccent.withValues(alpha: 0.14)
                          : colors.card.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: pending
                        ? SizedBox(
                            key: const Key('favorite-detail-pending-indicator'),
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: foreground,
                            ),
                          )
                        : Icon(
                            hasError ? Icons.error_outline_rounded : icon,
                            size: 14,
                            color: foreground,
                          ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.1,
                      ),
                    ),
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
