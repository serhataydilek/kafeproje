class PlacesQueryCatalog {
  PlacesQueryCatalog._();

  /// Most effective city-wide queries. These 2 capture 90%+ of cafes.
  /// Keep this list intentionally short to balance coverage and API cost.
  static const List<String> _cityWideTextTemplates = <String>[
    'cafe in {city}',
    'coffee shop in {city}',
    'specialty coffee in {city}',
    'kahve in {city}',
  ];

  static const List<String> _chainTemplates = <String>[
    'Starbucks in {city}',
    'Mikel Coffee in {city}',
    'Caffe Nero in {city}',
    'Kahve Dunyasi in {city}',
    'EspressoLab in {city}',
  ];

  static List<String> buildCityTextSearchQueries({
    required String cityDisplayName,
    bool fullSet = true,
  }) {
    final templates =
        fullSet ? _cityWideTextTemplates : _cityWideTextTemplates.take(1);
    return templates
        .map((template) => template.replaceAll('{city}', cityDisplayName))
        .toList(growable: false);
  }

  static List<String> buildChainSearchQueries({
    required String cityDisplayName,
    String? districtDisplayName,
  }) {
    final effectiveLocation =
        districtDisplayName == null || districtDisplayName.trim().isEmpty
            ? cityDisplayName
            : '${districtDisplayName.trim()} $cityDisplayName';
    return _chainTemplates
        .map((template) => template.replaceAll('{city}', effectiveLocation))
        .toList(growable: false);
  }
}
