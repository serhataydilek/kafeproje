import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AppFormLabel extends StatelessWidget {
  const AppFormLabel({
    super.key,
    required this.colors,
    required this.text,
  });

  final AppColors colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: colors.text,
          fontSize: 14,
        ),
      ),
    );
  }
}

class AppFormInput extends StatelessWidget {
  const AppFormInput({
    super.key,
    required this.colors,
    required this.controller,
    required this.hint,
    this.multiline = false,
    this.maxLines,
    this.keyboardType,
    this.errorText,
    this.onChanged,
  });

  final AppColors colors;
  final TextEditingController controller;
  final String hint;
  final bool multiline;
  final int? maxLines;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: controller,
        maxLines: maxLines ?? (multiline ? 3 : 1),
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(color: colors.text),
        decoration: InputDecoration(
          hintText: hint,
          errorText: errorText,
          hintStyle: TextStyle(color: colors.mutedText),
          filled: true,
          fillColor: colors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: colors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class AppFormHelperText extends StatelessWidget {
  const AppFormHelperText({
    super.key,
    required this.colors,
    required this.text,
  });

  final AppColors colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: TextStyle(
          color: colors.mutedText,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}

class AppFormOptionRow<T> extends StatelessWidget {
  const AppFormOptionRow({
    super.key,
    required this.colors,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onTap,
  });

  final AppColors colors;
  final List<T> options;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: options.map((option) {
          final active = selected == option;
          return GestureDetector(
            onTap: () => onTap(option),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: active ? colors.primary : colors.card,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: active ? colors.primary : colors.border,
                ),
              ),
              child: Text(
                labelBuilder(option),
                style: TextStyle(
                  color: active ? colors.card : colors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AppFormToggle extends StatelessWidget {
  const AppFormToggle({
    super.key,
    required this.colors,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final AppColors colors;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
