enum CafeOwnerClaimStatus {
  pending,
  approved,
  rejected;

  static CafeOwnerClaimStatus fromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'approved':
        return CafeOwnerClaimStatus.approved;
      case 'rejected':
        return CafeOwnerClaimStatus.rejected;
      case 'pending':
      default:
        return CafeOwnerClaimStatus.pending;
    }
  }

  String get value => name;
}

class CafeOwnerClaim {
  const CafeOwnerClaim({
    required this.id,
    required this.userId,
    required this.cafeId,
    required this.businessName,
    this.phone,
    this.note,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory CafeOwnerClaim.fromJson(Map<String, dynamic> json) {
    return CafeOwnerClaim(
      id: (json['id'] as String?)?.trim() ?? '',
      userId: (json['user_id'] as String?)?.trim() ?? '',
      cafeId: (json['cafe_id'] as String?)?.trim() ?? '',
      businessName: (json['business_name'] as String?)?.trim() ?? '',
      phone: _normalizeOptional(json['phone'] as String?),
      note: _normalizeOptional(json['note'] as String?),
      status: CafeOwnerClaimStatus.fromString(json['status'] as String?),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now().toUtc(),
      reviewedAt: _parseDateTime(json['reviewed_at']),
      reviewedBy: _normalizeOptional(json['reviewed_by'] as String?),
    );
  }

  final String id;
  final String userId;
  final String cafeId;
  final String businessName;
  final String? phone;
  final String? note;
  final CafeOwnerClaimStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  bool get isPending => status == CafeOwnerClaimStatus.pending;
  bool get isApproved => status == CafeOwnerClaimStatus.approved;
  bool get isRejected => status == CafeOwnerClaimStatus.rejected;

  CafeOwnerClaim copyWith({
    CafeOwnerClaimStatus? status,
    DateTime? Function()? reviewedAt,
    String? Function()? reviewedBy,
  }) {
    return CafeOwnerClaim(
      id: id,
      userId: userId,
      cafeId: cafeId,
      businessName: businessName,
      phone: phone,
      note: note,
      status: status ?? this.status,
      createdAt: createdAt,
      reviewedAt: reviewedAt != null ? reviewedAt() : this.reviewedAt,
      reviewedBy: reviewedBy != null ? reviewedBy() : this.reviewedBy,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'cafe_id': cafeId,
        'business_name': businessName,
        'phone': phone,
        'note': note,
        'status': status.value,
        'created_at': createdAt.toUtc().toIso8601String(),
        'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
        'reviewed_by': reviewedBy,
      };
}

String? _normalizeOptional(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

DateTime? _parseDateTime(Object? raw) {
  if (raw is DateTime) {
    return raw.toUtc();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw)?.toUtc();
  }
  return null;
}
