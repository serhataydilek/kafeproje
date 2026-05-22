import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/input_validation.dart';

void main() {
  group('input validation helpers', () {
    test('normalize email and username trim and lowercase values', () {
      expect(normalizeEmail('  USER@Example.COM '), 'user@example.com');
      expect(normalizeUsername('  Cafe.User  '), 'cafe.user');
    });

    test('email and username validators accept expected values', () {
      expect(isValidEmail('hello@example.com'), isTrue);
      expect(isValidEmail('invalid-email'), isFalse);
      expect(isValidUsername('cafe.user'), isTrue);
      expect(isValidUsername('no'), isFalse);
      expect(isValidUsername('bad space'), isFalse);
    });

    test('email validation rejects whitespace-only and empty strings', () {
      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('   '), isFalse);
    });

    test('email validation accepts various valid formats', () {
      expect(isValidEmail('a@b.co'), isTrue);
      expect(isValidEmail('user.name+tag@domain.org'), isTrue);
    });

    test('username validation respects length boundaries', () {
      expect(isValidUsername('ab'), isFalse); // too short (< 3)
      expect(isValidUsername('abc'), isTrue); // minimum
      expect(isValidUsername('a' * 24), isTrue); // max
      expect(isValidUsername('a' * 25), isFalse); // too long
    });

    test('username rejects special characters', () {
      expect(isValidUsername('user@name'), isFalse);
      expect(isValidUsername('user name'), isFalse);
      expect(isValidUsername('user#1'), isFalse);
    });

    test('username accepts dots and underscores', () {
      expect(isValidUsername('user.name'), isTrue);
      expect(isValidUsername('user_name'), isTrue);
      expect(isValidUsername('us.er_1'), isTrue);
    });

    test('looksLikeEmail detects @ symbol', () {
      expect(looksLikeEmail('user@domain'), isTrue);
      expect(looksLikeEmail('just-a-string'), isFalse);
    });
  });
}
