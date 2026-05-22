import '../models/index.dart';

const double istanbulCenterLat = 41.0082;
const double istanbulCenterLng = 28.9784;

const Coordinates istanbulCenterCoordinates = Coordinates(
  lat: istanbulCenterLat,
  lng: istanbulCenterLng,
);

const double istanbulSouthwestLat = 40.8020;
const double istanbulSouthwestLng = 28.5120;
const double istanbulNortheastLat = 41.3380;
const double istanbulNortheastLng = 29.3780;

bool isWithinIstanbul(double lat, double lng) {
  return lat >= istanbulSouthwestLat &&
      lat <= istanbulNortheastLat &&
      lng >= istanbulSouthwestLng &&
      lng <= istanbulNortheastLng;
}
