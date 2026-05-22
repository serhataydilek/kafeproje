import 'package:flutter/widgets.dart';

/// A mixin for [StatefulWidget]s that provides automatic lifecycle management
/// for [TextEditingController]s and a standardized submit-with-loading flag and error tracker.
mixin FormStateMixin<T extends StatefulWidget> on State<T> {
  final List<TextEditingController> _managedControllers = [];
  bool isSubmitting = false;
  String? formError;

  /// Creates a [TextEditingController] that will be automatically disposed
  /// when the state is disposed.
  TextEditingController useTextController({String? text}) {
    final ctrl = TextEditingController(text: text);
    _managedControllers.add(ctrl);
    return ctrl;
  }

  @override
  void dispose() {
    for (final ctrl in _managedControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Sets [isSubmitting] to true, clears the previous `formError`,
  /// executes the [action], and then sets [isSubmitting] back to false.
  ///
  /// Note: The [action] is responsible for throwing or setting custom errors
  /// manually via [setFormError] if `false` or errors occur.
  Future<void> submitWithLoading(Future<void> Function() action) async {
    if (isSubmitting) return;

    if (mounted) {
      setState(() {
        isSubmitting = true;
        formError = null;
      });
    }

    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => formError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  /// Safely overrides the local [formError] ensuring [setState] is guarded by [mounted].
  void setFormError(String? error) {
    if (mounted) {
      setState(() => formError = error);
    }
  }
}
