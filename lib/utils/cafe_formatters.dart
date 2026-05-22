import '../models/index.dart';
import 'cafe_hours.dart';

String formatPriceRange(Cafe cafe, {String noDataLabel = 'No data'}) {
  if (!cafe.hasPriceLevel) {
    return noDataLabel;
  }
  return cafe.priceLevel.value;
}

String formatWorkingHoursSummary(Cafe cafe, {String noDataLabel = 'No data'}) {
  final summary = summarizeWorkingHours(cafe.openingHours);
  return summary == 'No data' ? noDataLabel : summary;
}
