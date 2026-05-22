import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/text_normalization.dart';

void main() {
  group('normalizeSearchText', () {
    test('maps Turkish dotted and dotless i variants to ascii i', () {
      expect(normalizeSearchText('I İ ı i'), 'i i i i');
    });

    test('normalizes Turkish diacritics for search matching', () {
      expect(normalizeSearchText('Çay Şöleni Üsküdar'), 'cay soleni uskudar');
    });

    test('normalizes common mojibake variants back into searchable text', () {
      expect(normalizeSearchText('KadÄ±kÃ¶y Ã‡arÅŸÄ±'), 'kadikoy carsi');
    });
  });

  group('containsNormalizedText', () {
    test('matches small repeated-letter variations for cafe names', () {
      expect(
        containsNormalizedText('Mikel Coffee Company', 'Mikkel Coffee'),
        isTrue,
      );
    });

    test('matches across Turkish character variants', () {
      expect(
        containsNormalizedText('Kadıköy Çay Evi', 'kadikoy cay'),
        isTrue,
      );
    });
  });
}
