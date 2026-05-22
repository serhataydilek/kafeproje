import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import 'map_surface.dart';

class MapRadiusSelector extends StatelessWidget {
  const MapRadiusSelector({
    super.key,
    required this.colors,
    required this.selectedPreset,
    required this.isEnabled,
    required this.onSelected,
    this.isRefreshing = false,
  });

  final AppColors colors;
  final MapRadiusPreset selectedPreset;
  final bool isEnabled;
  final bool isRefreshing;
  final ValueChanged<MapRadiusPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectorRadius = MapSurfaceTokens.borderRadius();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isEnabled ? 1 : 0.68,
      child: Semantics(
        container: true,
        label: context.l10n.mapNearbyRadiusMessage(
          _distanceLabelFor(selectedPreset),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colors.bg.withValues(alpha: 0.18),
              colors.card.withValues(alpha: 0.94),
            ),
            borderRadius: selectorRadius,
            border: Border.all(
              color: colors.border.withValues(alpha: 0.84),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final preset in MapRadiusPreset.values) ...[
                  _RadiusPresetButton(
                    colors: colors,
                    preset: preset,
                    label: _labelForPreset(context, preset),
                    isSelected: preset == selectedPreset,
                    isEnabled: isEnabled,
                    onTap: isEnabled ? () => onSelected(preset) : null,
                  ),
                  if (preset != MapRadiusPreset.values.last)
                    const SizedBox(width: 4),
                ],
                if (isRefreshing) ...[
                  const SizedBox(width: 4),
                  _RadiusRefreshIndicator(colors: colors),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _labelForPreset(BuildContext context, MapRadiusPreset preset) {
    final l10n = context.l10n;
    switch (preset) {
      case MapRadiusPreset.small:
        return l10n.mapRadiusSmall;
      case MapRadiusPreset.medium:
        return l10n.mapRadiusMedium;
      case MapRadiusPreset.large:
        return l10n.mapRadiusLarge;
    }
  }

  String _distanceLabelFor(MapRadiusPreset preset) {
    if (preset.radiusMeters >= 1000) {
      final kilometers = preset.radiusMeters / 1000;
      final label = kilometers % 1 == 0
          ? kilometers.toStringAsFixed(0)
          : kilometers.toStringAsFixed(1);
      return '$label km';
    }
    return '${preset.radiusMeters}m';
  }
}

class _RadiusPresetButton extends StatelessWidget {
  const _RadiusPresetButton({
    required this.colors,
    required this.preset,
    required this.label,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final AppColors colors;
  final MapRadiusPreset preset;
  final String label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? onColor(colors.primary)
        : isEnabled
            ? colors.text
            : colors.mutedText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('map-radius-${preset.name}'),
        onTap: onTap,
        borderRadius:
            MapSurfaceTokens.borderRadius(MapSurfaceTokens.innerRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(
            minWidth: 68,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary
                : colors.card.withValues(alpha: isEnabled ? 0.0 : 0.22),
            borderRadius:
                MapSurfaceTokens.borderRadius(MapSurfaceTokens.innerRadius),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.border.withValues(alpha: 0.0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.24),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RadiusPresetBadge(
                color: foreground,
                isSelected: isSelected,
                diameter: _glyphDiameterFor(preset),
              ),
              const SizedBox(width: 7),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _glyphDiameterFor(MapRadiusPreset preset) {
    switch (preset) {
      case MapRadiusPreset.small:
        return 6;
      case MapRadiusPreset.medium:
        return 8;
      case MapRadiusPreset.large:
        return 10;
    }
  }
}

class _RadiusPresetBadge extends StatelessWidget {
  const _RadiusPresetBadge({
    required this.color,
    required this.isSelected,
    required this.diameter,
  });

  final Color color;
  final bool isSelected;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.16)
            : color.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: isSelected ? 0.26 : 0.18),
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.92)),
        ),
      ),
    );
  }
}

class _RadiusRefreshIndicator extends StatelessWidget {
  const _RadiusRefreshIndicator({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.commonRefreshing,
      child: Semantics(
        liveRegion: true,
        label: context.l10n.commonRefreshing,
        child: Container(
          key: const Key('map-radius-refresh-indicator'),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: colors.primarySoft.withValues(alpha: 0.88),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(5),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
      ),
    );
  }
}
