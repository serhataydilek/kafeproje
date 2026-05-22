// Normalizes and deduplicates cafe tags for user-facing display.
//
// Raw tags from Google Places often contain noisy, generic, or duplicated
// entries. This utility cleans them into a compact, readable set.
import 'text_normalization.dart';

/// Tags hidden from user-facing display (generic Google Place types).
const Set<String> _hiddenGenericTags = {
  'food',
  'point of interest',
  'point_of_interest',
  'establishment',
  'food and drink',
  'food_and_drink',
  'store',
  'health',
  'service',
  'business',
  'place',
  'locality',
  'political',
  'geocode',
  'meal delivery',
  'meal takeaway',
};

/// Title-cases a tag token: "coffee shop" → "Coffee Shop".
String _titleCaseTag(String tag) {
  if (tag.isEmpty) {
    return tag;
  }

  return tag.split(' ').map((word) {
    if (word.isEmpty) {
      return word;
    }
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

/// Normalizes and deduplicates cafe tags for user-facing display.
///
/// 1. Strips leading/trailing whitespace
/// 2. Replaces underscores with spaces
/// 3. Title-cases each tag
/// 4. Deduplicates case-insensitively
/// 5. Filters out hidden generic tags
/// 6. Returns clean, ordered list
List<String> normalizeDisplayTags(List<String> rawTags) {
  if (rawTags.isEmpty) {
    return const <String>[];
  }

  final seen = <String>{};
  final result = <String>[];

  for (final raw in rawTags) {
    final cleaned = raw.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) {
      continue;
    }

    final normalized = normalizeSearchText(cleaned);
    if (_hiddenGenericTags.contains(normalized)) {
      continue;
    }

    if (!seen.add(normalized)) {
      continue;
    }

    result.add(_titleCaseTag(cleaned));
  }

  return List<String>.unmodifiable(result);
}
