import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';
import '../../utils/compare_formatters.dart';
import 'cafe_image_carousel.dart';

class CompareMatrix extends StatelessWidget {
  const CompareMatrix({
    super.key,
    required this.cafes,
    required this.colors,
    required this.metrics,
    required this.highlightedMetrics,
    required this.onRemove,
  });

  final List<Cafe> cafes;
  final AppColors colors;
  final List<CompareMetric> metrics;
  final Map<String, String> highlightedMetrics;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final table = Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: {
            0: const FlexColumnWidth(2),
            for (var index = 0; index < cafes.length; index++)
              index + 1: const FlexColumnWidth(3),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: colors.primarySoft),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    context.l10n.compareFeature,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final cafe in cafes)
                  _CompareMatrixHeaderCell(
                    key: ValueKey('matrix-header-${cafe.id}'),
                    cafe: cafe,
                    colors: colors,
                    onRemove: () => onRemove(cafe.id),
                  ),
              ],
            ),
            for (var index = 0; index < metrics.length; index++)
              TableRow(
                decoration: BoxDecoration(
                  color: index.isOdd
                      ? colors.chip.withValues(alpha: 0.42)
                      : colors.card,
                ),
                children: [
                  _CompareMatrixLabelCell(
                    metric: metrics[index],
                    colors: colors,
                    dense: isMobile || cafes.length >= 3,
                  ),
                  for (final cafe in cafes)
                    _CompareMatrixValueCell(
                      key: ValueKey(
                        'matrix-${metrics[index].key}-${cafe.id}',
                      ),
                      value: metrics[index].valueBuilder(cafe),
                      colors: colors,
                      highlighted:
                          highlightedMetrics[metrics[index].key] == cafe.id,
                    ),
                ],
              ),
          ],
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
            ),
            child: DecoratedBox(
              key: const Key('compare-grid'),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: table,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompareMatrixHeaderCell extends StatelessWidget {
  const _CompareMatrixHeaderCell({
    super.key,
    required this.cafe,
    required this.colors,
    required this.onRemove,
  });

  final Cafe cafe;
  final AppColors colors;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/cafe/${cafe.id}'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: CafeImageCarousel(
                key: ValueKey('compare-header-gallery-${cafe.id}'),
                imageUrls: cafe.photoUrls,
                height: 68,
                colors: colors,
                borderRadius: BorderRadius.circular(AppRadius.md),
                cacheWidth: 180,
                cacheHeight: 120,
                requestWidth: 220,
                compact: true,
                traceTag: 'compare:${cafe.id}',
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('compare-remove-${cafe.id}'),
                  onPressed: onRemove,
                  tooltip:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
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
            const SizedBox(height: AppSpacing.xs),
            if (cafe.rating > 0)
              Text(
                cafeRatingLabel(context.l10n, cafe),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompareMatrixLabelCell extends StatelessWidget {
  const _CompareMatrixLabelCell({
    required this.metric,
    required this.colors,
    required this.dense,
  });

  final CompareMetric metric;
  final AppColors colors;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? AppSpacing.xs + 2 : AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, size: 15, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              metric.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareMatrixValueCell extends StatelessWidget {
  const _CompareMatrixValueCell({
    super.key,
    required this.value,
    required this.colors,
    required this.highlighted,
  });

  final String value;
  final AppColors colors;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color:
              highlighted ? colors.accent.withValues(alpha: 0.12) : colors.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: highlighted
                ? colors.accent.withValues(alpha: 0.3)
                : colors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: highlighted ? colors.accent : colors.text,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
