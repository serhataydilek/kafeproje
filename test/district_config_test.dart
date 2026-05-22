import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/district.dart';
import 'package:kafeproje/providers/district_providers.dart';
import 'package:kafeproje/services/districts_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MissingTableDistrictsService extends DistrictsService {
  _MissingTableDistrictsService()
      : super(
          SupabaseClient(
            'https://example.com',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<List<District>> fetchActiveDistricts({
    String? city,
  }) async {
    throw Exception('PGRST205: Could not find the table public.districts');
  }
}

void main() {
  test('district config falls back when districts table is missing', () async {
    final container = ProviderContainer(
      overrides: [
        districtsServiceProvider
            .overrideWithValue(_MissingTableDistrictsService()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(districtConfigProvider.notifier);
    await notifier.preload();
    await notifier.refresh();

    final state = container.read(districtConfigProvider);
    expect(state.districts, isNotEmpty);
    expect(state.isUsingFallback, isTrue);
    expect(state.errorMessage, isNull);
  });
}
