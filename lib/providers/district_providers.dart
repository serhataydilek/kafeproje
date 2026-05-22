import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../data/fallback_districts.dart';
import '../models/district.dart';
import '../repositories/district_repository.dart';
import '../services/connectivity_service.dart';
import '../services/districts_service.dart';
import '../services/local_storage_service.dart';
import '../utils/app_logger.dart';
import '../utils/district_utils.dart';

final discoveryCityProvider = Provider<String>((ref) {
  return FallbackDistrictCatalog.defaultCity;
});

final discoveryCityDisplayNameProvider = Provider<String>((ref) {
  switch (ref.watch(discoveryCityProvider)) {
    case 'istanbul':
      return 'Istanbul';
    default:
      final city = ref.watch(discoveryCityProvider);
      if (city.isEmpty) {
        return 'Istanbul';
      }
      return '${city[0].toUpperCase()}${city.substring(1)}';
  }
});

final districtLocalStorageServiceProvider =
    Provider<LocalStorageService?>((ref) => null);

final districtSupabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!Env.hasSupabaseConfig) {
    return null;
  }
  return Supabase.instance.client;
});

final districtsServiceProvider = Provider<DistrictsService?>((ref) {
  final client = ref.watch(districtSupabaseClientProvider);
  if (client == null) {
    return null;
  }
  return DistrictsService(client);
});

final districtRepositoryProvider = Provider<DistrictRepository>((ref) {
  return DistrictRepository(
    remoteService: ref.watch(districtsServiceProvider),
    storage: ref.watch(districtLocalStorageServiceProvider),
  );
});

enum DistrictConfigSource {
  initial,
  remote,
  cache,
  fallback,
}

class DistrictConfigState {
  const DistrictConfigState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.districts = const <District>[],
    this.source = DistrictConfigSource.initial,
    this.errorMessage,
    this.lastUpdated,
  });

  final bool isLoading;
  final bool isRefreshing;
  final List<District> districts;
  final DistrictConfigSource source;
  final String? errorMessage;
  final DateTime? lastUpdated;

  bool get isUsingFallback => source == DistrictConfigSource.fallback;
  bool get isUsingCache => source == DistrictConfigSource.cache;

  DistrictConfigState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    List<District>? districts,
    DistrictConfigSource? source,
    String? Function()? errorMessage,
    DateTime? Function()? lastUpdated,
  }) {
    return DistrictConfigState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      districts: districts ?? this.districts,
      source: source ?? this.source,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      lastUpdated: lastUpdated != null ? lastUpdated() : this.lastUpdated,
    );
  }
}

class DistrictConfigNotifier extends StateNotifier<DistrictConfigState> {
  DistrictConfigNotifier(this._ref) : super(const DistrictConfigState()) {
    _bindConnectivityRefresh();
    unawaited(preload());
  }

  final Ref _ref;
  StreamSubscription<bool>? _connectivitySubscription;
  Future<void>? _preloadFuture;
  Future<void>? _refreshFuture;
  bool _loggedMissingTableWarning = false;

  void _bindConnectivityRefresh() {
    WidgetsFlutterBinding.ensureInitialized();
    final connectivity = _ref.read(connectivityServiceProvider);
    _connectivitySubscription = connectivity.isOnline.listen((isOnline) {
      if (!isOnline || !_shouldRefresh()) {
        return;
      }
      unawaited(refresh());
    });
  }

  Future<void> preload() {
    return _preloadFuture ??= _preload();
  }

  Future<void> _preload() async {
    final repository = _ref.read(districtRepositoryProvider);
    final city = _ref.read(discoveryCityProvider);
    final cached = await repository.loadCachedDistricts(city: city);
    if (!mounted) {
      return;
    }

    if (cached != null && cached.districts.isNotEmpty) {
      state = state.copyWith(
        isLoading: false,
        districts: cached.districts,
        source: DistrictConfigSource.cache,
        errorMessage: () => null,
        lastUpdated: () => cached.lastUpdated,
      );
    } else {
      final fallback = repository.loadFallbackDistricts(city: city);
      state = state.copyWith(
        isLoading: false,
        districts: fallback,
        source: DistrictConfigSource.fallback,
        errorMessage: () => null,
        lastUpdated: () => null,
      );
    }

    if (_shouldRefresh()) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() {
    final inflight = _refreshFuture;
    if (inflight != null) {
      return inflight;
    }

    final future = _refresh();
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
  }

  Future<void> _refresh() async {
    final repository = _ref.read(districtRepositoryProvider);
    final city = _ref.read(discoveryCityProvider);

    state = state.copyWith(
      isLoading: state.districts.isEmpty,
      isRefreshing: true,
      errorMessage: () => null,
    );

    try {
      final snapshot = await repository.refreshDistricts(city: city);
      if (!mounted) {
        return;
      }

      if (snapshot == null || snapshot.districts.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: () => state.districts.isEmpty
              ? 'District configuration is unavailable.'
              : null,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        districts: snapshot.districts,
        source: DistrictConfigSource.remote,
        errorMessage: () => null,
        lastUpdated: () => snapshot.lastUpdated,
      );
    } catch (error, stackTrace) {
      if (_isMissingDistrictsTable(error)) {
        if (!_loggedMissingTableWarning) {
          _loggedMissingTableWarning = true;
          AppLogger.warn(
            '[DISTRICTS_CONFIG_FALLBACK] reason=missing_table',
            key: 'districts-config-fallback-missing-table',
            throttle: Duration.zero,
          );
        }
        if (!mounted) {
          return;
        }

        if (state.districts.isEmpty) {
          final fallback = repository.loadFallbackDistricts(city: city);
          state = state.copyWith(
            isLoading: false,
            isRefreshing: false,
            districts: fallback,
            source: DistrictConfigSource.fallback,
            errorMessage: () => null,
            lastUpdated: () => null,
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            isRefreshing: false,
            errorMessage: () => null,
          );
        }
        return;
      }

      AppLogger.error(
        'DistrictConfigNotifier.refresh failed',
        error: error,
        stackTrace: stackTrace,
        key: 'district-config-refresh',
      );
      if (!mounted) {
        return;
      }

      if (state.districts.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: () => 'District configuration is unavailable.',
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: () => 'Using cached district configuration.',
      );
    }
  }

  bool _shouldRefresh() {
    final snapshot = state.lastUpdated == null
        ? null
        : DistrictCacheSnapshot(
            city: _ref.read(discoveryCityProvider),
            districts: state.districts,
            lastUpdated: state.lastUpdated!,
          );
    return _ref.read(districtRepositoryProvider).shouldRefresh(snapshot);
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }
}

bool _isMissingDistrictsTable(Object error) {
  if (error is PostgrestException) {
    final code = error.code?.trim();
    if (code == 'PGRST205') {
      return true;
    }
    final message = error.message.toLowerCase();
    if (message.contains('could not find the table') ||
        message.contains('does not exist')) {
      return true;
    }
  }

  final message = error.toString().toLowerCase();
  return message.contains('pgrst205') ||
      message.contains('could not find the table') ||
      (message.contains('districts') && message.contains('does not exist'));
}

final districtConfigProvider =
    StateNotifierProvider<DistrictConfigNotifier, DistrictConfigState>((ref) {
  return DistrictConfigNotifier(ref);
});

final activeDistrictsProvider = Provider<List<District>>((ref) {
  final state = ref.watch(districtConfigProvider);
  return state.districts.isNotEmpty
      ? state.districts
      : FallbackDistrictCatalog.districtsForCity(
          ref.watch(discoveryCityProvider));
});

final districtOptionsProvider = Provider<List<String>>((ref) {
  return districtDisplayNames(ref.watch(activeDistrictsProvider));
});

final districtOptionsWithUnknownProvider = Provider<List<String>>((ref) {
  return districtDisplayNames(
    ref.watch(activeDistrictsProvider),
    includeUnknown: true,
  );
});
