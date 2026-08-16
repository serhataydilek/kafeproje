import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../layout/adaptive_layout.dart';

class AdaptiveCafeCollection extends StatelessWidget {
  const AdaptiveCafeCollection({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.colors,
    this.padding = EdgeInsets.zero,
    this.cacheExtent,
    this.shrinkWrap = false,
    this.physics,
    this.maxColumns = 3,
    this.controller,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final AppColors colors;
  final EdgeInsets padding;
  final double? cacheExtent;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final int maxColumns;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AdaptiveLayoutData.fromWidth(constraints.maxWidth);
        final columns = layout.cafeCardColumns(maxColumns: maxColumns);

        if (columns == 1) {
          return ListView.builder(
            controller: controller,
            shrinkWrap: shrinkWrap,
            physics: physics,
            cacheExtent: cacheExtent,
            itemCount: itemCount,
            padding: padding,
            itemBuilder: itemBuilder,
          );
        }

        final spacing = layout.sectionSpacing;
        final availableWidth = constraints.maxWidth -
            padding.horizontal -
            (spacing * (columns - 1));
        final tileWidth = availableWidth / columns;
        final mainAxisExtent = tileWidth >= 340 ? 440.0 : 410.0;

        return GridView.builder(
          controller: controller,
          shrinkWrap: shrinkWrap,
          physics: physics,
          cacheExtent: cacheExtent,
          itemCount: itemCount,
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
