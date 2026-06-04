bool isSuppressedCafeRow(Map<String, dynamic> row) {
  final isDeleted = _readLooseBool(row['is_deleted']) ?? false;
  final isHidden =
      (_readLooseBool(row['is_hidden']) ?? _readLooseBool(row['hidden'])) ??
          false;
  final isActive =
      _readLooseBool(row['is_active']) ?? _readLooseBool(row['active']);
  final deletedAt = row['deleted_at'];
  final hasDeletedAt =
      deletedAt != null && deletedAt.toString().trim().isNotEmpty;

  return isDeleted ||
      isHidden ||
      (isActive != null && !isActive) ||
      hasDeletedAt;
}

bool? _readLooseBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'true' ||
        normalized == 't' ||
        normalized == '1' ||
        normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == 'f' ||
        normalized == '0' ||
        normalized == 'no') {
      return false;
    }
  }
  return null;
}
