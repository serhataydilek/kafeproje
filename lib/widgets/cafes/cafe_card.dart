import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/index.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/cafe_hours.dart';
import '../../utils/cafe_tag_utils.dart';
import '../../utils/cafe_media.dart';
import '../../utils/log_sanitizer.dart';
import '../../utils/text_normalization.dart';
import 'cafe_image_carousel.dart';

class CafeCard extends StatelessWidget {
  const CafeCard({
    super.key,
    required this.cafe,
    required this.isFavorite,
    this.isFavoritePending = false,
    this.hasFavoriteError = false,
    required this.inCompare,
    required this.onPress,
    required this.onFavoritePress,
    required this.onComparePress,
    required this.colors,
    this.surface = 'cafe-card',
    this.sponsoredLabel,
  });
  final Cafe cafe;
  final bool isFavorite;
  final bool isFavoritePending;
  final bool hasFavoriteError;
  final bool inCompare;
  final VoidCallback onPress;
  final VoidCallback onFavoritePress;
  final VoidCallback onComparePress;
  final AppColors colors;
  final String surface;
  final String? sponsoredLabel;

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
    final languageCode = Localizations.localeOf(context).languageCode;
    final trimmedSponsoredLabel = sponsoredLabel?.trim();
    final showSponsoredTreatment = cafe.isFeatured &&
        trimmedSponsoredLabel != null &&
        trimmedSponsoredLabel.isNotEmpty;
    final normalizedImageUrls = normalizeCafeImageUrls(cafe.photoUrls);
    _logImageSourceDiagnostics(
      cafe: cafe,
      surface: surface,
      selectedUrls: normalizedImageUrls,
    );
    _logHomeSponsoredImageDiagnostics(
      cafe: cafe,
      surface: surface,
      normalizedUrls: normalizedImageUrls,
      height: 160,
    );
    final displayRating =
        cafe.appRating ?? cafe.adminFallbackRating ?? cafe.googleRating;
    final ratingPresentation = displayRating == null
        ? null
        : _CafeCardRatingPresentation(
            label: displayRating.toStringAsFixed(1),
            source: cafe.appRating != null
                ? 'app'
                : cafe.adminFallbackRating != null
                    ? 'admin'
                    : 'google',
          );
    if (showSponsoredTreatment) {
      AppLogger.debug(
        '[SPONSORED_RATING_UI] cafeId=${_shortCafeId(cafe.id)} visible=${ratingPresentation != null} source=${ratingPresentation?.source ?? 'hidden'}',
        key: 'sponsored-rating-ui-${cafe.id}',
        throttle: Duration.zero,
      );
    }
    final featuredSummary =
        showSponsoredTreatment ? _featuredSummaryText(cafe) : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const sponsoredGold = Color(0xFFC6A15B);
    final sponsoredFrameColor = Color.alphaBlend(
      sponsoredGold.withValues(alpha: isDark ? 0.52 : 0.66),
      colors.primary,
    );
    final sponsoredSurface = Color.alphaBlend(
      sponsoredGold.withValues(alpha: isDark ? 0.08 : 0.045),
      colors.card,
    );
    final cardBorderColor = showSponsoredTreatment
        ? sponsoredFrameColor.withValues(alpha: isDark ? 0.9 : 0.82)
        : colors.border;
    final cardBorderWidth = showSponsoredTreatment ? 2.4 : 1.0;

    return Semantics(
      button: true,
      label: l10n.cafeCardSemanticLabel(cafe.name),
      child: GestureDetector(
        key: ValueKey('cafe-card-${cafe.id}'),
        onTap: onPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: showSponsoredTreatment ? sponsoredSurface : colors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: cardBorderColor,
              width: cardBorderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: showSponsoredTreatment
                      ? (isDark ? 0.18 : 0.08)
                      : (isDark ? 0.16 : 0.05),
                ),
                offset: const Offset(0, 4),
                blurRadius: showSponsoredTreatment ? 16 : 10,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CafeImageCarousel(
                      key: ValueKey('cafe-card-gallery-$surface-${cafe.id}'),
                      colors: colors,
                      imageUrls: cafe.photoUrls,
                      traceTag: '$surface:${cafe.id}',
                      diagnosticCafeId: cafe.id,
                      diagnosticCafeName: cafe.name,
                      height: 160,
                      borderRadius: BorderRadius.zero,
                      cacheWidth: 640,
                      cacheHeight: 360,
                      requestWidth: 720,
                      compact: false,
                    ),
                    if (showSponsoredTreatment)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: _SponsoredBadge(
                          key: ValueKey(
                            'cafe-card-sponsored-badge-${cafe.id}',
                          ),
                          label: trimmedSponsoredLabel,
                          colors: colors,
                          accentColor: sponsoredFrameColor,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cafe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cafeLocationSummary(l10n, cafe),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (ratingPresentation != null) ...[
                          Icon(
                            Icons.star_rounded,
                            color: colors.primary,
                            size: AppIconSize.sm,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            ratingPresentation.label,
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Container(
                          constraints: const BoxConstraints(maxWidth: 96),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? colors.accent.withValues(alpha: 0.15)
                                : statusColor.withValues(alpha: 0.15),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (featuredSummary != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        featuredSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (normalizeDisplayTags(cafe.tags).isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children:
                            normalizeDisplayTags(cafe.tags).take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.chip,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              tag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            key: ValueKey('cafe-card-compare-${cafe.id}'),
                            label: inCompare
                                ? l10n.cafeCardCompared
                                : l10n.cafeCardCompare,
                            icon: Icons.compare_arrows,
                            isActive: inCompare,
                            activeColor: colors.accent,
                            colors: colors,
                            onTap: onComparePress,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ActionButton(
                            key: ValueKey('cafe-card-favorite-${cafe.id}'),
                            label: isFavoritePending
                                ? l10n.commonLoading
                                : hasFavoriteError
                                    ? l10n.commonRetry
                                    : isFavorite
                                        ? l10n.cafeCardSaved
                                        : l10n.cafeCardSave,
                            icon: hasFavoriteError
                                ? Icons.error_outline_rounded
                                : isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                            isActive: isFavorite,
                            isPending: isFavoritePending,
                            hasError: hasFavoriteError,
                            activeColor: colors.primary,
                            colors: colors,
                            onTap: onFavoritePress,
                          ),
                        ),
                      ],
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

String? _featuredSummaryText(Cafe cafe) {
  String? clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  return clean(cafe.description) ??
      clean(cafe.googlePlaceData?.formattedAddress) ??
      clean(cafe.address) ??
      clean(cafe.district) ??
      _firstCleanTag(cafe.tags, clean);
}

String? _firstCleanTag(
  Iterable<String> tags,
  String? Function(String? value) clean,
) {
  for (final tag in tags) {
    final cleaned = clean(tag);
    if (cleaned != null) {
      return cleaned;
    }
  }
  return null;
}

class _CafeCardRatingPresentation {
  const _CafeCardRatingPresentation({
    required this.label,
    required this.source,
  });

  final String label;
  final String source;
}

String _shortCafeId(String cafeId) {
  final normalized = cafeId.trim();
  if (normalized.length <= 12) {
    return normalized;
  }
  return normalized.substring(0, 12);
}

void _logHomeSponsoredImageDiagnostics({
  required Cafe cafe,
  required String surface,
  required List<String> normalizedUrls,
  required double height,
}) {
  if (!kDebugMode || !kVerboseCafeDiagnostics || surface != 'home-sponsored') {
    return;
  }
  final hasResolved = normalizedUrls.isNotEmpty;
  final firstUrl = hasResolved
      ? summarizeUrlForLog(normalizedUrls.first, presenceLabel: 'firstUrl')
      : 'firstUrl=false';
  final branch = hasResolved ? 'carousel' : 'placeholder';
  AppLogger.debug(
    '[CAFE_DIAG_PHOTO_UI] surface=home_sponsored_card cafeId=${cafe.id} cafeName="${cafe.name}" images=${cafe.images.length} photoUrls=${cafe.photoUrls.length} resolvedFirstImagePresent=$hasResolved branch=$branch height=$height $firstUrl',
    key: 'cafe-diag-photo-ui-home-sponsored-${cafe.id}',
    throttle: Duration.zero,
  );
}

void _logImageSourceDiagnostics({
  required Cafe cafe,
  required String surface,
  required List<String> selectedUrls,
}) {
  if (!kDebugMode || !kVerboseCafeDiagnostics) {
    return;
  }
  final selected = selectedUrls.isEmpty ? null : selectedUrls.first;
  final isFeaturedSurface = surface == 'home-sponsored' || cafe.isFeatured;
  final tag = isFeaturedSurface
      ? 'FEATURED_IMAGE_SOURCE_DIAG'
      : 'NORMAL_IMAGE_SOURCE_DIAG';
  AppLogger.debug(
    '[$tag] cafeId=${cafe.id} cafeName="${cafe.name}" surface=$surface selectedField=resolvedDisplayUrls ${cafeImageSourceDiagnosticsForLog(selected)} fromCache=false fromSupabase=${cafe.usesAppManagedFields}',
    key: 'image-source-diag-$surface-${cafe.id}',
    throttle: Duration.zero,
  );
}

class CafeCardListItem extends ConsumerWidget {
  const CafeCardListItem({
    super.key,
    required this.cafe,
    required this.onPress,
    required this.colors,
    this.surface = 'list',
    this.sponsoredLabel,
  });

  final Cafe cafe;
  final VoidCallback onPress;
  final AppColors colors;
  final String surface;
  final String? sponsoredLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isCafeFavoritedProvider(cafe.id));
    final isFavoritePending =
        ref.watch(isFavoriteMutationPendingProvider(cafe.id));
    final hasFavoriteError =
        ref.watch(hasFavoriteMutationErrorProvider(cafe.id));
    final inCompare = ref.watch(isCafeInCompareListProvider(cafe.id));

    return CafeCard(
      key: ValueKey('cafe-card-item-${cafe.id}'),
      cafe: cafe,
      isFavorite: isFavorite,
      isFavoritePending: isFavoritePending,
      hasFavoriteError: hasFavoriteError,
      inCompare: inCompare,
      onPress: onPress,
      onFavoritePress: () =>
          ref.read(profileProvider.notifier).toggleFavorite(cafe.id),
      onComparePress: () =>
          ref.read(profileProvider.notifier).toggleCompare(cafe.id),
      colors: colors,
      surface: surface,
      sponsoredLabel: sponsoredLabel,
    );
  }
}

class _SponsoredBadge extends StatelessWidget {
  const _SponsoredBadge({
    super.key,
    required this.label,
    required this.colors,
    required this.accentColor,
  });

  final String label;
  final AppColors colors;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: accentColor.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 14,
            color: accentColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    this.isPending = false,
    this.hasError = false,
    required this.activeColor,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final bool isPending;
  final bool hasError;
  final Color activeColor;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = hasError
        ? colors.danger
        : isActive
            ? colors.card
            : colors.text;
    final background = hasError
        ? colors.danger.withValues(alpha: 0.1)
        : isActive
            ? activeColor
            : Colors.transparent;
    final borderColor = hasError
        ? colors.danger
        : isActive
            ? activeColor
            : colors.border;

    return GestureDetector(
      onTap: isPending
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap();
            },
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPending)
              SizedBox(
                key: const Key('favorite-action-pending-indicator'),
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(icon, size: AppIconSize.sm, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
