import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A pulsing shimmer placeholder that mimics a cafe card skeleton.
class ShimmerCafeCard extends StatefulWidget {
  const ShimmerCafeCard({super.key, required this.colors});

  final AppColors colors;

  @override
  State<ShimmerCafeCard> createState() => _ShimmerCafeCardState();
}

class _ShimmerCafeCardState extends State<ShimmerCafeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final opacity = 0.3 + (_animation.value * 0.4);
        return Opacity(
          opacity: opacity,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: widget.colors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: widget.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image placeholder
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: widget.colors.chip,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Title placeholder
                Container(
                  height: 18,
                  width: 180,
                  decoration: BoxDecoration(
                    color: widget.colors.chip,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // Subtitle placeholder
                Container(
                  height: 14,
                  width: 120,
                  decoration: BoxDecoration(
                    color: widget.colors.chip,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Tags row placeholder
                Row(
                  children: List.generate(
                    3,
                    (_) => Container(
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      height: 24,
                      width: 60,
                      decoration: BoxDecoration(
                        color: widget.colors.chip,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A list of shimmer cafe card skeletons.
class ShimmerCafeList extends StatelessWidget {
  const ShimmerCafeList({
    super.key,
    required this.colors,
    this.itemCount = 3,
  });

  final AppColors colors;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl * 3),
      itemBuilder: (_, __) => ShimmerCafeCard(colors: colors),
    );
  }
}
