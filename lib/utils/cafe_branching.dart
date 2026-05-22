import '../models/index.dart';
import 'text_normalization.dart';

List<Cafe> applySharedBrandPricing(List<Cafe> cafes) {
  final priceByBrand = <String, PriceLevel>{};

  for (final cafe in cafes) {
    if (!cafe.hasPriceLevel) {
      continue;
    }
    final brandKey = deriveCafeBrandKey(cafe.name);
    if (brandKey.isEmpty) {
      continue;
    }
    priceByBrand.putIfAbsent(brandKey, () => cafe.priceLevel);
  }

  return cafes.map((cafe) {
    if (cafe.hasPriceLevel) {
      return cafe;
    }
    final brandKey = deriveCafeBrandKey(cafe.name);
    final sharedPrice = priceByBrand[brandKey];
    if (sharedPrice == null) {
      return cafe;
    }
    return cafe.copyWith(
      priceLevel: sharedPrice,
      hasPriceLevel: true,
    );
  }).toList(growable: false);
}

String deriveCafeBrandKey(String name) {
  final normalized = normalizeSearchText(name)
      .replaceAll(
          RegExp(
              r'\b(istanbul|kadikoy|kadıkoy|besiktas|beşiktaş|sisli|şişli|taksim|nisantasi|nişantaşı|bebek|ortakoy|ortaköy|uskudar|üsküdar|levent|beyoglu|beyoğlu)\b'),
          ' ')
      .replaceAll(
          RegExp(
              r'\b(branch|sube|şube|store|cafe lounge|cafe|kahve|coffee shop)\b'),
          ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized.isEmpty) {
    return '';
  }

  final tokens =
      normalized.split(' ').where((token) => token.isNotEmpty).toList();
  if (tokens.isEmpty) {
    return '';
  }

  return tokens.take(3).join(' ');
}
