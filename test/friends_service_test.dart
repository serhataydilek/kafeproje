import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/services/friends_service.dart';
import 'package:kafeproje/utils/service_error.dart';

void main() {
  group('NoopFriendsService', () {
    const service = NoopFriendsService();

    test('returns empty relationship and presence snapshots', () async {
      final relationships = await service.fetchFriendRelationships('user-1');
      final presence = await service.fetchFriendPresence('user-1');

      expect(relationships.ok, isTrue);
      expect(relationships.data, isEmpty);
      expect(presence.ok, isTrue);
      expect(presence.data, isEmpty);
    });

    test('returns unavailable failures for mutation methods', () async {
      final requestResult = await service.sendFriendRequest(
        fromUserId: 'user-1',
        toUserId: 'user-2',
      );
      final sharingResult = await service.updateLocationSharingMode(
        userId: 'user-1',
        mode: FriendLocationSharingMode.cityOnly,
      );

      expect(requestResult.ok, isFalse);
      expect(requestResult.errorType, ServiceErrorType.unavailable);
      expect(sharingResult.ok, isFalse);
      expect(sharingResult.errorType, ServiceErrorType.unavailable);
    });
  });
}
