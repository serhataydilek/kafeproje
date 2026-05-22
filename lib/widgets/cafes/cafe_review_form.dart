import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/async_result.dart';
import '../../models/review.dart';
import '../../models/service_result.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/localized_error.dart';
import '../../utils/service_error.dart';
import '../ui/app_action_button.dart';
import '../ui/list_tiles.dart';
import '../layout/adaptive_layout.dart';

class CafeReviewFormModal extends ConsumerStatefulWidget {
  const CafeReviewFormModal({
    super.key,
    required this.cafeId,
    this.initialReview,
  });

  final String cafeId;
  final CafeReview? initialReview;

  @override
  ConsumerState<CafeReviewFormModal> createState() =>
      _CafeReviewFormModalState();
}

class _CafeReviewFormModalState extends ConsumerState<CafeReviewFormModal> {
  late int _rating;
  late int _wifiQuality;
  late int _noiseLevel;
  late int _studyFriendliness;
  late int _seatingComfort;
  late String? _socketAvailability;
  late String? _smokingPolicy;
  late final TextEditingController _contentCtrl;
  bool _isClosing = false;

  bool get _isEditing => widget.initialReview != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReview;
    _rating = initial?.rating ?? 0;
    _wifiQuality = initial?.wifiQuality ?? 0;
    _noiseLevel = initial?.noiseLevel ?? 0;
    _studyFriendliness = initial?.studyFriendliness ?? 0;
    _seatingComfort = initial?.seatingComfort ?? 0;
    _socketAvailability = initial?.socketAvailability;
    _smokingPolicy = initial?.smokingPolicy;
    _contentCtrl = TextEditingController(text: initial?.content ?? '');
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  void _handleModalDismiss() {
    if (mounted && !_isClosing) {
      setState(() {
        _isClosing = true;
      });
    }
    FocusManager.instance.primaryFocus?.unfocus();
    ref
        .read(reviewSubmissionControllerProvider(widget.cafeId).notifier)
        .resetState();
  }

  void _closeModal() {
    if (_isClosing) {
      return;
    }
    _handleModalDismiss();
    final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNavigator != null && rootNavigator.canPop()) {
      rootNavigator.pop();
      return;
    }
    Navigator.maybeOf(context)?.maybePop();
  }

  Future<void> _submit() async {
    final submissionState = ref.read(
      reviewSubmissionControllerProvider(widget.cafeId),
    );
    if (submissionState.isLoading) return;

    final l10n = context.l10n;
    final currentUser = ref.read(currentUserProvider);
    final controller = ref.read(
      reviewSubmissionControllerProvider(widget.cafeId).notifier,
    );

    if (_rating == 0) {
      _showSnackBar(
        l10n.reviewsRatingRequired,
        isError: true,
      );
      return;
    }

    if (currentUser == null) {
      _showSnackBar(
        l10n.reviewsAuthRequired,
        isError: true,
      );
      return;
    }

    final result = await controller.submitReview(
      userId: currentUser.id,
      rating: _rating,
      wifiQuality: _wifiQuality > 0 ? _wifiQuality : null,
      noiseLevel: _noiseLevel > 0 ? _noiseLevel : null,
      studyFriendliness: _studyFriendliness > 0 ? _studyFriendliness : null,
      seatingComfort: _seatingComfort > 0 ? _seatingComfort : null,
      socketAvailability: _socketAvailability,
      smokingPolicy: _smokingPolicy,
      content: _contentCtrl.text,
    );

    if (!mounted) {
      return;
    }

    if (result.ok) {
      AppLogger.debug(
        '[CAFE_DIAG_REVIEW_MODAL] cafeId=${widget.cafeId} action=submit-success',
        key: 'cafe-diag-review-modal-submit-${widget.cafeId}',
      );
      _showSnackBar(
        result.queuedOffline
            ? l10n.reviewsQueuedSuccess
            : ((result.data?.didUpdateExisting ?? false)
                ? l10n.reviewsUpdateSuccess
                : l10n.reviewsSubmitSuccess),
      );
      _closeModal();
      return;
    }

    _showSnackBar(
      _resolveErrorMessage(result, l10n),
      isError: true,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  String _resolveErrorMessage(
    ServiceResult<dynamic> result,
    AppLocalizations l10n,
  ) {
    if (result.errorCode != null) {
      return localizeError(result.errorCode!, l10n);
    }

    final rawError = result.error?.toString().toLowerCase() ?? '';
    switch (result.errorType) {
      case ServiceErrorType.auth:
        return l10n.reviewsAuthRequired;
      case ServiceErrorType.cancelled:
        return l10n.authGenericError;
      case ServiceErrorType.unavailable:
        return l10n.reviewsUnavailable;
      case ServiceErrorType.rateLimit:
        return l10n.reviewsRefreshWarning;
      case ServiceErrorType.validation:
        if (rawError.contains('smoking_policy')) {
          return l10n.reviewsValidationError;
        }
        return l10n.reviewsValidationError;
      case ServiceErrorType.conflict:
        return l10n.reviewsConflictError;
      case ServiceErrorType.network:
      case ServiceErrorType.timeout:
        return l10n.reviewsRefreshWarning;
      case ServiceErrorType.notFound:
      case ServiceErrorType.parse:
      case ServiceErrorType.unknown:
        return localizeServiceMessage(result, l10n,
            fallback: l10n.authGenericError);
    }
  }

  Widget _buildStarRow({
    required String title,
    required int currentValue,
    required ValueChanged<int> onChanged,
    required AppColors colors,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            final isActive = starValue <= currentValue;
            return GestureDetector(
              onTap: enabled ? () => onChanged(starValue) : null,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(
                  isActive ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 32,
                  color: isActive ? colors.primary : colors.border,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildChipRow({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onChanged,
    required AppColors colors,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options.map((option) {
            final isSelected = selected == option;
            var label = option;
            if (option == 'allowed') {
              label = context.l10n.smokingAllowed;
            }
            if (option == 'outdoor_only') {
              label = context.l10n.smokingOutdoorOnly;
            }
            if (option == 'not_allowed') {
              label = context.l10n.smokingNotAllowed;
            }
            if (option == 'Yes') {
              label = context.l10n.compareYes;
            }
            if (option == 'No') {
              label = context.l10n.compareNo;
            }
            if (option == 'Unknown' || option == 'unknown') {
              label = context.l10n.commonUnknown;
            }

            return GestureDetector(
              onTap: enabled ? () => onChanged(option) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.card,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? colors.bg : colors.text,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final submissionState = ref.watch(
      reviewSubmissionControllerProvider(widget.cafeId),
    );
    final isSubmitting = submissionState.isLoading;
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final l10n = context.l10n;
    final title =
        _isEditing ? l10n.reviewsFormUpdateTitle : l10n.reviewsFormTitle;
    final submitLabel = isSubmitting
        ? (_isEditing ? l10n.reviewsFormUpdating : l10n.reviewsFormSubmitting)
        : (_isEditing ? l10n.reviewsFormUpdate : l10n.reviewsFormSubmit);

    if (_isClosing) {
      return const SizedBox.shrink();
    }

    return PopScope(
      canPop: !isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          return;
        }
        AppLogger.debug(
          '[CAFE_DIAG_REVIEW_MODAL] cafeId=${widget.cafeId} action=pop-dismiss',
          key: 'cafe-diag-review-modal-pop-${widget.cafeId}',
        );
        _handleModalDismiss();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AdaptiveLayoutData.fromWidth(constraints.maxWidth);
          final horizontalPadding =
              layout.isTablet ? AppSpacing.lg : AppSpacing.md;

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.sm,
                horizontalPadding,
                0,
              ),
              child: Column(
                key: ValueKey('review-form-sheet-${widget.cafeId}'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: AppSectionTitle(colors: colors, title: title)),
                      if (!isSubmitting)
                        IconButton(
                          icon: Icon(Icons.close, color: colors.mutedText),
                          onPressed: _closeModal,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.reviewsFormCommentHelper,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          EdgeInsets.only(bottom: bottomInset + AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                final starValue = index + 1;
                                final isActive = starValue <= _rating;
                                return GestureDetector(
                                  onTap: isSubmitting
                                      ? null
                                      : () =>
                                          setState(() => _rating = starValue),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs,
                                    ),
                                    child: Icon(
                                      isActive
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 40,
                                      color: isActive
                                          ? colors.primary
                                          : colors.border,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.reviewsFormRatingHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _buildStarRow(
                            title: l10n.metricWifi,
                            currentValue: _wifiQuality,
                            onChanged: (value) =>
                                setState(() => _wifiQuality = value),
                            colors: colors,
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildStarRow(
                            title: l10n.metricQuietness,
                            currentValue: _noiseLevel,
                            onChanged: (value) =>
                                setState(() => _noiseLevel = value),
                            colors: colors,
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildStarRow(
                            title: l10n.metricStudyFriendly,
                            currentValue: _studyFriendliness,
                            onChanged: (value) =>
                                setState(() => _studyFriendliness = value),
                            colors: colors,
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildStarRow(
                            title: l10n.metricSeating,
                            currentValue: _seatingComfort,
                            onChanged: (value) =>
                                setState(() => _seatingComfort = value),
                            colors: colors,
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildChipRow(
                            title: l10n.metricOutlet,
                            options: const ['Yes', 'No', 'Unknown'],
                            selected: _socketAvailability,
                            onChanged: (value) =>
                                setState(() => _socketAvailability = value),
                            colors: colors,
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildChipRow(
                            title: l10n.metricSmoking,
                            options: const [
                              'allowed',
                              'outdoor_only',
                              'not_allowed',
                              'unknown',
                            ],
                            selected: _smokingPolicy,
                            onChanged: (value) =>
                                setState(() => _smokingPolicy = value),
                            colors: colors,
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          TextField(
                            controller: _contentCtrl,
                            maxLines: 4,
                            maxLength: 2000,
                            enabled: !isSubmitting,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(color: colors.text),
                            decoration: InputDecoration(
                              labelText: l10n.reviewsFormCommentLabel,
                              hintText: l10n.reviewsFormCommentHint,
                              helperText: l10n.reviewsFormCommentHelper,
                              helperMaxLines: 2,
                              hintStyle: TextStyle(color: colors.mutedText),
                              filled: true,
                              fillColor: colors.card,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide(color: colors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AppActionButton(
                            label: submitLabel,
                            onPressed:
                                _rating == 0 || isSubmitting ? null : _submit,
                            icon: Icons.send_rounded,
                            isLoading: isSubmitting,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
