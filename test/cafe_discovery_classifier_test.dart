import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/cafe_discovery_classifier.dart';

void main() {
  group('isLikelyCafeVenue', () {
    test(
        'accepts allowed secondary coffee types even with imperfect primary type',
        () {
      final result = isLikelyCafeVenue(
        primaryType: 'store',
        placeTypes: const {'store', 'coffee_shop', 'food'},
        searchableText: 'Generic Coffee Branch, Istanbul',
      );

      expect(result, isTrue);
    });

    test('rejects clearly irrelevant grocery-style venues', () {
      final result = isLikelyCafeVenue(
        primaryType: 'convenience_store',
        placeTypes: const {'convenience_store', 'store', 'food'},
        searchableText: 'Moda Mini Market, Istanbul',
      );

      expect(result, isFalse);
    });

    test('rejects obvious non-cafe venues like hotel museum and gas station',
        () {
      for (final scenario in const [
        (
          primaryType: 'point_of_interest',
          placeTypes: <String>{'point_of_interest', 'establishment'},
          searchableText: 'Grand Hotel Lobby Cafe',
        ),
        (
          primaryType: 'point_of_interest',
          placeTypes: <String>{'point_of_interest', 'establishment'},
          searchableText: 'City Museum Cafe',
        ),
        (
          primaryType: 'point_of_interest',
          placeTypes: <String>{'point_of_interest', 'establishment'},
          searchableText: 'North Gas Station Cafe',
        ),
      ]) {
        expect(
          isLikelyCafeVenue(
            primaryType: scenario.primaryType,
            placeTypes: scenario.placeTypes,
            searchableText: scenario.searchableText,
          ),
          isFalse,
          reason: scenario.searchableText,
        );
      }
    });

    test('keeps relevant tea venues when source typing is tea-house like', () {
      final result = isLikelyCafeVenue(
        primaryType: 'tea_house',
        placeTypes: const {'tea_house', 'food', 'point_of_interest'},
        searchableText: 'Tea House Bebek, Istanbul',
      );

      expect(result, isTrue);
    });

    test('rejects borek and pide salon style venues', () {
      final result = isLikelyCafeVenue(
        primaryType: 'cafe',
        placeTypes: const {'cafe', 'restaurant', 'food'},
        searchableText: 'IKIZLER SARIYER BOREKCISI. BOREK VE PIDE SALONU',
      );

      expect(result, isFalse);
    });

    test('rejects strong food-only names like doner and kebap', () {
      final result = isLikelyCafeVenue(
        primaryType: 'restaurant',
        placeTypes: const {'restaurant', 'food'},
        searchableText: 'Levent Doner Kebap Salonu',
      );

      expect(result, isFalse);
    });

    test('keeps major coffee chains', () {
      final result = isLikelyCafeVenue(
        primaryType: 'point_of_interest',
        placeTypes: const {'point_of_interest', 'food'},
        searchableText: 'Starbucks Kadikoy Istanbul',
      );

      expect(result, isTrue);
    });

    test('rejects Arabic-script public discovery names', () {
      const arabicName =
          '\u0645\u0642\u0647\u0649 \u0627\u0644\u0642\u0647\u0648\u0629';
      const mixedName = 'Fig Coffee $arabicName';

      expect(containsArabicScript(arabicName), isTrue);
      expect(shouldRejectForPublicDiscoveryScript(arabicName), isTrue);
      expect(shouldRejectForPublicDiscoveryScript(mixedName), isTrue);
      expect(
        assessGoogleCafeCandidate({
          'displayName': {'text': arabicName},
          'primaryType': 'cafe',
          'types': ['cafe', 'food'],
        }).denyReason,
        'arabic_script_name',
      );
    });

    test('keeps Turkish Latin and English cafe names script-valid', () {
      expect(shouldRejectForPublicDiscoveryScript('Cagri Kahve Atolyesi'),
          isFalse);
      expect(shouldRejectForPublicDiscoveryScript('Çağrı Kahve Atölyesi'),
          isFalse);
      expect(
          shouldRejectForPublicDiscoveryScript('Fig Coffee Cocktail'), isFalse);
    });

    test('keeps patisserie-cafe hybrids with clear cafe signals', () {
      final result = isLikelyCafeVenue(
        primaryType: 'bakery',
        placeTypes: const {'bakery', 'food', 'cafe'},
        searchableText: 'Maison Patisserie Cafe Nisantasi',
      );

      expect(result, isTrue);
    });

    test('rejects bakery-only simit style places without cafe signals', () {
      final result = isLikelyCafeVenue(
        primaryType: 'bakery',
        placeTypes: const {'bakery', 'food'},
        searchableText: 'Simit Sarayi Besiktas',
      );

      expect(result, isFalse);
    });

    test('accepts mixed coffee and cocktail venues with strong cafe signal',
        () {
      expect(
        isLikelyCafeVenue(
          primaryType: 'bar',
          placeTypes: const {'bar', 'food', 'point_of_interest'},
          searchableText: 'Fig Coffee & Cocktail',
        ),
        isTrue,
      );

      expect(
        isLikelyCafeVenue(
          primaryType: 'bar',
          placeTypes: const {'bar', 'food', 'point_of_interest'},
          searchableText: 'Coffee & Cocktail Bar',
        ),
        isTrue,
      );

      expect(
        isLikelyCafeVenue(
          primaryType: 'bar',
          placeTypes: const {'bar', 'food', 'point_of_interest'},
          searchableText: 'Cafe & Cocktail Bistro',
        ),
        isTrue,
      );
    });

    test('does not accept nightlife venue by name without cafe signal', () {
      final result = isLikelyCafeVenue(
        primaryType: 'bar',
        placeTypes: const {'bar', 'food', 'point_of_interest'},
        searchableText: 'Cocktail Bar',
      );

      expect(result, isFalse);
    });

    test('keeps nargile-only venues blocked unless cafe signal exists', () {
      expect(
        isLikelyCafeVenue(
          primaryType: 'point_of_interest',
          placeTypes: const {'point_of_interest', 'food'},
          searchableText: 'Nargile Lounge',
        ),
        isFalse,
      );

      expect(
        isLikelyCafeVenue(
          primaryType: 'point_of_interest',
          placeTypes: const {'point_of_interest', 'food'},
          searchableText: 'Nargile Coffee House',
        ),
        isTrue,
      );
    });
  });

  group('google candidate assessment', () {
    test('provides higher confidence for real cafe chains than food venues',
        () {
      final cafeScore = googleCafeConfidenceScore({
        'primaryType': 'point_of_interest',
        'types': const ['point_of_interest', 'food'],
        'displayName': const {'text': 'EspressoLab Bebek'},
        'shortFormattedAddress': 'Bebek, Istanbul',
      });
      final foodScore = googleCafeConfidenceScore({
        'primaryType': 'restaurant',
        'types': const ['restaurant', 'food'],
        'displayName': const {'text': 'Sariyer Pide Salonu'},
        'shortFormattedAddress': 'Sariyer, Istanbul',
      });

      expect(cafeScore, greaterThan(foodScore));
      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'restaurant',
          'types': const ['restaurant', 'food'],
          'displayName': const {'text': 'Sariyer Pide Salonu'},
          'shortFormattedAddress': 'Sariyer, Istanbul',
        }),
        isFalse,
      );
    });

    test('rejects restaurants with denied primary types', () {
      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'steakhouse',
          'types': const ['steakhouse', 'restaurant', 'food'],
          'displayName': const {'text': 'Nusret Steakhouse'},
          'shortFormattedAddress': 'Etiler, Istanbul',
        }),
        isFalse,
      );

      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'meal_takeaway',
          'types': const ['meal_takeaway', 'restaurant', 'food'],
          'displayName': const {'text': 'Dürümcü Sedat'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isFalse,
      );
    });

    test('rejects strong negative venue tokens without dominant cafe signal',
        () {
      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'point_of_interest', // Generic type
          'types': const ['point_of_interest', 'food'],
          'displayName': const {'text': 'Balık Evi Restoran'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isFalse,
      );

      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'restaurant',
          'types': const ['restaurant', 'food'],
          'displayName': const {'text': 'Köfteci Yusuf'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isFalse,
      );

      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'food',
          'types': const ['food'],
          'displayName': const {'text': 'Şampiyon Kokoreç'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isFalse,
      );
    });

    test('accepts strong cafe signals despite mixed restaurant types', () {
      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'cafe',
          'types': const ['cafe', 'meal_takeaway', 'food'],
          'displayName': const {'text': 'Starbucks Cafe'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isTrue,
      );

      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'coffee_shop',
          'types': const ['coffee_shop', 'restaurant', 'food'],
          'displayName': const {'text': 'EspressoLab'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isTrue,
      );

      // Soft negative "grill" does not block strong cafe signal
      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'cafe',
          'types': const ['cafe', 'restaurant', 'food'],
          'displayName': const {'text': 'Lounge Cafe & Grill'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isTrue,
      );
    });

    test('rejects restaurant false positives unless cafe type is strong', () {
      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'restaurant',
          'types': const ['restaurant', 'food'],
          'displayName': const {'text': 'Example Cafe Restaurant'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isFalse,
      );

      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'coffee_shop',
          'types': const ['coffee_shop', 'restaurant', 'food'],
          'displayName': const {'text': 'Example Coffee Restaurant'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isTrue,
      );
    });

    test('keeps known sponsored cafe names valid', () {
      for (final name in const [
        'Fig Coffee Cocktail',
        'B.BLOK Bakery - Akaretler',
        '7K coffee workshop',
      ]) {
        expect(
          shouldIncludeGoogleCafeCandidate({
            'primaryType': name.contains('Bakery') ? 'bakery' : 'coffee_shop',
            'types': const ['coffee_shop', 'cafe', 'food'],
            'displayName': {'text': name},
            'shortFormattedAddress': 'Istanbul',
          }),
          isTrue,
          reason: name,
        );
      }
    });

    test('rejects internet and gaming cafes even if the word cafe is present',
        () {
      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'point_of_interest',
          'types': const ['point_of_interest', 'establishment'],
          'displayName': const {'text': 'Internet Cafe'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isFalse,
      );

      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'point_of_interest',
          'types': const ['point_of_interest', 'establishment'],
          'displayName': const {'text': 'Alkan E-SPOR Internet Cafe'},
          'shortFormattedAddress': 'Istanbul',
        }),
        isFalse,
      );

      expect(
        shouldIncludeGoogleCafeCandidate({
          'primaryType': 'cafe', // weak positive
          'types': const ['cafe', 'establishment'],
          'displayName': const {'text': 'Matrix Playstation Cafe'},
          'shortFormattedAddress': 'Kadikoy, Istanbul',
        }),
        isFalse,
      );

      for (final name in const [
        'Alkan E-SPOR Internet Cafe',
        'Arena Gaming Cafe',
        'Retro PS Cafe',
        'Kadikoy Oyun Salonu',
        'Besiktas Game Center',
      ]) {
        expect(
          shouldIncludeGoogleCafeCandidate({
            'primaryType': 'cafe',
            'types': const ['cafe', 'coffee_shop', 'establishment'],
            'displayName': {'text': name},
            'shortFormattedAddress': 'Istanbul',
          }),
          isFalse,
          reason: name,
        );
      }
    });

    test('records structured reasons for mixed venue classification', () {
      final accepted = assessGoogleCafeCandidate({
        'primaryType': 'bar',
        'types': const ['bar', 'food', 'point_of_interest'],
        'displayName': const {'text': 'Fig Coffee & Cocktail'},
        'shortFormattedAddress': 'Istanbul',
      });
      final rejected = assessGoogleCafeCandidate({
        'primaryType': 'bar',
        'types': const ['bar', 'food', 'point_of_interest'],
        'displayName': const {'text': 'Cocktail Bar'},
        'shortFormattedAddress': 'Istanbul',
      });

      expect(accepted.isValidCafe, isTrue);
      expect(accepted.allowReason, 'strong_cafe_signal');
      expect(accepted.denyReason, isNull);
      expect(accepted.primaryType, 'bar');
      expect(accepted.types, containsAll(<String>{'bar', 'food'}));
      expect(accepted.name, 'fig coffee cocktail');

      expect(rejected.isValidCafe, isFalse);
      expect(rejected.allowReason, isNull);
      expect(rejected.denyReason, isNotNull);
      expect(rejected.primaryType, 'bar');
      expect(rejected.name, 'cocktail bar');
    });

    test('rejects food and market venues even with cafe typing', () {
      for (final name in const [
        'Moda Borekci Cafe',
        'Sariyer Pide Cafe',
        'Levent Kebap Cafe',
        'Nisantasi Pizza Cafe',
        'Kadikoy Mini Market Cafe',
        'Besiktas Bakkal Cafe',
        'Sisli Grocery Cafe',
      ]) {
        expect(
          shouldIncludeGoogleCafeCandidate({
            'primaryType': 'cafe',
            'types': const ['cafe', 'food', 'establishment'],
            'displayName': {'text': name},
            'shortFormattedAddress': 'Istanbul',
          }),
          isFalse,
          reason: name,
        );
      }
    });
  });
}
