import '../models/index.dart';
import '../models/service_result.dart';
import '../utils/service_error.dart';

abstract class FriendsServiceBase {
  Future<ServiceResult<List<FriendRelationship>>> fetchFriendRelationships(
    String userId,
  );

  Future<ServiceResult<List<FriendLocationPresence>>> fetchFriendPresence(
    String userId,
  );

  Future<ServiceResult<void>> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  });

  Future<ServiceResult<void>> updateLocationSharingMode({
    required String userId,
    required FriendLocationSharingMode mode,
  });
}

/// Intentionally lightweight placeholder until a dedicated social backend exists.
class NoopFriendsService implements FriendsServiceBase {
  const NoopFriendsService();

  @override
  Future<ServiceResult<List<FriendRelationship>>> fetchFriendRelationships(
    String userId,
  ) async {
    return ServiceResult.success(
      data: <FriendRelationship>[],
      message: 'Friend relationships are not configured yet.',
    );
  }

  @override
  Future<ServiceResult<List<FriendLocationPresence>>> fetchFriendPresence(
    String userId,
  ) async {
    return ServiceResult.success(
      data: <FriendLocationPresence>[],
      message: 'Live friend locations are not configured yet.',
    );
  }

  @override
  Future<ServiceResult<void>> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    return ServiceResult.failure(
      message: 'Friend requests are not available yet.',
      errorType: ServiceErrorType.unavailable,
    );
  }

  @override
  Future<ServiceResult<void>> updateLocationSharingMode({
    required String userId,
    required FriendLocationSharingMode mode,
  }) async {
    return ServiceResult.failure(
      message: 'Live location sharing is not available yet.',
      errorType: ServiceErrorType.unavailable,
    );
  }
}
