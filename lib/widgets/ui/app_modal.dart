import 'package:flutter/material.dart';

import '../layout/adaptive_layout.dart';

const _AppModalTokens _appModalTokens = _AppModalTokens();

class _AppModalTokens {
  const _AppModalTokens();

  final Duration sheetEnterDuration = const Duration(milliseconds: 280);
  final Duration sheetExitDuration = const Duration(milliseconds: 210);
  final Duration dialogDuration = const Duration(milliseconds: 180);
  final Curve sheetEnterCurve = Curves.easeOutCubic;
  final Curve sheetExitCurve = Curves.easeInCubic;
  final Curve dialogCurve = Curves.easeOutCubic;
}

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool useRootNavigator = false,
  double? maxWidth,
}) async {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final overlay = navigator.overlay;
  if (overlay == null) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: true,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: _sheetConstraints(context, maxWidth: maxWidth),
      builder: builder,
    );
  }

  final controller = BottomSheet.createAnimationController(overlay)
    ..duration = _appModalTokens.sheetEnterDuration
    ..reverseDuration = _appModalTokens.sheetExitDuration;

  try {
    return await showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: true,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: _sheetConstraints(context, maxWidth: maxWidth),
      transitionAnimationController: controller,
      builder: (sheetContext) {
        return _AppModalAnimatedBody(
          animation: controller.view,
          child: builder(sheetContext),
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
}) {
  return showGeneralDialog<bool>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.26),
    transitionDuration: _appModalTokens.dialogDuration,
    pageBuilder: (dialogContext, __, ___) => builder(dialogContext),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: _appModalTokens.dialogCurve,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

BoxConstraints _sheetConstraints(
  BuildContext context, {
  double? maxWidth,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final layout = AdaptiveLayoutData.fromWidth(width);
  return BoxConstraints(
    maxWidth: maxWidth ?? (layout.isTablet ? 720 : layout.contentMaxWidth),
  );
}

class _AppModalAnimatedBody extends StatelessWidget {
  const _AppModalAnimatedBody({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: _appModalTokens.sheetEnterCurve,
      reverseCurve: _appModalTokens.sheetExitCurve,
    );

    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final offsetY = Tween<double>(begin: 0.02, end: 0).evaluate(curved);
        return Transform.translate(
          offset: Offset(0, MediaQuery.sizeOf(context).height * offsetY),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
