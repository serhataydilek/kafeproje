import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'remote_image.dart';

class ProfileAvatarCard extends StatelessWidget {
  const ProfileAvatarCard({
    super.key,
    required this.colors,
    required this.name,
    this.avatarUrl,
    this.avatarImageProvider,
    this.size = 108,
    this.badge,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  final AppColors colors;
  final String name;
  final String? avatarUrl;
  final ImageProvider<Object>? avatarImageProvider;
  final double size;
  final Widget? badge;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.card,
            colors.primarySoft.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _AvatarVisual(
            colors: colors,
            name: name,
            avatarUrl: avatarUrl,
            avatarImageProvider: avatarImageProvider,
            size: size,
          ),
          if (badge != null) ...[
            const SizedBox(height: AppSpacing.sm),
            badge!,
          ],
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileAvatarActionChip extends StatelessWidget {
  const ProfileAvatarActionChip({
    super.key,
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final AppColors colors;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? colors.danger : colors.text;
    final background = destructive
        ? colors.danger.withValues(alpha: 0.08)
        : colors.card.withValues(alpha: 0.82);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: destructive
                  ? colors.danger.withValues(alpha: 0.18)
                  : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarVisual extends StatelessWidget {
  const _AvatarVisual({
    required this.colors,
    required this.name,
    required this.avatarUrl,
    required this.avatarImageProvider,
    required this.size,
  });

  final AppColors colors;
  final String name;
  final String? avatarUrl;
  final ImageProvider<Object>? avatarImageProvider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = avatarUrl?.trim();
    final previewImageProvider = avatarImageProvider;
    final hasAvatar = effectiveUrl != null && effectiveUrl.isNotEmpty;
    final hasPreview = previewImageProvider != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colors.primary.withValues(alpha: 0.95),
            colors.primary.withValues(alpha: 0.72),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.card,
        ),
        child: ClipOval(
          child: hasPreview
              ? Image(
                  image: previewImageProvider,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : hasAvatar
                  ? RemoteImage(
                      imageUrl: effectiveUrl,
                      cacheWidth: 256,
                      cacheHeight: 256,
                      requestWidth: 256,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      loadingBuilder: (_) => _AvatarFallback(
                        colors: colors,
                        name: name,
                        loading: true,
                      ),
                      errorBuilder: (_) => _AvatarFallback(
                        colors: colors,
                        name: name,
                        hasError: true,
                      ),
                    )
                  : _AvatarFallback(
                      colors: colors,
                      name: name,
                    ),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.colors,
    required this.name,
    this.loading = false,
    this.hasError = false,
  });

  final AppColors colors;
  final String name;
  final bool loading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final initials = _buildInitials(name);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primarySoft,
            colors.chip,
          ],
        ),
      ),
      child: Center(
        child: loading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: colors.primary,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (initials.isNotEmpty)
                    Text(
                      initials,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    )
                  else
                    Icon(
                      hasError
                          ? Icons.broken_image_outlined
                          : Icons.person_rounded,
                      size: 36,
                      color: colors.primary,
                    ),
                  if (hasError) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Foto yok',
                      style: TextStyle(
                        color: colors.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

String _buildInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return '';
  }
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}
