import 'package:flutter/foundation.dart';

@immutable
class CafeReview {
  const CafeReview({
    required this.id,
    required this.cafeId,
    required this.userId,
    required this.rating,
    this.wifiQuality,
    this.noiseLevel,
    this.studyFriendliness,
    this.seatingComfort,
    this.socketAvailability,
    this.smokingPolicy,
    this.content,
    required this.createdAt,
    this.username, // Joined from profiles table
    this.avatarUrl, // Joined from profiles table
  });

  factory CafeReview.fromSupabaseRow(Map<String, dynamic> row) {
    // The query will likely join with the profiles table to get username and avatar_url
    final profiles = row['profiles'] as Map<String, dynamic>?;

    return CafeReview(
      id: row['id'] as String,
      cafeId: row['cafe_id'] as String,
      userId: row['user_id'] as String,
      rating: (row['rating'] as num).toInt(),
      wifiQuality: (row['wifi_quality'] as num?)?.toInt(),
      noiseLevel: (row['noise_level'] as num?)?.toInt(),
      studyFriendliness: (row['study_friendliness'] as num?)?.toInt(),
      seatingComfort: (row['seating_comfort'] as num?)?.toInt(),
      socketAvailability: row['socket_availability'] as String?,
      smokingPolicy: _normalizeSmokingPolicy(row['smoking_policy'] as String?),
      content: row['content'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      username: profiles?['username'] as String?,
      avatarUrl: profiles?['avatar_url'] as String?,
    );
  }

  final String id;
  final String cafeId;
  final String userId;
  final int rating;
  final int? wifiQuality;
  final int? noiseLevel;
  final int? studyFriendliness;
  final int? seatingComfort;
  final String? socketAvailability;
  final String? smokingPolicy;
  final String? content;
  final DateTime createdAt;
  final String? username;
  final String? avatarUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CafeReview &&
          id == other.id &&
          cafeId == other.cafeId &&
          userId == other.userId &&
          rating == other.rating &&
          wifiQuality == other.wifiQuality &&
          noiseLevel == other.noiseLevel &&
          studyFriendliness == other.studyFriendliness &&
          seatingComfort == other.seatingComfort &&
          socketAvailability == other.socketAvailability &&
          smokingPolicy == other.smokingPolicy &&
          content == other.content &&
          createdAt == other.createdAt &&
          username == other.username &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode => Object.hash(
        id,
        cafeId,
        userId,
        rating,
        wifiQuality,
        noiseLevel,
        studyFriendliness,
        seatingComfort,
        socketAvailability,
        smokingPolicy,
        content,
        createdAt,
        username,
        avatarUrl,
      );
}

String? _normalizeSmokingPolicy(String? value) {
  if (value == 'mixed') {
    return 'outdoor_only';
  }
  return value;
}

@immutable
class ReviewMutationResult {
  const ReviewMutationResult({
    required this.review,
    required this.didUpdateExisting,
  });

  final CafeReview review;
  final bool didUpdateExisting;
}

@immutable
class ReviewPage {
  const ReviewPage({
    required this.reviews,
    required this.hasMore,
  });

  final List<CafeReview> reviews;
  final bool hasMore;
}
