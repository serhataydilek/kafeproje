import 'package:flutter/material.dart';

class ScreenContainer extends StatefulWidget {
  const ScreenContainer({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
  });
  final Widget child;
  final bool scrollable;
  final EdgeInsets padding;
  final Color? backgroundColor;

  @override
  State<ScreenContainer> createState() => _ScreenContainerState();
}

class _ScreenContainerState extends State<ScreenContainer> {
  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: widget.padding,
      child: widget.child,
    );

    if (widget.scrollable) {
      return SingleChildScrollView(
        child: content,
      );
    }

    return content;
  }
}
