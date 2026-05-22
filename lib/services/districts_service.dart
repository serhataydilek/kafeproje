import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/network_config.dart';
import '../models/district.dart';
import '../utils/app_logger.dart';

class DistrictsService {
  DistrictsService(this._client);

  final SupabaseClient _client;

  Future<List<District>> fetchActiveDistricts({
    String? city,
  }) async {
    final response = await _query(city).timeout(
      NetworkTimeoutConfig.supabaseDataRequestTimeout,
    );

    final districts = <District>[];
    for (final row in response) {
      if (row is! Map) {
        AppLogger.warn(
          'DistrictsService skipped a malformed non-map row.',
          key: 'districts-row-not-map',
        );
        continue;
      }

      final district = District.tryFromSupabaseRow(
        row.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (district == null) {
        final rowId = row['id']?.toString() ?? 'unknown';
        AppLogger.warn(
          'DistrictsService skipped malformed district row id=$rowId.',
          key: 'districts-row-malformed-$rowId',
        );
        continue;
      }
      districts.add(district);
    }

    return districts;
  }

  Future<List<dynamic>> _query(String? city) {
    final normalizedCity = city?.trim();
    var query = _client
        .from('districts')
        .select('*')
        .eq('is_active', true);
    if (normalizedCity != null && normalizedCity.isNotEmpty) {
      query = query.ilike('city', normalizedCity);
    }
    return query
        .order('city', ascending: true)
        .order('sort_order', ascending: true);
  }
}
