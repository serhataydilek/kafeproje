import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

import '../constants/network_config.dart';

class AppImageCacheManager {
  AppImageCacheManager._();

  static const String cacheKey = 'kafeprojeImageCacheV3';

  static final BaseCacheManager instance = CacheManager(
    Config(
      cacheKey,
      stalePeriod: const Duration(days: 10),
      maxNrOfCacheObjects: 120,
      fileService: _TimeoutHttpFileService(),
    ),
  );
}

class _TimeoutHttpFileService extends HttpFileService {
  _TimeoutHttpFileService()
      : super(
          httpClient: http.Client(),
        );

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) {
    return super
        .get(url, headers: headers)
        .timeout(NetworkTimeoutConfig.imageRequestTimeout);
  }
}
