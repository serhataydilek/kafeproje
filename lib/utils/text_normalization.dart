const List<(String, String)> _searchSequenceReplacements = [
  ('Ä°', 'I'),
  ('Ä±', 'i'),
  ('Äž', 'G'),
  ('ÄŸ', 'g'),
  ('Ãœ', 'U'),
  ('Ã¼', 'u'),
  ('Ã–', 'O'),
  ('Ã¶', 'o'),
  ('Åž', 'S'),
  ('ÅŸ', 's'),
  ('Ã‡', 'C'),
  ('Ã§', 'c'),
  ('Ã„Â°', 'I'),
  ('Ã„Â±', 'i'),
  ('Ã„Å¾', 'G'),
  ('Ã„Å¸', 'g'),
  ('ÃƒÅ“', 'U'),
  ('ÃƒÂ¼', 'u'),
  ('Ãƒâ€“', 'O'),
  ('ÃƒÂ¶', 'o'),
  ('Ã…Å¾', 'S'),
  ('Ã…Å¸', 's'),
  ('Ãƒâ€¡', 'C'),
  ('ÃƒÂ§', 'c'),
];

const Map<String, String> _searchCharacterFoldMap = {
  'I': 'i',
  'İ': 'i',
  'ı': 'i',
  'Ç': 'c',
  'ç': 'c',
  'Ğ': 'g',
  'ğ': 'g',
  'Ö': 'o',
  'ö': 'o',
  'Ş': 's',
  'ş': 's',
  'Ü': 'u',
  'ü': 'u',
};

const Map<String, String> _turkishUppercaseMap = {
  'i': 'İ',
  'ı': 'I',
  'ç': 'Ç',
  'ğ': 'Ğ',
  'ö': 'Ö',
  'ş': 'Ş',
  'ü': 'Ü',
};

/// Normalizes text for search only.
///
/// This intentionally flattens Turkish-specific letters into ASCII-friendly
/// lowercase output so search matches stay forgiving across diacritics,
/// punctuation, and known mojibake variants. Do not use it for display text
/// or locale-aware case conversion.
String normalizeSearchText(String input) {
  if (input.isEmpty) {
    return '';
  }

  final normalized = _replaceCommonTurkishMojibake(input).replaceAll(
    '\u0307',
    '',
  );
  final buffer = StringBuffer();
  for (final rune in normalized.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(_searchCharacterFoldMap[character] ?? character);
  }

  return buffer
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool containsNormalizedText(
  String candidate,
  String query,
) {
  final normalizedQuery = normalizeSearchText(query);
  if (normalizedQuery.isEmpty) {
    return true;
  }

  final normalizedCandidate = normalizeSearchText(candidate);
  if (normalizedCandidate.contains(normalizedQuery)) {
    return true;
  }

  return _collapseRepeatedLetters(normalizedCandidate)
      .contains(_collapseRepeatedLetters(normalizedQuery));
}

String turkishAwareUppercase(String input, String languageCode) {
  if (languageCode != 'tr') {
    return input.toUpperCase();
  }

  final normalized = _replaceCommonTurkishMojibake(input).replaceAll(
    '\u0307',
    '',
  );
  final buffer = StringBuffer();
  for (final rune in normalized.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(_turkishUppercaseMap[character] ?? character.toUpperCase());
  }
  return buffer.toString();
}

String _replaceCommonTurkishMojibake(String input) {
  var output = input;
  for (final replacement in _searchSequenceReplacements) {
    output = output.replaceAll(replacement.$1, replacement.$2);
  }
  return output;
}

String _collapseRepeatedLetters(String input) {
  if (input.length < 2) {
    return input;
  }

  final buffer = StringBuffer();
  var previous = '';
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    if (char == previous) {
      continue;
    }
    buffer.write(char);
    previous = char;
  }
  return buffer.toString();
}
