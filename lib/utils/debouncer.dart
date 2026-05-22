import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/app_cache_config.dart';

class Debouncer {
  Debouncer({this.delay = RequestTuningConfig.searchInputDebounce});

  final Duration delay;
  Timer? _timer;

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
