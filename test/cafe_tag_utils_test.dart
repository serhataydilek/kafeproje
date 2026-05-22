import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/cafe_tag_utils.dart';

void main() {
  group('normalizeDisplayTags', () {
    test('returns empty string for empty input', () {
      expect(normalizeDisplayTags([]), isEmpty);
    });

    test('trims whitespace and normalizes underscores', () {
      final tags = ['  specialty coffee  ', 'third_wave', '  board_games  '];
      expect(normalizeDisplayTags(tags), [
        'Specialty Coffee',
        'Third Wave',
        'Board Games',
      ]);
    });

    test('title-cases words', () {
      final tags = ['COFFEE shop', 'tea HOUSE', 'wifi'];
      expect(normalizeDisplayTags(tags), [
        'Coffee Shop',
        'Tea House',
        'Wifi',
      ]);
    });

    test('deduplicates case-insensitively', () {
      final tags = ['Coffee', 'coffee', ' COFFEE '];
      final result = normalizeDisplayTags(tags);
      expect(result, hasLength(1));
      expect(result.first, 'Coffee');
    });

    test('deduplicates Google cafe casing and separators', () {
      final tags = ['Cafe', 'cafe', 'point_of_interest', 'POINT OF INTEREST'];
      expect(normalizeDisplayTags(tags), ['Cafe']);
    });

    test('filters out generic hidden tags', () {
      final tags = [
        'Coffee Shop',
        'establishment',
        'point_of_interest',
        'food',
        'food_and_drink',
        'health',
        'store',
        'meal_takeaway',
        'meal delivery',
        'Vegan Options',
      ];
      expect(normalizeDisplayTags(tags), [
        'Coffee Shop',
        'Vegan Options',
      ]);
    });
  });
}
