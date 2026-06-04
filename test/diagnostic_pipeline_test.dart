import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/utils/cafe_discovery_classifier.dart';

// Since we have Env variables from dotenv in the app, this is a mock proxy or we can test with standard mock response.
// Actually, this test will just call the actual network if the env is available or we can inject a mock JSON.
// But the user's prompt suggests adding logging TO THE PIPELINE and inspecting.

void main() {
  test('diagnostic logs for cafe discovery', () async {
    // 1. Raw Places API
    final rawPlaces = [
      {
        'id': 'place1',
        'displayName': {'text': 'Starbucks Kadikoy'},
        'primaryType': 'coffee_shop',
        'types': ['cafe'],
        'shortFormattedAddress': 'Kadikoy',
        'location': {'latitude': 41.0, 'longitude': 29.0},
        'businessStatus': 'OPERATIONAL',
      },
      {
        'id': 'place2',
        'displayName': {'text': 'Mikel Coffee'},
        'primaryType': 'restaurant', // Mikel sometimes classified as restaurant
        'types': ['restaurant', 'food'],
        'shortFormattedAddress': 'Moda',
        'location': {'latitude': 41.0, 'longitude': 29.0},
        'businessStatus': 'OPERATIONAL',
      },
      {
        'id': 'place3',
        'displayName': {'text': 'Unknown Cafe'},
        'primaryType': '', // Unknown type
        'types': [],
        'shortFormattedAddress': 'Moda',
        'location': {'latitude': 41.0, 'longitude': 29.0},
        'businessStatus': 'OPERATIONAL',
      },
    ];

    debugPrint('1) raw Places API results count: ${rawPlaces.length}');

    int afterKeyword = 0;
    for (final p in rawPlaces) {
      if (shouldIncludeGoogleCafeCandidate(p)) {
        afterKeyword++;
      } else {
        final displayName =
            (p['displayName'] as Map<String, dynamic>?)?['text'];
        debugPrint('Dropped by keyword/type: $displayName');
      }
    }
    debugPrint('2) count after keyword/type filtering: $afterKeyword');
  });
}
