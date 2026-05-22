import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/index.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../layout/adaptive_layout.dart';
import 'map_cafe_preview_card.dart';
import 'map_radius_selector.dart';
import 'map_surface.dart';

class _MapOverlayTokens {
  const _MapOverlayTokens._();
  static const double railGap = 6;
  static const double roundActionSize = 38;
  static const double roundActionIconSize = 16;
}

class MapBottomOverlay extends StatelessWidget {
  const MapBottomOverlay({
    super.key,
    required this.colors,
    required this.filtersActiveCount,
    required this.compareCount,
    required this.selectedCafe,
    required this.radiusPreset,
    required this.isRadiusEnabled,
    required this.isRadiusRefreshing,
    required this.onLocate,
    required this.onSelectRadiusPreset,
    required this.onOpenFilters,
    required this.onOpenCompare,
    required this.onOpenDetails,
    required this.onCloseSelectedCafe,
  });

  final AppColors colors;
  final int filtersActiveCount;
  final int compareCount;
  final Cafe? selectedCafe;
  final MapRadiusPreset radiusPreset;
  final bool isRadiusEnabled;
  final bool isRadiusRefreshing;
  final VoidCallback onLocate;
  final ValueChanged<MapRadiusPreset> onSelectRadiusPreset;
  final VoidCallback onOpenFilters;
  final VoidCallback? onOpenCompare;
  final VoidCallback? onOpenDetails;
  final VoidCallback onCloseSelectedCafe;

  @override
  Widget build(BuildContext context) {
    final layout =
        AdaptiveLayoutData.fromWidth(MediaQuery.sizeOf(context).width);
    final controlsTopOffset = layout.horizontalPadding;
    final edgeInset = layout.horizontalPadding;
    final previewMaxWidth = layout.isTablet ? 640.0 : 560.0;

    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: offsetAnimation,
                  child: child,
                ),
              );
            },
            child: selectedCafe == null
                ? const SizedBox.shrink(key: Key('map-selected-sheet-empty'))
                : Padding(
                    key:
                        ValueKey('map-selected-sheet-host-${selectedCafe!.id}'),
                    padding: EdgeInsets.only(
                      left: edgeInset - 2,
                      right: edgeInset - 2,
                      bottom: layout.sectionSpacing / 2 + 6,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: previewMaxWidth,
                      ),
                      child: MapCafePreviewCard(
                        key: ValueKey(
                          'map-selected-sheet-${selectedCafe!.id}',
                        ),
                        colors: colors,
                        cafe: selectedCafe!,
                        onTap: onOpenDetails!,
                        onClose: onCloseSelectedCafe,
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          top: controlsTopOffset,
          right: edgeInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (onOpenCompare != null) ...[
                _MapCompareButton(
                  colors: colors,
                  compareCount: compareCount,
                  onPressed: onOpenCompare!,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              _MapActionRail(
                colors: colors,
                filtersActiveCount: filtersActiveCount,
                radiusPreset: radiusPreset,
                isRadiusEnabled: isRadiusEnabled,
                isRadiusRefreshing: isRadiusRefreshing,
                onLocate: onLocate,
                onSelectRadiusPreset: onSelectRadiusPreset,
                onOpenFilters: onOpenFilters,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapCompareButton extends StatelessWidget {
  const _MapCompareButton({
    required this.colors,
    required this.compareCount,
    required this.onPressed,
  });

  final AppColors colors;
  final int compareCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isActive = compareCount > 0;
    final label =
        isActive ? l10n.compareSelectedCount(compareCount) : l10n.compareTitle;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          key: const Key('map-compare-fab'),
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isActive
                    ? colors.primary
                    : colors.card.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isActive ? colors.primary : colors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: MapSurfaceTokens.shadowBlur,
                    offset: MapSurfaceTokens.shadowOffset,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.compare_arrows_rounded,
                        color: isActive ? colors.bg : colors.primary,
                        size: 18,
                      ),
                      if (compareCount > 0)
                        Positioned(
                          right: -7,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colors.bg,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color:
                                    isActive ? colors.primary : colors.border,
                              ),
                            ),
                            child: Text(
                              compareCount > 9 ? '9+' : '$compareCount',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
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
    );
  }
}

class _MapActionRail extends StatelessWidget {
  const _MapActionRail({
    required this.colors,
    required this.filtersActiveCount,
    required this.radiusPreset,
    required this.isRadiusEnabled,
    required this.isRadiusRefreshing,
    required this.onLocate,
    required this.onSelectRadiusPreset,
    required this.onOpenFilters,
  });

  final AppColors colors;
  final int filtersActiveCount;
  final MapRadiusPreset radiusPreset;
  final bool isRadiusEnabled;
  final bool isRadiusRefreshing;
  final VoidCallback onLocate;
  final ValueChanged<MapRadiusPreset> onSelectRadiusPreset;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('map-action-rail'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _RadiusPresetSelector(
          colors: colors,
          selectedPreset: radiusPreset,
          isEnabled: isRadiusEnabled,
          isRefreshing: isRadiusRefreshing,
          onSelected: onSelectRadiusPreset,
        ),
        const SizedBox(height: _MapOverlayTokens.railGap),
        _MapRoundActionButton(
          key: const Key('map-location-fab'),
          colors: colors,
          icon: Icons.my_location,
          tooltip: context.l10n.mapLocateMe,
          onTap: onLocate,
        ),
        const SizedBox(height: _MapOverlayTokens.railGap),
        _MapRoundActionButton(
          key: const Key('map-filter-fab'),
          colors: colors,
          icon: Icons.tune,
          tooltip: context.l10n.filterTitle,
          onTap: onOpenFilters,
          child: Badge(
            isLabelVisible: filtersActiveCount > 0,
            label: Text('$filtersActiveCount'),
            child: Icon(
              Icons.tune,
              color: colors.primary,
              size: 19,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapRoundActionButton extends StatelessWidget {
  const _MapRoundActionButton({
    super.key,
    required this.colors,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.child,
  });

  final AppColors colors;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Ink(
              width: _MapOverlayTokens.roundActionSize,
              height: _MapOverlayTokens.roundActionSize,
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.96),
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: child ??
                    Icon(
                      icon,
                      color: colors.text,
                      size: _MapOverlayTokens.roundActionIconSize,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadiusPresetSelector extends StatelessWidget {
  const _RadiusPresetSelector({
    required this.colors,
    required this.selectedPreset,
    required this.isEnabled,
    required this.isRefreshing,
    required this.onSelected,
  });

  final AppColors colors;
  final MapRadiusPreset selectedPreset;
  final bool isEnabled;
  final bool isRefreshing;
  final ValueChanged<MapRadiusPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return MapRadiusSelector(
      colors: colors,
      selectedPreset: selectedPreset,
      isEnabled: isEnabled,
      isRefreshing: isRefreshing,
      onSelected: onSelected,
    );
  }
}
