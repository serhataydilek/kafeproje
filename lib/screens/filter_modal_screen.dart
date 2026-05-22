import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/options.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../models/index.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/layout/adaptive_layout.dart';

class FilterModalScreen extends ConsumerStatefulWidget {
  const FilterModalScreen({
    super.key,
    this.scope = FilterModalScope.explore,
    this.initialFilters,
  });

  final FilterModalScope scope;
  final Filters? initialFilters;

  @override
  ConsumerState<FilterModalScreen> createState() => _FilterModalScreenState();
}

class _FilterModalScreenState extends ConsumerState<FilterModalScreen> {
  late Filters _draft;
  late _FilterScope _scope;
  final TextEditingController _presetNameCtrl = TextEditingController();
  List<FilterPreset> _presets = const <FilterPreset>[];
  bool _isLoadingPresets = true;
  String? _editingPresetId;

  @override
  void initState() {
    super.initState();
    _scope = widget.scope == FilterModalScope.map
        ? _FilterScope.map
        : _FilterScope.explore;
    _draft = widget.initialFilters ??
        (_scope == _FilterScope.map
            ? ref.read(mapFiltersProvider)
            : ref.read(exploreFiltersProvider));
    unawaited(_loadPresets());
  }

  @override
  void dispose() {
    _presetNameCtrl.dispose();
    super.dispose();
  }

  String _presetStorageScope() {
    final userId = ref.read(currentUserProvider)?.id ?? 'guest';
    return '${_scope.name}:$userId';
  }

  void _showPresetFeedback(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadPresets() async {
    final storage = ref.read(localStorageServiceProvider);
    if (storage == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _presets = const <FilterPreset>[];
        _isLoadingPresets = false;
      });
      return;
    }

    final presets = await storage.loadFilterPresets(_presetStorageScope());
    if (!mounted) {
      return;
    }
    setState(() {
      _presets = presets;
      _isLoadingPresets = false;
    });
  }

  Future<void> _persistPresets(List<FilterPreset> presets) async {
    final storage = ref.read(localStorageServiceProvider);
    if (storage == null) {
      return;
    }
    await storage.saveFilterPresets(_presetStorageScope(), presets);
  }

  Future<void> _applyFiltersAndClose(Filters filters) async {
    final notifier = ref.read(cafeProvider.notifier);
    if (_scope == _FilterScope.map) {
      await notifier.setMapFilters(filters);
    } else {
      await notifier.setExploreFilters(filters);
    }
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _savePreset() async {
    final name = _presetNameCtrl.text.trim();
    if (name.isEmpty) {
      _showPresetFeedback('Preset name cannot be empty.');
      return;
    }
    if (_draft.activeCount == 0) {
      _showPresetFeedback('Add at least one filter before saving a preset.');
      return;
    }

    final now = DateTime.now().toUtc();
    final editingPreset = _editingPresetId == null
        ? null
        : _presets.where((preset) => preset.id == _editingPresetId).firstWhere(
              (_) => true,
              orElse: () => const FilterPreset(
                id: '',
                name: '',
                filters: Filters.empty,
              ),
            );
    final normalizedName = name.toLowerCase();
    final matchedByName = _presets.where((preset) {
      return preset.name.toLowerCase() == normalizedName;
    }).firstWhere(
      (_) => true,
      orElse: () => const FilterPreset(
        id: '',
        name: '',
        filters: Filters.empty,
      ),
    );
    final hasEditingPreset =
        editingPreset != null && editingPreset.id.isNotEmpty;
    final hasNameMatch = matchedByName.id.isNotEmpty;

    final basePreset = hasEditingPreset
        ? editingPreset
        : hasNameMatch
            ? matchedByName
            : null;
    final wasOverwrite = basePreset != null;
    final target = (basePreset ??
            FilterPreset(
              id: 'preset-${now.microsecondsSinceEpoch}',
              name: name,
              filters: _draft,
              createdAt: now,
              updatedAt: now,
            ))
        .copyWith(
      name: name,
      filters: _draft,
      createdAt: () => basePreset?.createdAt ?? now,
      updatedAt: () => now,
    );

    final next = <FilterPreset>[
      for (final preset in _presets)
        if (preset.id != target.id) preset,
      target,
    ]..sort((left, right) {
        final leftUpdated = left.updatedAt ??
            left.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final rightUpdated = right.updatedAt ??
            right.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return rightUpdated.compareTo(leftUpdated);
      });

    setState(() {
      _presets = next;
      _editingPresetId = target.id;
      _presetNameCtrl.text = target.name;
    });
    await _persistPresets(next);
    _showPresetFeedback(wasOverwrite ? 'Preset updated.' : 'Preset saved.');
  }

  Future<void> _deletePreset(FilterPreset preset) async {
    final next =
        _presets.where((item) => item.id != preset.id).toList(growable: false);
    setState(() {
      _presets = next;
      if (_editingPresetId == preset.id) {
        _editingPresetId = null;
        _presetNameCtrl.clear();
      }
    });
    await _persistPresets(next);
    _showPresetFeedback('Preset deleted.');
  }

  Future<void> _applyPreset(FilterPreset preset) async {
    setState(() {
      _editingPresetId = preset.id;
      _presetNameCtrl.text = preset.name;
      _draft = preset.filters;
    });

    final notifier = ref.read(cafeProvider.notifier);
    if (_scope == _FilterScope.map) {
      await notifier.setMapFilters(preset.filters);
    } else {
      await notifier.setExploreFilters(preset.filters);
    }

    _showPresetFeedback('Preset applied.');
  }

  void _startPresetEdit(FilterPreset preset) {
    setState(() {
      _editingPresetId = preset.id;
      _presetNameCtrl.text = preset.name;
      _draft = preset.filters;
    });
  }

  void _clearPresetEditor() {
    setState(() {
      _editingPresetId = null;
      _presetNameCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final l10n = context.l10n;
    final hasActiveFilters = _draft.activeCount > 0;
    final districts = ref.watch(districtOptionsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: AdaptivePage(
          maxWidth: 980,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = AdaptiveLayoutData.fromWidth(constraints.maxWidth);
              final sections = _buildSections(colors, l10n, districts);
              final columns = layout.filterColumns();
              final sectionWidth = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - layout.sectionSpacing) / columns;

              return FocusTraversalGroup(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: layout.sectionSpacing,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            key: const Key('filters-back-button'),
                            onPressed: () => context.pop(),
                            icon: Icon(
                              Icons.arrow_back,
                              size: 18,
                              color: colors.text,
                            ),
                            label: Text(
                              l10n.commonBack,
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                l10n.filterTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: layout.isTablet ? 24 : 22,
                                  fontWeight: FontWeight.w800,
                                  color: colors.text,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              key: const Key('filters-reset-button'),
                              onPressed: hasActiveFilters
                                  ? () => setState(() => _draft = Filters.empty)
                                  : null,
                              icon: Icon(
                                Icons.restart_alt_rounded,
                                size: 18,
                                color: hasActiveFilters
                                    ? colors.danger
                                    : colors.mutedText,
                              ),
                              label: Text(
                                l10n.commonReset,
                                style: TextStyle(
                                  color: hasActiveFilters
                                      ? colors.danger
                                      : colors.mutedText,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: hasActiveFilters
                                    ? colors.primarySoft
                                    : colors.card,
                                foregroundColor: hasActiveFilters
                                    ? colors.danger
                                    : colors.mutedText,
                                disabledBackgroundColor: colors.card,
                                disabledForegroundColor: colors.mutedText,
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm + 2,
                                ),
                                side: BorderSide(
                                  color: hasActiveFilters
                                      ? colors.danger.withValues(alpha: 0.18)
                                      : colors.border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          Wrap(
                            spacing: layout.sectionSpacing,
                            runSpacing: layout.sectionSpacing,
                            children: sections
                                .map(
                                  (section) => SizedBox(
                                    width: sectionWidth,
                                    child: section,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          SizedBox(height: layout.sectionSpacing * 2),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: layout.sectionSpacing,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('filters-apply-button'),
                          onPressed: () {
                            unawaited(_applyFiltersAndClose(_draft));
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.card,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                          child: Text(
                            _draft.activeCount > 0
                                ? l10n.filterApplyCount(_draft.activeCount)
                                : l10n.commonApply,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(
    AppColors colors,
    AppLocalizations l10n,
    List<String> districts,
  ) {
    return [
      _buildPresetSection(colors, l10n),
      _FilterSectionCard(
        colors: colors,
        title: l10n.commonCategory,
        child: _chipRow(
          cafeCategoryOptions
              .map((value) => (value, cafeCategoryValueLabel(l10n, value)))
              .toList(),
          _draft.category?.value,
          (v) => setState(() => _draft = _draft.copyWith(
                category: () {
                  final parsed = CafeCategoryExtension.fromString(v);
                  return _draft.category == parsed ? null : parsed;
                },
              )),
          colors,
        ),
      ),
      _FilterSectionCard(
        colors: colors,
        title: l10n.filterDistrict,
        child: _multiChipRow(
          districts.map((d) => (d, districtLabel(l10n, d))).toList(),
          _draft.effectiveDistricts,
          (v) => setState(() => _draft = _draft.copyWith(
                district: () {
                  final next = Set<String>.from(_draft.effectiveDistricts);
                  if (next.contains(v)) {
                    next.remove(v);
                  } else {
                    next.add(v);
                  }
                  return next.length == 1 ? next.single : null;
                },
                selectedDistricts: () {
                  final next = Set<String>.from(_draft.effectiveDistricts);
                  if (next.contains(v)) {
                    next.remove(v);
                  } else {
                    next.add(v);
                  }
                  return next;
                },
                neighborhood: () => null,
              )),
          colors,
        ),
      ),
      _FilterSectionCard(
        colors: colors,
        title: l10n.filterPrice,
        child: _chipRow(
          priceLevels.map((v) => (v, v)).toList(),
          _draft.priceLevel?.value,
          (v) => setState(() => _draft = _draft.copyWith(
                priceLevel: () {
                  final parsed = PriceLevelExtension.fromString(v);
                  return _draft.priceLevel == parsed ? null : parsed;
                },
              )),
          colors,
        ),
      ),
      _FilterSectionCard(
        colors: colors,
        title: l10n.filterMinRating,
        child: _chipRow(
          ['3.0', '3.5', '4.0', '4.5']
              .map((v) => (v, l10n.filterMinRatingOption(v)))
              .toList(),
          _draft.minRating?.toString(),
          (v) => setState(() => _draft = _draft.copyWith(
                minRating: () => v == _draft.minRating?.toString()
                    ? null
                    : double.tryParse(v),
              )),
          colors,
        ),
      ),
      _FilterSectionCard(
        colors: colors,
        title: l10n.filterWifi,
        child: _chipRow(
          wifiQualities.map((v) => (v, wifiLabel(l10n, v))).toList(),
          _draft.wifiQuality?.value,
          (v) => setState(() => _draft = _draft.copyWith(
                wifiQuality: () {
                  final parsed = WifiQualityExtension.fromString(v);
                  return _draft.wifiQuality == parsed ? null : parsed;
                },
              )),
          colors,
        ),
      ),
      _FilterSectionCard(
        colors: colors,
        title: l10n.filterOutlet,
        child: _chipRow(
          outletAvailabilities.map((v) => (v, outletLabel(l10n, v))).toList(),
          _draft.outletAvailability?.value,
          (v) => setState(() => _draft = _draft.copyWith(
                outletAvailability: () {
                  final parsed = OutletAvailabilityExtension.fromString(v);
                  return _draft.outletAvailability == parsed ? null : parsed;
                },
              )),
          colors,
        ),
      ),
      _FilterSectionCard(
        colors: colors,
        title: l10n.filterQuietness,
        child: _chipRow(
          quietnessLevels.map((v) => (v, quietnessLabel(l10n, v))).toList(),
          _draft.quietnessLevel?.value,
          (v) => setState(() => _draft = _draft.copyWith(
                quietnessLevel: () {
                  final parsed = QuietnessLevelExtension.fromString(v);
                  return _draft.quietnessLevel == parsed ? null : parsed;
                },
              )),
          colors,
        ),
      ),
      _FilterSectionCard(
        colors: colors,
        title: l10n.filterSmoking,
        child: _chipRow(
          smokingPolicies.map((v) => (v, smokingPolicyLabel(l10n, v))).toList(),
          _draft.smokingPolicy?.value,
          (v) => setState(() => _draft = _draft.copyWith(
                smokingPolicy: () {
                  final parsed = SmokingPolicyExtension.fromString(v);
                  return _draft.smokingPolicy == parsed ? null : parsed;
                },
              )),
          colors,
        ),
      ),
      _FilterSectionCard(
        colors: colors,
        title: l10n.filterTitle,
        child: Column(
          children: [
            _toggleRow(
              colors,
              l10n.filterOpenNow,
              _draft.openNow,
              (v) => setState(() => _draft = _draft.copyWith(
                    openNow: () => v ? true : null,
                  )),
            ),
            _toggleRow(
              colors,
              l10n.filterStudyFriendly,
              _draft.studyFriendly,
              (v) => setState(() => _draft = _draft.copyWith(
                    studyFriendly: () => v ? true : null,
                  )),
            ),
            _toggleRow(
              colors,
              l10n.filterPetFriendly,
              _draft.petFriendly,
              (v) => setState(() => _draft = _draft.copyWith(
                    petFriendly: () => v ? true : null,
                  )),
            ),
            _toggleRow(
              colors,
              l10n.filterOutdoorSeating,
              _draft.outdoorSeating,
              (v) => setState(() => _draft = _draft.copyWith(
                    outdoorSeating: () => v ? true : null,
                  )),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildPresetSection(AppColors colors, AppLocalizations l10n) {
    final isEditing = _editingPresetId != null;

    return _FilterSectionCard(
      colors: colors,
      title: 'Presets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('filter-preset-name-input'),
                  controller: _presetNameCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => unawaited(_savePreset()),
                  decoration: InputDecoration(
                    hintText: 'Save current filters as a preset',
                    filled: true,
                    fillColor: colors.card,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide(
                        color: colors.primary.withValues(alpha: 0.74),
                        width: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonal(
                key: const Key('filter-preset-save-button'),
                onPressed:
                    _isLoadingPresets ? null : () => unawaited(_savePreset()),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: Text(isEditing ? l10n.commonEdit : l10n.commonSave),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('filter-preset-clear-edit-button'),
                onPressed: _clearPresetEditor,
                child: Text(l10n.commonClear),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (_isLoadingPresets)
            const LinearProgressIndicator(minHeight: 2)
          else if (_presets.isEmpty)
            Text(
              'No presets yet. Save your current filters to reuse them.',
              style: TextStyle(
                color: colors.mutedText,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < _presets.length; index++)
                  _FilterPresetRow(
                    key: Key('filter-preset-row-$index'),
                    colors: colors,
                    preset: _presets[index],
                    isSelected: _presets[index].id == _editingPresetId,
                    index: index,
                    onApply: () => unawaited(_applyPreset(_presets[index])),
                    onEdit: () => _startPresetEdit(_presets[index]),
                    onDelete: () => unawaited(_deletePreset(_presets[index])),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chipRow(
    List<(String, String)> items,
    String? selected,
    void Function(String) onTap,
    AppColors colors,
  ) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: items.map((item) {
        final (value, label) = item;
        final active = selected == value;
        return ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              color: active ? colors.card : colors.text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          selected: active,
          showCheckmark: false,
          onSelected: (_) => onTap(value),
          side: BorderSide(color: active ? colors.primary : colors.border),
          backgroundColor: colors.card,
          selectedColor: colors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(growable: false),
    );
  }

  Widget _multiChipRow(
    List<(String, String)> items,
    Set<String> selected,
    void Function(String) onTap,
    AppColors colors,
  ) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: items.map((item) {
        final (value, label) = item;
        final active = selected.contains(value);
        return FilterChip(
          label: Text(
            label,
            style: TextStyle(
              color: active ? colors.card : colors.text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          selected: active,
          showCheckmark: false,
          onSelected: (_) => onTap(value),
          side: BorderSide(color: active ? colors.primary : colors.border),
          backgroundColor: colors.card,
          selectedColor: colors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(growable: false),
    );
  }

  Widget _toggleRow(
    AppColors colors,
    String label,
    bool? value,
    void Function(bool) onChanged,
  ) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile.adaptive(
            value: value ?? false,
            onChanged: onChanged,
            activeThumbColor: colors.primary,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            title: Text(
              label,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _FilterScope {
  explore,
  map,
}

enum FilterModalScope {
  explore,
  map,
}

class _FilterPresetRow extends StatelessWidget {
  const _FilterPresetRow({
    super.key,
    required this.colors,
    required this.preset,
    required this.isSelected,
    required this.index,
    required this.onApply,
    required this.onEdit,
    required this.onDelete,
  });

  final AppColors colors;
  final FilterPreset preset;
  final bool isSelected;
  final int index;
  final VoidCallback onApply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: isSelected ? colors.primarySoft : colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.3)
              : colors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${preset.filters.activeCount} filters',
                  style: TextStyle(
                    color: colors.mutedText,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('filter-preset-apply-$index'),
            tooltip: 'Apply',
            onPressed: onApply,
            icon: Icon(
              Icons.play_arrow_rounded,
              color: colors.primary,
            ),
          ),
          IconButton(
            key: Key('filter-preset-edit-$index'),
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: Icon(
              Icons.edit_outlined,
              color: colors.text,
              size: 20,
            ),
          ),
          IconButton(
            key: Key('filter-preset-delete-$index'),
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: colors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSectionCard extends StatelessWidget {
  const _FilterSectionCard({
    required this.colors,
    required this.title,
    required this.child,
  });

  final AppColors colors;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.text,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}
