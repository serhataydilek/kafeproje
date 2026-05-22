import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafeproje/screens/auth_screen.dart';
import 'package:kafeproje/constants/error_codes.dart';
import 'package:kafeproje/models/service_result.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/service_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'test_helpers.dart';

class _FakeAuthNotifier extends AppShellNotifier {
  _FakeAuthNotifier(
    super.ref, {
    required super.initialState,
    this.signInResult = const ServiceSuccess<void>(),
    this.signUpResult = const ServiceSuccess<void>(),
    this.resetPasswordResult = const ServiceSuccess<void>(),
  }) : super.test();

  final ServiceResult<void> signInResult;
  final ServiceResult<void> signUpResult;
  final ServiceResult<void> resetPasswordResult;

  @override
  Future<ServiceResult<void>> signIn(String identifier, String password) async {
    return signInResult;
  }

  @override
  Future<ServiceResult<void>> signUp(
    String username,
    String firstName,
    String lastName,
    String email,
    String password,
  ) async {
    return signUpResult;
  }

  @override
  Future<ServiceResult<void>> resetPassword(String email) async {
    return resetPasswordResult;
  }
}

void main() {
  group('AuthScreen Tests', () {
    testWidgets('renders login form by default', (tester) async {
      final container = createTestContainer(state: buildTestAppShellState());

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(body: AuthScreen()),
        ),
      );

      expect(find.byType(TextFormField), findsNWidgets(2)); // Email, Password
      expect(find.text('Sign in'), findsWidgets);
      expect(find.byType(TextButton), findsWidgets);
    });

    testWidgets('toggles to sign up form', (tester) async {
      final container = createTestContainer(state: buildTestAppShellState());

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(body: AuthScreen()),
        ),
      );

      await tester.tap(find.text('Create a new account'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(5));
      expect(find.text('Sign up'), findsWidgets);
    });

    testWidgets('submit is disabled when fields are empty', (tester) async {
      final container = createTestContainer(state: buildTestAppShellState());

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(body: AuthScreen()),
        ),
      );

      final submitBtn = tester.widget<FilledButton>(
        find.byType(FilledButton).first,
      );
      expect(submitBtn.onPressed, isNull);
    });

    testWidgets('submit is enabled when valid login fields are entered',
        (tester) async {
      final container = createTestContainer(state: buildTestAppShellState());

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(body: AuthScreen()),
        ),
      );

      await tester.enterText(
          find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.pumpAndSettle();

      final submitBtn = tester.widget<FilledButton>(
        find.byType(FilledButton).first,
      );
      expect(submitBtn.onPressed, isNotNull);
    });

    testWidgets('shows localized invalid credentials message', (tester) async {
      late _FakeAuthNotifier notifier;
      final container = ProviderContainer(
        overrides: [
          appShellProvider.overrideWith(
            (ref) => notifier = _FakeAuthNotifier(
              ref,
              initialState: buildTestAppShellState(
                currentUser: null,
                isAuthReady: true,
              ),
              signInResult: const ServiceFailure<void>(
                errorCode: AppErrorCode.authInvalidCredentials,
                errorType: ServiceErrorType.auth,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(body: AuthScreen()),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(notifier, isNotNull);
      expect(
        find.text('Email, username, or password is incorrect.'),
        findsOneWidget,
      );
    });

    testWidgets('rate-limited sign in starts cooldown state', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appShellProvider.overrideWith(
            (ref) => _FakeAuthNotifier(
              ref,
              initialState: buildTestAppShellState(
                currentUser: null,
                isAuthReady: true,
              ),
              signInResult: const ServiceFailure<void>(
                errorCode: AppErrorCode.authRateLimited,
                errorType: ServiceErrorType.auth,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(body: AuthScreen()),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Too many attempts. Please wait a little before trying again.',
        ),
        findsOneWidget,
      );

      final submitBtn = tester.widget<FilledButton>(
        find.byType(FilledButton).first,
      );
      expect(submitBtn.onPressed, isNull);
    });

    testWidgets('sign up success shows localized verification notice',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appShellProvider.overrideWith(
            (ref) => _FakeAuthNotifier(
              ref,
              initialState: buildTestAppShellState(
                currentUser: null,
                isAuthReady: true,
              ),
              signUpResult: const ServiceSuccess<void>(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(body: AuthScreen()),
        ),
      );

      await tester.tap(find.text('Create a new account'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'newuser');
      await tester.enterText(fields.at(1), 'Ada');
      await tester.enterText(fields.at(2), 'Lovelace');
      await tester.enterText(fields.at(3), 'ada@example.com');
      await tester.enterText(fields.at(4), 'password123');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your account was created. Check your inbox to verify your email address.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('reset password failure is localized', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appShellProvider.overrideWith(
            (ref) => _FakeAuthNotifier(
              ref,
              initialState: buildTestAppShellState(
                currentUser: null,
                isAuthReady: true,
              ),
              resetPasswordResult: const ServiceFailure<void>(
                errorCode: AppErrorCode.authPasswordResetFailed,
                errorType: ServiceErrorType.auth,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(body: AuthScreen()),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password reset could not be started right now.'),
        findsOneWidget,
      );
    });

    test('username sign-in surfaces lookup network failures as network errors',
        () async {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(
            SupabaseClient('https://example.com', 'test-anon-key'),
          ),
          profilesServiceProvider.overrideWithValue(
            _FakeProfilesServiceForAuth(
              lookupResult: ServiceResult.failure(
                errorCode: AppErrorCode.networkError,
                errorType: ServiceErrorType.network,
              ),
            ),
          ),
          appShellProvider.overrideWith(
            (ref) => AppShellNotifier.test(
              ref,
              initialState: buildTestAppShellState(
                currentUser: null,
                isAuthReady: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(appShellProvider.notifier)
          .signIn('username_only', 'password123');

      expect(result.ok, isFalse);
      expect(result.errorCode, AppErrorCode.networkError);
      expect(result.errorType, ServiceErrorType.network);
    });
  });
}

class _FakeProfilesServiceForAuth extends ProfilesService {
  _FakeProfilesServiceForAuth({
    required this.lookupResult,
  }) : super(SupabaseClient('https://example.com', 'test-anon-key'));

  final ServiceResult<String?> lookupResult;

  @override
  Future<ServiceResult<String?>> findEmailByUsernameResult(String username) {
    return Future.value(lookupResult);
  }
}
