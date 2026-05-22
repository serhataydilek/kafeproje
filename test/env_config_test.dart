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

  group('Env.collectGoogleApiConfigurationWarnings', () {
    test('warns when maps key looks malformed', () {
      final warnings = Env.collectGoogleApiConfigurationWarnings(
        mapsApiKey: 'not-a-google-key',
        placesApiKey: 'AIzaSyDUMMYPLACESKEY00000000000000001',
      );

      expect(
        warnings.any((warning) => warning.contains('Google Maps API key')),
        isTrue,
      );
    });

    test('warns when maps and places keys are shared', () {
      const sharedKey = 'AIzaSySHAREDKEY000000000000000000000001';
      final warnings = Env.collectGoogleApiConfigurationWarnings(
        mapsApiKey: sharedKey,
        placesApiKey: sharedKey,
      );

      expect(
        warnings.any((warning) => warning.contains('same API key')),
        isTrue,
      );
    });

    test('returns no warnings for distinct valid-looking keys', () {
      final warnings = Env.collectGoogleApiConfigurationWarnings(
        mapsApiKey: 'AIzaSyMAPSKEY000000000000000000000001',
        placesApiKey: 'AIzaSyPLACESKEY0000000000000000000001',
      );

      expect(warnings, isEmpty);
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
        supabaseUrl: 'https://project.supabase.co',
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
            dartDefine: 'https://project.supabase.co',
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
          supabaseUrl: 'https://project.supabase.co',
          supabaseAnonKey: 'secret-anon-key',
        ),
        isTrue,
      );
    });

    test('dart-define source wins over dotenv asset fallback', () {
      final diagnostics = Env.buildConfigDiagnostics(
        values: const <String, ({String dartDefine, String? dotenvAsset})>{
          'SUPABASE_URL': (
            dartDefine: 'https://define-project.supabase.co',
            dotenvAsset: 'https://dotenv-project.supabase.co',
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
      expect(logOutput, isNot(contains('define-project')));
      expect(logOutput, isNot(contains('dotenv-project')));
      expect(logOutput, isNot(contains('define-secret-anon-key')));
      expect(logOutput, isNot(contains('dotenv-secret-anon-key')));
    });

    test('dotenv asset fallback can configure Supabase locally', () {
      final diagnostics = Env.buildConfigDiagnostics(
        values: const <String, ({String dartDefine, String? dotenvAsset})>{
          'SUPABASE_URL': (
            dartDefine: '',
            dotenvAsset: 'https://dotenv-project.supabase.co',
          ),
          'SUPABASE_ANON_KEY': (
            dartDefine: '',
            dotenvAsset: 'dotenv-secret-anon-key',
          ),
          'GOOGLE_MAPS_API_KEY': (
            dartDefine: '',
            dotenvAsset: 'AIzaSyDOTENVMAPSKEY0000000000000001',
          ),
          'GOOGLE_PLACES_API_KEY': (
            dartDefine: '',
            dotenvAsset: 'AIzaSyDOTENVPLACESKEY0000000000001',
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
          supabaseUrl: 'https://dotenv-project.supabase.co',
          supabaseAnonKey: 'dotenv-secret-anon-key',
        ),
        isTrue,
      );
    });

    test('missing Supabase key reports missing key names', () {
      final missing = Env.collectMissingRequiredConfigKeys(
        supabaseUrl: 'https://project.supabase.co',
        supabaseAnonKey: '',
      );
      final diagnostics = Env.buildConfigDiagnostics(
        values: const <String, ({String dartDefine, String? dotenvAsset})>{
          'SUPABASE_URL': (
            dartDefine: 'https://project.supabase.co',
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
      const secretUrl = 'https://secret-project.supabase.co';
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
