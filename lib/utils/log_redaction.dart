import 'dart:convert';

String redactUrlForLog(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return '';
  }

  final uri = Uri.tryParse(trimmed);
  final normalized =
      uri == null ? trimmed : uri.replace(query: '', fragment: '').toString();
  final parsed = Uri.tryParse(normalized);
  final host = parsed != null && parsed.host.isNotEmpty
      ? parsed.host.toLowerCase()
      : 'local';
  final path =
      parsed != null && parsed.path.isNotEmpty ? parsed.path : normalized;

  return 'host=$host pathHash=${_shortHash(path)}';
}

String _shortHash(String input) {
  final bytes = utf8.encode(input);
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return (hash & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}
