enum OfflineQueueAction {
  /// Remote favorite write that should be retried when connectivity returns.
  favoriteToggle,

  /// Remote review write that should be retried when connectivity returns.
  reviewSubmission,

  /// Remote profile write that should be retried when connectivity returns.
  profileUpdate,
}

/// Persisted offline mutation entry.
///
/// Only remote writes that need retry/reconciliation should be enqueued here.
/// Read/fetch flows must use repository caches instead of this queue.
class OfflineQueueEntry {
  const OfflineQueueEntry({
    required this.id,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory OfflineQueueEntry.fromJson(Map<String, dynamic> json) {
    final actionName = json['action'] as String? ?? '';
    return OfflineQueueEntry(
      id: json['id'] as String? ?? '',
      action: OfflineQueueAction.values.firstWhere(
        (value) => value.name == actionName,
        orElse: () => OfflineQueueAction.favoriteToggle,
      ),
      payload: Map<String, dynamic>.from(
        (json['payload'] as Map?) ?? const <String, dynamic>{},
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
    );
  }

  final String id;
  final OfflineQueueAction action;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  OfflineQueueEntry copyWith({
    String? id,
    OfflineQueueAction? action,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? retryCount,
    String? Function()? lastError,
  }) {
    return OfflineQueueEntry(
      id: id ?? this.id,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError != null ? lastError() : this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.name,
      'payload': payload,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }
}
