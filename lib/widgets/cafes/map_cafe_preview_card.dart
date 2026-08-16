import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';
import '../../utils/cafe_hours.dart';
import 'cafe_image_carousel.dart';
import 'map_surface.dart';

class _MapCafePreviewCardTokens {
  const _MapCafePreviewCardTokens._();

  static const double cardRadius = MapSurfaceTokens.outerRadius + 2;
  static const double imageRadius = 20;
  static const double imageSize = 96;
  static const double closeButtonSize = 40;
  static const double badgeMaxWidth = 136;
  static const double metricMaxWidth = 126;
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(14, 14, 14, 14);
}

class MapCafePreviewCard extends StatelessWidget {
  const MapCafePreviewCard({
    super.key,
    required this.colors,
    required this.cafe,
    required this.onTap,
    required this.onClose,
  });

  final AppColors colors;
  final Cafe cafe;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cardRadius = MapSurfaceTokens.borderRadius(
      _MapCafePreviewCardTokens.cardRadius,
    );
    final cardShape =
        MapSurfaceTokens.shape(_MapCafePreviewCardTokens.cardRadius);
    final imageRadius = BorderRadius.circular(
      _MapCafePreviewCardTokens.imageRadius,
    );
    final visibleRating =
        cafe.appRating ?? cafe.adminFallbackRating ?? cafe.googleRating;
    final hasVisibleRating = visibleRating != null;
    final openStatus = resolveCafeOpenStatus(cafe);

    return MapSurface(
      colors: colors,
      radius: _MapCafePreviewCardTokens.cardRadius,
      opacity: 0.985,
      padding: EdgeInsets.zero,
      child: Semantics(
        button: true,
        label: '${cafe.name}, ${l10n.commonDetails}',
        child: Material(
          color: Colors.transparent,
          shape: cardShape,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: cardRadius,
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: cardShape,
              child: Padding(
                padding: _MapCafePreviewCardTokens.contentPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MapCardImageFrame(
                          colors: colors,
                          borderRadius: imageRadius,
                          child: CafeImageCarousel(
                            key: ValueKey('map-preview-gallery-${cafe.id}'),
                            imageUrls: cafe.photoUrls,
                            traceTag: 'map-preview:${cafe.id}',
                            height: _MapCafePreviewCardTokens.imageSize,
                            colors: colors,
                            borderRadius: imageRadius,
                            cacheWidth: 240,
                            cacheHeight: 240,
                            requestWidth: 320,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      cafe.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  _MapIconAction(
                                    buttonKey: const Key('map-selected-close'),
                                    tooltip: l10n.commonClose,
                                    icon: Icons.close_rounded,
                                    colors: colors,
                                    onPressed: onClose,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _StatusBadge(
                                colors: colors,
                                status: openStatus,
                                label: switch (openStatus) {
                                  CafeOpenStatus.open => l10n.commonOpen,
                                  CafeOpenStatus.closed => l10n.commonClosed,
                                  CafeOpenStatus.unknown => l10n.commonUnknown,
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cafeLocationSummary(l10n, cafe),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricPill(
                            colors: colors,
                            icon: hasVisibleRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            iconColor: hasVisibleRating
                                ? colors.primary
                                : colors.mutedText,
                            label: visibleRating?.toStringAsFixed(1) ??
                                l10n.cafeNoRatingsYet,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.text,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 36),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.commonDetails,
                                    style: TextStyle(
                                      color: colors.card,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: colors.card,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapCardImageFrame extends StatelessWidget {
  const _MapCardImageFrame({
    required this.colors,
    required this.borderRadius,
    required this.child,
  });

  final AppColors colors;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _MapCafePreviewCardTokens.imageSize,
      height: _MapCafePreviewCardTokens.imageSize,
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: borderRadius,
        border: Border.all(
          color: colors.border.withValues(alpha: 0.8),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _MapIconAction extends StatelessWidget {
  const _MapIconAction({
    required this.tooltip,
    required this.icon,
    required this.colors,
    required this.onPressed,
    this.buttonKey,
  });

  final String tooltip;
  final IconData icon;
  final AppColors colors;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(
        width: _MapCafePreviewCardTokens.closeButtonSize,
        height: _MapCafePreviewCardTokens.closeButtonSize,
      ),
      padding: EdgeInsets.zero,
      iconSize: 16,
      style: IconButton.styleFrom(
        backgroundColor: colors.card.withValues(alpha: 0.96),
        foregroundColor: colors.mutedText,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      icon: Icon(icon, color: colors.mutedText, size: 16),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.colors,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final AppColors colors;
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _MapCafePreviewCardTokens.metricMaxWidth,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.colors,
    required this.status,
    required this.label,
  });

  final AppColors colors;
  final CafeOpenStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isOpen = status == CafeOpenStatus.open;
    final isUnknown = status == CafeOpenStatus.unknown;
    final accent =
        isUnknown ? colors.primary : (isOpen ? colors.accent : colors.danger);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: accent.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOpen
                  ? Icons.schedule_rounded
                  : isUnknown
                      ? Icons.schedule_outlined
                      : Icons.do_not_disturb_on_rounded,
              size: 12,
              color: accent,
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _MapCafePreviewCardTokens.badgeMaxWidth,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
