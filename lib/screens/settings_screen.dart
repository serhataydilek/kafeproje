import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/l10n.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/list_tiles.dart';
import '../widgets/layout/adaptive_layout.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = 'v${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      if (mounted) setState(() => _version = 'v1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final localeMode = ref.watch(localeModeProvider);
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final themeNotifier = ref.read(appShellProvider.notifier);
    final localeNotifier = ref.read(localeModeProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/profile');
          },
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
        ),
        title: Text(
          l10n.commonSettings,
          style: TextStyle(
            color: colors.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: AdaptivePage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              0,
              AppSpacing.sm,
              0,
              AppSpacing.xl,
            ),
            children: [
              AppSectionTitle(colors: colors, title: l10n.commonTheme),
              const SizedBox(height: AppSpacing.sm),
              ...[
                (AppThemeMode.light, l10n.commonLight, Icons.light_mode),
                (AppThemeMode.dark, l10n.commonDark, Icons.dark_mode),
                (
                  AppThemeMode.system,
                  l10n.commonSystem,
                  Icons.settings_brightness,
                ),
              ].map((item) {
                final (mode, label, icon) = item;
                final active = themeMode == mode;
                return AppRadioTile(
                  icon: icon,
                  label: label,
                  colors: colors,
                  active: active,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeNotifier.setThemeMode(mode);
                  },
                );
              }),
              const SizedBox(height: AppSpacing.md),
              AppSectionTitle(colors: colors, title: l10n.commonLanguage),
              const SizedBox(height: AppSpacing.sm),
              ...[
                (AppLocaleMode.system, l10n.commonSystemLanguage),
                (AppLocaleMode.tr, l10n.commonTurkish),
                (AppLocaleMode.en, l10n.commonEnglish),
              ].map((item) {
                final (mode, label) = item;
                final active = localeMode == mode;
                return AppRadioTile(
                  icon: Icons.language,
                  label: label,
                  colors: colors,
                  active: active,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    localeNotifier.setLocaleMode(mode);
                  },
                );
              }),
              const SizedBox(height: AppSpacing.md),
              AppSectionTitle(colors: colors, title: l10n.commonAbout),
              const SizedBox(height: AppSpacing.sm),
              Container(
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
                      l10n.appTitle,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _version.isEmpty ? l10n.commonLoading : _version,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.settingsAboutDescription,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
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
