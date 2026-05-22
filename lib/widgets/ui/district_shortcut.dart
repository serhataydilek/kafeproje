import 'package:flutter/material.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/l10n/l10n.dart';

class DistrictShortcut extends StatelessWidget {
  const DistrictShortcut({
    super.key,
    required this.district,
    this.isSelected = false,
    this.onPressed,
  });
  final District district;
  final bool isSelected;
  final Function(District)? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      child: InkWell(
        onTap: () => onPressed?.call(district),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            districtLabel(l10n, district.value),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
