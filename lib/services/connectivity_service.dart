import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _currentlyOnline = true;
  bool _started = false;

  bool get currentlyOnline => _currentlyOnline;

  Stream<bool> get isOnline async* {
    await ensureStarted();
    yield _currentlyOnline;
    yield* _controller.stream;
  }

  Future<void> ensureStarted() async {
    if (_started) {
      return;
    }
    _started = true;
    try {
      final current = await _connectivity.checkConnectivity();
      _emit(_isOnline(current));
      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        _emit(_isOnline(results));
      });
    } on MissingPluginException {
      // In tests or unsupported hosts, default to online and skip stream bind.
      _emit(true);
    }
  }

  void _emit(bool next) {
    if (_currentlyOnline == next && _controller.hasListener) {
      return;
    }
    _currentlyOnline = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  unawaited(service.ensureStarted());
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

final connectivityProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isOnline;
});
