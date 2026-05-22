import '../models/index.dart';
import '../models/service_result.dart';
import '../services/friends_service.dart';

/// Remote-only access layer for friends data.
///
/// `friendsProvider` owns the reactive UI state derived from these calls.
class FriendRepository {
  const FriendRepository(this._service);

  final FriendsServiceBase _service;

  Future<List<FriendRelationship>> fetchFriendRelationships(
      String userId) async {
    final result = await _service.fetchFriendRelationships(userId);
    return result.data ?? const <FriendRelationship>[];
  }

  Future<List<FriendLocationPresence>> fetchFriendPresence(
      String userId) async {
    final result = await _service.fetchFriendPresence(userId);
    return result.data ?? const <FriendLocationPresence>[];
  }

  Future<ServiceResult<void>> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) {
    return _service.sendFriendRequest(
      fromUserId: fromUserId,
      toUserId: toUserId,
    );
  }

  Future<ServiceResult<void>> updateLocationSharingMode({
    required String userId,
    required FriendLocationSharingMode mode,
  }) {
    return _service.updateLocationSharingMode(
      userId: userId,
      mode: mode,
    );
  }
}
