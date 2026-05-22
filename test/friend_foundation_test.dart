import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';

import 'test_helpers.dart';

void main() {
  group('friend foundation', () {
    test('social providers stay empty without an implemented backend',
        () async {
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
      );
      addTearDown(container.dispose);

      final relationshipsAsync = container.read(friendRelationshipsProvider);
      final relationships =
          relationshipsAsync is AsyncData<List<FriendRelationship>>
              ? relationshipsAsync.value
              : const <FriendRelationship>[];
      final presenceAsync = container.read(friendLocationPresenceProvider);
      final presence = presenceAsync is AsyncData<List<FriendLocationPresence>>
          ? presenceAsync.value
          : const <FriendLocationPresence>[];
      final visiblePresence = container.read(visibleFriendMapPresenceProvider);

      expect(relationships, isEmpty);
      expect(presence, isEmpty);
      expect(visiblePresence, isEmpty);
    });
  });
}
