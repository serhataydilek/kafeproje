import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/index.dart';
import '../../theme/app_theme.dart';
import '../../utils/cafe_hours.dart';

class OpeningHoursEditor extends StatefulWidget {
  const OpeningHoursEditor({
    super.key,
    required this.colors,
    required this.initialHours,
    required this.onChanged,
  });

  final AppColors colors;
  final List<OpeningHour> initialHours;
  final ValueChanged<List<OpeningHour>> onChanged;

  @override
  State<OpeningHoursEditor> createState() => _OpeningHoursEditorState();
}

class _OpeningHoursEditorState extends State<OpeningHoursEditor> {
  late final Map<String, TextEditingController> _openControllers;
  late final Map<String, TextEditingController> _closeControllers;
  late final Map<String, bool> _closedByDay;

  @override
  void initState() {
    super.initState();
    final normalized = normalizeWeeklyHours(widget.initialHours);
    _openControllers = {
      for (final hour in normalized)
        hour.day: TextEditingController(text: hour.open ?? ''),
    };
    _closeControllers = {
      for (final hour in normalized)
        hour.day: TextEditingController(text: hour.close ?? ''),
    };
    _closedByDay = {
      for (final hour in normalized) hour.day: hour.closed || !hour.hasSchedule,
    };
  }

  @override
  void dispose() {
    for (final controller in _openControllers.values) {
      controller.dispose();
    }
    for (final controller in _closeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final hours = canonicalWeekdays.map((day) {
      final isClosed = _closedByDay[day] ?? false;
      final open = _openControllers[day]!.text.trim();
      final close = _closeControllers[day]!.text.trim();
      return OpeningHour(
        day: day,
        open: isClosed || open.isEmpty ? null : open,
        close: isClosed || close.isEmpty ? null : close,
        closed: isClosed,
      );
    }).toList(growable: false);

    widget.onChanged(hours);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: canonicalWeekdays.map((day) {
        final isClosed = _closedByDay[day] ?? false;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  dayLabel(l10n, day),
                  style: TextStyle(
                    color: widget.colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _openControllers[day],
                  enabled: !isClosed,
                  onChanged: (_) => _emit(),
                  decoration: InputDecoration(
                    hintText: '08:00',
                    isDense: true,
                    filled: true,
                    fillColor: widget.colors.card,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _closeControllers[day],
                  enabled: !isClosed,
                  onChanged: (_) => _emit(),
                  decoration: InputDecoration(
                    hintText: '22:00',
                    isDense: true,
                    filled: true,
                    fillColor: widget.colors.card,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(
                value: isClosed,
                onChanged: (value) {
                  setState(() => _closedByDay[day] = value);
                  _emit();
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
