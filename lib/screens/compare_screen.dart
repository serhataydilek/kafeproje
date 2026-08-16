import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../models/index.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/cafe_hours.dart';
import '../utils/compare_formatters.dart';
import '../widgets/cafes/cafe_image_carousel.dart';
import '../widgets/cafes/compare_single_state.dart';
import '../widgets/layout/adaptive_layout.dart';
import '../widgets/ui/state_views.dart';

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compareIds = ref.watch(normalizedCompareListProvider);
    final compareCafes = ref.watch(comparedCafesProvider);
    final resolvedAsync = ref.watch(resolvedComparedCafesProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final l10n = context.l10n;

    final isResolving = compareIds.isNotEmpty &&
        compareCafes.isEmpty &&
        resolvedAsync.isLoading;

    final slots = _buildCompareSlots(compareIds, compareCafes);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/');
          },
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
        ),
        titleSpacing: 0,
        title: Text(
          l10n.compareTitle,
          key: const Key('compare-screen-title'),
          style: TextStyle(
            color: colors.text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: AdaptivePage(
          maxWidth: AdaptiveLayoutData.fromWidth(
            MediaQuery.sizeOf(context).width,
          ).compareContentMaxWidth(),
          child: isResolving
              ? LoadingStateView(colors: colors, label: l10n.commonLoading)
              : compareIds.isEmpty
                  ? _CompareEmptyState(colors: colors)
                  : compareIds.length == 1 && compareCafes.length == 1
                      ? CompareSingleState(
                          cafe: compareCafes.first,
                          colors: colors,
                        )
                      : _CompareBoard(
                          slots: slots,
                          colors: colors,
                          currentLocation: currentLocation,
                        ),
        ),
      ),
    );
  }
}

class _CompareEmptyState extends StatelessWidget {
  const _CompareEmptyState({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = _buildEmptyFeatureItems(l10n);

    return ListView(
      key: const Key('compare-empty-state'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Text(
          l10n.compareEmptyMessage,
          style: TextStyle(
            color: colors.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('compare-empty-add-cafes-button'),
            onPressed: () => context.push('/explore'),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.compareEmptyAddCafes),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('compare-empty-explore-cafes-button'),
            onPressed: () => context.go('/explore'),
            icon: const Icon(Icons.travel_explore_rounded),
            label: Text(l10n.compareEmptyExploreCafes),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DecoratedBox(
          key: const Key('compare-empty-feature-explanations'),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _CompareEmptyFeatureRow(
                    item: items[index],
                    colors: colors,
                  ),
                  if (index != items.length - 1)
                    Divider(height: 16, color: colors.border),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareEmptyFeatureRow extends StatelessWidget {
  const _CompareEmptyFeatureRow({
    required this.item,
    required this.colors,
  });

  final _CompareEmptyFeatureItem item;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('compare-empty-feature-${item.key}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Icon(item.icon, size: 18, color: colors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.description,
                style: TextStyle(
                  color: colors.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompareBoard extends ConsumerWidget {
  const _CompareBoard({
    required this.slots,
    required this.colors,
    required this.currentLocation,
  });

  final List<_CompareSlot> slots;
  final AppColors colors;
  final Coordinates? currentLocation;

  static const double _slotCardHeight = 244;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rows = _buildRowSpecs(
      l10n,
      currentLocation: currentLocation,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < slots.length; index++) ...[
              Expanded(
                child: SizedBox(
                  key: Key('compare-slot-$index'),
                  height: _slotCardHeight,
                  child: _CompareTopCard(
                    slot: slots[index],
                    colors: colors,
                    onRemove: (id) =>
                        ref.read(profileProvider.notifier).toggleCompare(id),
                  ),
                ),
              ),
              if (index != slots.length - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        DecoratedBox(
          key: const Key('compare-grid'),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: _CompareMatrixTable(
              rows: rows,
              slots: slots,
              colors: colors,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareMatrixTable extends StatelessWidget {
  const _CompareMatrixTable({
    required this.rows,
    required this.slots,
    required this.colors,
  });

  final List<_CompareRowSpec> rows;
  final List<_CompareSlot> slots;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(44),
      for (var i = 0; i < slots.length; i++) i + 1: const FlexColumnWidth(1),
    };

    return SingleChildScrollView(
      key: const Key('compare-table-scroll'),
      scrollDirection: Axis.vertical,
      child: Table(
        columnWidths: columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: TableBorder(
          horizontalInside:
              BorderSide(color: colors.border.withValues(alpha: 0.75)),
          verticalInside:
              BorderSide(color: colors.border.withValues(alpha: 0.75)),
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: colors.chip.withValues(alpha: 0.58),
            ),
            children: [
              _tableHeaderCell(
                key: const Key('compare-table-header-attribute'),
                tooltip: l10n.compareFeature,
                icon: Icons.tune_rounded,
                iconOnly: true,
              ),
              for (var i = 0; i < slots.length; i++)
                _tableHeaderCell(
                  key: Key('compare-table-header-slot-$i'),
                  tooltip: _slotHeaderLabel(slots[i], l10n),
                  icon: _slotHeaderIcon(slots[i]),
                ),
            ],
          ),
          for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
            TableRow(
              decoration: BoxDecoration(
                color: rowIndex.isOdd
                    ? colors.bg.withValues(alpha: 0.38)
                    : colors.card.withValues(alpha: 0.92),
              ),
              children: [
                _tableAttributeCell(
                  key: Key('compare-table-attribute-$rowIndex'),
                  label: rows[rowIndex].label,
                  icon: rows[rowIndex].icon,
                ),
                for (var slotIndex = 0; slotIndex < slots.length; slotIndex++)
                  _tableValueCell(
                    key: Key('compare-table-cell-$rowIndex-$slotIndex'),
                    value: rows[rowIndex].valueForSlot(slots[slotIndex], l10n),
                    muted: slots[slotIndex].cafe == null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tableHeaderCell({
    required Key key,
    required String tooltip,
    required IconData icon,
    bool iconOnly = false,
  }) {
    return SizedBox(
      key: key,
      height: 44,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Tooltip(
          message: tooltip,
          child: Semantics(
            label: tooltip,
            child: iconOnly
                ? Center(
                    child: Icon(icon, size: 18, color: colors.primary),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(icon, size: 14, color: colors.primary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          tooltip,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _tableAttributeCell({
    required Key key,
    required String label,
    required IconData icon,
  }) {
    return Tooltip(
      key: key,
      message: label,
      child: Semantics(
        label: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Center(
            child: Icon(
              icon,
              key: ValueKey('compare-table-attribute-icon-$label'),
              color: colors.primary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableValueCell({
    required Key key,
    required String value,
    required bool muted,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        value,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        textWidthBasis: TextWidthBasis.parent,
        style: TextStyle(
          color: muted ? colors.mutedText : colors.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.28,
        ),
      ),
    );
  }

  String _slotHeaderLabel(_CompareSlot slot, AppLocalizations l10n) {
    final cafe = slot.cafe;
    if (cafe != null) {
      return cafe.name;
    }
    if (slot.isUnresolved) {
      return l10n.compareUnresolvedSlot;
    }
    return l10n.compareAddAnotherPrompt;
  }

  IconData _slotHeaderIcon(_CompareSlot slot) {
    if (slot.cafe != null) {
      return Icons.storefront_rounded;
    }
    if (slot.isUnresolved) {
      return Icons.warning_amber_rounded;
    }
    return Icons.add_rounded;
  }
}

class _CompareTopCard extends StatelessWidget {
  const _CompareTopCard({
    required this.slot,
    required this.colors,
    required this.onRemove,
  });

  final _CompareSlot slot;
  final AppColors colors;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (slot.isEmpty) {
      return _CompareSlotPlaceholder(
        colors: colors,
        icon: Icons.add_rounded,
        title: l10n.compareAddAnotherPrompt,
        message: l10n.compareAddCafeAction,
        onTap: () => context.go('/explore'),
      );
    }

    if (slot.isUnresolved) {
      return _CompareSlotPlaceholder(
        colors: colors,
        icon: Icons.warning_amber_rounded,
        title: l10n.compareUnresolvedSlot,
        message: l10n.compareUnresolvedMessage,
        selectedId: slot.selectedId,
        onRemove: () => onRemove(slot.selectedId!),
      );
    }

    final cafe = slot.cafe!;
    return SizedBox.expand(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push('/cafe/${cafe.id}'),
          child: Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    topRight: Radius.circular(AppRadius.lg),
                  ),
                  child: Stack(
                    children: [
                      CafeImageCarousel(
                        key: ValueKey('compare-header-gallery-${cafe.id}'),
                        imageUrls: cafe.photoUrls,
                        height: 132,
                        colors: colors,
                        borderRadius: BorderRadius.zero,
                        cacheWidth: 320,
                        cacheHeight: 220,
                        requestWidth: 420,
                        compact: true,
                        traceTag: 'compare:${cafe.id}',
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.06),
                                Colors.black.withValues(alpha: 0.56),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: IconButton(
                            key: ValueKey('compare-remove-${cafe.id}'),
                            tooltip: MaterialLocalizations.of(context)
                                .deleteButtonTooltip,
                            onPressed: () => onRemove(cafe.id),
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            constraints: const BoxConstraints.tightFor(
                                width: 34, height: 34),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.sm,
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: Text(
                          cafe.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _communityRatingLabel(l10n, cafe),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${l10n.compareGoogleRating}: ${_googleRatingLabel(l10n, cafe)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareSlotPlaceholder extends StatelessWidget {
  const _CompareSlotPlaceholder({
    required this.colors,
    required this.icon,
    required this.title,
    required this.message,
    this.selectedId,
    this.onTap,
    this.onRemove,
  });

  final AppColors colors;
  final IconData icon;
  final String title;
  final String message;
  final String? selectedId;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final isAddSlot = onTap != null && selectedId == null && onRemove == null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          key: onTap != null ? const Key('compare-add-cafe-button') : null,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isAddSlot
                  ? colors.primary.withValues(alpha: 0.52)
                  : colors.border,
              width: isAddSlot ? 1.6 : 1,
            ),
          ),
          child: isAddSlot
              ? _buildAddSlotContent()
              : _buildStatusSlotContent(context),
        ),
      ),
    );
  }

  Widget _buildAddSlotContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.42),
                  width: 1.4,
                ),
              ),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Icon(icon, color: colors.primary, size: 42),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSlotContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selectedId != null && onRemove != null)
                IconButton(
                  key: ValueKey('compare-remove-$selectedId'),
                  tooltip:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.mutedText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareRowSpec {
  const _CompareRowSpec({
    required this.label,
    required this.icon,
    required this.valueForSlot,
  });

  final String label;
  final IconData icon;
  final String Function(_CompareSlot slot, AppLocalizations l10n) valueForSlot;
}

class _CompareEmptyFeatureItem {
  const _CompareEmptyFeatureItem({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String key;
  final String label;
  final String description;
  final IconData icon;
}

List<_CompareEmptyFeatureItem> _buildEmptyFeatureItems(AppLocalizations l10n) {
  return <_CompareEmptyFeatureItem>[
    _CompareEmptyFeatureItem(
      key: 'community-rating',
      label: l10n.compareCommunityRating,
      description: l10n.compareEmptyFeatureCommunityRating,
      icon: Icons.star_rounded,
    ),
    _CompareEmptyFeatureItem(
      key: 'price',
      label: l10n.comparePrice,
      description: l10n.compareEmptyFeaturePrice,
      icon: Icons.attach_money_rounded,
    ),
    _CompareEmptyFeatureItem(
      key: 'district',
      label: l10n.compareAddressDistrict,
      description: l10n.compareEmptyFeatureDistrict,
      icon: Icons.location_on_outlined,
    ),
    _CompareEmptyFeatureItem(
      key: 'wifi',
      label: l10n.compareWifi,
      description: l10n.compareEmptyFeatureWifi,
      icon: Icons.wifi_rounded,
    ),
    _CompareEmptyFeatureItem(
      key: 'ambiance',
      label: l10n.compareAmbiance,
      description: l10n.compareEmptyFeatureAmbiance,
      icon: Icons.chair_rounded,
    ),
    _CompareEmptyFeatureItem(
      key: 'outlets',
      label: l10n.compareOutlet,
      description: l10n.compareEmptyFeatureOutlet,
      icon: Icons.power_rounded,
    ),
  ];
}

List<_CompareRowSpec> _buildRowSpecs(
  AppLocalizations l10n, {
  required Coordinates? currentLocation,
}) {
  return <_CompareRowSpec>[
    _CompareRowSpec(
      label: l10n.compareCommunityRating,
      icon: Icons.star_rounded,
      valueForSlot: (slot, l10n) {
        final cafe = slot.cafe;
        if (cafe == null) {
          return _slotFallbackLabel(slot, l10n);
        }
        return _communityRatingLabel(l10n, cafe);
      },
    ),
    _CompareRowSpec(
      label: l10n.compareGoogleRating,
      icon: Icons.travel_explore_rounded,
      valueForSlot: (slot, l10n) {
        final cafe = slot.cafe;
        if (cafe == null) {
          return _slotFallbackLabel(slot, l10n);
        }
        return _googleRatingLabel(l10n, cafe);
      },
    ),
    _CompareRowSpec(
      label: l10n.compareGoogleReviews,
      icon: Icons.reviews_outlined,
      valueForSlot: (slot, l10n) {
        final cafe = slot.cafe;
        if (cafe == null) {
          return _slotFallbackLabel(slot, l10n);
        }
        final reviewCount = cafe.googleReviewCount;
        if (reviewCount == null || reviewCount <= 0) {
          return l10n.compareUnavailable;
        }
        return reviewCount.toString();
      },
    ),
    _CompareRowSpec(
      label: l10n.comparePrice,
      icon: Icons.attach_money_rounded,
      valueForSlot: (slot, l10n) {
        final cafe = slot.cafe;
        if (cafe == null) {
          return _slotFallbackLabel(slot, l10n);
        }
        return cafePriceLabel(l10n, cafe);
      },
    ),
    _CompareRowSpec(
      label: l10n.compareOpeningStatus,
      icon: Icons.schedule_rounded,
      valueForSlot: (slot, l10n) {
        final cafe = slot.cafe;
        if (cafe == null) {
          return _slotFallbackLabel(slot, l10n);
        }
        final status = resolveCafeOpenStatus(cafe);
        final statusText = switch (status) {
          CafeOpenStatus.open => l10n.commonOpen,
          CafeOpenStatus.closed => l10n.commonClosed,
          CafeOpenStatus.unknown => l10n.commonUnknown,
        };
        final hoursText = cafe.hasWorkingHours
            ? summarizeWorkingHoursLabel(l10n, cafe.openingHours)
            : l10n.compareHoursUnavailable;
        return '$statusText / $hoursText';
      },
    ),
    _CompareRowSpec(
      label: l10n.compareDistance,
      icon: Icons.near_me_outlined,
      valueForSlot: (slot, l10n) {
        final cafe = slot.cafe;
        if (cafe == null) {
          return _slotFallbackLabel(slot, l10n);
        }
        return cafeDistanceLabel(l10n, cafe, currentLocation);
      },
    ),
    _CompareRowSpec(
      label: l10n.compareAddressDistrict,
      icon: Icons.location_on_outlined,
      valueForSlot: (slot, l10n) {
        final cafe = slot.cafe;
        if (cafe == null) {
          return _slotFallbackLabel(slot, l10n);
        }
        final address = cafeAddressLabel(l10n, cafe);
        final district =
            cafe.district.trim().isEmpty ? l10n.commonUnknown : cafe.district;
        if (address == l10n.commonUnknown || address.trim().isEmpty) {
          return district;
        }
        if (district == l10n.commonUnknown) {
          return address;
        }
        return '$district • $address';
      },
    ),
    _CompareRowSpec(
      label: l10n.compareFeatures,
      icon: Icons.tune_rounded,
      valueForSlot: (slot, l10n) {
        final cafe = slot.cafe;
        if (cafe == null) {
          return _slotFallbackLabel(slot, l10n);
        }
        return cafeFeatureSummaryLabel(l10n, cafe);
      },
    ),
  ];
}

String _slotFallbackLabel(_CompareSlot slot, AppLocalizations l10n) {
  if (slot.isUnresolved) {
    return l10n.compareUnresolvedSlot;
  }
  return l10n.commonUnknown;
}

String _communityRatingLabel(AppLocalizations l10n, Cafe cafe) {
  final rating = cafe.appRating;
  final reviewCount = cafe.appReviewCount;
  if (rating == null || rating <= 0) {
    return l10n.compareNoAppReviewsYet;
  }
  if (reviewCount == null || reviewCount <= 0) {
    return rating.toStringAsFixed(1);
  }
  return '${rating.toStringAsFixed(1)} ($reviewCount)';
}

String _googleRatingLabel(AppLocalizations l10n, Cafe cafe) {
  final rating = cafe.googleRating;
  final reviewCount = cafe.googleReviewCount;
  if (rating == null || rating <= 0) {
    return l10n.compareGoogleRatingUnavailable;
  }
  if (reviewCount == null || reviewCount <= 0) {
    return rating.toStringAsFixed(1);
  }
  return '${rating.toStringAsFixed(1)} ($reviewCount)';
}

List<_CompareSlot> _buildCompareSlots(List<String> ids, List<Cafe> cafes) {
  final slots = <_CompareSlot>[];
  final usedCafeIds = <String>{};

  for (final id in ids.take(ProfileNotifier.maxCompareCafes)) {
    Cafe? matched;
    for (final cafe in cafes) {
      if (usedCafeIds.contains(cafe.id)) {
        continue;
      }
      if (cafe.id == id || cafe.placeId == id) {
        matched = cafe;
        break;
      }
    }
    if (matched != null) {
      usedCafeIds.add(matched.id);
    }
    slots.add(_CompareSlot(selectedId: id, cafe: matched));
  }

  while (slots.length < ProfileNotifier.maxCompareCafes) {
    slots.add(const _CompareSlot());
  }

  return List<_CompareSlot>.unmodifiable(slots);
}

class _CompareSlot {
  const _CompareSlot({this.selectedId, this.cafe});

  final String? selectedId;
  final Cafe? cafe;

  bool get isEmpty => selectedId == null && cafe == null;
  bool get isUnresolved => selectedId != null && cafe == null;
}
