import 'cafe.dart';

enum FriendRelationshipStatus {
  pendingIncoming,
  pendingOutgoing,
  accepted,
  blocked,
}

extension FriendRelationshipStatusExtension on FriendRelationshipStatus {
  String get value {
    switch (this) {
      case FriendRelationshipStatus.pendingIncoming:
        return 'pending_incoming';
      case FriendRelationshipStatus.pendingOutgoing:
        return 'pending_outgoing';
      case FriendRelationshipStatus.accepted:
        return 'accepted';
      case FriendRelationshipStatus.blocked:
        return 'blocked';
    }
  }

  static FriendRelationshipStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'pending_incoming':
        return FriendRelationshipStatus.pendingIncoming;
      case 'pending_outgoing':
        return FriendRelationshipStatus.pendingOutgoing;
      case 'blocked':
        return FriendRelationshipStatus.blocked;
      default:
        return FriendRelationshipStatus.accepted;
    }
  }
}

enum FriendLocationSharingMode {
  off,
  cityOnly,
  precise,
}

extension FriendLocationSharingModeExtension on FriendLocationSharingMode {
  String get value {
    switch (this) {
      case FriendLocationSharingMode.off:
        return 'off';
      case FriendLocationSharingMode.cityOnly:
        return 'city_only';
      case FriendLocationSharingMode.precise:
        return 'precise';
    }
  }

  static FriendLocationSharingMode fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'city_only':
        return FriendLocationSharingMode.cityOnly;
      case 'precise':
        return FriendLocationSharingMode.precise;
      default:
        return FriendLocationSharingMode.off;
    }
  }
}

class FriendProfile {
  const FriendProfile({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
}

class FriendRelationship {
  const FriendRelationship({
    required this.id,
    required this.userId,
    required this.friendUserId,
    required this.status,
    this.friendProfile,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String friendUserId;
  final FriendRelationshipStatus status;
  final FriendProfile? friendProfile;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAccepted => status == FriendRelationshipStatus.accepted;
}

class FriendLocationPresence {
  const FriendLocationPresence({
    required this.userId,
    required this.sharingMode,
    this.coordinates,
    this.updatedAt,
    this.heading,
    this.speedMetersPerSecond,
  });

  final String userId;
  final FriendLocationSharingMode sharingMode;
  final Coordinates? coordinates;
  final DateTime? updatedAt;
  final double? heading;
  final double? speedMetersPerSecond;

  bool get isVisibleOnMap =>
      sharingMode == FriendLocationSharingMode.precise && coordinates != null;

  bool get isFresh {
    final updatedAt = this.updatedAt;
    if (updatedAt == null) {
      return false;
    }
    return DateTime.now().difference(updatedAt).inMinutes <= 15;
  }
}
