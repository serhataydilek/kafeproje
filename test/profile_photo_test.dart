import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/models/service_result.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/screens/profile_screen.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/service_error.dart';
import 'package:kafeproje/widgets/ui/remote_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_helpers.dart';

void main() {
  group('profile photo UI', () {
    testWidgets('missing avatar url falls back to initials avatar',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: const CurrentUser(
            id: 'user-1',
            email: 'user@example.com',
            name: 'Test User',
          ),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ProfileScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('TU'), findsOneWidget);
    });

    testWidgets('profile screen shows polished photo actions', (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: const CurrentUser(
            id: 'user-1',
            email: 'user@example.com',
            name: 'Test User',
            username: 'tester',
          ),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ProfileScreen()),
      );
      await tester.pumpAndSettle();

      // Enter editing mode first — photo actions are only visible in edit mode
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      expect(find.text('Edit photo'), findsOneWidget);
      expect(find.text('Add a photo to make your profile feel more personal.'),
          findsOneWidget);
    });

    testWidgets('profile screen supports avatar url removal inline',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: const CurrentUser(
            id: 'user-1',
            email: 'user@example.com',
            name: 'Test User',
            avatarUrl: 'https://example.com/avatar.png',
          ),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ProfileScreen()),
      );
      // Use pump() instead of pumpAndSettle() because CachedNetworkImage
      // runs an infinite loading animation that prevents settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Enter editing mode first — photo actions are only visible in edit mode
      await tester.tap(find.text('Edit profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsNWidgets(2));

      await tester.tap(find.text('Remove photo').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining(
            'Pick a photo from your gallery to preview it before saving'),
        findsOneWidget,
      );
    });

    testWidgets(
        'cold-start hydration shows profile photo and admin badge without extra navigation',
        (tester) async {
      const profile = UserProfile(
        id: 'admin-user',
        username: 'manager',
        firstName: 'Ada',
        lastName: 'Admin',
        fullName: 'Ada Admin',
        email: 'admin@example.com',
        role: ProfileRole.admin,
        createdAt: '2026-04-19T09:00:00.000Z',
        avatarUrl: 'https://example.com/avatar.png',
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: null,
          isAuthReady: false,
          isAdmin: false,
          isAdminRoleResolved: false,
        ),
        overrides: [
          profilesServiceProvider.overrideWithValue(
            _FakeStartupProfilesService(profile),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(container: container, child: const ProfileScreen()),
      );
      await tester.pump();

      expect(find.byType(RemoteImage), findsNothing);

      await container
          .read(appShellProvider.notifier)
          .bootstrapAuthenticatedUserForTesting(
            _buildAuthUser(
              id: 'admin-user',
              email: 'admin@example.com',
            ),
            source: 'test_cold_start',
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(RemoteImage), findsOneWidget);
      expect(container.read(isAdminProvider), isTrue);
      expect(container.read(currentUserProvider)?.avatarUrl,
          'https://example.com/avatar.png');
      expect(find.text('Ada Admin'), findsWidgets);
    });
  });
}

class _FakeStartupProfilesService extends ProfilesService {
  _FakeStartupProfilesService(this.profile)
      : super(
          SupabaseClient(
            'https://example.com',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final UserProfile profile;

  @override
  Future<ServiceResult<UserProfile?>> fetchProfileById(String userId) async {
    if (userId != profile.id) {
      return ServiceResult.failure(
        message: 'Profile not found.',
        errorType: ServiceErrorType.notFound,
      );
    }
    return ServiceResult.success(data: profile);
  }
}

User _buildAuthUser({
  required String id,
  required String email,
}) {
  return User.fromJson({
    'id': id,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': email,
    'app_metadata': const <String, dynamic>{},
    'user_metadata': const <String, dynamic>{},
    'created_at': '2026-04-19T09:00:00.000Z',
  })!;
}
