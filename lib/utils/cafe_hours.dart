import '../models/cafe.dart';

enum CafeOpenStatus {
  open,
  closed,
  unknown,
}

const Map<String, int> _weekdayIndices = {
  'Sun': 0,
  'Sunday': 0,
  'Mon': 1,
  'Monday': 1,
  'Tue': 2,
  'Tuesday': 2,
  'Wed': 3,
  'Wednesday': 3,
  'Thu': 4,
  'Thursday': 4,
  'Fri': 5,
  'Friday': 5,
  'Sat': 6,
  'Saturday': 6,
};

const List<String> canonicalWeekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String canonicalWeekday(String value) {
  final trimmed = value.trim();
  for (final entry in _weekdayIndices.entries) {
    if (entry.key.toLowerCase() == trimmed.toLowerCase()) {
      return canonicalWeekdays[(entry.value + 6) % 7];
    }
  }
  return trimmed.isEmpty ? 'Mon' : trimmed;
}

List<OpeningHour> parseOpeningHours(Object? raw) {
  if (raw is! List) {
    return const [];
  }

  final hours = raw
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry('$key', value)))
      .map(OpeningHour.fromJson)
      .toList(growable: false);

  return normalizeWeeklyHours(hours);
}

List<OpeningHour> parseGoogleOpeningHours(Object? raw) {
  if (raw is! Map<String, dynamic>) {
    return const [];
  }

  final periods = raw['periods'];
  if (periods is! List) {
    return const [];
  }

  final byDay = <int, OpeningHour>{};
  for (final period in periods.whereType<Map<String, dynamic>>()) {
    final open = period['open'] as Map<String, dynamic>?;
    final close = period['close'] as Map<String, dynamic>?;
    final openDay = (open?['day'] as int?) ?? 0;
    final openHour = (open?['hour'] as int?) ?? 0;
    final openMinute = (open?['minute'] as int?) ?? 0;
    final closeHour = (close?['hour'] as int?) ?? 0;
    final closeMinute = (close?['minute'] as int?) ?? 0;
    byDay[openDay] = OpeningHour(
      day: canonicalWeekdays[(openDay + 6) % 7],
      open: _formatTime(openHour, openMinute),
      close: _formatTime(closeHour, closeMinute),
    );
  }

  return normalizeWeeklyHours(byDay.values.toList(growable: false));
}

bool? parseGoogleOpenNow(Object? raw) {
  if (raw is! Map<String, dynamic>) {
    return null;
  }
  final direct = raw['openNow'];
  if (direct is bool) {
    return direct;
  }
  final legacy = raw['open_now'];
  if (legacy is bool) {
    return legacy;
  }
  return null;
}

List<OpeningHour> normalizeWeeklyHours(List<OpeningHour> hours) {
  final byDay = <String, OpeningHour>{
    for (final hour in hours) canonicalWeekday(hour.day): hour,
  };

  return canonicalWeekdays
      .map(
        (day) =>
            byDay[day] ??
            OpeningHour(
              day: day,
              closed: true,
            ),
      )
      .toList(growable: false);
}

bool isOpenNow(List<OpeningHour> openingHours) {
  return resolveCafeOpenState(openingHours);
}

CafeOpenStatus resolveCafeOpenStatus(Cafe cafe, {DateTime? now}) {
  final explicitGoogleOpenNow = cafe.googlePlaceData?.googleOpenNow;
  if (explicitGoogleOpenNow != null) {
    return explicitGoogleOpenNow
        ? CafeOpenStatus.open
        : CafeOpenStatus.closed;
  }
  if (!cafe.hasWorkingHours) {
    return CafeOpenStatus.unknown;
  }
  return cafe.openNow || resolveCafeOpenState(cafe.openingHours, now: now)
      ? CafeOpenStatus.open
      : CafeOpenStatus.closed;
}

bool resolveCafeOpenState(List<OpeningHour> openingHours, {DateTime? now}) {
  if (openingHours.isEmpty) {
    return false;
  }

  final moment = now ?? DateTime.now();
  final currentDayIndex = moment.weekday % 7;
  final currentMinutes = moment.hour * 60 + moment.minute;

  for (final hour in openingHours) {
    final mappedDay = _weekdayIndices[hour.day];
    if (mappedDay == null || !hour.hasSchedule) {
      continue;
    }

    final openMinutes = _parseMinutes(hour.open!);
    final closeMinutes = _parseMinutes(hour.close!);
    if (openMinutes == null || closeMinutes == null) {
      continue;
    }

    final previousDay = (mappedDay - 1) < 0 ? 6 : mappedDay - 1;
    final overnight = closeMinutes <= openMinutes;

    if (mappedDay == currentDayIndex) {
      if (!overnight &&
          currentMinutes >= openMinutes &&
          currentMinutes < closeMinutes) {
        return true;
      }
      if (overnight && currentMinutes >= openMinutes) {
        return true;
      }
    }

    if (overnight &&
        previousDay == currentDayIndex &&
        currentMinutes < closeMinutes) {
      return true;
    }
  }

  return false;
}

String formatWorkingHoursRange(OpeningHour hour) {
  if (!hour.hasSchedule) {
    return 'No data';
  }
  return '${hour.open} - ${hour.close}';
}

String summarizeWorkingHours(List<OpeningHour> hours) {
  final today = canonicalWeekdays[(DateTime.now().weekday + 6) % 7];
  for (final entry in hours) {
    if (entry.day == today) {
      return entry.hasSchedule ? formatWorkingHoursRange(entry) : 'No data';
    }
  }
  return 'No data';
}

List<String> compactWorkingHours(List<OpeningHour> hours) {
  if (hours.isEmpty) {
    return const ['No data'];
  }

  final normalizedHours = normalizeWeeklyHours(hours);
  final rows = <String>[];
  var rangeStart = 0;

  while (rangeStart < normalizedHours.length) {
    final current = normalizedHours[rangeStart];
    final currentLabel = formatWorkingHoursRange(current);
    var rangeEnd = rangeStart;

    while (rangeEnd + 1 < normalizedHours.length &&
        formatWorkingHoursRange(normalizedHours[rangeEnd + 1]) ==
            currentLabel) {
      rangeEnd++;
    }

    final startDay = normalizedHours[rangeStart].day;
    final endDay = normalizedHours[rangeEnd].day;
    final dayLabel = rangeStart == rangeEnd ? startDay : '$startDay-$endDay';
    rows.add('$dayLabel  $currentLabel');
    rangeStart = rangeEnd + 1;
  }

  return rows;
}

String _formatTime(int hour, int minute) {
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

int? _parseMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return hour * 60 + minute;
}
