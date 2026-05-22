import 'text_normalization.dart';

class ReviewModerationResult {
  const ReviewModerationResult({
    required this.isBlocked,
    required this.sanitizedText,
    this.matchedTerm,
  });

  final bool isBlocked;
  final String sanitizedText;
  final String? matchedTerm;
}

const Set<String> _blockedReviewTerms = {
  'aptal',
  'gerizekali',
  'geri zekali',
  'salak',
  'mal',
  'serefsiz',
  'saygisiz',
  'pislik',
  'dangoz',
  'hayvan',
  'bok',
  'boktan',
  'orospu',
  'pic',
  'pic kurusu',
  'siktir',
  'sikerim',
  'amk',
  'aq',
  'idiot',
  'moron',
  'stupid',
  'dumbass',
  'bastard',
  'asshole',
  'jerk',
  'fuck',
  'fucking',
  'shit',
  'shitty',
};

ReviewModerationResult moderateReviewText(String? rawText) {
  final text = rawText?.trim() ?? '';
  if (text.isEmpty) {
    return const ReviewModerationResult(
      isBlocked: false,
      sanitizedText: '',
    );
  }

  final normalized = normalizeSearchText(text);
  final tokenized = _normalizeForModeration(normalized);
  final squashed = tokenized.replaceAll(' ', '');

  for (final blockedTerm in _blockedReviewTerms) {
    final normalizedTerm = _normalizeForModeration(blockedTerm);
    if (normalizedTerm.isEmpty) {
      continue;
    }

    final hasTokenMatch = tokenized.contains(normalizedTerm);
    final hasSquashedMatch =
        squashed.contains(normalizedTerm.replaceAll(' ', ''));
    if (hasTokenMatch || hasSquashedMatch) {
      return ReviewModerationResult(
        isBlocked: true,
        sanitizedText: _maskBlockedTerm(text, blockedTerm),
        matchedTerm: blockedTerm,
      );
    }
  }

  return ReviewModerationResult(
    isBlocked: false,
    sanitizedText: text,
  );
}

String friendlyReviewModerationMessage() {
  return 'Please keep reviews friendly and avoid profanity or abusive language.';
}

String _normalizeForModeration(String value) {
  return normalizeSearchText(value)
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _maskBlockedTerm(String text, String blockedTerm) {
  final trimmedTerm = blockedTerm.trim();
  if (trimmedTerm.isEmpty) {
    return text;
  }

  final replacement = '${trimmedTerm[0]}***';
  return text.replaceAll(
    RegExp(RegExp.escape(trimmedTerm), caseSensitive: false),
    replacement,
  );
}
