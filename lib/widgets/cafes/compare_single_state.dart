import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../models/index.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import 'cafe_image_carousel.dart';

class CompareSingleState extends ConsumerWidget {
  const CompareSingleState({
    super.key,
    required this.cafe,
    required this.colors,
  });

  final Cafe cafe;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final stackButtons = width < 520;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.compare_arrows_rounded, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.compareEmptyMessage,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: CafeImageCarousel(
                    key: ValueKey('compare-single-gallery-${cafe.id}'),
                    imageUrls: cafe.photoUrls,
                    height: 140,
                    colors: colors,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    cacheWidth: 420,
                    cacheHeight: 240,
                    requestWidth: 480,
                    compact: true,
                    traceTag: 'compare-single:${cafe.id}',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cafe.name,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            cafeLocationSummary(l10n, cafe),
                            style: TextStyle(
                              color: colors.mutedText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey('compare-remove-${cafe.id}'),
                      tooltip:
                          MaterialLocalizations.of(context).deleteButtonTooltip,
                      onPressed: () => ref
                          .read(profileProvider.notifier)
                          .toggleCompare(cafe.id),
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (cafe.rating > 0)
                      _CompareCompactTag(
                        colors: colors,
                        icon: Icons.star_rounded,
                        label: cafeRatingLabel(l10n, cafe),
                      ),
                    _CompareCompactTag(
                      colors: colors,
                      icon: Icons.attach_money,
                      label: cafePriceLabel(l10n, cafe),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (stackButtons)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('compare-add-cafe-button'),
                          onPressed: () => context.push('/explore'),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.compareAddCafeAction),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/cafe/${cafe.id}'),
                          icon: const Icon(Icons.storefront_outlined),
                          label: Text(l10n.compareOpenCafeAction),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('compare-add-cafe-button'),
                          onPressed: () => context.push('/explore'),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.compareAddCafeAction),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/cafe/${cafe.id}'),
                          icon: const Icon(Icons.storefront_outlined),
                          label: Text(l10n.compareOpenCafeAction),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _CompareCompactTag(
                      colors: colors,
                      icon: Icons.wifi,
                      label: cafeWifiDisplayLabel(l10n, cafe),
                    ),
                    _CompareCompactTag(
                      colors: colors,
                      icon: Icons.power_outlined,
                      label: cafeOutletDisplayLabel(l10n, cafe),
                    ),
                    _CompareCompactTag(
                      colors: colors,
                      icon: Icons.volume_up_outlined,
                      label: cafeQuietnessDisplayLabel(l10n, cafe),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareCompactTag extends StatelessWidget {
  const _CompareCompactTag({
    required this.colors,
    required this.icon,
    required this.label,
  });

  final AppColors colors;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.text),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: colors.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
