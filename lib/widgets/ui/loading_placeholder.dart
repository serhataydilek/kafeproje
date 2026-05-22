import 'package:flutter/material.dart';

class LoadingPlaceholder extends StatelessWidget {
  const LoadingPlaceholder({
    super.key,
    this.width = double.infinity,
    this.height = 100,
    this.borderRadius,
  });
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
