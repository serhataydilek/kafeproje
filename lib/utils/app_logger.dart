import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static final Map<String, DateTime> _lastLogAtByKey = {};
  static final Map<String, int> _suppressedCounts = {};
  static const Duration _defaultThrottle = Duration(seconds: 8);
  static FirebaseCrashlytics? _crashlytics;

  static void configureCrashlytics(FirebaseCrashlytics? crashlytics) {
    _crashlytics = crashlytics;
  }

  static void debug(
    String message, {
    String? key,
    Duration throttle = _defaultThrottle,
  }) {
    if (!kDebugMode) {
      return;
    }
    final effectiveKey = key ?? message;
    if (_shouldSkip(effectiveKey, throttle)) {
      return;
    }
    debugPrint('[debug] ${_prefixWithSuppressedCount(effectiveKey)}$message');
  }

  static void warn(
    String message, {
    String? key,
    Duration throttle = _defaultThrottle,
  }) {
    final effectiveKey = key ?? message;
    if (_shouldSkip(effectiveKey, throttle)) {
      return;
    }
    debugPrint('[warn] ${_prefixWithSuppressedCount(effectiveKey)}$message');
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? key,
    Duration throttle = _defaultThrottle,
  }) {
    final effectiveKey = key ?? message;
    if (_shouldSkip(effectiveKey, throttle)) {
      return;
    }
    final suffix = error == null ? '' : ' | $error';
    debugPrint(
      '[error] ${_prefixWithSuppressedCount(effectiveKey)}$message$suffix',
    );
    _recordCrashlytics(
      message,
      error: error,
      stackTrace: stackTrace,
      key: effectiveKey,
      fatal: false,
    );
  }

  static void critical(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? key,
  }) {
    final effectiveKey = key ?? message;
    final suffix = error == null ? '' : ' | $error';
    debugPrint(
      '[critical] ${_prefixWithSuppressedCount(effectiveKey)}$message$suffix',
    );
    _recordCrashlytics(
      message,
      error: error,
      stackTrace: stackTrace,
      key: effectiveKey,
      fatal: true,
    );
  }

  static void flush() {
    final keys = _suppressedCounts.keys.toList(growable: false);
    for (final key in keys) {
      final count = _suppressedCounts.remove(key) ?? 0;
      if (count <= 0) {
        continue;
      }
      debugPrint('[log] (repeated $count x) throttled key=$key');
    }
  }

  static bool _shouldSkip(String key, Duration throttle) {
    final now = DateTime.now();
    final lastLoggedAt = _lastLogAtByKey[key];
    if (lastLoggedAt != null && now.difference(lastLoggedAt) < throttle) {
      _suppressedCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
      return true;
    }
    _lastLogAtByKey[key] = now;
    return false;
  }

  static String _prefixWithSuppressedCount(String key) {
    final count = _suppressedCounts.remove(key) ?? 0;
    if (count <= 0) {
      return '';
    }
    return '(repeated $count x) ';
  }

  static void _recordCrashlytics(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? key,
    required bool fatal,
  }) {
    if (kDebugMode || _crashlytics == null) {
      return;
    }

    unawaited(() async {
      try {
        if (key != null) {
          await _crashlytics!.setCustomKey('logger_key', key);
        }
        await _crashlytics!.recordError(
          error ?? message,
          stackTrace ?? StackTrace.current,
          reason: message,
          fatal: fatal,
        );
      } catch (_) {
        // Logging should never crash the app.
      }
    }());
  }
}
