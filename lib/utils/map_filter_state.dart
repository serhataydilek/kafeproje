import '../models/index.dart';

enum MapFilterResultState {
  hasResults,
  noResultsForFilters,
  noData,
}

MapFilterResultState resolveMapFilterResultState({
  required List<Cafe> allCafes,
  required List<Cafe> filteredCafes,
  required Filters filters,
}) {
  if (allCafes.isEmpty) {
    return MapFilterResultState.noData;
  }
  if (filteredCafes.isEmpty && filters.activeCount > 0) {
    return MapFilterResultState.noResultsForFilters;
  }
  if (filteredCafes.isEmpty) {
    return MapFilterResultState.noData;
  }
  return MapFilterResultState.hasResults;
}
