import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/options.dart';
import '../l10n/l10n.dart';
import '../models/index.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final List<PreferenceKey> _selected = [];

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final canContinue = _selected.isNotEmpty;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: themeMode == AppThemeMode.dark
                        ? [const Color(0xFF2B2521), const Color(0xFF13110F)]
                        : [const Color(0xFFF2E3D6), const Color(0xFFF8F4EE)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onboardingBrand,
                      style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.onboardingTitle,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.onboardingSubtitle,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: preferenceOptions.map((pref) {
                      final active = _selected.contains(pref);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (active) {
                              _selected.remove(pref);
                            } else {
                              _selected.add(pref);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: active ? colors.primary : colors.chip,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: active ? colors.primary : colors.border,
                            ),
                          ),
                          child: Text(
                            preferenceLabel(l10n, pref),
                            style: TextStyle(
                              color: active ? colors.card : colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              GestureDetector(
                onTap: canContinue
                    ? () {
                        ref
                            .read(profileProvider.notifier)
                            .setPreferences(_selected);
                        ref
                            .read(appShellProvider.notifier)
                            .setOnboardingCompleted(true);
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.primary
                        .withValues(alpha: canContinue ? 1 : 0.45),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.onboardingContinue,
                    style: TextStyle(
                      color: colors.card,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
