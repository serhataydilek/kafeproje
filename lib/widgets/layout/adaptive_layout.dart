import 'package:flutter/material.dart';

enum AdaptiveSizeClass {
  compactPhone,
  standardPhone,
  largePhone,
  tablet,
}

class AdaptiveLayoutData {
  const AdaptiveLayoutData._({
    required this.width,
    required this.sizeClass,
    required this.horizontalPadding,
    required this.sectionSpacing,
    required this.contentMaxWidth,
  });

  factory AdaptiveLayoutData.fromWidth(double width) {
    if (width >= 840) {
      return AdaptiveLayoutData._(
        width: width,
        sizeClass: AdaptiveSizeClass.tablet,
        horizontalPadding: 24,
        sectionSpacing: 24,
        contentMaxWidth: 1120,
      );
    }
    if (width >= 600) {
      return AdaptiveLayoutData._(
        width: width,
        sizeClass: AdaptiveSizeClass.largePhone,
        horizontalPadding: 20,
        sectionSpacing: 20,
        contentMaxWidth: 760,
      );
    }
    if (width >= 390) {
      return AdaptiveLayoutData._(
        width: width,
        sizeClass: AdaptiveSizeClass.standardPhone,
        horizontalPadding: 16,
        sectionSpacing: 16,
        contentMaxWidth: 560,
      );
    }

    return AdaptiveLayoutData._(
      width: width,
      sizeClass: AdaptiveSizeClass.compactPhone,
      horizontalPadding: 12,
      sectionSpacing: 14,
      contentMaxWidth: 520,
    );
  }

  final double width;
  final AdaptiveSizeClass sizeClass;
  final double horizontalPadding;
  final double sectionSpacing;
  final double contentMaxWidth;

  bool get isCompactPhone => sizeClass == AdaptiveSizeClass.compactPhone;
  bool get isPhone => sizeClass != AdaptiveSizeClass.tablet;
  bool get isLargePhoneOrWider =>
      sizeClass == AdaptiveSizeClass.largePhone ||
      sizeClass == AdaptiveSizeClass.tablet;
  bool get isTablet => sizeClass == AdaptiveSizeClass.tablet;
  bool get usesSplitContent => width >= 900;
  bool get usesWrappedChips => isLargePhoneOrWider;

  int cafeCardColumns({
    int maxColumns = 3,
  }) {
    if (width >= 1180) {
      return maxColumns.clamp(1, 3);
    }
    if (width >= 840) {
      return maxColumns >= 2 ? 2 : 1;
    }
    return 1;
  }

  int filterColumns() {
    if (width >= 980) {
      return 2;
    }
    return 1;
  }

  int adminColumns() {
    if (width >= 980) {
      return 2;
    }
    return 1;
  }

  double compareContentMaxWidth() {
    if (width >= 1100) {
      return 1180;
    }
    return contentMaxWidth;
  }

  double detailExpandedHeight() {
    if (width >= 840) {
      return 320;
    }
    if (width >= 600) {
      return 290;
    }
    return 250;
  }
}

class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AdaptiveLayoutData.fromWidth(constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? layout.contentMaxWidth,
            ),
            child: Padding(
              padding: padding ??
                  EdgeInsets.symmetric(horizontal: layout.horizontalPadding),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
