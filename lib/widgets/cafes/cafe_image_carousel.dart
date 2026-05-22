import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../utils/app_logger.dart';
import '../../utils/cafe_media.dart';
import '../../utils/log_sanitizer.dart';
import '../ui/remote_image.dart';

class CafeImageCarousel extends StatefulWidget {
  const CafeImageCarousel({
    super.key,
    required this.imageUrls,
    required this.height,
    required this.colors,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.lg)),
    this.imageProviders,
    this.cacheWidth,
    this.cacheHeight,
    this.requestWidth,
    this.compact = false,
    this.traceTag,
    this.diagnosticCafeId,
    this.diagnosticCafeName,
  });

  final List<String> imageUrls;
  final double height;
  final AppColors colors;
  final BorderRadius borderRadius;
  final List<ImageProvider<Object>>? imageProviders;
  final int? cacheWidth;
  final int? cacheHeight;
  final int? requestWidth;
  final bool compact;
  final String? traceTag;
  final String? diagnosticCafeId;
  final String? diagnosticCafeName;

  @override
  State<CafeImageCarousel> createState() => _CafeImageCarouselState();
}

class _CafeImageCarouselState extends State<CafeImageCarousel> {
  late final PageController _pageController;
  late List<String> _normalizedImageUrls;
  final Set<String> _failedImageUrls = <String>{};
  final Set<int> _failedProviderIndexes = <int>{};
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
    _normalizedImageUrls = _normalizeForWidget(widget);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CafeImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameStringList(oldWidget.imageUrls, widget.imageUrls)) {
      _failedImageUrls.clear();
      _normalizedImageUrls = _normalizeForWidget(widget);
    }
    if (oldWidget.imageProviders?.length != widget.imageProviders?.length) {
      _failedProviderIndexes.clear();
    }
    final oldCount = _itemCountFor(oldWidget);
    final nextCount = _itemCountFor(widget);
    if (nextCount == 0) {
      if (_currentPage != 0) {
        setState(() {
          _currentPage = 0;
        });
      }
      return;
    }

    if (_currentPage >= nextCount || oldCount != nextCount) {
      final nextPage = _currentPage.clamp(0, nextCount - 1);
      if (nextPage != _currentPage) {
        setState(() {
          _currentPage = nextPage;
        });
      }
      if (_pageController.hasClients) {
        _pageController.jumpToPage(nextPage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = _visibleImageUrls();
    final imageProviderEntries = _visibleImageProviderEntries();
    final hasProvidedImages = widget.imageProviders?.isNotEmpty == true;
    final itemCount =
        hasProvidedImages ? imageProviderEntries.length : imageUrls.length;

    _logHomeSponsoredUiDiagnostics(
      normalizedUrls: imageUrls,
      itemCount: itemCount,
      hasProvidedImages: hasProvidedImages,
    );
    _logCandidateOrder(
      normalizedUrls: imageUrls,
      hasProvidedImages: hasProvidedImages,
    );

    if (itemCount == 0) {
      return _CarouselFallback(
        height: widget.height,
        colors: widget.colors,
        borderRadius: widget.borderRadius,
        compact: widget.compact,
      );
    }

    final hasMultipleImages = itemCount > 1;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              physics: hasMultipleImages
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: itemCount,
              onPageChanged: (value) {
                if (_currentPage == value) {
                  return;
                }
                setState(() {
                  _currentPage = value;
                });
              },
              itemBuilder: (context, index) {
                final fallback = _CarouselFallback(
                  height: widget.height,
                  colors: widget.colors,
                  borderRadius: BorderRadius.zero,
                  compact: true,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    hasProvidedImages
                        ? Image(
                            key: ValueKey(
                              'provider-image-${imageProviderEntries[index].originalIndex}',
                            ),
                            image: imageProviderEntries[index].provider,
                            fit: BoxFit.cover,
                            isAntiAlias: true,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) {
                              _logImageProviderFailure(error);
                              _markProviderFailed(
                                imageProviderEntries[index].originalIndex,
                              );
                              return fallback;
                            },
                          )
                        : RemoteImage(
                            imageUrl: imageUrls[index],
                            traceTag: widget.traceTag != null
                                ? '${widget.traceTag}:$index'
                                : null,
                            fit: BoxFit.cover,
                            cacheWidth: widget.cacheWidth ??
                                CafeImageVariant.detailGallery.decodeWidthPx,
                            cacheHeight: widget.cacheHeight ??
                                CafeImageVariant.detailGallery.decodeHeightPx,
                            requestWidth: widget.requestWidth ??
                                CafeImageVariant.detailGallery.requestWidthPx,
                            filterQuality: widget.compact
                                ? FilterQuality.low
                                : FilterQuality.medium,
                            diagnosticSurface: traceSurface,
                            diagnosticCafeId: widget.diagnosticCafeId,
                            diagnosticCafeName: widget.diagnosticCafeName,
                            onError: (status) =>
                                _markUrlFailed(imageUrls[index], status),
                            loadingBuilder: (_) => _CarouselLoadingState(
                              colors: widget.colors,
                              compact: widget.compact,
                            ),
                            errorBuilder: (_) => fallback,
                          ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.06),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.26),
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              top: widget.compact ? AppSpacing.xs : AppSpacing.md,
              right: widget.compact ? AppSpacing.xs : AppSpacing.md,
              child: _CarouselImageCountBadge(
                colors: widget.colors,
                currentPage: _currentPage,
                totalPages: itemCount,
                compact: widget.compact,
              ),
            ),
            if (hasMultipleImages)
              Positioned(
                left: widget.compact ? AppSpacing.xs : AppSpacing.md,
                right: widget.compact ? AppSpacing.xs : AppSpacing.md,
                bottom: widget.compact ? AppSpacing.xs : AppSpacing.md,
                child: _CarouselFooter(
                  colors: widget.colors,
                  currentPage: _currentPage,
                  totalPages: itemCount,
                  compact: widget.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _logHomeSponsoredUiDiagnostics({
    required List<String> normalizedUrls,
    required int itemCount,
    required bool hasProvidedImages,
  }) {
    if (!kDebugMode) {
      return;
    }
    final traceTag = widget.traceTag;
    if (traceTag == null || traceTag.isEmpty) {
      return;
    }
    final surface = traceTag.split(':').first.trim();
    if (surface != 'home-sponsored') {
      return;
    }
    final hasResolved = normalizedUrls.isNotEmpty;
    final firstUrl = hasResolved
        ? summarizeUrlForLog(normalizedUrls.first, presenceLabel: 'firstUrl')
        : 'firstUrl=false';
    final branch = itemCount == 0
        ? 'placeholder'
        : (hasProvidedImages ? 'provider' : 'carousel');
    AppLogger.debug(
      '[CAFE_DIAG_PHOTO_UI] surface=home_sponsored_card listLength=${widget.imageUrls.length} normalizedCount=${normalizedUrls.length} resolvedFirstImagePresent=$hasResolved branch=$branch height=${widget.height} $firstUrl',
      key: 'cafe-diag-photo-ui-home-sponsored-carousel-$traceTag',
      throttle: Duration.zero,
    );
  }

  int _itemCountFor(CafeImageCarousel widget) {
    final providerCount = widget.imageProviders?.length ?? 0;
    if (providerCount > 0) {
      final visibleCount = providerCount - _failedProviderIndexes.length;
      return visibleCount.clamp(0, providerCount).toInt();
    }
    if (identical(widget, this.widget)) {
      return _normalizedImageUrls.length;
    }
    return _normalizeForWidget(widget).length;
  }

  List<String> _visibleImageUrls() {
    if (_failedImageUrls.isEmpty) {
      return _normalizedImageUrls;
    }
    return _normalizedImageUrls
        .where((url) => !_failedImageUrls.contains(url))
        .toList(growable: false);
  }

  List<({int originalIndex, ImageProvider<Object> provider})>
      _visibleImageProviderEntries() {
    final providers = widget.imageProviders;
    if (providers == null || providers.isEmpty) {
      return const <({int originalIndex, ImageProvider<Object> provider})>[];
    }
    final visible = <({int originalIndex, ImageProvider<Object> provider})>[];
    for (var index = 0; index < providers.length; index += 1) {
      if (_failedProviderIndexes.contains(index)) {
        continue;
      }
      visible.add((originalIndex: index, provider: providers[index]));
    }
    return visible;
  }

  void _markUrlFailed(String url, int? status) {
    if (!mounted || _failedImageUrls.contains(url)) {
      return;
    }
    _logCandidateFailover(url, status);
    _failedImageUrls.add(url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPage = 0;
      });
      _jumpToFirstPage();
    });
  }

  void _markProviderFailed(int originalIndex) {
    if (!mounted) {
      return;
    }
    if (_failedProviderIndexes.contains(originalIndex)) {
      return;
    }
    _failedProviderIndexes.add(originalIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPage = 0;
      });
      _jumpToFirstPage();
    });
  }

  void _jumpToFirstPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      _pageController.jumpToPage(0);
    });
  }

  List<String> _normalizeForWidget(CafeImageCarousel widget) {
    final stopwatch = Stopwatch()..start();
    final surface = widget.traceTag?.split(':').first.trim();
    final normalized = normalizeCafeImageUrls(
      widget.imageUrls,
      diagnosticSurface:
          surface == 'home-sponsored' || surface == 'featured' ? surface : null,
    );
    if (widget.imageUrls.length > 20 || stopwatch.elapsedMilliseconds > 8) {
      AppLogger.debug(
        '[HOME_PERF] stage=imageNormalize count=${widget.imageUrls.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
        key: 'home-perf-image-normalize',
      );
    }
    return normalized;
  }

  String get traceSurface {
    final traceTag = widget.traceTag?.trim();
    if (traceTag == null || traceTag.isEmpty) {
      return 'cafe_image_carousel';
    }
    return traceTag.split(':').first;
  }

  void _logCandidateOrder({
    required List<String> normalizedUrls,
    required bool hasProvidedImages,
  }) {
    if (!kDebugMode) {
      return;
    }
    final surface = traceSurface;
    if (surface != 'home-sponsored' && surface != 'featured') {
      return;
    }
    final segments = <String>[];
    for (var index = 0;
        index < normalizedUrls.length && index < 5;
        index += 1) {
      final url = normalizedUrls[index];
      segments.add(
        'candidate$index=index=$index host=${_candidateHost(url)} pathShape=${_candidatePathShape(url)} generated=${isGeneratedPlacesMediaImageUrl(url)} knownFailed=${isKnownFailedCafeImageUrl(url)} sourceType=${cafeImageSourceTypeLabel(url)}',
      );
    }
    AppLogger.debug(
      '[IMAGE_CANDIDATE_ORDER] surface=$surface cafeId=${widget.diagnosticCafeId ?? 'unknown'} cafeName="${widget.diagnosticCafeName ?? 'unknown'}" candidateCount=${normalizedUrls.length} ${segments.isEmpty ? 'candidates=0' : segments.join(' ')}',
      key:
          'image-candidate-order-$surface-${widget.diagnosticCafeId ?? 'unknown'}',
      throttle: Duration.zero,
    );
  }

  void _logCandidateFailover(String failedUrl, int? status) {
    if (!kDebugMode) {
      return;
    }
    final surface = traceSurface;
    if (surface != 'home-sponsored' && surface != 'featured') {
      return;
    }
    final failedIndex = _normalizedImageUrls.indexOf(failedUrl);
    final remaining = _normalizedImageUrls
        .where((url) => url != failedUrl && !_failedImageUrls.contains(url))
        .toList(growable: false);
    final nextCandidate = remaining.isEmpty ? null : remaining.first;
    final nextIndex = nextCandidate == null
        ? null
        : _normalizedImageUrls.indexOf(nextCandidate);
    AppLogger.debug(
      '[IMAGE_CANDIDATE_FAILOVER] surface=$surface cafeId=${widget.diagnosticCafeId ?? 'unknown'} failedIndex=$failedIndex failedHost=${_candidateHost(failedUrl)} failedPathShape=${_candidatePathShape(failedUrl)} status=${status ?? 'unknown'} remainingCandidateCount=${remaining.length} nextCandidateIndex=${nextIndex ?? 'none'} nextCandidateHost=${nextCandidate == null ? 'none' : _candidateHost(nextCandidate)} nextCandidateGenerated=${nextCandidate == null ? 'none' : isGeneratedPlacesMediaImageUrl(nextCandidate)} willShowFallback=${remaining.isEmpty}',
      key:
          'image-candidate-failover-$surface-${widget.diagnosticCafeId ?? 'unknown'}-$failedIndex',
      throttle: Duration.zero,
    );
  }

  String _candidateHost(String url) {
    return Uri.tryParse(url)?.host.toLowerCase() ?? 'invalid';
  }

  String _candidatePathShape(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return 'invalid';
    }
    final parts = uri.path.replaceFirst(RegExp(r'^/+'), '').split('/');
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
    if (uri.path.contains('%2F') || uri.path.contains('%2f')) {
      return 'encoded-slashes';
    }
    return 'other';
  }

  void _logImageProviderFailure(Object error) {
    if (!kDebugMode) {
      return;
    }
    AppLogger.debug(
      '[CAFE_DIAG_PHOTO_LOAD_ERROR] surface=$traceSurface cafeId=${widget.diagnosticCafeId ?? 'unknown'} cafeName="${widget.diagnosticCafeName ?? 'unknown'}" traceTag=${widget.traceTag ?? 'none'} imageUrl=false errorType=${error.runtimeType} error="${_safeErrorMessage(error)}"',
      key:
          'cafe-photo-provider-error-${widget.traceTag ?? traceSurface}-${widget.diagnosticCafeId ?? 'unknown'}',
    );
  }

  String _safeErrorMessage(Object? error) {
    final raw = error?.toString() ?? 'unknown';
    final withoutUrls = raw.replaceAll(
      RegExp(r'https?:\/\/\S+'),
      '[redacted-url]',
    );
    return withoutUrls.length > 180
        ? '${withoutUrls.substring(0, 180)}...'
        : withoutUrls;
  }

  bool _sameStringList(List<String> left, List<String> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}

class _CarouselFooter extends StatelessWidget {
  const _CarouselFooter({
    required this.colors,
    required this.currentPage,
    required this.totalPages,
    required this.compact,
  });

  final AppColors colors;
  final int currentPage;
  final int totalPages;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!compact) const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(totalPages, (index) {
            final isActive = index == currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              margin: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
              width: isActive ? (compact ? 14 : 18) : (compact ? 6 : 8),
              height: compact ? 6 : 8,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CarouselImageCountBadge extends StatelessWidget {
  const _CarouselImageCountBadge({
    required this.colors,
    required this.currentPage,
    required this.totalPages,
    required this.compact,
  });

  final AppColors colors;
  final int currentPage;
  final int totalPages;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_rounded,
              color: Colors.white,
              size: compact ? 12 : 14,
            ),
            SizedBox(width: compact ? 4 : 6),
            Text(
              context.l10n.mapPhotoCount(currentPage + 1, totalPages),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 10 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselLoadingState extends StatelessWidget {
  const _CarouselLoadingState({
    required this.colors,
    required this.compact,
  });

  final AppColors colors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.chip,
            colors.primarySoft.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: compact ? 42 : 56,
          height: compact ? 42 : 56,
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarouselFallback extends StatelessWidget {
  const _CarouselFallback({
    required this.height,
    required this.colors,
    required this.borderRadius,
    this.compact = false,
  });

  final double height;
  final AppColors colors;
  final BorderRadius borderRadius;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isCompact = compact || height <= 120;
    final isThumbnail = height <= 88;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.chip,
            colors.primarySoft.withValues(alpha: 0.86),
            colors.bg,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isThumbnail ? 34 : (isCompact ? 52 : 64),
              height: isThumbnail ? 34 : (isCompact ? 52 : 64),
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.84),
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Icon(
                isCompact
                    ? Icons.broken_image_outlined
                    : Icons.photo_library_outlined,
                color: colors.mutedText,
                size: isThumbnail ? 16 : (isCompact ? 24 : 28),
              ),
            ),
            if (!isThumbnail) ...[
              SizedBox(height: isCompact ? 6 : AppSpacing.sm),
              Text(
                isCompact ? l10n.commonNoData : l10n.mapNoPhotos,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: isCompact ? 12 : 13,
                ),
              ),
            ],
            if (!isCompact) ...[
              const SizedBox(height: 4),
              Text(
                l10n.mapEmptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.mutedText,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
