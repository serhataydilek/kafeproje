import 'cafe_support.dart';
import 'social_models.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    this.username,
    this.firstName,
    this.lastName,
    required this.fullName,
    required this.email,
    this.role = ProfileRole.user,
    required this.createdAt,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] as String?)?.trim().toLowerCase();
    final rawIsAdmin = json['is_admin'];
    final isAdminFlag = rawIsAdmin == true ||
        (rawIsAdmin is String &&
            const <String>{'true', 't', '1', 'yes'}
                .contains(rawIsAdmin.trim().toLowerCase())) ||
        (rawIsAdmin is num && rawIsAdmin != 0);

    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: ProfileRole.fromString(rawRole, isAdmin: isAdminFlag),
      createdAt: json['created_at'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String id;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String fullName;
  final String email;
  final ProfileRole role;
  final String createdAt;
  final String? avatarUrl;

  UserProfile copyWith({
    String? username,
    String? firstName,
    String? lastName,
    String? fullName,
    String? email,
    ProfileRole? role,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  FriendProfile toFriendProfile() {
    return FriendProfile(
      id: id,
      username: username,
      displayName: fullName.isNotEmpty ? fullName : username,
      avatarUrl: avatarUrl,
    );
  }
}

class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.isAdmin = false,
    this.role = ProfileRole.user,
  });

  final String id;
  final String email;
  final String? name;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final bool isAdmin;
  final ProfileRole role;
  bool get isCafeOwner => role == ProfileRole.cafeOwner;

  CurrentUser copyWith({
    String? name,
    String? username,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarUrl,
    bool? isAdmin,
    ProfileRole? role,
  }) {
    return CurrentUser(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAdmin: isAdmin ?? this.isAdmin,
      role: role ?? this.role,
    );
  }

  FriendProfile toFriendProfile() {
    final displayName = [
      firstName,
      lastName,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');
    return FriendProfile(
      id: id,
      username: username,
      displayName: displayName.isNotEmpty ? displayName : (name ?? email),
      avatarUrl: avatarUrl,
    );
  }
}
