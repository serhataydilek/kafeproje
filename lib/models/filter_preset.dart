import 'cafe.dart';
import 'cafe_support.dart';

class FilterPreset {
  const FilterPreset({
    required this.id,
    required this.name,
    required this.filters,
    this.createdAt,
    this.updatedAt,
  });

  factory FilterPreset.fromJson(Map<String, dynamic> json) {
    return FilterPreset(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      filters: _decodeFilters(json['filters']),
      createdAt: _tryParseDateTime(json['createdAt'] as String?),
      updatedAt: _tryParseDateTime(json['updatedAt'] as String?),
    );
  }

  final String id;
  final String name;
  final Filters filters;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FilterPreset copyWith({
    String? id,
    String? name,
    Filters? filters,
    DateTime? Function()? createdAt,
    DateTime? Function()? updatedAt,
  }) {
    return FilterPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      filters: filters ?? this.filters,
      createdAt: createdAt != null ? createdAt() : this.createdAt,
      updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'filters': _encodeFilters(filters),
      'createdAt': createdAt?.toUtc().toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> _encodeFilters(Filters filters) {
    final data = <String, dynamic>{};
    if (filters.category != null) {
      data['category'] = filters.category!.value;
    }
    final selectedDistricts = filters.effectiveDistricts
        .map((district) => district.trim())
        .where((district) => district.isNotEmpty)
        .toList(growable: false);
    if (selectedDistricts.isNotEmpty) {
      data['selectedDistricts'] = selectedDistricts;
      if (selectedDistricts.length == 1) {
        data['district'] = selectedDistricts.single;
      }
    }
    if (filters.neighborhood?.trim().isNotEmpty == true) {
      data['neighborhood'] = filters.neighborhood!.trim();
    }
    if (filters.minRating != null) {
      data['minRating'] = filters.minRating;
    }
    if (filters.priceLevel != null) {
      data['priceLevel'] = filters.priceLevel!.value;
    }
    if (filters.wifiQuality != null) {
      data['wifiQuality'] = filters.wifiQuality!.value;
    }
    if (filters.outletAvailability != null) {
      data['outletAvailability'] = filters.outletAvailability!.value;
    }
    if (filters.quietnessLevel != null) {
      data['quietnessLevel'] = filters.quietnessLevel!.value;
    }
    if (filters.outdoorSeating != null) {
      data['outdoorSeating'] = filters.outdoorSeating;
    }
    if (filters.petFriendly != null) {
      data['petFriendly'] = filters.petFriendly;
    }
    if (filters.studyFriendly != null) {
      data['studyFriendly'] = filters.studyFriendly;
    }
    if (filters.openNow != null) {
      data['openNow'] = filters.openNow;
    }
    if (filters.smokingPolicy != null) {
      data['smokingPolicy'] = filters.smokingPolicy!.value;
    }
    if (filters.searchQuery?.trim().isNotEmpty == true) {
      data['searchQuery'] = filters.searchQuery!.trim();
    }
    return data;
  }

  static Filters _decodeFilters(Object? raw) {
    if (raw is! Map) {
      return Filters.empty;
    }
    final map = raw.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    String? trimmedString(Object? value) {
      if (value is! String) {
        return null;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return Filters(
      category: trimmedString(map['category']) == null
          ? null
          : CafeCategoryExtension.fromString(trimmedString(map['category'])!),
      district: trimmedString(map['district']),
      selectedDistricts: _decodeDistrictSet(
        map['selectedDistricts'] ?? map['districts'],
        legacyDistrict: trimmedString(map['district']),
      ),
      neighborhood: trimmedString(map['neighborhood']),
      minRating: (map['minRating'] as num?)?.toDouble(),
      priceLevel: trimmedString(map['priceLevel']) == null
          ? null
          : PriceLevelExtension.fromString(trimmedString(map['priceLevel'])!),
      wifiQuality: trimmedString(map['wifiQuality']) == null
          ? null
          : WifiQualityExtension.fromString(trimmedString(map['wifiQuality'])!),
      outletAvailability: trimmedString(map['outletAvailability']) == null
          ? null
          : OutletAvailabilityExtension.fromString(
              trimmedString(map['outletAvailability'])!,
            ),
      quietnessLevel: trimmedString(map['quietnessLevel']) == null
          ? null
          : QuietnessLevelExtension.fromString(
              trimmedString(map['quietnessLevel'])!,
            ),
      outdoorSeating: map['outdoorSeating'] as bool?,
      petFriendly: map['petFriendly'] as bool?,
      studyFriendly: map['studyFriendly'] as bool?,
      openNow: map['openNow'] as bool?,
      smokingPolicy: trimmedString(map['smokingPolicy']) == null
          ? null
          : SmokingPolicyExtension.fromString(
              trimmedString(map['smokingPolicy'])!,
            ),
      searchQuery: trimmedString(map['searchQuery']),
    );
  }

  static DateTime? _tryParseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static Set<String> _decodeDistrictSet(
    Object? raw, {
    String? legacyDistrict,
  }) {
    final districts = <String>{};
    if (raw is List) {
      for (final item in raw) {
        final value = item is String ? item.trim() : '';
        if (value.isNotEmpty) {
          districts.add(value);
        }
      }
    }
    if (districts.isEmpty && legacyDistrict?.trim().isNotEmpty == true) {
      districts.add(legacyDistrict!.trim());
    }
    return Set<String>.unmodifiable(districts);
  }
}
