import 'package:flutter/material.dart';

class Chip extends StatelessWidget {
  const Chip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onSelected,
    this.selectedColor,
    this.unselectedColor,
  });
  final String label;
  final bool isSelected;
  final Function(bool)? onSelected;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: onSelected,
        backgroundColor: unselectedColor ?? Colors.grey[200],
        selectedColor: selectedColor ?? Theme.of(context).primaryColor,
      ),
    );
  }
}
