/// UI configuration constants for responsive design and layout.
///
/// Defines breakpoints, dialog sizes, cache configurations, and other
/// UI-related constants that should be centralized for consistency.
class BreakpointsConfig {
  /// Maximum width for mobile layout (phones).
  static const int mobileMax = 480;

  /// Minimum width for tablet layout.
  static const int tabletMin = 600;

  /// Maximum width for tablet layout.
  static const int tabletMax = 1000;

  /// Minimum width for desktop layout.
  static const int desktopMin = 1200;
}

/// Dialog and modal configuration constants.
class DialogConfig {
  /// Maximum width for most dialogs.
  static const int maxWidth = 1400;

  /// Maximum height for most dialogs.
  static const int maxHeight = 1400;

  /// Maximum width for detail view dialogs.
  static const int detailsMaxWidth = 500;

  /// Standard dialog elevation.
  static const double elevation = 8.0;

  /// Standard border radius for dialogs.
  static const double borderRadius = 16.0;
}

/// Image and media configuration constants.
class ImageConfig {
  /// Standard width for detail page images.
  static const int detailImageWidth = 500;

  /// Standard height for detail page images.
  static const int detailImageHeight = 300;

  /// Cache width for list item images.
  static const int listItemCacheWidth = 400;

  /// Cache height for list item images.
  static const int listItemCacheHeight = 300;

  /// Cache width for thumbnail images.
  static const int thumbnailCacheWidth = 200;

  /// Cache height for thumbnail images.
  static const int thumbnailCacheHeight = 150;

  /// Image fade-in animation duration.
  static const Duration fadeInDuration = Duration(milliseconds: 300);

  /// Image loading placeholder color opacity.
  static const double placeholderOpacity = 0.1;
}

/// Font weight configuration constants.
class FontWeightConfig {
  /// Regular font weight.
  static const int regular = 400;

  /// Medium font weight (semi-bold).
  static const int medium = 500;

  /// Semi-bold font weight.
  static const int semiBold = 600;

  /// Bold font weight.
  static const int bold = 700;

  /// Extra bold font weight.
  static const int extraBold = 800;
}

/// Cache configuration constants for memory and persistent storage.
class AppCacheConfig {
  /// Maximum number of cafe details to keep in memory.
  static const int memoryCafeDetailSize = 100;

  /// Maximum age for cached cafe data.
  static const Duration cafeCacheMaxAge = Duration(hours: 24);

  /// Maximum number of items to keep in review cache.
  static const int reviewCacheMaxSize = 50;

  /// Maximum age for review data.
  static const Duration reviewCacheMaxAge = Duration(hours: 12);

  /// LRU cache eviction policy flag.
  static const bool useLruEviction = true;
}

/// Spacing and padding constants.
class SpacingConfig {
  /// Extra small spacing (4px).
  static const double xs = 4.0;

  /// Small spacing (8px).
  static const double sm = 8.0;

  /// Medium spacing (16px).
  static const double md = 16.0;

  /// Large spacing (24px).
  static const double lg = 24.0;

  /// Extra large spacing (32px).
  static const double xl = 32.0;

  /// Large spacing for page sections (48px).
  static const double xxl = 48.0;
}

/// Animation and transition duration constants.
class AnimationConfig {
  /// Quick animations (100ms).
  static const Duration quick = Duration(milliseconds: 100);

  /// Standard animations (300ms).
  static const Duration standard = Duration(milliseconds: 300);

  /// Slow animations (500ms).
  static const Duration slow = Duration(milliseconds: 500);

  /// Page transitions (600ms).
  static const Duration pageTransition = Duration(milliseconds: 600);
}
