import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/options.dart';
import '../l10n/l10n.dart';
import '../models/index.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/cafe_media.dart';
import '../utils/form_state_mixin.dart';
import '../utils/input_validation.dart';
import '../utils/localized_error.dart';
import '../widgets/cafes/opening_hours_editor.dart';
import '../widgets/ui/app_action_button.dart';
import '../widgets/ui/form_fields.dart';
import '../widgets/ui/state_views.dart';

class CafeEditScreen extends ConsumerStatefulWidget {
  const CafeEditScreen({super.key, required this.cafeId});

  final String cafeId;

  @override
  ConsumerState<CafeEditScreen> createState() => _CafeEditScreenState();
}

class _CafeEditScreenState extends ConsumerState<CafeEditScreen>
    with FormStateMixin {
  late final _nameCtrl = useTextController();
  late final _neighborhoodCtrl = useTextController();
  late final _addressCtrl = useTextController();
  late final _descriptionCtrl = useTextController();
  late final _tagsCtrl = useTextController();
  late final _photosCtrl = useTextController();
  late final _ownerEmailCtrl = useTextController();
  late final _ownerFirstNameCtrl = useTextController();
  late final _ownerLastNameCtrl = useTextController();
  late final _featuredPriorityCtrl = useTextController(text: '0');
  late final _featuredUntilCtrl = useTextController();
  late final _featuredLabelCtrl = useTextController();

  String _district = 'Unknown';
  String _category = 'normal_cafe';
  String _priceLevel = unknownPriceLevelOption;
  String _wifiQuality = 'Average';
  String _outletAvailability = 'Medium';
  String _quietnessLevel = 'Balanced';
  String _smokingPolicy = 'not_allowed';
  bool _studyFriendly = false;
  bool _petFriendly = false;
  bool _outdoorSeating = false;
  bool _isFeatured = false;
  List<OpeningHour> _openingHours = const [];
  bool _isLoading = true;
  bool _navigatedAfterDelete = false;
  bool _shouldLogPostDeleteVerify = false;
  Cafe? _editingCafe;
  bool _showValidation = false;
  String? _nameError;
  String? _neighborhoodError;
  String? _addressError;
  String? _descriptionError;
  String? _photosError;
  String? _featuredPriorityError;
  String? _featuredUntilError;

  Cafe _buildEditableFallbackCafe() {
    return Cafe.empty(id: widget.cafeId).copyWith(
      neighborhood: 'Unknown',
      description: 'N/A',
      ownerApprovalStatus: 'approved',
      isDeleted: false,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _hydrateFromProvider();
    });
  }

  void _updateValidation({bool reveal = false}) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final shouldShow = _showValidation || reveal;
    final l10n = context.l10n;

    setState(() {
      _showValidation = shouldShow;
      _nameError = shouldShow
          ? validateRequiredText(
              _nameCtrl.text,
              isTr ? 'Kafe adı' : 'Cafe name',
            )
          : null;
      _neighborhoodError = shouldShow
          ? validateRequiredText(
              _neighborhoodCtrl.text,
              isTr ? 'Mahalle' : 'Neighborhood',
            )
          : null;
      _addressError = shouldShow
          ? validateRequiredText(
              _addressCtrl.text,
              isTr ? 'Adres' : 'Address',
            )
          : null;
      _descriptionError = null;
      _photosError = shouldShow &&
              hasInvalidCafeImageInput(
                _photosCtrl.text,
                requireTrustedHosts: true,
              )
          ? l10n.errorPhotoUrlsInvalid
          : null;
      _featuredPriorityError = shouldShow
          ? _validateFeaturedPriority(_featuredPriorityCtrl.text)
          : null;
      _featuredUntilError =
          shouldShow ? _validateFeaturedUntil(_featuredUntilCtrl.text) : null;
    });
  }

  bool get _isFormValid =>
      validateRequiredText(_nameCtrl.text, 'Cafe name') == null &&
      validateRequiredText(_neighborhoodCtrl.text, 'Neighborhood') == null &&
      validateRequiredText(_addressCtrl.text, 'Address') == null &&
      !hasInvalidCafeImageInput(
        _photosCtrl.text,
        requireTrustedHosts: true,
      ) &&
      _validateFeaturedPriority(_featuredPriorityCtrl.text) == null &&
      _validateFeaturedUntil(_featuredUntilCtrl.text) == null;

  String? _fieldError(TextEditingController controller) {
    if (identical(controller, _nameCtrl)) {
      return _nameError;
    }
    if (identical(controller, _neighborhoodCtrl)) {
      return _neighborhoodError;
    }
    if (identical(controller, _addressCtrl)) {
      return _addressError;
    }
    if (identical(controller, _descriptionCtrl)) {
      return _descriptionError;
    }
    if (identical(controller, _photosCtrl)) {
      return _photosError;
    }
    if (identical(controller, _featuredPriorityCtrl)) {
      return _featuredPriorityError;
    }
    if (identical(controller, _featuredUntilCtrl)) {
      return _featuredUntilError;
    }
    return null;
  }

  void _applyCafe(Cafe cafe) {
    _editingCafe = cafe;
    final districtOptions = ref.read(districtOptionsWithUnknownProvider);
    _nameCtrl.text = cafe.name;
    _neighborhoodCtrl.text = cafe.neighborhood;
    _addressCtrl.text = cafe.address;
    _descriptionCtrl.text = cafe.description;
    _tagsCtrl.text = cafe.tags.join(', ');
    _photosCtrl.text = cafe.photoUrls.join('\n');
    _category = cafe.category.value;
    _district = districtOptions.contains(cafe.district)
        ? cafe.district
        : District.unknown.displayName;
    _priceLevel = editablePriceLevelSelection(cafe);
    _wifiQuality = wifiQualities.contains(cafe.wifiQuality.value)
        ? cafe.wifiQuality.value
        : wifiQualities.first;
    _outletAvailability =
        outletAvailabilities.contains(cafe.outletAvailability.value)
            ? cafe.outletAvailability.value
            : outletAvailabilities.first;
    _quietnessLevel = quietnessLevels.contains(cafe.quietnessLevel.value)
        ? cafe.quietnessLevel.value
        : quietnessLevels.first;
    _smokingPolicy = smokingPolicies.contains(cafe.smokingPolicy.value)
        ? cafe.smokingPolicy.value
        : smokingPolicies.first;
    _studyFriendly = cafe.studyFriendly;
    _petFriendly = cafe.petFriendly;
    _outdoorSeating = cafe.outdoorSeating;
    _isFeatured = cafe.isFeatured;
    _featuredPriorityCtrl.text = cafe.featuredPriority.toString();
    _featuredUntilCtrl.text = _formatFeaturedDate(cafe.featuredUntil);
    _featuredLabelCtrl.text = cafe.featuredLabel ?? '';
    _openingHours = cafe.openingHours;
    _isLoading = false;
    _updateValidation();
  }

  Future<void> _hydrateFromProvider() async {
    final cafe = await ref.read(adminCafeDetailsProvider(widget.cafeId).future);
    final resolvedCafe = cafe ??
        ref.read(cafeByIdProvider(widget.cafeId)) ??
        _buildEditableFallbackCafe();
    if (!mounted) {
      return;
    }
    setState(() {
      _applyCafe(resolvedCafe);
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    _updateValidation(reveal: true);
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorGenericTitle)),
      );
      return;
    }

    await submitWithLoading(() async {
      final parsedImages = parseCafeImageInput(
        _photosCtrl.text,
        requireTrustedHosts: true,
      );
      final featuredUntil = _parseFeaturedUntil(_featuredUntilCtrl.text);
      final result = await ref
          .read(cafeAdminMutationControllerProvider.notifier)
          .updateCafe(
            widget.cafeId,
            CafeAdminUpdateInput(
              name: sanitizeInput(_nameCtrl.text),
              category: _category,
              district: _district,
              neighborhood: sanitizeInput(_neighborhoodCtrl.text),
              address: sanitizeInput(_addressCtrl.text),
              description: sanitizeInput(_descriptionCtrl.text),
              priceLevel: persistablePriceLevelValue(_priceLevel),
              wifiQuality: _wifiQuality,
              outletAvailability: _outletAvailability,
              quietnessLevel: _quietnessLevel,
              studyFriendly: _studyFriendly,
              petFriendly: _petFriendly,
              outdoorSeating: _outdoorSeating,
              smokingPolicy: _smokingPolicy,
              openingHours: _openingHours,
              tags: sanitizeTagList(_tagsCtrl.text),
              images: parsedImages,
              isFeatured: _isFeatured,
              featuredPriority: _parseFeaturedPriority(
                _featuredPriorityCtrl.text,
              ),
              featuredUntil: featuredUntil,
              clearFeaturedUntil: _featuredUntilCtrl.text.trim().isEmpty,
              featuredLabel: _featuredLabelCtrl.text,
            ),
          );

      if (result.ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.cafeEditSuccess)),
          );
          context.pop();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizeServiceMessage(result, l10n,
                  fallback: l10n.cafeEditFailed),
            ),
          ),
        );
      }
    });
  }

  Future<void> _delete() async {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTr ? 'Kafeyi Sil' : 'Delete Cafe'),
        content: Text(
          isTr
              ? 'Bu kafeyi kalıcı olarak gizlemek istediğine emin misin?'
              : 'Are you sure you want to permanently hide this cafe?',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: Text(isTr ? 'İptal' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: Text(
              isTr ? 'Sil' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    AppLogger.debug(
      '[ADMIN_DELETE_CONFIRM] surface=cafe_edit confirmed=true',
      key: 'admin-edit-delete-confirm-${widget.cafeId}',
      throttle: Duration.zero,
    );

    if (isSubmitting) {
      return;
    }
    setState(() {
      isSubmitting = true;
      formError = null;
    });

    try {
      final resolvedCafe =
          await ref.read(adminCafeDetailsProvider(widget.cafeId).future);
      AppLogger.debug(
        '[ADMIN_DELETE_TAP] surface=cafe_edit id=${widget.cafeId} placeId=${resolvedCafe?.placeId ?? ''} google_place_id=${resolvedCafe?.placeId ?? ''}',
        key: 'admin-edit-delete-tap-${widget.cafeId}',
        throttle: Duration.zero,
      );
      AppLogger.debug(
        '[ADMIN_DELETE_BUTTON] buttonHandlerReached=true surface=cafe_edit selectedId=${widget.cafeId} selectedGooglePlaceId=${resolvedCafe?.placeId ?? ''}',
        key: 'admin-edit-delete-button-${widget.cafeId}',
        throttle: Duration.zero,
      );
      final result = await ref
          .read(cafeAdminMutationControllerProvider.notifier)
          .deleteCafe(widget.cafeId);

      if (!mounted) {
        return;
      }
      if (result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isTr ? 'Kafe silindi.' : 'Cafe deleted.')),
        );
        _shouldLogPostDeleteVerify = true;
        AppLogger.debug(
          '[ADMIN_DELETE_NAVIGATION] source=cafe_edit action=go_admin_cafes',
          key: 'admin-delete-navigation-${widget.cafeId}',
          throttle: Duration.zero,
        );
        AppLogger.debug(
          '[ADMIN_ROUTE] tab=cafes source=post_delete',
          key: 'admin-route-post-delete-${widget.cafeId}',
          throttle: Duration.zero,
        );
        context.go('/admin?tab=cafes');
        _schedulePostDeleteVerify();
        return;
      }

      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizeServiceMessage(result, l10n,
                fallback: isTr ? 'Silme başarısız oldu.' : 'Failed to delete.'),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setFormError(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> _inviteOwner() async {
    final email = _ownerEmailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_trEn(
            'Gecerli bir sahip e-postasi gir.',
            'Enter a valid owner email.',
          )),
        ),
      );
      return;
    }

    if (isSubmitting) {
      return;
    }
    setState(() {
      isSubmitting = true;
      formError = null;
    });

    try {
      final result = await ref
          .read(cafeOwnerInviteControllerProvider.notifier)
          .inviteAndAssign(
            cafeId: widget.cafeId,
            email: email,
            firstName: _ownerFirstNameCtrl.text,
            lastName: _ownerLastNameCtrl.text,
            fullName: [
              _ownerFirstNameCtrl.text.trim(),
              _ownerLastNameCtrl.text.trim(),
            ].where((part) => part.isNotEmpty).join(' '),
          );
      if (!mounted) {
        return;
      }
      if (result.ok && result.data != null) {
        setState(() {
          _ownerEmailCtrl.clear();
          _ownerFirstNameCtrl.clear();
          _ownerLastNameCtrl.clear();
          _applyCafe(result.data!.cafe);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.data!.invited
                ? _trEn(
                    'Sahip daveti gonderildi ve kafe atandi.',
                    'Owner invite sent and cafe assigned.',
                  )
                : _trEn(
                    'Mevcut kullanici kafe sahibi olarak atandi.',
                    'Existing user assigned as cafe owner.',
                  )),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ??
              _trEn('Sahip daveti basarisiz oldu.', 'Owner invite failed.')),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Cafe owner invite action failed',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-owner-invite-action-${widget.cafeId}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_trEn(
              'Sahip daveti basarisiz oldu.',
              'Owner invite failed.',
            )),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> _unassignOwner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_trEn('Sahibi kaldir', 'Unassign owner')),
        content: Text(_trEn(
          'Bu kafe icin atanmis sahip erisimini kaldirmak istiyor musun?',
          'Remove the assigned owner access for this cafe?',
        )),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: Text(_trEn('Iptal', 'Cancel')),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: Text(_trEn('Kaldir', 'Unassign')),
          ),
        ],
      ),
    );
    if (confirmed != true || isSubmitting) {
      return;
    }

    setState(() {
      isSubmitting = true;
      formError = null;
    });
    try {
      final result = await ref
          .read(cafeOwnerInviteControllerProvider.notifier)
          .unassignOwner(widget.cafeId);
      if (!mounted) {
        return;
      }
      if (result.ok && result.data != null) {
        setState(() => _applyCafe(result.data!));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_trEn(
              'Kafe sahibi atamasi kaldirildi.',
              'Cafe owner assignment removed.',
            )),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ??
              _trEn('Sahip kaldirilamadi.', 'Owner unassign failed.')),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Cafe owner unassign action failed',
        error: error,
        stackTrace: stackTrace,
        key: 'cafe-owner-unassign-action-${widget.cafeId}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_trEn(
              'Sahip kaldirilamadi.',
              'Owner unassign failed.',
            )),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final cafeAsync = ref.watch(adminCafeDetailsProvider(widget.cafeId));
    final districtOptions = ref.watch(districtOptionsWithUnknownProvider);
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final l10n = context.l10n;
    final providerCafe = cafeAsync.valueOrNull;
    final cafe = _editingCafe ?? providerCafe;
    final isAdmin = ref.watch(isAdminProvider);
    final canManageCafe =
        cafe == null ? false : ref.watch(canManageCafeProvider(cafe));
    final adminUsers =
        isAdmin ? ref.watch(adminUsersProvider).valueOrNull : null;
    final assignedOwner = _assignedOwner(cafe, adminUsers);
    final isUnavailable =
        !cafeAsync.isLoading && (cafe == null || cafe.isDeleted);
    final isForbidden = !cafeAsync.isLoading && cafe != null && !canManageCafe;
    if (isUnavailable && !_navigatedAfterDelete) {
      _navigatedAfterDelete = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        AppLogger.debug(
          '[ADMIN_DELETE_NAVIGATION] source=cafe_edit action=go_admin_cafes',
          key: 'admin-delete-navigation-${widget.cafeId}',
          throttle: Duration.zero,
        );
        AppLogger.debug(
          '[ADMIN_ROUTE] tab=cafes source=post_delete',
          key: 'admin-route-post-delete-${widget.cafeId}',
          throttle: Duration.zero,
        );
        context.go('/admin?tab=cafes');
        _schedulePostDeleteVerify();
      });
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border),
                      ),
                      child:
                          Icon(Icons.arrow_back, color: colors.text, size: 18),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.cafeEditTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isForbidden
                  ? ErrorStateView(
                      colors: colors,
                      message: _trEn(
                        'Bu kafeyi yonetme yetkiniz yok.',
                        'You do not have permission to manage this cafe.',
                      ),
                    )
                  : isUnavailable
                      ? ErrorStateView(
                          colors: colors,
                          message: l10n.cafeDetailNotFound,
                          onRetry: () => ref.invalidate(
                            adminCafeDetailsProvider(widget.cafeId),
                          ),
                        )
                      : cafeAsync.isLoading && _isLoading
                          ? LoadingStateView(colors: colors)
                          : ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              children: [
                                _sectionCard(
                                  colors,
                                  _trEn('Temel Bilgiler', 'Basic info'),
                                  [
                                    _input(
                                        colors, _nameCtrl, l10n.cafeFormName),
                                    _label(colors, l10n.commonCategory),
                                    _optionRow(
                                      colors,
                                      cafeCategoryOptions,
                                      _category,
                                      (value) =>
                                          cafeCategoryValueLabel(l10n, value),
                                      (v) => setState(() => _category = v),
                                    ),
                                    _label(colors, l10n.cafeFormDistrict),
                                    _optionRow(
                                      colors,
                                      districtOptions,
                                      _district,
                                      (value) => districtLabel(l10n, value),
                                      (v) => setState(() => _district = v),
                                    ),
                                    _input(
                                      colors,
                                      _neighborhoodCtrl,
                                      l10n.cafeFormNeighborhood,
                                    ),
                                  ],
                                ),
                                _sectionCard(
                                  colors,
                                  _trEn('Konum', 'Location'),
                                  [
                                    _input(
                                      colors,
                                      _addressCtrl,
                                      l10n.cafeFormAddress,
                                    ),
                                    _label(colors, l10n.cafeDetailHours),
                                    OpeningHoursEditor(
                                      colors: colors,
                                      initialHours: _openingHours,
                                      onChanged: (hours) =>
                                          _openingHours = hours,
                                    ),
                                  ],
                                ),
                                _sectionCard(
                                  colors,
                                  _trEn('Kafe Detayları', 'Cafe details'),
                                  [
                                    _input(
                                      colors,
                                      _descriptionCtrl,
                                      l10n.cafeFormDescription,
                                      key: const Key('admin-description-input'),
                                      multiline: true,
                                    ),
                                    _label(colors, l10n.cafeFormPrice),
                                    _optionRow(
                                      colors,
                                      editablePriceLevels,
                                      _priceLevel,
                                      (value) =>
                                          priceLevelOptionLabel(l10n, value),
                                      (v) => setState(() => _priceLevel = v),
                                    ),
                                    _label(colors, l10n.cafeFormWifi),
                                    _optionRow(
                                      colors,
                                      wifiQualities,
                                      _wifiQuality,
                                      (value) => wifiLabel(l10n, value),
                                      (v) => setState(() => _wifiQuality = v),
                                    ),
                                    _label(colors, l10n.cafeFormOutlet),
                                    _optionRow(
                                      colors,
                                      outletAvailabilities,
                                      _outletAvailability,
                                      (value) => outletLabel(l10n, value),
                                      (v) => setState(
                                          () => _outletAvailability = v),
                                    ),
                                    _label(colors, l10n.cafeFormQuietness),
                                    _optionRow(
                                      colors,
                                      quietnessLevels,
                                      _quietnessLevel,
                                      (value) => quietnessLabel(l10n, value),
                                      (v) =>
                                          setState(() => _quietnessLevel = v),
                                    ),
                                    _toggle(
                                      colors,
                                      l10n.cafeFormStudyFriendly,
                                      _studyFriendly,
                                      (v) => setState(() => _studyFriendly = v),
                                    ),
                                    _toggle(
                                      colors,
                                      l10n.cafeFormPetFriendly,
                                      _petFriendly,
                                      (v) => setState(() => _petFriendly = v),
                                    ),
                                    _toggle(
                                      colors,
                                      l10n.cafeFormOutdoorSeating,
                                      _outdoorSeating,
                                      (v) =>
                                          setState(() => _outdoorSeating = v),
                                    ),
                                    _label(colors, l10n.cafeFormSmoking),
                                    _optionRow(
                                      colors,
                                      smokingPolicies,
                                      _smokingPolicy,
                                      (value) =>
                                          smokingPolicyLabel(l10n, value),
                                      (v) => setState(() => _smokingPolicy = v),
                                    ),
                                    _input(
                                        colors, _tagsCtrl, l10n.cafeFormTags),
                                  ],
                                ),
                                _sectionCard(
                                  colors,
                                  _trEn('Fotoğraflar', 'Photos'),
                                  [
                                    _input(
                                      colors,
                                      _photosCtrl,
                                      l10n.cafeFormPhotos,
                                      multiline: true,
                                      maxLines: 4,
                                    ),
                                    AppFormHelperText(
                                      colors: colors,
                                      text: l10n.cafeFormPhotosHint,
                                    ),
                                  ],
                                ),
                                if (isAdmin)
                                  _sectionCard(
                                    colors,
                                    _trEn('Kafe Sahibi', 'Cafe owner'),
                                    [
                                      _ownerAssignmentPanel(
                                        colors,
                                        cafe,
                                        assignedOwner,
                                      ),
                                    ],
                                  ),
                                if (isAdmin)
                                  _sectionCard(
                                    colors,
                                    _trEn('Öne Çıkan Yerleşimi',
                                        'Featured placement'),
                                    [
                                      _toggle(
                                        colors,
                                        _trEn(
                                            'Öne çıkan kafe', 'Featured cafe'),
                                        _isFeatured,
                                        (v) => setState(() => _isFeatured = v),
                                        key: const Key(
                                          'admin-featured-toggle',
                                        ),
                                      ),
                                      _input(
                                        colors,
                                        _featuredPriorityCtrl,
                                        _trEn('Öne çıkan önceliği',
                                            'Featured priority'),
                                        key: const Key(
                                          'admin-featured-priority-input',
                                        ),
                                        keyboardType: TextInputType.number,
                                        revealValidationOnChange: true,
                                      ),
                                      AppFormHelperText(
                                        colors: colors,
                                        text: _trEn(
                                          'Daha yüksek sayılar sponsorlu yerleşimde önce gösterilir.',
                                          'Higher numbers appear first in sponsored placements.',
                                        ),
                                      ),
                                      _input(
                                        colors,
                                        _featuredUntilCtrl,
                                        _trEn(
                                          'Öne çıkan bitiş tarihi (YYYY-MM-DD)',
                                          'Featured until (YYYY-MM-DD)',
                                        ),
                                        key: const Key(
                                          'admin-featured-until-input',
                                        ),
                                        keyboardType: TextInputType.datetime,
                                        revealValidationOnChange: true,
                                      ),
                                      AppFormHelperText(
                                        colors: colors,
                                        text: _trEn(
                                          'Bitiş tarihi yoksa boş bırak. Tarihler UTC olarak kaydedilir.',
                                          'Leave blank for no expiration. Dates are saved as UTC.',
                                        ),
                                      ),
                                      _input(
                                        colors,
                                        _featuredLabelCtrl,
                                        _trEn('Öne çıkan etiketi',
                                            'Featured label'),
                                        key: const Key(
                                          'admin-featured-label-input',
                                        ),
                                      ),
                                      AppFormHelperText(
                                        colors: colors,
                                        text: _trEn(
                                          'İsteğe bağlıdır. Boş etiketler etiketsiz olarak kaydedilir.',
                                          'Optional. Empty labels are saved as no label.',
                                        ),
                                      ),
                                    ],
                                  ),
                                _sectionCard(
                                  colors,
                                  isAdmin
                                      ? _trEn(
                                          'Yönetici İşlemleri', 'Admin actions')
                                      : _trEn(
                                          'Sahip İşlemleri', 'Owner actions'),
                                  [
                                    AppActionButton(
                                      key: const Key('admin-save-action'),
                                      label: isSubmitting
                                          ? l10n.cafeFormSaving
                                          : l10n.commonSave,
                                      onPressed: isSubmitting || !_isFormValid
                                          ? null
                                          : _save,
                                      icon: Icons.check,
                                      isLoading: isSubmitting,
                                    ),
                                    if (isAdmin) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(
                                          AppSpacing.sm,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.md),
                                          border: Border.all(
                                            color: Colors.redAccent.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                        child: TextButton.icon(
                                          onPressed:
                                              isSubmitting ? null : _delete,
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                          ),
                                          label: Text(
                                            _trEn('Kafeyi Sil', 'Delete Cafe'),
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xl * 2),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  UserProfile? _assignedOwner(Cafe? cafe, List<UserProfile>? users) {
    final ownerId = cafe?.ownerUserId?.trim();
    if (ownerId == null || ownerId.isEmpty || users == null) {
      return null;
    }
    for (final user in users) {
      if (user.id == ownerId) {
        return user;
      }
    }
    return null;
  }

  Widget _ownerAssignmentPanel(
    AppColors colors,
    Cafe? cafe,
    UserProfile? owner,
  ) {
    final ownerId = cafe?.ownerUserId?.trim();
    final hasOwner = ownerId != null && ownerId.isNotEmpty;
    final ownerLabel = owner == null
        ? ownerId
        : [
            owner.fullName.trim().isNotEmpty ? owner.fullName.trim() : null,
            owner.email.trim().isNotEmpty ? owner.email.trim() : null,
            owner.role.value,
          ].whereType<String>().join(' - ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.chip,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _trEn('Atanmis sahip', 'Assigned owner'),
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(
                hasOwner
                    ? ownerLabel ?? ownerId
                    : _trEn('Henuz sahip atanmadi.', 'No owner assigned yet.'),
                style: TextStyle(color: colors.mutedText, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _input(
          colors,
          _ownerEmailCtrl,
          _trEn('Sahip e-postasi', 'Owner email'),
          key: const Key('admin-owner-email-input'),
          keyboardType: TextInputType.emailAddress,
        ),
        _input(
          colors,
          _ownerFirstNameCtrl,
          _trEn('Sahip adi', 'Owner first name'),
          key: const Key('admin-owner-first-name-input'),
        ),
        _input(
          colors,
          _ownerLastNameCtrl,
          _trEn('Sahip soyadi', 'Owner last name'),
          key: const Key('admin-owner-last-name-input'),
        ),
        AppFormHelperText(
          colors: colors,
          text: _trEn(
            'Yeni e-postaya Supabase daveti gonderilir. Mevcut kullanici otomatik cafe_owner yapilip bu kafeye atanir.',
            'New emails receive a Supabase invite. Existing users are promoted to cafe_owner and assigned to this cafe.',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              key: const Key('admin-owner-invite-button'),
              onPressed: isSubmitting ? null : _inviteOwner,
              icon: const Icon(Icons.mail_outline),
              label: Text(_trEn('Davet et ve ata', 'Invite and assign')),
            ),
            if (hasOwner)
              OutlinedButton.icon(
                key: const Key('admin-owner-unassign-button'),
                onPressed: isSubmitting ? null : _unassignOwner,
                icon: const Icon(Icons.person_remove_outlined),
                label: Text(_trEn('Sahibi kaldir', 'Unassign owner')),
              ),
          ],
        ),
      ],
    );
  }

  Widget _label(AppColors colors, String text) =>
      AppFormLabel(colors: colors, text: text);

  void _schedulePostDeleteVerify() {
    if (!_shouldLogPostDeleteVerify) {
      return;
    }
    _shouldLogPostDeleteVerify = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_logPostDeleteVerification());
    });
  }

  Future<void> _logPostDeleteVerification() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) {
      return;
    }
    final location = GoRouter.of(context).location;
    final stillInRoute = location.contains(widget.cafeId);
    ref.read(cafeAdminMutationControllerProvider.notifier).logDeletePostVerify(
          deletedId: widget.cafeId,
          stillInRoute: stillInRoute,
        );
  }

  Widget _input(
    AppColors colors,
    TextEditingController ctrl,
    String hint, {
    Key? key,
    bool multiline = false,
    int? maxLines,
    TextInputType? keyboardType,
    bool revealValidationOnChange = false,
  }) =>
      AppFormInput(
        key: key,
        colors: colors,
        controller: ctrl,
        hint: hint,
        multiline: multiline,
        maxLines: maxLines,
        keyboardType: keyboardType,
        errorText: _fieldError(ctrl),
        onChanged: (_) => _updateValidation(reveal: revealValidationOnChange),
      );

  Widget _optionRow(
    AppColors colors,
    List<String> options,
    String selected,
    String Function(String) labelBuilder,
    void Function(String) onTap,
  ) =>
      AppFormOptionRow<String>(
        colors: colors,
        options: options,
        selected: selected,
        labelBuilder: labelBuilder,
        onTap: onTap,
      );

  Widget _toggle(
    AppColors colors,
    String label,
    bool value,
    void Function(bool) onChanged, {
    Key? key,
  }) =>
      AppFormToggle(
        key: key,
        colors: colors,
        label: label,
        value: value,
        onChanged: onChanged,
      );

  Widget _sectionCard(AppColors colors, String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }

  int _parseFeaturedPriority(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return int.parse(trimmed);
  }

  DateTime? _parseFeaturedUntil(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  String? _validateFeaturedPriority(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed) == null
        ? _trEn(
            'Öne çıkan önceliği tam sayı olmalıdır.',
            'Featured priority must be a whole number.',
          )
        : null;
  }

  String? _validateFeaturedUntil(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return _parseFeaturedUntil(trimmed) == null
        ? _trEn(
            'Öne çıkan bitiş tarihi için YYYY-MM-DD kullan.',
            'Use YYYY-MM-DD for featured expiration.',
          )
        : null;
  }

  String _trEn(String tr, String en) {
    return Localizations.localeOf(context).languageCode == 'tr' ? tr : en;
  }

  String _formatFeaturedDate(DateTime? date) {
    if (date == null) {
      return '';
    }
    final utc = date.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
