import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../config/env.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/app_image_cache_manager.dart';
import 'app_logger.dart';
import 'log_sanitizer.dart';

enum CafeImageVariant {
  listThumbnail,
  mapPreview,
  detailGallery,
  avatar,
}

enum CafeImageSourceType {
  none,
  directUrl,
  supabaseStorage,
  legacyGooglePhoto,
  placesV1Media,
  invalid,
}

// Admin-managed image URLs are restricted to trusted hosts so arbitrary
// tracking/unknown domains are not silently accepted.
const Set<String> _trustedAdminImageHosts = <String>{
  'places.googleapis.com',
  'maps.googleapis.com',
  'googleusercontent.com',
  'lh3.googleusercontent.com',
};

const Set<String> _nonProductionTrustedAdminImageHosts = <String>{
  // Included to keep deterministic test fixtures valid.
  'example.com',
};

const bool _allowNonProductionTrustedHosts = !kReleaseMode && !kProfileMode;
const int _maxRememberedFailedImageUrls = 80;

final Set<String> _failedCafeImageUrlKeys = <String>{};

extension CafeImageVariantSizing on CafeImageVariant {
  int get requestWidthPx => switch (this) {
        CafeImageVariant.listThumbnail => 720,
        CafeImageVariant.mapPreview => 320,
        CafeImageVariant.detailGallery => 1280,
        CafeImageVariant.avatar => 256,
      };

  int get decodeWidthPx => switch (this) {
        CafeImageVariant.listThumbnail => 640,
        CafeImageVariant.mapPreview => 240,
        CafeImageVariant.detailGallery => 1280,
        CafeImageVariant.avatar => 256,
      };

  int? get decodeHeightPx => switch (this) {
        CafeImageVariant.listThumbnail => 360,
        CafeImageVariant.mapPreview => 240,
        CafeImageVariant.detailGallery => 720,
        CafeImageVariant.avatar => 256,
      };
}

List<String> normalizeCafeImageUrls(
  Iterable<String?> rawUrls, {
  int maxCount = 8,
  String? diagnosticSurface,
}) {
  final urls = <String>[];
  final seen = <String>{};

  for (final rawUrl in rawUrls) {
    final normalized = resolveCafeImageUrl(rawUrl);
    final rejectedReason = normalized == null
        ? 'resolve_null'
        : isKnownFailedCafeImageUrl(normalized)
            ? 'known_failed'
            : !seen.add(normalized)
                ? 'duplicate'
                : null;
    _logMediaClassificationDiag(
      rawUrl,
      normalized,
      rejectedReason: rejectedReason,
      diagnosticSurface: diagnosticSurface,
    );
    final accepted = normalized;
    if (rejectedReason != null || accepted == null) {
      continue;
    }
    urls.add(accepted);
    if (urls.length >= maxCount) {
      break;
    }
  }

  return List<String>.unmodifiable(urls);
}

List<String> normalizeCafeImageUrlsByPriority(
  Iterable<String?> rawUrls, {
  int maxCount = 8,
  bool includeGeneratedPlacesMedia = true,
  String? diagnosticSurface,
}) {
  final preferred = <String>[];
  final generatedPlaces = <String>[];
  final seen = <String>{};

  for (final rawUrl in rawUrls) {
    final normalized = resolveCafeImageUrl(rawUrl);
    final rejectedReason = normalized == null
        ? 'resolve_null'
        : isKnownFailedCafeImageUrl(normalized)
            ? 'known_failed'
            : !seen.add(normalized)
                ? 'duplicate'
                : null;
    _logMediaClassificationDiag(
      rawUrl,
      normalized,
      rejectedReason: rejectedReason,
      diagnosticSurface: diagnosticSurface,
    );
    final accepted = normalized;
    if (rejectedReason != null || accepted == null) {
      continue;
    }
    if (isGeneratedPlacesMediaImageUrl(accepted)) {
      generatedPlaces.add(accepted);
    } else {
      preferred.add(accepted);
    }
  }

  final merged = <String>[
    ...preferred,
    if (includeGeneratedPlacesMedia) ...generatedPlaces,
  ];
  return List<String>.unmodifiable(merged.take(maxCount));
}

void _logMediaClassificationDiag(
  String? rawUrl,
  String? resolvedUrl, {
  required String? rejectedReason,
  String? diagnosticSurface,
}) {
  if (!kDebugMode) {
    return;
  }
  final surface = diagnosticSurface?.trim();
  if (surface != 'featured' &&
      surface != 'home-sponsored' &&
      surface != 'featured-hydration') {
    return;
  }
  final generatedResult = isGeneratedPlacesMediaImageUrl(rawUrl);
  final resolveReturnedNull = resolvedUrl == null;
  final sourceType = cafeImageSourceType(rawUrl);
  final outputUri = resolvedUrl == null ? null : Uri.tryParse(resolvedUrl);
  final outputHost = outputUri?.host.toLowerCase() ?? 'none';
  final outputPathShape =
      outputUri == null ? 'none' : _googlePhotoPathShape(outputUri.path);
  AppLogger.debug(
    '[MEDIA_CLASSIFICATION_DIAG] surface=$surface inputShape=${_mediaInputShape(rawUrl)} outputHost=$outputHost outputPathShape=$outputPathShape classifiedAsStored=${sourceType == CafeImageSourceType.supabaseStorage} classifiedAsGenerated=${sourceType == CafeImageSourceType.placesV1Media} classifiedAsLegacy=${sourceType == CafeImageSourceType.legacyGooglePhoto} classifiedAsDirect=${sourceType == CafeImageSourceType.directUrl} rejectedReason=${rejectedReason ?? 'none'} isGeneratedPlacesMediaImageUrlResult=$generatedResult resolveCafeImageUrlReturnedNull=$resolveReturnedNull',
    key: 'media-classification-${surface ?? 'unknown'}-${_mediaLogKey(rawUrl)}',
    throttle: Duration.zero,
  );
}

String _mediaInputShape(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return 'empty';
  }
  final uri = Uri.tryParse(trimmed);
  if (uri?.hasScheme == true) {
    return 'url:${uri!.host.toLowerCase()}:${_googlePhotoPathShape(uri.path)}';
  }
  if (normalizeGooglePhotoName(trimmed) != null) {
    return 'places_photo_name';
  }
  if (_normalizeLegacyGooglePhotoReference(trimmed) != null) {
    return 'legacy_photo_reference';
  }
  if (_normalizeSupabaseStoragePath(trimmed) != null) {
    return 'storage_path';
  }
  return 'unknown';
}

String _mediaLogKey(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return 'empty';
  }
  return trimmed.hashCode.abs().toString();
}

List<String> parseCafeImageInput(
  String rawInput, {
  int maxCount = 8,
  bool requireTrustedHosts = false,
}) {
  final normalized = normalizeCafeImageUrls(
    rawInput
        .split(RegExp(r'[\r\n,]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty),
    maxCount: maxCount,
  );

  if (!requireTrustedHosts) {
    return normalized;
  }

  return normalized.where(isTrustedAdminImageUrl).toList(growable: false);
}

bool hasInvalidCafeImageInput(
  String rawInput, {
  bool requireTrustedHosts = false,
}) {
  final parts = rawInput
      .split(RegExp(r'[\r\n,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return false;
  }

  for (final part in parts) {
    final resolved = resolveCafeImageUrl(part);
    if (resolved == null) {
      return true;
    }
    if (requireTrustedHosts && !isTrustedAdminImageUrl(resolved)) {
      return true;
    }
  }

  return false;
}

bool hasUntrustedAdminImageHosts(Iterable<String> urls) {
  for (final url in urls) {
    final normalized = resolveCafeImageUrl(url);
    if (normalized == null || !isTrustedAdminImageUrl(normalized)) {
      return true;
    }
  }
  return false;
}

bool isTrustedAdminImageUrl(
  String resolvedUrl, {
  bool allowNonProductionHosts = _allowNonProductionTrustedHosts,
}) {
  final uri = Uri.tryParse(resolvedUrl);
  if (uri == null || uri.host.isEmpty) {
    return false;
  }

  final host = uri.host.toLowerCase();
  for (final candidate in _resolvedTrustedAdminHosts(
    allowNonProductionHosts: allowNonProductionHosts,
  )) {
    if (host == candidate || host.endsWith('.$candidate')) {
      return true;
    }
  }

  return false;
}

Set<String> _resolvedTrustedAdminHosts({
  bool allowNonProductionHosts = _allowNonProductionTrustedHosts,
}) {
  final hosts = <String>{..._trustedAdminImageHosts};
  if (allowNonProductionHosts) {
    hosts.addAll(_nonProductionTrustedAdminImageHosts);
  }
  final supabaseUrl = Env.optionalSupabaseUrl;
  final supabaseUri = supabaseUrl == null || supabaseUrl.isEmpty
      ? null
      : Uri.tryParse(supabaseUrl);
  final supabaseHost = supabaseUri?.host.trim().toLowerCase();
  if (supabaseHost != null && supabaseHost.isNotEmpty) {
    hosts.add(supabaseHost);
  }
  return hosts;
}

String? resolveCafeImageUrl(
  String? rawUrl, {
  int? maxWidthPx,
}) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final protocolSafe = trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
  final googlePhotoName = normalizeGooglePhotoName(protocolSafe);
  if (googlePhotoName != null) {
    final effectiveMaxWidth = _validImageSize(maxWidthPx) ??
        CafeImageVariant.detailGallery.requestWidthPx;
    final apiKey = Env.optionalGooglePlacesPhotoApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      // Without an API key, still emit a deterministic HTTPS media URL so
      // callers can keep stable image pipelines in test/dev environments.
      final uri = Uri.tryParse(protocolSafe);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        return _appendGoogleSizeQuery(uri, effectiveMaxWidth)
            .replace(scheme: 'https')
            .toString();
      }

      return Uri.https(
        'places.googleapis.com',
        '/v1/${_stripMediaSuffix(googlePhotoName)}/media',
        <String, String>{
          'maxWidthPx': '$effectiveMaxWidth',
        },
      ).toString();
    }
    return buildGooglePhotoMediaUrl(
      googlePhotoName,
      apiKey: apiKey,
      maxWidthPx: effectiveMaxWidth,
    );
  }

  final legacyReference = _normalizeLegacyGooglePhotoReference(protocolSafe);
  if (legacyReference != null) {
    return _buildLegacyGooglePhotoUrl(
      legacyReference,
      maxWidthPx: maxWidthPx,
    );
  }

  final supabaseStorageUrl = _normalizeSupabaseStoragePath(protocolSafe);
  if (supabaseStorageUrl != null) {
    return supabaseStorageUrl;
  }

  final uri = Uri.tryParse(protocolSafe);
  if (uri == null || !uri.hasScheme) {
    return null;
  }

  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return null;
  }

  if (uri.host == 'places.googleapis.com') {
    return null;
  }

  if (uri.scheme == 'http') {
    return uri.replace(scheme: 'https').toString();
  }

  return uri.toString();
}

bool isGeneratedPlacesMediaImageUrl(String? rawUrl) {
  final resolved = resolveCafeImageUrl(rawUrl);
  if (resolved == null) {
    return false;
  }
  final uri = Uri.tryParse(resolved);
  return uri?.host.toLowerCase() == 'places.googleapis.com' &&
      normalizeGooglePhotoName(resolved) != null;
}

CafeImageSourceType cafeImageSourceType(String? rawUrl) {
  final resolved = resolveCafeImageUrl(rawUrl);
  if (resolved == null) {
    return rawUrl == null || rawUrl.trim().isEmpty
        ? CafeImageSourceType.none
        : CafeImageSourceType.invalid;
  }
  final uri = Uri.tryParse(resolved);
  final host = uri?.host.toLowerCase() ?? '';
  if (host == 'maps.googleapis.com') {
    return CafeImageSourceType.legacyGooglePhoto;
  }
  if (host == 'places.googleapis.com') {
    return CafeImageSourceType.placesV1Media;
  }
  final supabaseUrl = Env.optionalSupabaseUrl;
  final supabaseHost = supabaseUrl == null
      ? null
      : Uri.tryParse(supabaseUrl)?.host.toLowerCase();
  if (supabaseHost != null && host == supabaseHost) {
    return CafeImageSourceType.supabaseStorage;
  }
  if (host.isNotEmpty) {
    return CafeImageSourceType.directUrl;
  }
  return CafeImageSourceType.invalid;
}

String cafeImageSourceTypeLabel(String? rawUrl) {
  return switch (cafeImageSourceType(rawUrl)) {
    CafeImageSourceType.none => 'none',
    CafeImageSourceType.directUrl => 'direct-url',
    CafeImageSourceType.supabaseStorage => 'supabase-storage',
    CafeImageSourceType.legacyGooglePhoto => 'legacy-google-photo',
    CafeImageSourceType.placesV1Media => 'places-v1-media',
    CafeImageSourceType.invalid => 'invalid',
  };
}

String cafeImageSourceDiagnosticsForLog(String? rawUrl) {
  final resolved = resolveCafeImageUrl(rawUrl);
  final generatedUrl = rawUrl != null &&
      rawUrl.trim().isNotEmpty &&
      resolved != null &&
      rawUrl.trim() != resolved;
  return 'sourceType=${cafeImageSourceTypeLabel(rawUrl)} '
      '${googlePhotoUrlDiagnosticsForLog(resolved ?? rawUrl)} '
      'generatedUrl=$generatedUrl';
}

CafePhotoUrlBreakdown cafePhotoUrlBreakdownFromRaw(
  Map<String, Object?> rawImageInput,
) {
  final storedRaw = <String?>[];
  final generatedRaw = <String?>[];

  void collect(Object? raw, List<String?> target) {
    if (raw == null) {
      return;
    }
    if (raw is String) {
      target.add(raw);
      return;
    }
    if (raw is Iterable) {
      for (final item in raw) {
        collect(item, target);
      }
      return;
    }
    if (raw is Map) {
      final direct = raw['url'] ??
          raw['image_url'] ??
          raw['imageUrl'] ??
          raw['photo_url'] ??
          raw['photoUrl'] ??
          raw['photoUri'] ??
          raw['thumbnail_url'] ??
          raw['thumbnailUrl'];
      if (direct != null) {
        collect(direct, target);
      }
      final generated = raw['name'] ??
          raw['google_photo_reference'] ??
          raw['googlePhotoReference'] ??
          raw['photo_reference'] ??
          raw['photoReference'];
      if (generated != null) {
        collect(generated, generatedRaw);
      }
      for (final value in raw.values) {
        if (!identical(value, direct) && !identical(value, generated)) {
          collect(value, target);
        }
      }
      return;
    }
    target.add(raw.toString());
  }

  collect(rawImageInput['photo_urls'], storedRaw);
  collect(rawImageInput['photoUrls'], storedRaw);
  collect(rawImageInput['image_urls'], storedRaw);
  collect(rawImageInput['image_url'], storedRaw);
  collect(rawImageInput['imageUrl'], storedRaw);
  collect(rawImageInput['images'], storedRaw);
  collect(rawImageInput['photos'], generatedRaw);
  collect(rawImageInput['google_photo_reference'], generatedRaw);
  collect(rawImageInput['googlePhotoReference'], generatedRaw);
  collect(rawImageInput['photo_reference'], generatedRaw);
  collect(rawImageInput['photoReference'], generatedRaw);
  collect(rawImageInput['google_photo_references'], generatedRaw);
  collect(rawImageInput['googlePhotoReferences'], generatedRaw);
  collect(rawImageInput['photo_references'], generatedRaw);
  collect(rawImageInput['photoReferences'], generatedRaw);

  final stored = normalizeCafeImageUrlsByPriority(
    storedRaw,
    includeGeneratedPlacesMedia: false,
  );
  final generated = normalizeCafeImageUrls(
    generatedRaw.where(isGeneratedPlacesMediaImageUrl),
  );
  final display = normalizeCafeImageUrlsByPriority(
    <String?>[...storedRaw, ...generatedRaw],
  );
  return CafePhotoUrlBreakdown(
    storedPhotoUrls: stored,
    generatedPhotoUrls: generated,
    resolvedDisplayUrls: display,
  );
}

class CafePhotoUrlBreakdown {
  const CafePhotoUrlBreakdown({
    required this.storedPhotoUrls,
    required this.generatedPhotoUrls,
    required this.resolvedDisplayUrls,
  });

  final List<String> storedPhotoUrls;
  final List<String> generatedPhotoUrls;
  final List<String> resolvedDisplayUrls;
}

String? _normalizeSupabaseStoragePath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.contains('://')) {
    return null;
  }

  final supabaseUrl = Env.optionalSupabaseUrl?.trim();
  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    return null;
  }
  final baseUri = Uri.tryParse(supabaseUrl);
  if (baseUri == null || baseUri.host.isEmpty) {
    return null;
  }

  final path = trimmed.replaceFirst(RegExp(r'^/+'), '');
  if (!path.startsWith('storage/v1/object/public/')) {
    return null;
  }

  return baseUri
      .replace(
        path: '/$path',
        query: '',
        fragment: '',
      )
      .toString();
}

String? _normalizeLegacyGooglePhotoReference(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.contains('://') ||
      trimmed.contains('/') ||
      trimmed.contains('.')) {
    return null;
  }
  if (trimmed.contains(RegExp(r'\s'))) {
    return null;
  }
  if (trimmed.length < 20) {
    return null;
  }
  return trimmed;
}

String _buildLegacyGooglePhotoUrl(
  String reference, {
  int? maxWidthPx,
}) {
  final width = _validImageSize(maxWidthPx) ??
      CafeImageVariant.detailGallery.requestWidthPx;
  final apiKey = Env.optionalGooglePlacesPhotoApiKey;
  final params = <String, String>{
    'photoreference': reference,
    'maxwidth': '$width',
    if (apiKey != null && apiKey.isNotEmpty) 'key': apiKey,
  };
  return Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/photo',
    params,
  ).toString();
}

ImageProvider<Object>? buildCafeImageProvider(
  String? rawUrl, {
  required CafeImageVariant variant,
}) {
  final resolvedUrl = resolveCafeImageUrl(
    rawUrl,
    maxWidthPx: variant.requestWidthPx,
  );
  if (resolvedUrl == null || resolvedUrl.isEmpty) {
    return null;
  }

  return CachedNetworkImageProvider(
    resolvedUrl,
    cacheManager: AppImageCacheManager.instance,
    cacheKey: resolvedUrl,
    maxWidth: variant.decodeWidthPx,
    maxHeight: variant.decodeHeightPx,
  );
}

String? normalizeGooglePhotoName(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  if (trimmed.startsWith('places/')) {
    final normalized = _stripMediaSuffix(trimmed);
    return _isValidGooglePhotoName(normalized) ? normalized : null;
  }
  if (trimmed.startsWith('/v1/')) {
    final normalized = _stripMediaSuffix(trimmed.substring(4));
    return _isValidGooglePhotoName(normalized) ? normalized : null;
  }
  if (trimmed.startsWith('v1/')) {
    final normalized = _stripMediaSuffix(trimmed.substring(3));
    return _isValidGooglePhotoName(normalized) ? normalized : null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return null;
  }
  if (uri.host != 'places.googleapis.com') {
    return null;
  }

  final path = uri.path.startsWith('/v1/') ? uri.path.substring(4) : uri.path;
  if (!path.contains('/photos/')) {
    return null;
  }

  final normalized = _stripMediaSuffix(path.replaceFirst(RegExp(r'^/+'), ''));
  return _isValidGooglePhotoName(normalized) ? normalized : null;
}

String buildGooglePhotoMediaUrl(
  String photoName, {
  required String apiKey,
  int maxWidthPx = 1200,
}) {
  final normalizedPhotoName = _stripMediaSuffix(photoName);
  final width = _validImageSize(maxWidthPx) ??
      CafeImageVariant.detailGallery.requestWidthPx;
  return Uri.https(
    'places.googleapis.com',
    '/v1/$normalizedPhotoName/media',
    <String, String>{
      'maxWidthPx': '$width',
      'key': apiKey,
    },
  ).toString();
}

String _stripMediaSuffix(String photoName) {
  return photoName.endsWith('/media')
      ? photoName.substring(0, photoName.length - 6)
      : photoName;
}

Uri _appendGoogleSizeQuery(Uri uri, int? maxWidthPx) {
  final width = _validImageSize(maxWidthPx);
  if (width == null || uri.host != 'places.googleapis.com') {
    return uri;
  }

  return uri.replace(
    queryParameters: <String, String>{
      ...uri.queryParameters,
      'maxWidthPx': '$width',
    },
  );
}

bool _isValidGooglePhotoName(String photoName) {
  final parts = photoName.split('/');
  return parts.length == 4 &&
      parts[0] == 'places' &&
      parts[1].trim().isNotEmpty &&
      parts[2] == 'photos' &&
      parts[3].trim().isNotEmpty &&
      !photoName.contains('?') &&
      !photoName.contains('#') &&
      !photoName.contains(RegExp(r'\s'));
}

int? _validImageSize(int? value) {
  if (value == null || value <= 0) {
    return null;
  }
  return value;
}

bool isKnownFailedCafeImageUrl(String? rawUrl) {
  final key = _failedCafeImageUrlKey(rawUrl);
  return key != null && _failedCafeImageUrlKeys.contains(key);
}

void rememberFailedCafeImageUrl(String? rawUrl) {
  final key = _failedCafeImageUrlKey(rawUrl);
  if (key == null) {
    return;
  }
  if (_failedCafeImageUrlKeys.length >= _maxRememberedFailedImageUrls) {
    _failedCafeImageUrlKeys.clear();
  }
  _failedCafeImageUrlKeys.add(key);
}

@visibleForTesting
void clearRememberedFailedCafeImageUrls() {
  _failedCafeImageUrlKeys.clear();
}

String? _failedCafeImageUrlKey(String? rawUrl) {
  final resolved = resolveCafeImageUrl(rawUrl);
  if (resolved == null || resolved.isEmpty) {
    return null;
  }
  return redactUrlForLog(resolved);
}

String googlePhotoUrlDiagnosticsForLog(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return 'host=none pathShape=none hasMediaSuffix=false '
        'hasMaxWidthPx=false hasMaxHeightPx=false usesPhotoApiKey=false '
        'usesFallbackPlacesKey=false';
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    return 'host=invalid pathShape=invalid hasMediaSuffix=false '
        'hasMaxWidthPx=false hasMaxHeightPx=false usesPhotoApiKey=false '
        'usesFallbackPlacesKey=false';
  }
  final host = uri.host.toLowerCase();
  final path = uri.path;
  final pathShape = _googlePhotoPathShape(path);
  final key = uri.queryParameters['key']?.trim();
  final photoKey = Env.optionalExplicitGooglePlacesPhotoApiKey?.trim();
  final placesKey = Env.optionalGooglePlacesApiKey?.trim();
  final hasPhotoKey = photoKey != null && photoKey.isNotEmpty;
  final usesPhotoKey = key != null && key.isNotEmpty && hasPhotoKey;
  final usesFallbackPlacesKey = key != null &&
      key.isNotEmpty &&
      (photoKey == null || photoKey.isEmpty) &&
      placesKey != null &&
      placesKey.isNotEmpty;

  return 'host=$host pathShape=$pathShape '
      'hasMediaSuffix=${path.endsWith('/media')} '
      'hasMaxWidthPx=${uri.queryParameters['maxWidthPx']?.trim().isNotEmpty == true} '
      'hasMaxHeightPx=${uri.queryParameters['maxHeightPx']?.trim().isNotEmpty == true} '
      'usesPhotoApiKey=$usesPhotoKey usesFallbackPlacesKey=$usesFallbackPlacesKey';
}

String _googlePhotoPathShape(String path) {
  final normalized = path.replaceFirst(RegExp(r'^/+'), '');
  final parts = normalized.split('/');
  if (parts.length == 6 &&
      parts[0] == 'v1' &&
      parts[1] == 'places' &&
      parts[3] == 'photos' &&
      parts[5] == 'media') {
    return 'v1/places/*/photos/*/media';
  }
  if (parts.length == 5 &&
      parts[0] == 'v1' &&
      parts[1] == 'places' &&
      parts[3] == 'photos') {
    return 'v1/places/*/photos/*';
  }
  if (path.contains('%2F') || path.contains('%2f')) {
    return 'encoded-slashes';
  }
  return 'other';
}
