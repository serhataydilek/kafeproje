import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kafeproje/services/places_service.dart';
import 'package:kafeproje/utils/cafe_discovery_classifier.dart';

void main() {
  group('shouldIncludeGoogleCafeCandidate', () {
    test('keeps real cafe candidates with cafe place types', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Walter\'s Coffee Roastery'},
        'shortFormattedAddress': 'Moda, Kadikoy',
        'primaryType': 'cafe',
        'types': ['cafe', 'food', 'point_of_interest'],
      };

      expect(shouldIncludeGoogleCafeCandidate(place), isTrue);
    });

    test('rejects candidates with excluded keywords even if typed as cafe', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Moda Kiraathane'},
        'shortFormattedAddress': 'Kadikoy, Istanbul',
        'primaryType': 'cafe',
        'types': ['cafe', 'point_of_interest'],
      };

      expect(shouldIncludeGoogleCafeCandidate(place), isFalse);
    });

    test('rejects candidates whose names contain firin variants', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Levent Simit Firin Cafe'},
        'shortFormattedAddress': 'Levent, Besiktas, Istanbul',
        'primaryType': 'cafe',
        'types': ['cafe', 'food', 'point_of_interest'],
      };

      expect(shouldIncludeGoogleCafeCandidate(place), isFalse);
    });

    test('rejects candidates whose names contain fırın with Turkish casing',
        () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Levent Taş Fırın Kahve'},
        'shortFormattedAddress': 'Levent, Beşiktaş, Istanbul',
        'primaryType': 'cafe',
        'types': ['cafe', 'food', 'point_of_interest'],
      };

      expect(shouldIncludeGoogleCafeCandidate(place), isFalse);
    });

    test('rejects obvious bakery-style businesses beyond firin', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Levent Unlu Mamulleri'},
        'shortFormattedAddress': 'Levent, Besiktas, Istanbul',
        'primaryType': 'cafe',
        'types': ['cafe', 'food', 'point_of_interest'],
      };

      expect(shouldIncludeGoogleCafeCandidate(place), isFalse);
    });

    test('rejects candidates whose returned types are restaurant or bakery',
        () {
      final restaurantPlace = <String, dynamic>{
        'displayName': {'text': 'Pide House'},
        'shortFormattedAddress': 'Besiktas, Istanbul',
        'primaryType': 'restaurant',
        'types': ['restaurant', 'food', 'point_of_interest'],
      };
      final bakeryPlace = <String, dynamic>{
        'displayName': {'text': 'Galata Pastane'},
        'shortFormattedAddress': 'Beyoglu, Istanbul',
        'primaryType': 'bakery',
        'types': ['bakery', 'food', 'store'],
      };

      expect(shouldIncludeGoogleCafeCandidate(restaurantPlace), isFalse);
      expect(shouldIncludeGoogleCafeCandidate(bakeryPlace), isFalse);
    });

    test('keeps cross-district candidates during district-specific ingestion',
        () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Taksim Brew Lab'},
        'shortFormattedAddress': 'Taksim, Beyoglu, Istanbul',
        'primaryType': 'cafe',
        'types': ['cafe', 'food', 'point_of_interest'],
      };

      expect(
        shouldIncludeGoogleCafeCandidate(
          place,
          expectedDistrict: 'Kadıköy',
        ),
        isTrue,
      );
    });

    test('keeps valid Levent cafes during district-specific ingestion', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Kronotrop Levent'},
        'shortFormattedAddress': 'Levent, Besiktas, Istanbul',
        'primaryType': 'cafe',
        'types': ['cafe', 'coffee_shop', 'food', 'point_of_interest'],
      };

      expect(
        shouldIncludeGoogleCafeCandidate(
          place,
          expectedDistrict: 'Levent',
        ),
        isTrue,
      );
    });

    test('keeps Mikel Coffee Company as a valid Levent cafe candidate', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Mikel Coffee Company'},
        'shortFormattedAddress':
            'Levent, Gonca Sk. No:4 İç Kapı No:1, Beşiktaş',
        'primaryType': 'coffee_shop',
        'types': ['coffee_shop', 'cafe', 'food', 'point_of_interest'],
      };

      expect(
        shouldIncludeGoogleCafeCandidate(
          place,
          expectedDistrict: 'Levent',
        ),
        isTrue,
      );
    });

    test('keeps chain coffee shops when Google also tags them as store', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Starbucks Reserve'},
        'shortFormattedAddress': 'Nisantasi, Sisli, Istanbul',
        'primaryType': 'coffee_shop',
        'types': ['coffee_shop', 'store', 'food', 'point_of_interest'],
      };

      expect(shouldIncludeGoogleCafeCandidate(place), isTrue);
    });

    test('keeps chain cafes even when source typing is incomplete', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Kahve Dunyasi'},
        'shortFormattedAddress': 'Kadikoy, Istanbul',
        'primaryType': 'store',
        'types': ['store', 'food', 'point_of_interest'],
      };

      expect(shouldIncludeGoogleCafeCandidate(place), isTrue);
    });

    test('rejects market-like places even when they mention coffee', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Moda Mini Market Coffee Point'},
        'shortFormattedAddress': 'Kadikoy, Istanbul',
        'primaryType': 'convenience_store',
        'types': ['convenience_store', 'store', 'food'],
      };

      expect(shouldIncludeGoogleCafeCandidate(place), isFalse);
    });

    test('keeps Istanbul cafes outside the old district shortlist', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Sultanahmet Cafe'},
        'shortFormattedAddress': 'Fatih, Istanbul',
        'primaryType': 'cafe',
        'types': ['cafe', 'food', 'point_of_interest'],
      };

      expect(shouldIncludeGoogleCafeCandidate(place), isTrue);
    });

    test('rejects uncertain candidates when cafe types are missing', () {
      final place = <String, dynamic>{
        'displayName': {'text': 'Carsi Mekani'},
        'shortFormattedAddress': 'Uskudar, Istanbul',
        'types': ['food', 'point_of_interest'],
      };

      expect(shouldIncludeGoogleCafeCandidate(place), isFalse);
    });
  });

  group('normalizedGooglePlaceTypes', () {
    test('normalizes mixed-case place types into a searchable set', () {
      final types = normalizedGooglePlaceTypes(
        ['Cafe', 'Coffee_Shop', 'point_of_interest'],
      );

      expect(types, contains('cafe'));
      expect(types, contains('coffee_shop'));
      expect(types, contains('point_of_interest'));
    });
  });

  group('PlacesService logging', () {
    test('HTTP failure log omits upstream response bodies', () {
      final response = http.Response(
        '{"error":"bad key","apiKey":"SECRET-123","url":"https://places.googleapis.com/v1/places:searchText?key=SECRET-123&token=TOKEN-456"}',
        500,
      );

      final message = safePlacesHttpFailureLogMessage(
        response,
        operationName: 'Text Search',
      );

      expect(message, contains('HTTP 500'));
      expect(message, contains('Text Search'));
      expect(message, isNot(contains('SECRET-123')));
      expect(message, isNot(contains('TOKEN-456')));
      expect(message, isNot(contains('places:searchText')));
      expect(message, isNot(contains(response.body)));
    });
  });
}
