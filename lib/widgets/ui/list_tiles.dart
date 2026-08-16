import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AppPageTitle extends StatelessWidget {
  const AppPageTitle({
    super.key,
    required this.colors,
    required this.title,
    this.subtitle,
    this.large = false,
  });

  final AppColors colors;
  final String title;
  final String? subtitle;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: large ? 32 : 28,
            fontWeight: FontWeight.w800,
            color: colors.text,
            height: 1.15,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: TextStyle(
              color: colors.mutedText,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.colors,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionTooltip,
  });

  final AppColors colors;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? actionTooltip;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: colors.text,
        fontSize: 17,
      ),
    );

    if (actionLabel == null || onAction == null) {
      return titleText;
    }

    final action = Text(
      actionLabel!,
      style: TextStyle(
        color: colors.primary,
        fontWeight: FontWeight.w700,
      ),
    );

    return Row(
      children: [
        Expanded(child: titleText),
        Tooltip(
          message: actionTooltip ?? actionLabel!,
          child: Semantics(
            button: true,
            label: actionLabel,
            child: GestureDetector(
              onTap: onAction,
              child: action,
            ),
          ),
        ),
      ],
    );
  }
}

class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: colors.mutedText, size: 20),
          ],
        ),
      ),
    );
  }
}

class AppRadioTile extends StatelessWidget {
  const AppRadioTile({
    super.key,
    required this.icon,
    required this.label,
    required this.colors,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AppColors colors;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: active ? colors.primary : colors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: active ? colors.primary : colors.mutedText,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (active)
              Icon(
                Icons.check_circle,
                color: colors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
