import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class MapSurfaceTokens {
  const MapSurfaceTokens._();

  static const double outerRadius = AppRadius.lg + 4;
  static const double innerRadius = AppRadius.md + 4;
  static const EdgeInsets contentPadding = EdgeInsets.all(10);
  static const double shadowBlur = 16;
  static const Offset shadowOffset = Offset(0, 8);

  static BorderRadius borderRadius([double radius = outerRadius]) =>
      BorderRadius.circular(radius);

  static RoundedRectangleBorder shape([double radius = outerRadius]) =>
      RoundedRectangleBorder(
        borderRadius: borderRadius(radius),
      );
}

class MapSurface extends StatelessWidget {
  const MapSurface({
    super.key,
    required this.colors,
    required this.child,
    this.padding = MapSurfaceTokens.contentPadding,
    this.radius = MapSurfaceTokens.outerRadius,
    this.opacity = 0.96,
  });

  final AppColors colors;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final resolvedBorderRadius = MapSurfaceTokens.borderRadius(radius);

    return DecoratedBox(
      decoration: mapSurfaceDecoration(
        colors,
        radius: radius,
        opacity: opacity,
      ),
      child: ClipRRect(
        borderRadius: resolvedBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          shape: MapSurfaceTokens.shape(radius),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

BoxDecoration mapSurfaceDecoration(
  AppColors colors, {
  double radius = MapSurfaceTokens.outerRadius,
  double opacity = 0.96,
}) {
  return BoxDecoration(
    color: colors.card.withValues(alpha: opacity),
    borderRadius: MapSurfaceTokens.borderRadius(radius),
    border: Border.all(color: colors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: MapSurfaceTokens.shadowBlur,
        offset: MapSurfaceTokens.shadowOffset,
      ),
    ],
  );
}
