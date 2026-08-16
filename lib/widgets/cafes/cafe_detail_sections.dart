import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/index.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/cafe_hours.dart';
import '../../utils/cafe_map_focus.dart';
import '../../utils/cafe_tag_utils.dart';
import '../../utils/text_normalization.dart';
import '../ui/app_modal.dart';
import 'cafe_primary_actions.dart';
import 'cafe_review_form.dart';

class CafeDetailOverviewSection extends StatelessWidget {
  const CafeDetailOverviewSection({
    super.key,
    required this.cafe,
    required this.colors,
    required this.languageCode,
  });

  final Cafe cafe;
  final AppColors colors;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('cafe-detail-overview-${cafe.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CafeDetailHeaderSection(
          cafe: cafe,
          colors: colors,
          languageCode: languageCode,
        ),
        const SizedBox(height: 12),
        CafeDetailRatingSection(
          cafe: cafe,
          colors: colors,
        ),
        const SizedBox(height: AppSpacing.xs),
        CafeDetailInfoSection(
          cafe: cafe,
          colors: colors,
        ),
      ],
    );
  }
}

class CafeDetailHeaderSection extends StatelessWidget {
  const CafeDetailHeaderSection({
    super.key,
    required this.cafe,
    required this.colors,
    required this.languageCode,
  });

  final Cafe cafe;
  final AppColors colors;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final openStatus = resolveCafeOpenStatus(cafe);
    final isOpen = openStatus == CafeOpenStatus.open;
    final isUnknown = openStatus == CafeOpenStatus.unknown;
    final sponsoredLabel = (cafe.featuredLabel?.trim().isNotEmpty ?? false)
        ? cafe.featuredLabel!.trim()
        : l10n.homeSponsoredBadge;
    final statusColor =
        isUnknown ? colors.primary : (isOpen ? colors.accent : colors.danger);
    final statusLabel = switch (openStatus) {
      CafeOpenStatus.open => l10n.commonOpen,
      CafeOpenStatus.closed => l10n.commonClosed,
      CafeOpenStatus.unknown => l10n.commonUnknown,
    };

    return Row(
      key: ValueKey('cafe-detail-header-${cafe.id}'),
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cafe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                  height: 1.15,
                ),
              ),
              if (cafe.isActiveFeatured) ...[
                const SizedBox(height: 6),
                Container(
                  key: ValueKey('cafe-detail-sponsored-badge-${cafe.id}'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: colors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sponsoredLabel,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            turkishAwareUppercase(
              statusLabel,
              languageCode,
            ),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class CafeDetailRatingSection extends ConsumerWidget {
  const CafeDetailRatingSection({
    super.key,
    required this.cafe,
    required this.colors,
  });

  final Cafe cafe;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reviewSummary = ref.watch(cafeReviewSummaryProvider(cafe.id));
    final hasPrimaryRating = reviewSummary.rating > 0;
    final hasGoogleRating = (cafe.googleRating ?? 0) > 0;
    final hasGoogleReviewCount = (cafe.googleReviewCount ?? 0) > 0;
    final externalUpdatedLabel = hasGoogleRating || hasGoogleReviewCount
        ? _externalMetadataFreshnessLabel(
            l10n,
            cafe.googlePlaceData?.lastSyncedAt,
          )
        : null;
    final hasSecondaryMetadata = hasGoogleRating || hasGoogleReviewCount;

    return Column(
      key: ValueKey('cafe-detail-rating-${cafe.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: ValueKey('cafe-detail-primary-rating-${cafe.id}'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.compareCommunityRating,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasPrimaryRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: hasPrimaryRating
                              ? colors.primary
                              : colors.mutedText,
                          size: 22,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasPrimaryRating
                              ? reviewSummary.rating.toStringAsFixed(1)
                              : l10n.cafeNoRatingsYet,
                          style: TextStyle(
                            fontSize: hasPrimaryRating ? 20 : 14,
                            fontWeight: FontWeight.w800,
                            color: hasPrimaryRating
                                ? colors.text
                                : colors.mutedText,
                          ),
                        ),
                      ],
                    ),
                    if (reviewSummary.reviewCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.reviewsSectionTitle}: ${reviewSummary.reviewCount}',
                        key: ValueKey(
                            'cafe-detail-primary-review-count-${cafe.id}'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                key: ValueKey('cafe-detail-favorite-count-${cafe.id}'),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_rounded,
                        color: colors.primary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      cafe.favoriteCount.toString(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasSecondaryMetadata) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            key: ValueKey('cafe-detail-external-rating-${cafe.id}'),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.primarySoft.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.compareGoogleRating,
                  key: ValueKey('cafe-detail-external-source-${cafe.id}'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.mutedText,
                  ),
                ),
                if (hasGoogleRating) ...[
                  const SizedBox(height: 4),
                  Row(
                    key: ValueKey(
                        'cafe-detail-external-rating-value-${cafe.id}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: colors.primary,
                        size: 17,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cafe.googleRating!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ),
                ],
                if (hasGoogleReviewCount) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.compareGoogleReviews}: ${cafe.googleReviewCount}',
                    key: ValueKey(
                        'cafe-detail-external-review-count-${cafe.id}'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.mutedText,
                    ),
                  ),
                ],
                if (externalUpdatedLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    externalUpdatedLabel,
                    key: ValueKey('cafe-detail-external-updated-${cafe.id}'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String? _externalMetadataFreshnessLabel(
  AppLocalizations l10n,
  String? rawTimestamp,
) {
  final raw = rawTimestamp?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return null;
  }

  final age = DateTime.now().toUtc().difference(parsed.toUtc());
  if (age.isNegative) {
    return null;
  }

  if (age.inMinutes < 1) {
    return l10n.metadataJustNow;
  }
  if (age.inHours < 1) {
    return l10n.metadataMinutesAgo(age.inMinutes);
  }
  if (age.inDays < 1) {
    return l10n.metadataHoursAgo(age.inHours);
  }
  if (age.inDays < 7) {
    return l10n.metadataDaysAgo(age.inDays);
  }

  final utc = parsed.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}

class CafeDetailInfoSection extends StatelessWidget {
  const CafeDetailInfoSection({
    super.key,
    required this.cafe,
    required this.colors,
  });

  final Cafe cafe;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      key: ValueKey('cafe-detail-info-${cafe.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cafeLocationSummary(l10n, cafe),
          style: TextStyle(
            color: colors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          cafeCategoryLabel(l10n, cafe),
          style: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (cafeAddressLabel(l10n, cafe) != l10n.commonUnknown) ...[
          Text(
            cafeAddressLabel(l10n, cafe),
            style: TextStyle(
              color: colors.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          cafe.description.isNotEmpty
              ? cafe.description
              : l10n.cafeDetailDescriptionFallback,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        if (cafe.tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: normalizeDisplayTags(cafe.tags)
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.chip,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class CafeDetailMetadataSection extends StatelessWidget {
  const CafeDetailMetadataSection({
    super.key,
    required this.cafe,
    required this.colors,
  });

  final Cafe cafe;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      key: ValueKey('cafe-detail-metadata-${cafe.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cafeDetailDetails,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.text,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CafeDetailContributionCard(
          cafeId: cafe.id,
          colors: colors,
        ),
        const SizedBox(height: AppSpacing.sm),
        CafeDetailMetricsSection(
          cafe: cafe,
          colors: colors,
        ),
        const SizedBox(height: AppSpacing.md),
        CafeDetailHoursSection(cafe: cafe, colors: colors),
        const SizedBox(height: AppSpacing.md),
        CafeDetailMenuHighlightsSection(
          cafe: cafe,
          colors: colors,
        ),
      ],
    );
  }
}

class CafeDetailContributionCard extends ConsumerWidget {
  const CafeDetailContributionCard({
    super.key,
    required this.cafeId,
    required this.colors,
  });

  final String cafeId;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currentUser = ref.watch(currentUserProvider);
    final currentUserReview = ref.watch(currentUserCafeReviewProvider(cafeId));

    return Semantics(
      button: true,
      label: currentUserReview == null
          ? l10n.reviewsWriteAction
          : l10n.reviewsEditAction,
      child: InkWell(
        onTap: () {
          if (currentUser == null) {
            context.push('/auth?from=/cafe/$cafeId');
            return;
          }
          unawaited(showAppModalBottomSheet(
            context: context,
            useRootNavigator: true,
            maxWidth: 720,
            builder: (_) => CafeReviewFormModal(
              cafeId: cafeId,
              initialReview: currentUserReview,
            ),
          ).whenComplete(() {
            ref
                .read(reviewSubmissionControllerProvider(cafeId).notifier)
                .resetState();
          }));
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          key: ValueKey('cafe-detail-contribution-$cafeId'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cafeDetailContributionTitle,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.cafeDetailContributionSubtitle,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CafeDetailHoursSection extends StatelessWidget {
  const CafeDetailHoursSection({
    super.key,
    required this.cafe,
    required this.colors,
  });

  final Cafe cafe;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final openStatus = resolveCafeOpenStatus(cafe);
    final isOpen = openStatus == CafeOpenStatus.open;
    final isUnknown = openStatus == CafeOpenStatus.unknown;
    final statusColor =
        isUnknown ? colors.primary : (isOpen ? colors.accent : colors.danger);
    final statusLabel = switch (openStatus) {
      CafeOpenStatus.open => l10n.commonOpen,
      CafeOpenStatus.closed => l10n.commonClosed,
      CafeOpenStatus.unknown => l10n.commonUnknown,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cafeDetailHours,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.text,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          key: ValueKey('cafe-detail-hours-status-${cafe.id}'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: statusColor.withValues(alpha: 0.28)),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!cafe.hasWorkingHours)
          Text(
            l10n.cafeDetailHoursEmpty,
            style: TextStyle(
              color: colors.mutedText,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          ...compactWorkingHoursLabel(l10n, cafe.openingHours).map(
            (line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line,
                style: TextStyle(
                  color: colors.mutedText,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CafeDetailMenuHighlightsSection extends StatelessWidget {
  const CafeDetailMenuHighlightsSection({
    super.key,
    required this.cafe,
    required this.colors,
  });

  final Cafe cafe;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    if (cafe.menuHighlights.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cafeDetailMenuHighlights,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.text,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: cafe.menuHighlights
              .map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.chip,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class CafeDetailActionsSection extends ConsumerWidget {
  const CafeDetailActionsSection({
    super.key,
    required this.cafe,
    required this.colors,
  });

  final Cafe cafe;
  final AppColors colors;

  Future<void> _openCompare(BuildContext context, WidgetRef ref) async {
    final normalizedCafeId = cafe.id.trim();
    if (normalizedCafeId.isEmpty) {
      return;
    }
    final isAlreadySelected = ref.read(normalizedCompareListProvider).contains(
          normalizedCafeId,
        );
    if (!isAlreadySelected) {
      await ref.read(profileProvider.notifier).toggleCompare(normalizedCafeId);
    }
    if (context.mounted) {
      unawaited(context.push('/compare'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isFavorite = ref.watch(isCafeFavoritedProvider(cafe.id));
    final isFavoritePending =
        ref.watch(isFavoriteMutationPendingProvider(cafe.id));
    final hasFavoriteError =
        ref.watch(hasFavoriteMutationErrorProvider(cafe.id));
    final inCompare = ref.watch(isCafeInCompareListProvider(cafe.id));

    return Container(
      key: ValueKey('cafe-detail-actions-${cafe.id}'),
      child: CafePrimaryActions(
        colors: colors,
        isFavorite: isFavorite,
        isFavoritePending: isFavoritePending,
        hasFavoriteError: hasFavoriteError,
        inCompare: inCompare,
        favoriteLabel: isFavoritePending
            ? l10n.commonLoading
            : hasFavoriteError
                ? l10n.commonRetry
                : isFavorite
                    ? l10n.cafeDetailSaved
                    : l10n.cafeDetailSave,
        compareLabel:
            inCompare ? l10n.cafeDetailCompared : l10n.cafeDetailCompare,
        leadingAction: CafePrimaryLeadingAction(
          label: l10n.cafeDetailOpenOnMap,
          subtitle: cafeLocationSummary(l10n, cafe),
          icon: Icons.map_outlined,
          onTap: () => showCafeOnMap(context, ref, cafe.id),
        ),
        onFavorite: () =>
            ref.read(profileProvider.notifier).toggleFavorite(cafe.id),
        onCompare: () => unawaited(_openCompare(context, ref)),
      ),
    );
  }
}

class CafeDetailMetricsSection extends ConsumerWidget {
  const CafeDetailMetricsSection({
    super.key,
    required this.cafe,
    required this.colors,
  });

  final Cafe cafe;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reviews = ref.watch(
      paginatedCafeReviewsProvider(cafe.id).select((state) => state.reviews),
    );

    String formatAverageScore(Iterable<int?> rawScores) {
      final scores = rawScores.whereType<int>().toList(growable: false);
      if (scores.isEmpty) {
        return l10n.commonUnknown;
      }
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      return '${avg.toStringAsFixed(1)}/5';
    }

    String resolveWifi() {
      final scores = reviews.map((e) => e.wifiQuality).whereType<int>();
      return scores.isEmpty
          ? cafeWifiDisplayLabel(l10n, cafe)
          : formatAverageScore(scores);
    }

    String resolveNoise() {
      final scores = reviews.map((e) => e.noiseLevel).whereType<int>();
      return scores.isEmpty
          ? cafeQuietnessDisplayLabel(l10n, cafe)
          : formatAverageScore(scores);
    }

    String resolveStudy() {
      final scores = reviews.map((e) => e.studyFriendliness);
      final hasScores = scores.any((score) => score != null);
      return hasScores
          ? formatAverageScore(reviews.map((e) => e.studyFriendliness))
          : cafeStudyFriendlyDisplayLabel(l10n, cafe);
    }

    String resolveSeating() {
      final scores = reviews.map((e) => e.seatingComfort);
      final hasScores = scores.any((score) => score != null);
      if (!hasScores) {
        final label = cafeSeatingComfortLabel(l10n, cafe);
        return '$label${label == l10n.commonUnknown ? '' : '/5'}';
      }
      return formatAverageScore(reviews.map((e) => e.seatingComfort));
    }

    String resolveOutlets() {
      final sockets = reviews
          .map((e) => e.socketAvailability)
          .whereType<String>()
          .where((value) => value != 'Unknown');
      if (sockets.isEmpty) {
        return cafeOutletDisplayLabel(l10n, cafe);
      }
      final yesCount = sockets.where((value) => value == 'Yes').length;
      final ratio = yesCount / sockets.length;
      if (ratio >= 0.7) {
        return l10n.outletHigh;
      }
      if (ratio >= 0.3) {
        return l10n.outletMedium;
      }
      return l10n.outletLow;
    }

    final ambianceLabel = cafeAmbianceLabel(l10n, cafe);
    final items = [
      _MetricItem(l10n.metricWifi, resolveWifi(), Icons.wifi),
      _MetricItem(l10n.metricOutlet, resolveOutlets(), Icons.power),
      _MetricItem(l10n.metricQuietness, resolveNoise(), Icons.volume_down),
      _MetricItem(
          l10n.metricPrice, cafePriceLabel(l10n, cafe), Icons.attach_money),
      _MetricItem(l10n.metricSeating, resolveSeating(), Icons.chair),
      _MetricItem(
        l10n.metricAmbiance,
        '$ambianceLabel${ambianceLabel == l10n.commonUnknown ? '' : '/5'}',
        Icons.auto_awesome,
      ),
      _MetricItem(l10n.metricStudyFriendly, resolveStudy(), Icons.laptop),
      if (cafe.petFriendly)
        _MetricItem(l10n.metricPetFriendly, l10n.metricFriendly, Icons.pets),
      if (cafe.outdoorSeating)
        _MetricItem(l10n.metricOutdoor, l10n.metricAvailable, Icons.deck),
      _MetricItem(
        l10n.metricSmoking,
        cafeSmokingDisplayLabel(l10n, cafe),
        Icons.smoking_rooms,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final crossAxisCount = maxWidth >= 720
            ? 4
            : maxWidth >= 500
                ? 3
                : 2;
        final itemWidth = (maxWidth - (AppSpacing.sm * (crossAxisCount - 1))) /
            crossAxisCount;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(item.icon, size: 20, color: colors.primary),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: colors.mutedText,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.value,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _MetricItem {
  _MetricItem(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}
