import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'constants/app_cache_config.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'navigation/app_router.dart';
import 'providers/app_provider.dart';
import 'services/local_storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';

typedef PlatformErrorHandler = bool Function(
    Object error, StackTrace stackTrace);

bool _platformDispatcherErrorBridgeInstalled = false;

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    _installPlatformDispatcherErrorBridge();

    PaintingBinding.instance.imageCache.maximumSize =
        ImageCacheConfig.maximumSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        ImageCacheConfig.maximumSizeBytes;

    FlutterError.onError = FlutterError.presentError;

    FirebaseCrashlytics? crashlytics;
    try {
      await Env.load();

      crashlytics = await _initializeCrashReporting();

      final localStorage = await LocalStorageService.open();
      _logEnvConfigDiagnostics();

      if (Env.hasSupabaseConfig) {
        await Supabase.initialize(
          url: Env.supabaseUrl,
          anonKey: Env.supabaseAnonKey,
          debug: false,
        );
        _logSupabaseProjectRef();
      } else {
        _logMissingRequiredConfig();
      }

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(localStorage),
          districtLocalStorageServiceProvider.overrideWithValue(localStorage),
        ],
      );

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const MyApp(),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.critical(
        'Boot: startup failed',
        error: error,
        stackTrace: stackTrace,
        key: 'startup-failed',
      );
      if (crashlytics != null) {
        await crashlytics.recordError(error, stackTrace, fatal: true);
      }
      runApp(const _StartupErrorApp());
    }
  }, (error, stackTrace) {
    AppLogger.critical(
      'Boot: uncaught async error',
      error: error,
      stackTrace: stackTrace,
      key: 'startup-zone',
    );
  });
}

void _logEnvConfigDiagnostics() {
  for (final diagnostic in Env.configDiagnostics) {
    AppLogger.debug(
      diagnostic.logLine,
      key: 'env-config-${diagnostic.key}',
      throttle: Duration.zero,
    );
  }
  final missingKeys = Env.missingRequiredConfigKeys;
  AppLogger.debug(
    '[SUPABASE_INIT] configured=${missingKeys.isEmpty} '
    'missingKeys=${missingKeys.join(',')}',
    key: 'supabase-init-configured',
    throttle: Duration.zero,
  );
}

void _logMissingRequiredConfig() {
  final missingKeys = Env.missingRequiredConfigKeys;
  if (missingKeys.isEmpty) {
    return;
  }
  AppLogger.warn(
    '[ENV_CONFIG] missingRequiredKeys=${missingKeys.join(',')} '
    'Supabase will not initialize. Local run example: '
    'add .env locally or run flutter run --dart-define-from-file=.env.local.json',
    key: 'env-config-missing-required',
    throttle: Duration.zero,
  );
  if (Env.dotEnvLoadError != null) {
    AppLogger.debug(
      '[ENV_CONFIG] dotenvAssetLoaded=false reason=asset_unavailable',
      key: 'env-config-dotenv-asset',
      throttle: Duration.zero,
    );
  }
}

void _logSupabaseProjectRef() {
  final url = Env.optionalSupabaseUrl;
  if (url == null || url.trim().isEmpty) {
    return;
  }
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.isEmpty) {
    return;
  }
  AppLogger.debug(
    '[SUPABASE_ENV] host=$host',
    key: 'supabase-env-host',
    throttle: Duration.zero,
  );
}

void _installPlatformDispatcherErrorBridge() {
  if (_platformDispatcherErrorBridgeInstalled) {
    return;
  }

  final previousHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = buildPlatformErrorBridgeHandler(
    existingHandler: previousHandler,
    onUnhandledError: (error, stackTrace) {
      AppLogger.critical(
        'Boot: uncaught platform async error',
        error: error,
        stackTrace: stackTrace,
        key: 'startup-platform-dispatcher',
      );
    },
  );
  _platformDispatcherErrorBridgeInstalled = true;
}

PlatformErrorHandler buildPlatformErrorBridgeHandler({
  PlatformErrorHandler? existingHandler,
  required void Function(Object error, StackTrace stackTrace) onUnhandledError,
}) {
  return (Object error, StackTrace stackTrace) {
    final wasHandledByExisting =
        existingHandler?.call(error, stackTrace) ?? false;
    if (wasHandledByExisting) {
      return true;
    }

    onUnhandledError(error, stackTrace);
    return true;
  };
}

Future<FirebaseCrashlytics?> _initializeCrashReporting() async {
  try {
    await Firebase.initializeApp();
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    AppLogger.configureCrashlytics(crashlytics);
    return crashlytics;
  } catch (error) {
    AppLogger.configureCrashlytics(null);
    return null;
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    ref.watch(districtConfigProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      locale: locale,
      supportedLocales: const [
        Locale('tr'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale == null) {
          return const Locale('tr');
        }

        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == deviceLocale.languageCode) {
            return supportedLocale;
          }
        }

        return const Locale('tr');
      },
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'App startup failed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This feature is currently unavailable. Please check your app configuration and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: main,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
