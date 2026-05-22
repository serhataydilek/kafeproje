import 'dart:math';

import '../models/index.dart';
import 'cafe_hours.dart';

bool isOpenNow(List<OpeningHour> openingHours) {
  return resolveCafeOpenState(openingHours);
}

double _toRadians(double value) => value * pi / 180;

double distanceKm(Coordinates from, Coordinates to) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRadians(to.lat - from.lat);
  final dLng = _toRadians(to.lng - from.lng);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(from.lat)) *
          cos(_toRadians(to.lat)) *
          sin(dLng / 2) *
          sin(dLng / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}
