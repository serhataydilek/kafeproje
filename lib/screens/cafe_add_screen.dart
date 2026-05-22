import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/options.dart';
import '../l10n/l10n.dart';
import '../models/index.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/cafe_media.dart';
import '../utils/form_state_mixin.dart';
import '../utils/input_validation.dart';
import '../utils/localized_error.dart';
import '../widgets/cafes/opening_hours_editor.dart';
import '../widgets/ui/app_action_button.dart';
import '../widgets/ui/form_fields.dart';

class CafeAddScreen extends ConsumerStatefulWidget {
  const CafeAddScreen({super.key});

  @override
  ConsumerState<CafeAddScreen> createState() => _CafeAddScreenState();
}

class _CafeAddScreenState extends ConsumerState<CafeAddScreen>
    with FormStateMixin {
  late final _nameCtrl = useTextController();
  late final _neighborhoodCtrl = useTextController();
  late final _addressCtrl = useTextController();
  late final _descriptionCtrl = useTextController();
  late final _tagsCtrl = useTextController();
  late final _photosCtrl = useTextController();

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
  List<OpeningHour> _openingHours = const [
    OpeningHour(day: 'Mon', open: '08:00', close: '22:00'),
    OpeningHour(day: 'Tue', open: '08:00', close: '22:00'),
    OpeningHour(day: 'Wed', open: '08:00', close: '22:00'),
    OpeningHour(day: 'Thu', open: '08:00', close: '22:00'),
    OpeningHour(day: 'Fri', open: '08:00', close: '23:00'),
    OpeningHour(day: 'Sat', open: '09:00', close: '23:00'),
    OpeningHour(day: 'Sun', open: '09:00', close: '22:00'),
  ];
  bool _showValidation = false;
  String? _nameError;
  String? _neighborhoodError;
  String? _addressError;
  String? _descriptionError;
  String? _photosError;

  void _updateValidation({bool reveal = false}) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final shouldShow = _showValidation || reveal;
    final l10n = context.l10n;

    setState(() {
      _showValidation = shouldShow;
      _nameError = shouldShow
          ? validateRequiredText(
              _nameCtrl.text,
              isTr ? 'Kafe adi' : 'Cafe name',
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
      _descriptionError = shouldShow
          ? validateRequiredText(
              _descriptionCtrl.text,
              isTr ? 'Aciklama' : 'Description',
            )
          : null;
      _photosError = shouldShow &&
              hasInvalidCafeImageInput(
                _photosCtrl.text,
                requireTrustedHosts: true,
              )
          ? l10n.errorPhotoUrlsInvalid
          : null;
    });
  }

  bool get _isFormValid =>
      validateRequiredText(_nameCtrl.text, 'Cafe name') == null &&
      validateRequiredText(_neighborhoodCtrl.text, 'Neighborhood') == null &&
      validateRequiredText(_addressCtrl.text, 'Address') == null &&
      validateRequiredText(_descriptionCtrl.text, 'Description') == null &&
      !hasInvalidCafeImageInput(
        _photosCtrl.text,
        requireTrustedHosts: true,
      );

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
    return null;
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
      final result =
          await ref.read(cafeAdminMutationControllerProvider.notifier).addCafe(
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
                  tags: sanitizeTagList(_tagsCtrl.text),
                  images: parseCafeImageInput(
                    _photosCtrl.text,
                    requireTrustedHosts: true,
                  ),
                  openingHours: _openingHours,
                  ownerApprovalStatus: 'approved',
                ),
              );

      if (result.ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.cafeAddSuccess)),
          );
          context.pop();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizeServiceMessage(result, l10n,
                  fallback: l10n.cafeAddFailed),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final districtOptions = ref.watch(districtOptionsWithUnknownProvider);
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final l10n = context.l10n;

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
                    l10n.cafeAddTitle,
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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  _input(colors, _nameCtrl, l10n.cafeFormName),
                  _label(colors, l10n.cafeFormDistrict),
                  _optionRow(
                    colors,
                    districtOptions,
                    _district,
                    (value) => districtLabel(l10n, value),
                    (v) => setState(() => _district = v),
                  ),
                  _input(colors, _neighborhoodCtrl, l10n.cafeFormNeighborhood),
                  _input(colors, _addressCtrl, l10n.cafeFormAddress),
                  _label(colors, l10n.commonCategory),
                  _optionRow(
                    colors,
                    cafeCategoryOptions,
                    _category,
                    (value) => cafeCategoryValueLabel(l10n, value),
                    (v) => setState(() => _category = v),
                  ),
                  _input(
                    colors,
                    _descriptionCtrl,
                    l10n.cafeFormDescription,
                    multiline: true,
                  ),
                  _label(colors, l10n.cafeFormPrice),
                  _optionRow(
                    colors,
                    editablePriceLevels,
                    _priceLevel,
                    (value) => priceLevelOptionLabel(l10n, value),
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
                    (v) => setState(() => _outletAvailability = v),
                  ),
                  _label(colors, l10n.cafeFormQuietness),
                  _optionRow(
                    colors,
                    quietnessLevels,
                    _quietnessLevel,
                    (value) => quietnessLabel(l10n, value),
                    (v) => setState(() => _quietnessLevel = v),
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
                    (v) => setState(() => _outdoorSeating = v),
                  ),
                  _label(colors, l10n.cafeFormSmoking),
                  _optionRow(
                    colors,
                    smokingPolicies,
                    _smokingPolicy,
                    (value) => smokingPolicyLabel(l10n, value),
                    (v) => setState(() => _smokingPolicy = v),
                  ),
                  _label(colors, l10n.cafeDetailHours),
                  OpeningHoursEditor(
                    colors: colors,
                    initialHours: _openingHours,
                    onChanged: (hours) => _openingHours = hours,
                  ),
                  _input(colors, _tagsCtrl, l10n.cafeFormTags),
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
                  const SizedBox(height: AppSpacing.md),
                  AppActionButton(
                    label: isSubmitting ? l10n.cafeFormSaving : l10n.commonSave,
                    onPressed: isSubmitting ? null : _save,
                    icon: Icons.add_business_rounded,
                    isLoading: isSubmitting,
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

  Widget _label(AppColors colors, String text) =>
      AppFormLabel(colors: colors, text: text);

  Widget _input(
    AppColors colors,
    TextEditingController ctrl,
    String hint, {
    bool multiline = false,
    int? maxLines,
  }) =>
      AppFormInput(
        colors: colors,
        controller: ctrl,
        hint: hint,
        multiline: multiline,
        maxLines: maxLines,
        errorText: _fieldError(ctrl),
        onChanged: (_) => _updateValidation(),
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
    void Function(bool) onChanged,
  ) =>
      AppFormToggle(
        colors: colors,
        label: label,
        value: value,
        onChanged: onChanged,
      );
}
