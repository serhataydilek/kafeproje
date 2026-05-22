import '../models/cafe_support.dart';

CafeCategory inferCafeCategory({
  String? rawCategory,
  String? name,
  List<String> tags = const [],
  List<String> types = const [],
}) {
  final buffer = <String>[
    if (rawCategory != null) rawCategory,
    if (name != null) name,
    ...tags,
    ...types,
  ].join(' ').toLowerCase();

  if (buffer.contains('lounge') ||
      buffer.contains('shisha') ||
      buffer.contains('hookah') ||
      buffer.contains('teras') ||
      buffer.contains('terrace lounge')) {
    return CafeCategory.cafeLounge;
  }

  return CafeCategory.normalCafe;
}
