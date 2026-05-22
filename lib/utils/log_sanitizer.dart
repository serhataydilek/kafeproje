import 'dart:convert';

String summarizeUrlForLog(
  String? rawUrl, {
  String presenceLabel = 'hasUrl',
}) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return '$presenceLabel=false';
  }
  final summary = _redactUrl(trimmed);
  return '$presenceLabel=true $summary';
}

String? redactUrlForLog(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return _redactUrl(trimmed);
}

String _redactUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  final normalized = (uri == null)
      ? rawUrl.trim()
      : uri.replace(query: '', fragment: '').toString();
  final parsed = Uri.tryParse(normalized);
  final host = (parsed != null && parsed.host.isNotEmpty)
      ? parsed.host.toLowerCase()
      : 'local';
  final path = (parsed != null && parsed.path.isNotEmpty)
      ? parsed.path
      : normalized;
  final pathHash = _shortHash(path);
  return 'host=$host pathHash=$pathHash';
}

String _shortHash(String input) {
  final bytes = utf8.encode(input);
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  final normalized = hash & 0xFFFFFFFF;
  return normalized.toRadixString(16).padLeft(8, '0');
}
