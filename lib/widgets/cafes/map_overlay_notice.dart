import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'map_surface.dart';

class MapOverlayCard extends StatelessWidget {
  const MapOverlayCard({
    super.key,
    required this.colors,
    required this.child,
  });

  final AppColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MapSurface(colors: colors, child: child);
  }
}

class MapActiveFiltersNotice extends StatelessWidget {
  const MapActiveFiltersNotice({
    super.key,
    required this.colors,
    required this.label,
  });

  final AppColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MapOverlayCard(
      colors: colors,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
