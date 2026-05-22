import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/review_moderation.dart';

void main() {
  group('review moderation', () {
    test('blocks basic English profanity', () {
      final result = moderateReviewText('This place is fucking awful.');

      expect(result.isBlocked, isTrue);
      expect(result.matchedTerm, isNotNull);
    });

    test('blocks basic Turkish profanity', () {
      final result = moderateReviewText('Personel cok salak davrandi.');

      expect(result.isBlocked, isTrue);
      expect(result.matchedTerm, isNotNull);
    });

    test('allows respectful reviews', () {
      final result = moderateReviewText(
        'Great coffee, comfortable seats, but it gets busy after lunch.',
      );

      expect(result.isBlocked, isFalse);
      expect(result.sanitizedText, contains('Great coffee'));
    });
  });
}
