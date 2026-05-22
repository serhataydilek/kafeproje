import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_provider.dart';
import '../services/local_storage_service.dart';

enum AppLocaleMode {
  system,
  tr,
  en,
}

class LocaleNotifier extends StateNotifier<AppLocaleMode> {
  LocaleNotifier(this._ref) : super(AppLocaleMode.system) {
    _load();
  }

  final Ref _ref;

  LocalStorageService? _safeStorage() {
    return _ref.read(localStorageServiceProvider);
  }

  Future<void> _load() async {
    final storage = _safeStorage();
    if (storage == null) {
      state = AppLocaleMode.system;
      return;
    }

    final rawMode = await storage.loadLocaleMode();
    state = switch (rawMode) {
      'tr' => AppLocaleMode.tr,
      'en' => AppLocaleMode.en,
      _ => AppLocaleMode.system,
    };
  }

  Future<void> setLocaleMode(AppLocaleMode mode) async {
    state = mode;
    final storage = _safeStorage();
    if (storage == null) {
      return;
    }
    await storage.saveLocaleMode(mode.name);
  }
}

final localeModeProvider =
    StateNotifierProvider<LocaleNotifier, AppLocaleMode>((ref) {
  return LocaleNotifier(ref);
});

final appLocaleProvider = Provider<Locale?>((ref) {
  return switch (ref.watch(localeModeProvider)) {
    AppLocaleMode.system => null,
    AppLocaleMode.tr => const Locale('tr'),
    AppLocaleMode.en => const Locale('en'),
  };
});
