import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/config/env.dart';

void main() {
  const requiredEnvKeys = <String>{
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'GOOGLE_MAPS_API_KEY',
    'GOOGLE_PLACES_API_KEY',
  };

  group('.env.local.json.example', () {
    test('contains exactly the canonical local env keys', () {
      final file = File('.env.local.json.example');
      final decoded = jsonDecode(file.readAsStringSync());

      expect(decoded, isA<Map<String, dynamic>>());
      expect((decoded as Map<String, dynamic>).keys.toSet(), requiredEnvKeys);
      for (final key in requiredEnvKeys) {
        expect(decoded[key], isA<String>());
        expect((decoded[key] as String).trim(), isNotEmpty);
      }
    });
  });

  group('Android release config', () {
    test('requires a Places API key for release image loading', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('GOOGLE_PLACES_API_KEY'));
      expect(
        gradle,
        contains(
          'GOOGLE_PLACES_API_KEY is required for release builds so cafe photos can load.',
        ),
      );
    });
  });

  group('Env.collectGoogleApiConfigurationWarnings', () {
    test('warns when maps key looks malformed', () {
      final warnings = Env.collectGoogleApiConfigurationWarnings(
        mapsApiKey: 'not-a-google-key',
        placesApiKey: 'test_google_places_api_key',
      );

      expect(
        warnings.any((warning) => warning.contains('Google Maps API key')),
        isTrue,
      );
    });

    test('warns when maps and places keys are shared', () {
      const sharedKey = 'test_shared_google_api_key';
      final warnings = Env.collectGoogleApiConfigurationWarnings(
        mapsApiKey: sharedKey,
        placesApiKey: sharedKey,
      );

      expect(
        warnings.any((warning) => warning.contains('same API key')),
        isTrue,
      );
    });

    test('warns for placeholder-like keys', () {
      final warnings = Env.collectGoogleApiConfigurationWarnings(
        mapsApiKey: 'test_google_maps_api_key',
        placesApiKey: 'test_google_places_api_key',
      );

      expect(warnings, isNotEmpty);
    });
  });

  group('Env.collectMissingRequiredConfigKeys', () {
    test('names missing Supabase keys without inspecting values', () {
      final missing = Env.collectMissingRequiredConfigKeys(
        supabaseUrl: '',
        supabaseAnonKey: 'your_anon_key',
      );

      expect(missing, ['SUPABASE_URL', 'SUPABASE_ANON_KEY']);
    });

    test('accepts present Supabase config', () {
      final missing = Env.collectMissingRequiredConfigKeys(
        supabaseUrl: 'supabase_project_url',
        supabaseAnonKey: 'anon-key',
      );

      expect(missing, isEmpty);
    });
  });

  group('Env config diagnostics', () {
    test('dart-define config is reported as present and Supabase-ready', () {
      final diagnostics = Env.buildConfigDiagnostics(
        values: const <String, ({String dartDefine, String? dotenvAsset})>{
          'SUPABASE_URL': (
            dartDefine: 'supabase_project_url',
            dotenvAsset: null,
          ),
          'SUPABASE_ANON_KEY': (
            dartDefine: 'secret-anon-key',
            dotenvAsset: null,
          ),
        },
      );

      expect(
        diagnostics.map((diagnostic) => diagnostic.logLine),
        containsAll(<String>[
          '[ENV_CONFIG] SUPABASE_URL=present source=dart_define',
          '[ENV_CONFIG] SUPABASE_ANON_KEY=present source=dart_define',
        ]),
      );
      expect(
        Env.hasSupabaseConfigFor(
          supabaseUrl: 'supabase_project_url',
          supabaseAnonKey: 'secret-anon-key',
        ),
        isTrue,
      );
    });

    test('dart-define source wins over dotenv asset fallback', () {
      final diagnostics = Env.buildConfigDiagnostics(
        values: const <String, ({String dartDefine, String? dotenvAsset})>{
          'SUPABASE_URL': (
            dartDefine: 'define_supabase_project_url',
            dotenvAsset: 'dotenv_supabase_project_url',
          ),
          'SUPABASE_ANON_KEY': (
            dartDefine: 'define-secret-anon-key',
            dotenvAsset: 'dotenv-secret-anon-key',
          ),
        },
      );
      final logOutput =
          diagnostics.map((diagnostic) => diagnostic.logLine).join('\n');

      expect(
        logOutput,
        contains('[ENV_CONFIG] SUPABASE_URL=present source=dart_define'),
      );
      expect(
        logOutput,
        contains('[ENV_CONFIG] SUPABASE_ANON_KEY=present source=dart_define'),
      );
      expect(logOutput, isNot(contains('define_supabase_project_url')));
      expect(logOutput, isNot(contains('dotenv_supabase_project_url')));
      expect(logOutput, isNot(contains('define-secret-anon-key')));
      expect(logOutput, isNot(contains('dotenv-secret-anon-key')));
    });

    test('dotenv asset fallback can configure Supabase locally', () {
      final diagnostics = Env.buildConfigDiagnostics(
        values: const <String, ({String dartDefine, String? dotenvAsset})>{
          'SUPABASE_URL': (
            dartDefine: '',
            dotenvAsset: 'dotenv_supabase_project_url',
          ),
          'SUPABASE_ANON_KEY': (
            dartDefine: '',
            dotenvAsset: 'dotenv-secret-anon-key',
          ),
          'GOOGLE_MAPS_API_KEY': (
            dartDefine: '',
            dotenvAsset: 'test_google_maps_api_key',
          ),
          'GOOGLE_PLACES_API_KEY': (
            dartDefine: '',
            dotenvAsset: 'test_google_places_api_key',
          ),
        },
      );

      expect(
        diagnostics.map((diagnostic) => diagnostic.logLine),
        containsAll(<String>[
          '[ENV_CONFIG] SUPABASE_URL=present source=dotenv_asset',
          '[ENV_CONFIG] SUPABASE_ANON_KEY=present source=dotenv_asset',
          '[ENV_CONFIG] GOOGLE_MAPS_API_KEY=present source=dotenv_asset',
          '[ENV_CONFIG] GOOGLE_PLACES_API_KEY=present source=dotenv_asset',
        ]),
      );
      expect(
        Env.hasSupabaseConfigFor(
          supabaseUrl: 'dotenv_supabase_project_url',
          supabaseAnonKey: 'dotenv-secret-anon-key',
        ),
        isTrue,
      );
    });

    test('missing Supabase key reports missing key names', () {
      final missing = Env.collectMissingRequiredConfigKeys(
        supabaseUrl: 'supabase_project_url',
        supabaseAnonKey: '',
      );
      final diagnostics = Env.buildConfigDiagnostics(
        values: const <String, ({String dartDefine, String? dotenvAsset})>{
          'SUPABASE_URL': (
            dartDefine: 'supabase_project_url',
            dotenvAsset: null,
          ),
          'SUPABASE_ANON_KEY': (
            dartDefine: '',
            dotenvAsset: null,
          ),
        },
      );

      expect(missing, ['SUPABASE_ANON_KEY']);
      expect(
        diagnostics.map((diagnostic) => diagnostic.logLine),
        contains('[ENV_CONFIG] SUPABASE_ANON_KEY=missing source=none'),
      );
    });

    test('local fallback is reported without logging secret values', () {
      const secretUrl = 'redacted_supabase_project_url';
      const secretKey = 'secret-anon-key-value';
      final diagnostics = Env.buildConfigDiagnostics(
        values: const <String, ({String dartDefine, String? dotenvAsset})>{
          'SUPABASE_URL': (
            dartDefine: '',
            dotenvAsset: secretUrl,
          ),
          'SUPABASE_ANON_KEY': (
            dartDefine: '',
            dotenvAsset: secretKey,
          ),
        },
      );
      final logOutput =
          diagnostics.map((diagnostic) => diagnostic.logLine).join('\n');

      expect(
        logOutput,
        contains('[ENV_CONFIG] SUPABASE_URL=present source=dotenv_asset'),
      );
      expect(
        logOutput,
        contains(
          '[ENV_CONFIG] SUPABASE_ANON_KEY=present source=dotenv_asset',
        ),
      );
      expect(logOutput, isNot(contains(secretUrl)));
      expect(logOutput, isNot(contains(secretKey)));
    });
  });
}
