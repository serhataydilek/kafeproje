import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AppActionButton extends StatelessWidget {
  const AppActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = AppActionButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppActionButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = resolveColors(
      Theme.of(context).brightness == Brightness.dark
          ? AppThemeMode.dark
          : AppThemeMode.light,
      Theme.of(context).brightness,
    );
    final enabled = onPressed != null && !isLoading;
    final isPrimary = variant == AppActionButtonVariant.primary;
    final foreground =
        isPrimary ? Theme.of(context).colorScheme.onPrimary : colors.text;
    final background = isPrimary ? colors.primary : colors.card;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Ink(
            decoration: BoxDecoration(
              color: enabled
                  ? background
                  : (isPrimary ? colors.chip : colors.card),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isPrimary ? Colors.transparent : colors.border,
              ),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : const [],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else if (icon != null) ...[
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: enabled ? foreground : colors.mutedText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.15,
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

enum AppActionButtonVariant {
  primary,
  secondary,
}
