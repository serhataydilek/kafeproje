import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/error_codes.dart';
import '../../l10n/l10n.dart';
import '../../models/async_result.dart' as async_result;
import '../../models/index.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/localized_error.dart';
import '../ui/app_modal.dart';
import '../ui/state_views.dart';
import 'cafe_review_form.dart';

class CafeReviewsSection extends ConsumerWidget {
  const CafeReviewsSection({
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
    final reviewsState = ref.watch(paginatedCafeReviewsProvider(cafeId));
    final controller = ref.read(paginatedCafeReviewsProvider(cafeId).notifier);
    final currentUserReview = ref.watch(currentUserCafeReviewProvider(cafeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stackVertically = constraints.maxWidth < 420;
            final actionButton = TextButton.icon(
              key: ValueKey('cafe-reviews-open-form-$cafeId'),
              onPressed: () {
                if (currentUser == null) {
                  context.push('/auth?from=/cafe/$cafeId');
                  return;
                }
                _showReviewForm(context, ref, currentUserReview);
              },
              icon: Icon(
                currentUser == null ? Icons.login : Icons.edit,
                size: 16,
                color: colors.primary,
              ),
              label: Text(
                currentUser == null
                    ? l10n.reviewsSignInAction
                    : (currentUserReview == null
                        ? l10n.reviewsWriteAction
                        : l10n.reviewsEditAction),
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );

            if (stackVertically) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.reviewsSectionTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  actionButton,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n.reviewsSectionTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                actionButton,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        switch (reviewsState.status) {
          async_result.AsyncLoading<List<CafeReview>>()
              when reviewsState.reviews.isEmpty =>
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
          async_result.AsyncError<List<CafeReview>>(code: final code)
              when reviewsState.reviews.isEmpty =>
            ErrorStateView(
              colors: colors,
              message: localizeError(code, l10n),
              onRetry: controller.refresh,
            ),
          _ => _ReviewList(
              cafeId: cafeId,
              colors: colors,
              reviewsState: reviewsState,
              currentUser: currentUser,
              onDelete: (reviewId) => _deleteReview(
                context,
                ref,
                reviewId,
                currentUser,
              ),
              onLoadMore: controller.loadMore,
            ),
        },
      ],
    );
  }

  void _showReviewForm(
    BuildContext context,
    WidgetRef ref,
    CafeReview? initialReview,
  ) {
    unawaited(showAppModalBottomSheet(
      context: context,
      useRootNavigator: true,
      maxWidth: 720,
      builder: (_) => CafeReviewFormModal(
        cafeId: cafeId,
        initialReview: initialReview,
      ),
    ).whenComplete(() {
      ref
          .read(reviewSubmissionControllerProvider(cafeId).notifier)
          .resetState();
      AppLogger.debug(
        '[CAFE_DIAG_REVIEW_MODAL] cafeId=$cafeId action=closed',
        key: 'cafe-diag-review-modal-close-$cafeId',
      );
    }));
  }

  Future<void> _deleteReview(
    BuildContext context,
    WidgetRef ref,
    String reviewId,
    CurrentUser? currentUser,
  ) async {
    final l10n = context.l10n;
    final confirm = await showAppConfirmationDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        title: Text(l10n.reviewsDeleteTitle),
        content: Text(l10n.reviewsDeleteMessage),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.reviewsDeleteCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              foregroundColor: colors.danger,
              backgroundColor: colors.danger.withValues(alpha: 0.14),
            ),
            child: Text(l10n.reviewsDeleteConfirm),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reviewsAuthRequired)),
      );
      return;
    }

    final result = await ref
        .read(reviewDeletionControllerProvider(cafeId).notifier)
        .deleteReview(
          reviewId: reviewId,
          userId: currentUser.id,
          isAdmin: currentUser.isAdmin,
        );
    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    if (!result.ok) {
      AppLogger.warn(
        'CafeReviewsSection delete failed for reviewId=$reviewId message=${result.message ?? 'n/a'}',
        key: 'review-delete-ui-$reviewId',
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            localizeServiceMessage(result, l10n,
                fallback: l10n.reviewsDeleteError),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.reviewsDeleteSuccess)),
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.cafeId,
    required this.colors,
    required this.reviewsState,
    required this.currentUser,
    required this.onDelete,
    required this.onLoadMore,
  });

  final String cafeId;
  final AppColors colors;
  final PaginatedCafeReviewsState reviewsState;
  final CurrentUser? currentUser;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(String reviewId) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reviews = reviewsState.reviews;

    if (reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          l10n.reviewsEmptyState,
          style: TextStyle(
            color: colors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final itemCount = reviews.length + (reviewsState.hasMore ? 1 : 0);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= reviews.length) {
          return _LoadMoreSection(
            colors: colors,
            isLoadingMore: reviewsState.isLoadingMore,
            loadMoreErrorCode: reviewsState.loadMoreErrorCode,
            onLoadMore: onLoadMore,
          );
        }

        final review = reviews[index];
        return _ReviewCard(
          review: review,
          colors: colors,
          isOwner:
              currentUser?.id == review.userId || currentUser?.isAdmin == true,
          onDelete: () => onDelete(review.id),
        );
      },
    );
  }
}

class _LoadMoreSection extends StatefulWidget {
  const _LoadMoreSection({
    required this.colors,
    required this.isLoadingMore,
    required this.loadMoreErrorCode,
    required this.onLoadMore,
  });

  final AppColors colors;
  final bool isLoadingMore;
  final AppErrorCode? loadMoreErrorCode;
  final Future<void> Function() onLoadMore;

  @override
  State<_LoadMoreSection> createState() => _LoadMoreSectionState();
}

class _LoadMoreSectionState extends State<_LoadMoreSection> {
  bool _didTriggerAutoLoad = false;

  @override
  void didUpdateWidget(covariant _LoadMoreSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoadingMore && !widget.isLoadingMore) {
      _didTriggerAutoLoad = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoadingMore &&
        widget.loadMoreErrorCode == null &&
        !_didTriggerAutoLoad) {
      _didTriggerAutoLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onLoadMore();
        }
      });
    }

    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: widget.colors.border),
      ),
      child: Column(
        children: [
          if (widget.isLoadingMore)
            CircularProgressIndicator(color: widget.colors.primary)
          else
            FilledButton.tonalIcon(
              onPressed: widget.onLoadMore,
              icon: const Icon(Icons.expand_more),
              label: Text(l10n.commonLoadMore),
            ),
          if (widget.loadMoreErrorCode != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizeError(widget.loadMoreErrorCode!, l10n),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.colors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.colors,
    required this.isOwner,
    required this.onDelete,
  });

  final CafeReview review;
  final AppColors colors;
  final bool isOwner;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: colors.chip,
                backgroundImage: review.avatarUrl != null
                    ? NetworkImage(review.avatarUrl!)
                    : null,
                child: review.avatarUrl == null
                    ? Icon(Icons.person, size: 16, color: colors.mutedText)
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  review.username ?? 'Unknown Explorer',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: index < review.rating
                        ? colors.primary
                        : colors.mutedText,
                    size: 16,
                  ),
                ),
              ),
              if (isOwner) ...[
                const SizedBox(width: AppSpacing.xs),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: colors.danger,
                  ),
                ),
              ],
            ],
          ),
          if (review.content != null && review.content!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.content!,
              style: TextStyle(
                color: colors.text,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (_hasExtraDetails(review)) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (review.wifiQuality != null)
                  _buildDetailChip(
                    Icons.wifi,
                    'Wi-Fi: ${review.wifiQuality}/5',
                    colors,
                  ),
                if (review.noiseLevel != null)
                  _buildDetailChip(
                    Icons.volume_up,
                    '${context.l10n.metricQuietness}: ${review.noiseLevel}/5',
                    colors,
                  ),
                if (review.studyFriendliness != null)
                  _buildDetailChip(
                    Icons.book,
                    '${context.l10n.metricStudyFriendly}: ${review.studyFriendliness}/5',
                    colors,
                  ),
                if (review.seatingComfort != null)
                  _buildDetailChip(
                    Icons.chair,
                    '${context.l10n.metricSeating}: ${review.seatingComfort}/5',
                    colors,
                  ),
                if (review.socketAvailability != null &&
                    review.socketAvailability != 'Unknown')
                  _buildDetailChip(
                    Icons.electrical_services,
                    '${context.l10n.metricOutlet}: ${_translateSocket(context, review.socketAvailability!)}',
                    colors,
                  ),
                if (review.smokingPolicy != null &&
                    review.smokingPolicy != 'unknown')
                  _buildDetailChip(
                    Icons.smoking_rooms,
                    '${context.l10n.metricSmoking}: ${_translateSmoking(context, review.smokingPolicy!)}',
                    colors,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            _formatDate(review.createdAt),
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  bool _hasExtraDetails(CafeReview review) {
    return review.wifiQuality != null ||
        review.noiseLevel != null ||
        review.studyFriendliness != null ||
        review.seatingComfort != null ||
        (review.socketAvailability != null &&
            review.socketAvailability != 'Unknown') ||
        (review.smokingPolicy != null && review.smokingPolicy != 'unknown');
  }

  String _translateSocket(BuildContext context, String value) {
    if (value == 'Yes') {
      return context.l10n.compareYes;
    }
    if (value == 'No') {
      return context.l10n.compareNo;
    }
    return context.l10n.commonUnknown;
  }

  String _translateSmoking(BuildContext context, String value) {
    if (value == 'mixed') {
      value = 'outdoor_only';
    }

    return switch (value) {
      'allowed' => context.l10n.smokingAllowed,
      'outdoor_only' => context.l10n.smokingOutdoorOnly,
      'not_allowed' => context.l10n.smokingNotAllowed,
      _ => context.l10n.commonUnknown,
    };
  }

  Widget _buildDetailChip(IconData icon, String label, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.mutedText),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
