import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

import '../../constants/ui_config.dart';
import '../../services/app_image_cache_manager.dart';
import '../../utils/app_logger.dart';
import '../../utils/cafe_media.dart';
import '../../utils/log_sanitizer.dart';

class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.imageUrl,
    required this.fit,
    this.cacheWidth,
    this.cacheHeight,
    this.requestWidth,
    this.isAntiAlias = true,
    this.loadingBuilder,
    this.errorBuilder,
    this.fadeInDuration = ImageConfig.fadeInDuration,
    this.filterQuality = FilterQuality.medium,
    this.traceTag,
    this.diagnosticSurface,
    this.diagnosticCafeId,
    this.diagnosticCafeName,
    this.onError,
  });

  final String imageUrl;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final int? requestWidth;
  final bool isAntiAlias;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? errorBuilder;
  final Duration fadeInDuration;
  final FilterQuality filterQuality;
  final String? traceTag;
  final String? diagnosticSurface;
  final String? diagnosticCafeId;
  final String? diagnosticCafeName;
  final ValueChanged<int?>? onError;

  static final Set<String> _probedUrls = <String>{};
  static const int _maxDebugProbes = 6;

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = resolveCafeImageUrl(
      imageUrl.trim(),
      maxWidthPx: requestWidth ?? cacheWidth,
    );
    if (normalizedImageUrl == null || normalizedImageUrl.isEmpty) {
      _logImageLoadFailure(
        imageUrl,
        error: 'invalid-image-url',
      );
      return errorBuilder?.call(context) ?? const SizedBox.shrink();
    }
    if (isKnownFailedCafeImageUrl(normalizedImageUrl)) {
      _logImageLoadFailure(
        normalizedImageUrl,
        error: 'known-failed-image-url',
      );
      return errorBuilder?.call(context) ?? const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: normalizedImageUrl,
      cacheKey: normalizedImageUrl,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      fadeInDuration: fadeInDuration,
      cacheManager: AppImageCacheManager.instance,
      useOldImageOnUrlChange: true,
      placeholder: (context, _) =>
          loadingBuilder?.call(context) ?? const SizedBox.shrink(),
      errorWidget: (context, _, error) {
        _logImageLoadFailure(normalizedImageUrl, error: error);
        final statusCode = _statusCodeFromError(error);
        if (statusCode == 400 || statusCode == 404) {
          rememberFailedCafeImageUrl(normalizedImageUrl);
        }
        _probeImageUrlOnDebug(normalizedImageUrl);
        onError?.call(statusCode);
        return errorBuilder?.call(context) ?? const SizedBox.shrink();
      },
      imageBuilder: (context, imageProvider) => Image(
        image: imageProvider,
        fit: fit,
        isAntiAlias: isAntiAlias,
        gaplessPlayback: true,
        filterQuality: filterQuality,
      ),
    );
  }

  void _logImageLoadFailure(
    String url, {
    required Object? error,
  }) {
    if (!kDebugMode) {
      return;
    }
    final safeError = _safeErrorMessage(error);
    final urlSummary = summarizeUrlForLog(url, presenceLabel: 'imageUrl');
    final urlShape = googlePhotoUrlDiagnosticsForLog(url);
    final statusCode = _statusCodeFromError(error);
    AppLogger.debug(
      '[CAFE_DIAG_PHOTO_LOAD_ERROR] surface=${_diagnosticSurfaceLabel()} cafeId=${_diagnosticCafeIdLabel()} cafeName="${_diagnosticCafeNameLabel()}" traceTag=${traceTag ?? 'none'} $urlSummary $urlShape status=${statusCode ?? 'unknown'} errorType=${error.runtimeType} error="$safeError"',
      key:
          'cafe-photo-load-error-${traceTag ?? _diagnosticSurfaceLabel()}-${_diagnosticCafeIdLabel()}-${_urlHost(url)}',
    );
  }

  void _probeImageUrlOnDebug(String url) {
    if (!kDebugMode || !url.contains('places.googleapis.com')) {
      return;
    }
    if (_probedUrls.length >= _maxDebugProbes || !_probedUrls.add(url)) {
      return;
    }

    unawaited(() async {
      try {
        final uri = Uri.parse(url);
        final response = await http.head(uri).timeout(
              const Duration(seconds: 6),
            );
        if (response.statusCode == 400 || response.statusCode == 404) {
          rememberFailedCafeImageUrl(url);
        }
        AppLogger.debug(
          '[CAFE_DIAG_PHOTO_HTTP_PROBE] surface=${_diagnosticSurfaceLabel()} cafeId=${_diagnosticCafeIdLabel()} cafeName="${_diagnosticCafeNameLabel()}" ${googlePhotoUrlDiagnosticsForLog(url)} status=${response.statusCode} contentType=${response.headers['content-type'] ?? 'unknown'}',
          key: 'cafe-photo-http-probe-${traceTag ?? _diagnosticCafeIdLabel()}',
        );
      } catch (error) {
        AppLogger.debug(
          '[CAFE_DIAG_PHOTO_HTTP_PROBE] surface=${_diagnosticSurfaceLabel()} cafeId=${_diagnosticCafeIdLabel()} cafeName="${_diagnosticCafeNameLabel()}" ${googlePhotoUrlDiagnosticsForLog(url)} status=probe_failed errorType=${error.runtimeType} error="${_safeErrorMessage(error)}"',
          key: 'cafe-photo-http-probe-${traceTag ?? _diagnosticCafeIdLabel()}',
        );
      }
    }());
  }

  String _diagnosticSurfaceLabel() {
    final explicit = diagnosticSurface?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final tag = traceTag?.trim();
    if (tag == null || tag.isEmpty) {
      return 'remote_image';
    }
    return tag.split(':').first;
  }

  String _diagnosticCafeIdLabel() {
    final explicit = diagnosticCafeId?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final tag = traceTag?.trim();
    if (tag == null || tag.isEmpty || !tag.contains(':')) {
      return 'unknown';
    }
    return tag.split(':').skip(1).first;
  }

  String _diagnosticCafeNameLabel() {
    final value = diagnosticCafeName?.trim();
    if (value == null || value.isEmpty) {
      return 'unknown';
    }
    return value.length > 80 ? '${value.substring(0, 80)}...' : value;
  }

  String _urlHost(String url) {
    return Uri.tryParse(url)?.host.toLowerCase() ?? 'unknown';
  }

  String _safeErrorMessage(Object? error) {
    final raw = error?.toString() ?? 'unknown';
    final withoutUrls = raw.replaceAll(
      RegExp(r'https?:\/\/\S+'),
      '[redacted-url]',
    );
    final withoutKeys = withoutUrls.replaceAllMapped(
      RegExp(r'(key=)[^&\s]+', caseSensitive: false),
      (match) => '${match.group(1)}[redacted]',
    );
    return withoutKeys.length > 180
        ? '${withoutKeys.substring(0, 180)}...'
        : withoutKeys;
  }

  int? _statusCodeFromError(Object? error) {
    final raw = error?.toString() ?? '';
    final invalidStatus =
        RegExp(r'Invalid statusCode:\s*(\d{3})').firstMatch(raw);
    if (invalidStatus != null) {
      return int.tryParse(invalidStatus.group(1)!);
    }
    final status = RegExp(r'status(?:Code)?[=:]\s*(\d{3})').firstMatch(raw);
    if (status != null) {
      return int.tryParse(status.group(1)!);
    }
    return null;
  }
}
