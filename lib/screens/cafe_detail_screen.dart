import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/cafes/cafe_detail_screen_sections.dart';

class CafeDetailScreen extends ConsumerWidget {
  const CafeDetailScreen({
    super.key,
    required this.cafeId,
    this.source,
  });

  final String cafeId;
  final String? source;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(_fallbackRouteForSource(source));
  }

  String _fallbackRouteForSource(String? source) {
    return switch (source?.trim().toLowerCase()) {
      'map' => '/map',
      'favorites' => '/favorites',
      _ => '/explore',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    return Scaffold(
      backgroundColor: colors.bg,
      body: CafeDetailBody(
        cafeId: cafeId,
        colors: colors,
        onBack: () => _goBack(context),
      ),
    );
  }
}
