import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../models/index.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/cafe_media.dart';
import '../../utils/log_redaction.dart';
import '../layout/adaptive_layout.dart';
import '../ui/state_views.dart';
import 'cafe_detail_sections.dart';
import 'cafe_image_carousel.dart';
import 'cafe_reviews_section.dart';

class CafeDetailBody extends ConsumerWidget {
  const CafeDetailBody({
    super.key,
    required this.cafeId,
    required this.colors,
    required this.onBack,
  });

  final String cafeId;
  final AppColors colors;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cafe = ref.watch(cafeByIdProvider(cafeId));
    final isLoading = ref.watch(isCafeDetailLoadingProvider(cafeId));
    final errorMessage = ref.watch(cafeDetailErrorProvider(cafeId));

    if (cafe == null) {
      return CafeDetailStateSection(
        cafeId: cafeId,
        colors: colors,
        isLoading: isLoading,
        errorMessage: errorMessage,
        onBack: onBack,
      );
    }

    return CafeDetailContent(
      cafe: cafe,
      colors: colors,
      onBack: onBack,
    );
  }
}

class CafeDetailStateSection extends ConsumerWidget {
  const CafeDetailStateSection({
    super.key,
    required this.cafeId,
    required this.colors,
    required this.isLoading,
    required this.errorMessage,
    required this.onBack,
  });

  final String cafeId;
  final AppColors colors;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final normalizedError = errorMessage?.trim();
    final message = isLoading
        ? l10n.commonLoading
        : (normalizedError == null ||
                normalizedError.isEmpty ||
                normalizedError == 'Cafe not available.')
            ? l10n.cafeDetailNotFound
            : normalizedError;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const ValueKey('cafe-detail-back-button'),
              tooltip: l10n.commonBack,
              icon: Icon(Icons.arrow_back_rounded, color: colors.text),
              onPressed: onBack,
            ),
          ),
        ),
        Expanded(
          child: isLoading
              ? LoadingStateView(colors: colors, label: l10n.commonLoading)
              : ErrorStateView(
                  colors: colors,
                  message: message,
                  onRetry: () =>
                      ref.read(cafeProvider.notifier).ensureCafeLoaded(cafeId),
                ),
        ),
      ],
    );
  }
}

class CafeDetailContent extends ConsumerWidget {
  const CafeDetailContent({
    super.key,
    required this.cafe,
    required this.colors,
    required this.onBack,
  });

  final Cafe cafe;
  final AppColors colors;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final canManage = ref.watch(canManageCafeProvider(cafe));
    const ownerClaimsEnabled = bool.fromEnvironment('ENABLE_OWNER_CLAIMS');
    final showOwnership = canManage || (ownerClaimsEnabled && !isAdmin);
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AdaptiveLayoutData.fromWidth(constraints.maxWidth);
        final overview = CafeDetailOverviewSection(
          cafe: cafe,
          colors: colors,
          languageCode: Localizations.localeOf(context).languageCode,
        );
        final metadata = CafeDetailMetadataSection(
          cafe: cafe,
          colors: colors,
        );
        final actions = CafeDetailActionsSection(
          cafe: cafe,
          colors: colors,
        );
        final ownership = showOwnership
            ? CafeOwnershipClaimSection(
                cafe: cafe,
                colors: colors,
              )
            : null;
        final reviews = CafeDetailReviewsSection(
          cafeId: cafe.id,
          colors: colors,
        );

        Widget ownershipBlock() {
          if (ownership == null) {
            return const SizedBox.shrink();
          }
          return Column(
            children: [
              SizedBox(height: layout.sectionSpacing),
              ownership,
            ],
          );
        }

        return CustomScrollView(
          slivers: [
            CafeDetailPhotoSection(
              cafe: cafe,
              colors: colors,
              onBack: onBack,
            ),
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: layout.compareContentMaxWidth(),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(layout.horizontalPadding),
                    child: layout.usesSplitContent
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              overview,
                              SizedBox(height: layout.sectionSpacing),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        metadata,
                                        SizedBox(height: layout.sectionSpacing),
                                        actions,
                                        ownershipBlock(),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: layout.sectionSpacing),
                                  Expanded(
                                    flex: 6,
                                    child: reviews,
                                  ),
                                ],
                              ),
                              SizedBox(height: layout.sectionSpacing * 2),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              overview,
                              SizedBox(height: layout.sectionSpacing),
                              metadata,
                              SizedBox(height: layout.sectionSpacing),
                              actions,
                              ownershipBlock(),
                              SizedBox(height: layout.sectionSpacing * 1.5),
                              reviews,
                              SizedBox(height: layout.sectionSpacing * 2),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CafeDetailPhotoSection extends ConsumerWidget {
  const CafeDetailPhotoSection({
    super.key,
    required this.cafe,
    required this.colors,
    required this.onBack,
  });

  final Cafe cafe;
  final AppColors colors;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final canManageCafe = ref.watch(canManageCafeProvider(cafe));
    final l10n = context.l10n;
    final layout =
        AdaptiveLayoutData.fromWidth(MediaQuery.sizeOf(context).width);
    if (kVerboseCafeDiagnostics) {
      final firstUrl = cafe.photoUrls.isNotEmpty
          ? redactUrlForLog(cafe.photoUrls.first)
          : '';
      AppLogger.debug(
        '[CAFE_DIAG_PHOTO_UI] surface=detail cafeId=${cafe.id} cafeName="${cafe.name}" listLength=${cafe.photoUrls.length} firstUrl=$firstUrl',
        key: 'cafe-diag-photo-ui-detail-${cafe.id}',
        throttle: Duration.zero,
      );
    }

    return SliverAppBar(
      expandedHeight: layout.detailExpandedHeight(),
      pinned: true,
      backgroundColor: colors.bg,
      leading: IconButton(
        key: const ValueKey('cafe-detail-back-button'),
        tooltip: l10n.commonBack,
        icon: _CircularChromeIcon(
          colors: colors,
          icon: Icons.arrow_back,
          iconColor: colors.text,
        ),
        onPressed: onBack,
      ),
      actions: [
        if (isAdmin || canManageCafe)
          IconButton(
            key: ValueKey('cafe-detail-edit-${cafe.id}'),
            tooltip: l10n.commonEdit,
            icon: _CircularChromeIcon(
              colors: colors,
              icon: Icons.edit,
              iconColor: colors.accent,
            ),
            onPressed: () => context.push('/cafe-edit/${cafe.id}'),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: CafeImageCarousel(
          key: ValueKey('cafe-detail-photo-${cafe.id}'),
          imageUrls: cafe.photoUrls,
          traceTag: 'detail:${cafe.id}',
          height: layout.detailExpandedHeight(),
          colors: colors,
          borderRadius: BorderRadius.zero,
          cacheWidth: CafeImageVariant.detailGallery.decodeWidthPx,
          cacheHeight: CafeImageVariant.detailGallery.decodeHeightPx,
          requestWidth: CafeImageVariant.detailGallery.requestWidthPx,
        ),
      ),
    );
  }
}

class CafeOwnershipClaimSection extends ConsumerWidget {
  const CafeOwnershipClaimSection({
    super.key,
    required this.cafe,
    required this.colors,
  });

  final Cafe cafe;
  final AppColors colors;

  String _trEn(BuildContext context, String tr, String en) {
    return Localizations.localeOf(context).languageCode == 'tr' ? tr : en;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final canManage = ref.watch(canManageCafeProvider(cafe));
    const ownerClaimsEnabled = bool.fromEnvironment('ENABLE_OWNER_CLAIMS');
    final claim = ownerClaimsEnabled
        ? ref.watch(cafeOwnerClaimForCafeProvider(cafe.id))
        : null;
    final claimsLoading = ownerClaimsEnabled &&
        ref.watch(currentUserOwnerClaimsProvider).isLoading;

    final title = _trEn(
      context,
      'Bu isletmenin sahibi misiniz?',
      'Do you own this business?',
    );
    late final String body;
    late final Widget action;

    if (isAdmin) {
      body = _trEn(
        context,
        'Yonetici olarak bu kafeyi duzenleyebilirsiniz.',
        'Admins can manage this cafe.',
      );
      action = OutlinedButton.icon(
        key: ValueKey('cafe-owner-admin-manage-${cafe.id}'),
        onPressed: () => context.push('/cafe-edit/${cafe.id}'),
        icon: const Icon(Icons.admin_panel_settings_rounded),
        label: Text(_trEn(context, 'Yonet', 'Manage')),
      );
    } else if (canManage) {
      body = _trEn(
        context,
        'Sahiplik onaylandi. Bu kafeyi yonetebilirsiniz.',
        'Ownership is approved. You can manage this cafe.',
      );
      action = FilledButton.icon(
        key: ValueKey('cafe-owner-manage-${cafe.id}'),
        onPressed: () => context.push('/cafe-edit/${cafe.id}'),
        icon: const Icon(Icons.storefront_rounded),
        label: Text(_trEn(context, 'Kafeyi yonet', 'Manage cafe')),
      );
    } else if (!ownerClaimsEnabled) {
      body = _trEn(
        context,
        'Kafe yonetimi sadece yonetici tarafindan atanmis cafe_owner hesaplarina aciktir.',
        'Cafe management is available only to cafe_owner accounts assigned by an admin.',
      );
      action = OutlinedButton.icon(
        key: ValueKey('cafe-owner-claim-disabled-${cafe.id}'),
        onPressed: null,
        icon: const Icon(Icons.lock_outline_rounded),
        label: Text(_trEn(
            context, 'Yonetici atamasi gerekli', 'Admin assignment required')),
      );
    } else if (claim?.isPending == true) {
      body = _trEn(
        context,
        'Sahiplik talebiniz inceleniyor.',
        'Your ownership claim is pending review.',
      );
      action = OutlinedButton.icon(
        key: ValueKey('cafe-owner-pending-${cafe.id}'),
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded),
        label: Text(_trEn(context, 'Incelemede', 'Pending')),
      );
    } else {
      final rejected = claim?.isRejected == true;
      body = rejected
          ? _trEn(
              context,
              'Onceki talebiniz reddedildi. Bilgileri guncelleyerek tekrar talep edebilirsiniz.',
              'Your previous claim was rejected. You can request again with updated details.',
            )
          : _trEn(
              context,
              'Kafe bilgilerini yonetmek icin sahiplik talebi gonderin.',
              'Request ownership to manage this cafe profile.',
            );
      action = FilledButton.icon(
        key: ValueKey('cafe-owner-claim-${cafe.id}'),
        onPressed:
            claimsLoading ? null : () => _showClaimDialog(context, ref, user),
        icon: const Icon(Icons.assignment_ind_rounded),
        label: Text(
          rejected
              ? _trEn(context, 'Tekrar talep et', 'Request again')
              : _trEn(context, 'Kafe sahipligi talep et', 'Claim this cafe'),
        ),
      );
    }

    return Container(
      key: ValueKey('cafe-owner-claim-section-${cafe.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: TextStyle(color: colors.mutedText),
          ),
          const SizedBox(height: AppSpacing.sm),
          action,
        ],
      ),
    );
  }

  Future<void> _showClaimDialog(
    BuildContext context,
    WidgetRef ref,
    CurrentUser? user,
  ) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_trEn(
            context,
            'Sahiplik talebi icin giris yapmalisiniz.',
            'Please sign in to claim this cafe.',
          )),
        ),
      );
      unawaited(context.push('/auth?from=/cafe/${cafe.id}'));
      return;
    }

    final businessCtrl = TextEditingController(text: cafe.name);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController();
    final evidenceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_trEn(
            context,
            'Kafe sahipligi talebi',
            'Cafe ownership claim',
          )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('owner-claim-business-name-input'),
                controller: businessCtrl,
                decoration: InputDecoration(
                  labelText: _trEn(context, 'Isletme adi', 'Business name'),
                ),
              ),
              TextField(
                key: const Key('owner-claim-email-input'),
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: _trEn(context, 'Is e-postasi', 'Business email'),
                ),
              ),
              TextField(
                key: const Key('owner-claim-phone-input'),
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: _trEn(context, 'Telefon', 'Phone'),
                ),
              ),
              TextField(
                key: const Key('owner-claim-evidence-input'),
                controller: evidenceCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: _trEn(context, 'Kanıt linki', 'Evidence URL'),
                ),
              ),
              TextField(
                key: const Key('owner-claim-note-input'),
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _trEn(context, 'Not', 'Note'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(false),
              child: Text(_trEn(context, 'Iptal', 'Cancel')),
            ),
            FilledButton(
              key: const Key('owner-claim-submit-button'),
              onPressed: () => dialogContext.pop(true),
              child: Text(_trEn(context, 'Gonder', 'Submit')),
            ),
          ],
        );
      },
    );

    if (result != true || !context.mounted) {
      businessCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
      evidenceCtrl.dispose();
      noteCtrl.dispose();
      return;
    }

    final serviceResult =
        await ref.read(cafeOwnerClaimControllerProvider.notifier).createClaim(
              cafeId: cafe.id,
              businessName: businessCtrl.text,
              businessEmail: emailCtrl.text,
              evidenceUrl: evidenceCtrl.text,
              phone: phoneCtrl.text,
              note: noteCtrl.text,
            );
    businessCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    evidenceCtrl.dispose();
    noteCtrl.dispose();

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          serviceResult.ok
              ? _trEn(context, 'Talebiniz alindi.', 'Claim submitted.')
              : (serviceResult.message ??
                  _trEn(context, 'Talep gonderilemedi.', 'Claim failed.')),
        ),
      ),
    );
  }
}

class CafeDetailReviewsSection extends StatelessWidget {
  const CafeDetailReviewsSection({
    super.key,
    required this.cafeId,
    required this.colors,
  });

  final String cafeId;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('cafe-detail-reviews-$cafeId'),
      child: CafeReviewsSection(
        cafeId: cafeId,
        colors: colors,
      ),
    );
  }
}

class _CircularChromeIcon extends StatelessWidget {
  const _CircularChromeIcon({
    required this.colors,
    required this.icon,
    required this.iconColor,
  });

  final AppColors colors;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: 18),
    );
  }
}
