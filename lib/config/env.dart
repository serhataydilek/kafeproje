import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Expected local configuration keys:
/// - `SUPABASE_URL`
/// - `SUPABASE_ANON_KEY`
/// - `GOOGLE_MAPS_API_KEY`
/// - `GOOGLE_PLACES_API_KEY`
/// - `GOOGLE_PLACES_PHOTO_API_KEY` (optional; falls back to Places key)
///
/// Preferred release usage keeps secrets out of Flutter assets:
/// `flutter run --dart-define-from-file=.env.local.json`
///
/// During active local development, `.env` is bundled as a debug asset fallback.
/// Remove it from `flutter.assets` before release and use Dart defines/CI
/// secrets instead.
const _supabaseUrlFromDefine = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKeyFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
const _googleMapsApiKeyFromDefine =
    String.fromEnvironment('GOOGLE_MAPS_API_KEY');
const _googlePlacesApiKeyFromDefine =
    String.fromEnvironment('GOOGLE_PLACES_API_KEY');
const _googlePlacesPhotoApiKeyFromDefine =
    String.fromEnvironment('GOOGLE_PLACES_PHOTO_API_KEY');

class EnvConfigDiagnostic {
  const EnvConfigDiagnostic({
    required this.key,
    required this.isPresent,
    required this.source,
  });

  final String key;
  final bool isPresent;
  final String source;

  String get logLine {
    return '[ENV_CONFIG] $key=${isPresent ? 'present' : 'missing'} '
        'source=$source';
  }
}

class Env {
  static bool _didAttemptDotEnvLoad = false;
  static bool _didLoadDotEnv = false;
  static Object? _dotEnvLoadError;

  static Future<void> load() async {
    if (_didAttemptDotEnvLoad) {
      return;
    }

    _didAttemptDotEnvLoad = true;

    try {
      await dotenv.load(fileName: '.env');
      _didLoadDotEnv = true;
      _dotEnvLoadError = null;
    } catch (error) {
      _didLoadDotEnv = false;
      _dotEnvLoadError = error;
    }
  }

  static bool get didLoadDotEnv => _didLoadDotEnv;

  static Object? get dotEnvLoadError => _dotEnvLoadError;

  static String? _readEnv(String key) {
    if (!_didLoadDotEnv) {
      return null;
    }

    try {
      final value = dotenv.env[key]?.trim();
      if (value == null || value.isEmpty) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  static String? _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static bool _isPlaceholder(String value) {
    return value.contains('your_') || value.contains('YOUR_');
  }

  static bool _isUsableValue(String? value) {
    final normalized = value?.trim();
    return normalized != null &&
        normalized.isNotEmpty &&
        !_isPlaceholder(normalized);
  }

  static bool _looksLikeGoogleApiKey(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || _isPlaceholder(trimmed)) {
      return false;
    }

    // Google API keys for Maps/Places typically start with AIza and contain
    // URL-safe base characters. This is a sanity check, not a validator.
    return RegExp(r'^AIza[0-9A-Za-z_-]{20,}$').hasMatch(trimmed);
  }

  static List<String> collectGoogleApiConfigurationWarnings({
    required String? mapsApiKey,
    required String? placesApiKey,
    String? placesPhotoApiKey,
  }) {
    final warnings = <String>[];

    final normalizedMaps = mapsApiKey?.trim();
    final normalizedPlaces = placesApiKey?.trim();
    final normalizedPhoto = placesPhotoApiKey?.trim();

    if (normalizedMaps != null &&
        normalizedMaps.isNotEmpty &&
        !_looksLikeGoogleApiKey(normalizedMaps)) {
      warnings.add(
        'Google Maps API key appears malformed or placeholder-like. '
        'Verify release key provisioning.',
      );
    }

    if (normalizedPlaces != null &&
        normalizedPlaces.isNotEmpty &&
        !_looksLikeGoogleApiKey(normalizedPlaces)) {
      warnings.add(
        'Google Places API key appears malformed or placeholder-like. '
        'Verify release key provisioning.',
      );
    }

    if (normalizedPhoto != null &&
        normalizedPhoto.isNotEmpty &&
        !_looksLikeGoogleApiKey(normalizedPhoto)) {
      warnings.add(
        'Google Places photo API key appears malformed or placeholder-like. '
        'Verify release key provisioning.',
      );
    }

    if (normalizedMaps != null &&
        normalizedPlaces != null &&
        normalizedMaps.isNotEmpty &&
        normalizedPlaces.isNotEmpty &&
        !_isPlaceholder(normalizedMaps) &&
        !_isPlaceholder(normalizedPlaces) &&
        normalizedMaps == normalizedPlaces) {
      warnings.add(
        'Google Maps and Google Places currently use the same API key. '
        'Use separate restricted keys for production.',
      );
    }

    return warnings;
  }

  static String? get optionalSupabaseUrl => _firstNonEmpty([
        _supabaseUrlFromDefine,
        _readEnv('SUPABASE_URL') ?? '',
      ]);

  static String? get optionalSupabaseAnonKey => _firstNonEmpty([
        _supabaseAnonKeyFromDefine,
        _readEnv('SUPABASE_ANON_KEY') ?? '',
      ]);

  static bool get hasSupabaseConfig {
    final url = optionalSupabaseUrl;
    final anonKey = optionalSupabaseAnonKey;
    return hasSupabaseConfigFor(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
    );
  }

  static bool hasSupabaseConfigFor({
    required String? supabaseUrl,
    required String? supabaseAnonKey,
  }) {
    return _isUsableValue(supabaseUrl) && _isUsableValue(supabaseAnonKey);
  }

  static List<String> collectMissingRequiredConfigKeys({
    required String? supabaseUrl,
    required String? supabaseAnonKey,
  }) {
    final missing = <String>[];
    final normalizedUrl = supabaseUrl?.trim();
    final normalizedAnonKey = supabaseAnonKey?.trim();
    if (normalizedUrl == null ||
        normalizedUrl.isEmpty ||
        _isPlaceholder(normalizedUrl)) {
      missing.add('SUPABASE_URL');
    }
    if (normalizedAnonKey == null ||
        normalizedAnonKey.isEmpty ||
        _isPlaceholder(normalizedAnonKey)) {
      missing.add('SUPABASE_ANON_KEY');
    }
    return List<String>.unmodifiable(missing);
  }

  static List<String> get missingRequiredConfigKeys =>
      collectMissingRequiredConfigKeys(
        supabaseUrl: optionalSupabaseUrl,
        supabaseAnonKey: optionalSupabaseAnonKey,
      );

  static List<EnvConfigDiagnostic> get configDiagnostics {
    return buildConfigDiagnostics(
      values: <String, ({String dartDefine, String? dotenvAsset})>{
        'SUPABASE_URL': (
          dartDefine: _supabaseUrlFromDefine,
          dotenvAsset: _readEnv('SUPABASE_URL'),
        ),
        'SUPABASE_ANON_KEY': (
          dartDefine: _supabaseAnonKeyFromDefine,
          dotenvAsset: _readEnv('SUPABASE_ANON_KEY'),
        ),
        'GOOGLE_MAPS_API_KEY': (
          dartDefine: _googleMapsApiKeyFromDefine,
          dotenvAsset: _readEnv('GOOGLE_MAPS_API_KEY'),
        ),
        'GOOGLE_PLACES_API_KEY': (
          dartDefine: _googlePlacesApiKeyFromDefine,
          dotenvAsset: _readEnv('GOOGLE_PLACES_API_KEY'),
        ),
        'GOOGLE_PLACES_PHOTO_API_KEY': (
          dartDefine: _googlePlacesPhotoApiKeyFromDefine,
          dotenvAsset: _readEnv('GOOGLE_PLACES_PHOTO_API_KEY'),
        ),
      },
    );
  }

  static List<EnvConfigDiagnostic> buildConfigDiagnostics({
    required Map<String, ({String dartDefine, String? dotenvAsset})> values,
  }) {
    return values.entries.map((entry) {
      final dartDefine = entry.value.dartDefine;
      final dotenvAsset = entry.value.dotenvAsset;
      if (_isUsableValue(dartDefine)) {
        return EnvConfigDiagnostic(
          key: entry.key,
          isPresent: true,
          source: 'dart_define',
        );
      }
      if (_isUsableValue(dotenvAsset)) {
        return EnvConfigDiagnostic(
          key: entry.key,
          isPresent: true,
          source: 'dotenv_asset',
        );
      }
      return EnvConfigDiagnostic(
        key: entry.key,
        isPresent: false,
        source: 'none',
      );
    }).toList(growable: false);
  }

  static String get supabaseUrl {
    final url = optionalSupabaseUrl;
    if (url == null || _isPlaceholder(url)) {
      throw Exception(
        'Supabase URL is missing. Provide SUPABASE_URL with '
        '.env, --dart-define-from-file=.env.local.json, or '
        '--dart-define=SUPABASE_URL=your_url.',
      );
    }
    return url;
  }

  static String get supabaseAnonKey {
    final key = optionalSupabaseAnonKey;
    if (key == null || _isPlaceholder(key)) {
      throw Exception(
        'Supabase anon key is missing. Provide SUPABASE_ANON_KEY with '
        '.env, --dart-define-from-file=.env.local.json, or '
        '--dart-define=SUPABASE_ANON_KEY=your_key.',
      );
    }
    return key;
  }

  static String? get optionalGoogleMapsApiKey => _firstNonEmpty([
        _googleMapsApiKeyFromDefine,
        _readEnv('GOOGLE_MAPS_API_KEY') ?? '',
      ]);

  static String? get optionalGooglePlacesApiKey => _firstNonEmpty([
        _googlePlacesApiKeyFromDefine,
        _readEnv('GOOGLE_PLACES_API_KEY') ?? '',
      ]);

  static String? get optionalExplicitGooglePlacesPhotoApiKey => _firstNonEmpty([
        _googlePlacesPhotoApiKeyFromDefine,
        _readEnv('GOOGLE_PLACES_PHOTO_API_KEY') ?? '',
      ]);

  static String? get optionalGooglePlacesPhotoApiKey => _firstNonEmpty([
        optionalExplicitGooglePlacesPhotoApiKey ?? '',
        optionalGooglePlacesApiKey ?? '',
      ]);

  static List<String> get googleApiConfigurationWarnings =>
      collectGoogleApiConfigurationWarnings(
        mapsApiKey: optionalGoogleMapsApiKey,
        placesApiKey: optionalGooglePlacesApiKey,
        placesPhotoApiKey: optionalGooglePlacesPhotoApiKey,
      );

  static bool get hasGoogleMapsConfig {
    final key = optionalGoogleMapsApiKey;
    return key != null && !_isPlaceholder(key);
  }

  static bool get hasGooglePlacesConfig {
    final key = optionalGooglePlacesApiKey;
    return key != null && !_isPlaceholder(key);
  }

  static String get googleMapsApiKey {
    final key = optionalGoogleMapsApiKey;
    if (key == null || _isPlaceholder(key)) {
      throw Exception(
        'Google Maps API key is missing. Add GOOGLE_MAPS_API_KEY to .env or '
        'run with --dart-define-from-file=.env.local.json.',
      );
    }
    return key;
  }

  static String get googlePlacesApiKey {
    final key = optionalGooglePlacesApiKey;
    if (key == null || _isPlaceholder(key)) {
      throw Exception(
        'Google Places API key is missing. Add GOOGLE_PLACES_API_KEY to .env '
        'or run with --dart-define-from-file=.env.local.json.',
      );
    }
    return key;
  }
}
