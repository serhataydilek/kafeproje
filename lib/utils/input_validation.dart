final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp _usernameRegex = RegExp(
  r'^[a-z0-9._]{3,24}$',
  caseSensitive: false,
);

const int kUsernameMinLength = 3;
const int kUsernameMaxLength = 24;
const int kPasswordMinLength = 6;
const int kRequiredTextMaxLength = 180;

String normalizeEmail(String value) {
  return value.trim().toLowerCase();
}

String normalizeUsername(String value) {
  return value.trim().toLowerCase();
}

bool looksLikeEmail(String value) {
  return value.contains('@');
}

bool isValidEmail(String value) {
  return _emailRegex.hasMatch(normalizeEmail(value));
}

bool isValidUsername(String value) {
  return _usernameRegex.hasMatch(value.trim());
}

String? validateRequiredText(
  String value,
  String label, {
  int maxLength = kRequiredTextMaxLength,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '$label is required.';
  }
  if (trimmed.length > maxLength) {
    return '$label is too long.';
  }
  return null;
}

String sanitizeTag(String value) {
  return sanitizeInput(value);
}

List<String> sanitizeTagList(String value) {
  return value
      .split(',')
      .map(sanitizeTag)
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);
}

/// Strip HTML tags and normalize whitespace for safe storage.
String sanitizeInput(String value) {
  final stripped = value.replaceAll(RegExp(r'<[^>]*>'), '');
  return stripped.trim().replaceAll(RegExp(r'\s+'), ' ');
}
