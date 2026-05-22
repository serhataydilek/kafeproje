import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    super.key,
    required this.controller,
    required this.colors,
    required this.onChanged,
    this.hintText = 'Search cafes, districts, or vibes',
    this.onSubmitted,
    this.onFilterTap,
    this.onClear,
    this.filterTooltip,
    this.filterButtonKey,
    this.activeFilterCount = 0,
    this.textInputAction = TextInputAction.search,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final AppColors colors;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final VoidCallback? onClear;
  final String hintText;
  final String? filterTooltip;
  final Key? filterButtonKey;
  final int activeFilterCount;
  final TextInputAction textInputAction;
  final bool autofocus;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clear() {
    widget.controller.clear();
    if (widget.onClear != null) {
      widget.onClear!();
      return;
    }
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final hasInput = value.text.trim().isNotEmpty;
        final isFocused = _focusNode.hasFocus;
        final borderColor = isFocused
            ? widget.colors.primary.withValues(alpha: 0.58)
            : hasInput
                ? widget.colors.primary.withValues(alpha: 0.24)
                : widget.colors.border;
        final fillColor = hasInput || isFocused
            ? widget.colors.card
            : widget.colors.card.withValues(alpha: 0.92);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(
                color: (isFocused
                        ? widget.colors.primary
                        : Colors.black.withValues(alpha: 0.3))
                    .withValues(alpha: isFocused ? 0.14 : 0.05),
                blurRadius: isFocused ? 20 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            textInputAction: widget.textInputAction,
            style: TextStyle(
              color: widget.colors.text,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: widget.colors.mutedText,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 6,
              ),
              filled: true,
              fillColor: fillColor,
              prefixIcon: Icon(
                Icons.search_rounded,
                color:
                    isFocused ? widget.colors.primary : widget.colors.mutedText,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasInput)
                    IconButton(
                      tooltip: 'Clear search',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        color: widget.colors.mutedText,
                      ),
                      onPressed: _clear,
                    ),
                  if (widget.activeFilterCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${widget.activeFilterCount}',
                        style: TextStyle(
                          color: widget.colors.card,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (widget.onFilterTap != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: IconButton(
                        key: widget.filterButtonKey,
                        tooltip: widget.filterTooltip,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              widget.colors.primary.withValues(alpha: 0.1),
                          foregroundColor: widget.colors.primary,
                        ),
                        icon: const Icon(Icons.tune_rounded),
                        onPressed: widget.onFilterTap,
                      ),
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide(
                  color: widget.colors.primary.withValues(alpha: 0.75),
                  width: 1.4,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    this.placeholder = 'Ara...',
    required this.onChanged,
    this.onClear,
  });
  final String placeholder;
  final Function(String) onChanged;
  final Function()? onClear;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  // SearchBar manages its own controller, so callers only provide callbacks.
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors(
      bg: scheme.surface,
      card: scheme.surface,
      text: scheme.onSurface,
      mutedText: scheme.onSurfaceVariant,
      border: scheme.outlineVariant,
      primary: scheme.primary,
      primarySoft: scheme.primaryContainer,
      accent: scheme.secondary,
      danger: scheme.error,
      chip: scheme.surfaceContainerHighest,
    );

    return AppSearchBar(
      controller: _controller,
      colors: colors,
      hintText: widget.placeholder,
      onChanged: widget.onChanged,
      onClear: widget.onClear,
    );
  }
}
