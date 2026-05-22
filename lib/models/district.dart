import '../utils/text_normalization.dart';

class District {
  const District({
    required this.id,
    required this.city,
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.searchRadiusMeters,
    this.northeastLat,
    this.northeastLng,
    this.southwestLat,
    this.southwestLng,
    this.aliases = const <String>[],
    this.isActive = true,
    this.sortOrder = 0,
  });

  static const District unknown = District(
    id: 'unknown',
    city: '',
    name: 'unknown',
    displayName: 'Unknown',
    latitude: 0,
    longitude: 0,
    isActive: true,
    sortOrder: 1 << 30,
  );

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: (json['id'] as String?)?.trim() ?? unknown.id,
      city: (json['city'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      displayName:
          (json['displayName'] as String?)?.trim() ??
          (json['display_name'] as String?)?.trim() ??
          unknown.displayName,
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
      searchRadiusMeters: _asInt(json['searchRadiusMeters'] ?? json['search_radius_meters']),
      northeastLat: _asDouble(json['northeastLat'] ?? json['northeast_lat']),
      northeastLng: _asDouble(json['northeastLng'] ?? json['northeast_lng']),
      southwestLat: _asDouble(json['southwestLat'] ?? json['southwest_lat']),
      southwestLng: _asDouble(json['southwestLng'] ?? json['southwest_lng']),
      aliases: _stringList(json['aliases']),
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      sortOrder: _asInt(json['sortOrder'] ?? json['sort_order']) ?? 0,
    );
  }

  static District? tryFromSupabaseRow(Map<String, dynamic> row) {
    final displayName =
        _trimmed(row['display_name']) ??
        _trimmed(row['displayName']) ??
        _trimmed(row['name']);
    final city = _trimmed(row['city']);
    final latitude = _asDouble(row['latitude']);
    final longitude = _asDouble(row['longitude']);
    if (displayName == null ||
        city == null ||
        latitude == null ||
        longitude == null) {
      return null;
    }

    final rawName =
        _trimmed(row['name']) ?? _normalizedDistrictKey(displayName);
    return District(
      id:
          _trimmed(row['id']) ??
          '${_normalizedDistrictKey(city)}:$rawName',
      city: city,
      name: rawName,
      displayName: displayName,
      latitude: latitude,
      longitude: longitude,
      searchRadiusMeters: _asInt(row['search_radius_meters']),
      northeastLat: _asDouble(row['northeast_lat']),
      northeastLng: _asDouble(row['northeast_lng']),
      southwestLat: _asDouble(row['southwest_lat']),
      southwestLng: _asDouble(row['southwest_lng']),
      aliases: _stringList(row['aliases']),
      isActive: row['is_active'] as bool? ?? true,
      sortOrder: _asInt(row['sort_order']) ?? 0,
    );
  }

  final String id;
  final String city;
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final int? searchRadiusMeters;
  final double? northeastLat;
  final double? northeastLng;
  final double? southwestLat;
  final double? southwestLng;
  final List<String> aliases;
  final bool isActive;
  final int sortOrder;

  String get value => displayName;

  bool get hasBounds =>
      northeastLat != null &&
      northeastLng != null &&
      southwestLat != null &&
      southwestLng != null;

  List<String> get searchTerms => <String>[
        displayName,
        name,
        ...aliases,
      ];

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'city': city,
      'name': name,
      'displayName': displayName,
      'latitude': latitude,
      'longitude': longitude,
      'searchRadiusMeters': searchRadiusMeters,
      'northeastLat': northeastLat,
      'northeastLng': northeastLng,
      'southwestLat': southwestLat,
      'southwestLng': southwestLng,
      'aliases': aliases,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }

  District copyWith({
    String? id,
    String? city,
    String? name,
    String? displayName,
    double? latitude,
    double? longitude,
    int? Function()? searchRadiusMeters,
    double? Function()? northeastLat,
    double? Function()? northeastLng,
    double? Function()? southwestLat,
    double? Function()? southwestLng,
    List<String>? aliases,
    bool? isActive,
    int? sortOrder,
  }) {
    return District(
      id: id ?? this.id,
      city: city ?? this.city,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      searchRadiusMeters: searchRadiusMeters != null
          ? searchRadiusMeters()
          : this.searchRadiusMeters,
      northeastLat: northeastLat != null ? northeastLat() : this.northeastLat,
      northeastLng: northeastLng != null ? northeastLng() : this.northeastLng,
      southwestLat: southwestLat != null ? southwestLat() : this.southwestLat,
      southwestLng: southwestLng != null ? southwestLng() : this.southwestLng,
      aliases: aliases ?? this.aliases,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is District &&
          id == other.id &&
          city == other.city &&
          name == other.name &&
          displayName == other.displayName &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          searchRadiusMeters == other.searchRadiusMeters &&
          northeastLat == other.northeastLat &&
          northeastLng == other.northeastLng &&
          southwestLat == other.southwestLat &&
          southwestLng == other.southwestLng &&
          isActive == other.isActive &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(
        id,
        city,
        name,
        displayName,
        latitude,
        longitude,
        searchRadiusMeters,
        northeastLat,
        northeastLng,
        southwestLat,
        southwestLng,
        isActive,
        sortOrder,
      );
}

class DistrictCacheSnapshot {
  const DistrictCacheSnapshot({
    required this.city,
    required this.districts,
    required this.lastUpdated,
  });

  final String city;
  final List<District> districts;
  final DateTime lastUpdated;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'city': city,
      'districts': districts.map((district) => district.toJson()).toList(growable: false),
      'lastUpdated': lastUpdated.toUtc().toIso8601String(),
    };
  }
}

String _normalizedDistrictKey(String value) {
  return normalizeSearchText(value).replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

String? _trimmed(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }

  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
