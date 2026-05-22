import '../../l10n/app_localizations.dart';
import '../../models/index.dart';
import '../../utils/text_normalization.dart';

enum AdminTab {
  users,
  cafes,
  discovered,
  claims,
}

AdminTab adminTabFromQuery(
  String? rawValue, {
  AdminTab fallback = AdminTab.cafes,
}) {
  final value = rawValue?.trim().toLowerCase();
  switch (value) {
    case 'users':
    case 'user':
      return AdminTab.users;
    case 'cafes':
    case 'cafe':
      return AdminTab.cafes;
    case 'discovered':
    case 'discovery':
    case 'fetched':
      return AdminTab.discovered;
    case 'claims':
    case 'claim':
    case 'ownership':
      return AdminTab.claims;
    default:
      return fallback;
  }
}

String adminTabQueryValue(AdminTab tab) {
  return switch (tab) {
    AdminTab.users => 'users',
    AdminTab.cafes => 'cafes',
    AdminTab.discovered => 'discovered',
    AdminTab.claims => 'claims',
  };
}

class AdminUserFilters {
  const AdminUserFilters({
    this.searchQuery = '',
    this.roleFilter = 'all',
  });

  final String searchQuery;
  final String roleFilter;

  AdminUserFilters copyWith({
    String? searchQuery,
    String? roleFilter,
  }) {
    return AdminUserFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      roleFilter: roleFilter ?? this.roleFilter,
    );
  }
}

class AdminCafeFilters {
  const AdminCafeFilters({
    this.searchQuery = '',
    this.districtFilter = 'all',
    this.statusFilter = 'all',
  });

  final String searchQuery;
  final String districtFilter;
  final String statusFilter;

  AdminCafeFilters copyWith({
    String? searchQuery,
    String? districtFilter,
    String? statusFilter,
  }) {
    return AdminCafeFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      districtFilter: districtFilter ?? this.districtFilter,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

List<UserProfile> filterAdminUsers(
  List<UserProfile> users,
  AdminUserFilters filters,
) {
  var result = users;

  if (filters.roleFilter != 'all') {
    final role = filters.roleFilter == 'admin'
        ? ProfileRole.admin
        : filters.roleFilter == 'cafe_owner'
            ? ProfileRole.cafeOwner
            : ProfileRole.user;
    result = result.where((user) => user.role == role).toList(growable: false);
  }

  final query = filters.searchQuery.trim();
  if (query.isEmpty) {
    return result;
  }

  return result
      .where((user) =>
          containsNormalizedText(user.fullName, query) ||
          containsNormalizedText(user.username ?? '', query) ||
          containsNormalizedText(user.email, query))
      .toList(growable: false);
}

List<Cafe> filterAdminCafes(
  List<Cafe> cafes,
  AdminCafeFilters filters,
) {
  var result = cafes;

  final district = filters.districtFilter.trim();
  if (district.isNotEmpty && district != 'all') {
    result = result
        .where((cafe) =>
            normalizeSearchText(cafe.district) == normalizeSearchText(district))
        .toList(growable: false);
  }

  final query = filters.searchQuery.trim();
  if (query.isEmpty) {
    result = result;
  } else {
    result = result.where((cafe) {
      return containsNormalizedText(cafe.name, query) ||
          containsNormalizedText(cafe.district, query) ||
          containsNormalizedText(cafe.neighborhood, query) ||
          containsNormalizedText(cafe.address, query) ||
          containsNormalizedText(cafe.placeId ?? '', query);
    }).toList(growable: false);
  }

  final status = filters.statusFilter.trim();
  if (status == 'deleted') {
    result = result.where((cafe) => cafe.isDeleted).toList(growable: false);
  } else if (status == 'hidden') {
    result = result
        .where((cafe) => !cafe.isDeleted && !cafe.isVisibleInPublic)
        .toList(growable: false);
  } else if (status == 'visible') {
    result =
        result.where((cafe) => cafe.isVisibleInPublic).toList(growable: false);
  }

  return result;
}

String adminCafeSourceLabel(Cafe cafe) {
  return cafe.sourceType == 'google' ? 'Google/API' : 'Manual/DB';
}

String adminCafeStatusKey(Cafe cafe) {
  if (cafe.isDeleted) {
    return 'deleted';
  }
  return cafe.isVisibleInPublic ? 'visible' : 'hidden';
}

String adminRoleLabel(
  AppLocalizations l10n,
  ProfileRole role,
) {
  return switch (role) {
    ProfileRole.admin => l10n.adminRoleAdmin,
    ProfileRole.cafeOwner => 'Cafe owner',
    ProfileRole.user => l10n.adminRoleUser,
  };
}

String adminUserDisplayName(
  AppLocalizations l10n,
  UserProfile user,
) {
  return user.fullName.isNotEmpty ? user.fullName : l10n.adminUnnamedUser;
}
