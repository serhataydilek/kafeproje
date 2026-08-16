import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, system }

class AppColors {
  const AppColors({
    required this.bg,
    required this.card,
    required this.text,
    required this.mutedText,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.accent,
    required this.danger,
    required this.chip,
  });
  final Color bg;
  final Color card;
  final Color text;
  final Color mutedText;
  final Color border;
  final Color primary;
  final Color primarySoft;
  final Color accent;
  final Color danger;
  final Color chip;
}

const lightColors = AppColors(
  bg: Color(0xFFF8F4EE),
  card: Color(0xFFFFFFFF),
  text: Color(0xFF1A1A1A),
  mutedText: Color(0xFF8E8E93),
  border: Color(0xFFE5E5EA),
  primary: Color(0xFFB5651D),
  primarySoft: Color(0xFFF2E3D6),
  accent: Color(0xFF34C759),
  danger: Color(0xFFFF3B30),
  chip: Color(0xFFF2F2F7),
);

const darkColors = AppColors(
  bg: Color(0xFF13110F),
  card: Color(0xFF1C1C1E),
  text: Color(0xFFF2F2F7),
  mutedText: Color(0xFF8E8E93),
  border: Color(0xFF38383A),
  primary: Color(0xFFD4915E),
  primarySoft: Color(0xFF2B2521),
  accent: Color(0xFF30D158),
  danger: Color(0xFFFF453A),
  chip: Color(0xFF2C2C2E),
);

AppColors getThemeColors(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return lightColors;
    case AppThemeMode.dark:
      return darkColors;
    case AppThemeMode.system:
      return lightColors;
  }
}

AppColors resolveColors(AppThemeMode mode, Brightness platformBrightness) {
  if (mode == AppThemeMode.system) {
    return platformBrightness == Brightness.dark ? darkColors : lightColors;
  }
  return getThemeColors(mode);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double pill = 999;
}

class BottomChromeTokens {
  static const double navContainerRadius = AppRadius.lg + 4;
  static const double navInnerRadius = AppRadius.lg;
  static const double navHeight = 66;
  static const double navSelectedIconSize = 22;
  static const double navIconSize = 21;
  static const double navLabelFontSize = 11;
  static const double compareFabIconSize = 16;
  static const double compareFabBadgeSize = 28;
}

Color onColor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : const Color(0xFF181512);
}

ThemeData _buildTheme(AppColors colors, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final surface = Color.alphaBlend(
    colors.card.withValues(alpha: isDark ? 0.94 : 0.98),
    colors.bg,
  );
  final elevatedSurface = Color.alphaBlend(
    colors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
    colors.card,
  );
  final primaryForeground = onColor(colors.primary);
  final indicatorColor = Color.alphaBlend(
    colors.primary.withValues(alpha: isDark ? 0.22 : 0.14),
    colors.card,
  );
  final selectedLabelColor = Color.alphaBlend(
    colors.primary.withValues(alpha: isDark ? 0.82 : 0.9),
    colors.text,
  );
  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
    brightness: brightness,
    primary: colors.primary,
    secondary: colors.accent,
    surface: surface,
  ).copyWith(
    onPrimary: primaryForeground,
    onSecondary: onColor(colors.accent),
    error: colors.danger,
    onError: onColor(colors.danger),
    onSurface: colors.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: colors.bg,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: colors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: colors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.card,
      hintStyle:
          TextStyle(color: colors.mutedText, fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 6,
      ),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.danger, width: 1.4),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: primaryForeground,
        disabledBackgroundColor: colors.chip,
        disabledForegroundColor: colors.mutedText,
        elevation: 0,
        shadowColor: colors.primary.withValues(alpha: 0.22),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
          vertical: AppSpacing.sm + 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: elevatedSurface,
        foregroundColor: colors.text,
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
          vertical: AppSpacing.sm + 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
          vertical: AppSpacing.sm + 6,
        ),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: primaryForeground,
      elevation: 1,
      focusElevation: 1,
      hoverElevation: 2,
      highlightElevation: 2,
      extendedPadding: const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      extendedTextStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: indicatorColor,
      height: BottomChromeTokens.navHeight,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? selectedLabelColor
            : colors.mutedText;
        return TextStyle(
          color: color,
          fontSize: BottomChromeTokens.navLabelFontSize,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
          letterSpacing: 0.08,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? colors.primary : colors.mutedText,
          size: selected
              ? BottomChromeTokens.navSelectedIconSize
              : BottomChromeTokens.navIconSize,
        );
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return colors.primary.withValues(alpha: isDark ? 0.18 : 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return colors.primary.withValues(alpha: isDark ? 0.12 : 0.08);
        }
        return null;
      }),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
  );
}

ThemeData buildLightTheme() {
  return _buildTheme(lightColors, Brightness.light);
}

ThemeData buildDarkTheme() {
  return _buildTheme(darkColors, Brightness.dark);
}
