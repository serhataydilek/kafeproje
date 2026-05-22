import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../ui/remote_image.dart';

class CafePhoto extends StatelessWidget {
  const CafePhoto({
    super.key,
    required this.colors,
    required this.imageUrl,
    required this.borderRadius,
    required this.fit,
    this.cacheWidth,
    this.cacheHeight,
    this.icon = Icons.coffee_rounded,
    this.iconSize = 28,
    this.showLoadingSpinner = true,
  });

  final AppColors colors;
  final String? imageUrl;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final IconData icon;
  final double iconSize;
  final bool showLoadingSpinner;

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = imageUrl?.trim();
    final placeholder = _buildPlaceholder();

    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: normalizedImageUrl == null || normalizedImageUrl.isEmpty
          ? placeholder
          : RemoteImage(
              imageUrl: normalizedImageUrl,
              fit: fit,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              requestWidth: cacheWidth,
              filterQuality: FilterQuality.low,
              loadingBuilder: (_) =>
                  _buildPlaceholder(showLoadingSpinner: showLoadingSpinner),
              errorBuilder: (_) => placeholder,
            ),
    );
  }

  Widget _buildPlaceholder({bool showLoadingSpinner = false}) {
    return _CafePhotoPlaceholder(
      colors: colors,
      icon: icon,
      iconSize: iconSize,
      showLoadingSpinner: showLoadingSpinner,
    );
  }
}

class _CafePhotoPlaceholder extends StatelessWidget {
  const _CafePhotoPlaceholder({
    required this.colors,
    required this.icon,
    required this.iconSize,
    required this.showLoadingSpinner,
  });

  final AppColors colors;
  final IconData icon;
  final double iconSize;
  final bool showLoadingSpinner;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.chip,
            colors.primarySoft.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: showLoadingSpinner
            ? Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: colors.card.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              )
            : Container(
                width: iconSize + 22,
                height: iconSize + 22,
                decoration: BoxDecoration(
                  color: colors.card.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: colors.mutedText,
                  size: iconSize,
                ),
              ),
      ),
    );
  }
}
