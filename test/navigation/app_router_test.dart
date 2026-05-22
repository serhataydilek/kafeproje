import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/navigation/app_router.dart';
import 'package:kafeproje/providers/app_provider.dart';

void main() {
  group('Route Guards Redirect Logic (Unit)', () {
    GoRouterState buildState(String location) {
      return _GoRouterStateMock(location);
    }

    test('Auth not ready -> Returns null (no redirect)', () {
      final state = buildState('/profile');
      const shellState = AppShellState(isAuthReady: false);

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, isNull);
    });

    test('Unauthenticated user accessing protected route -> Redirects to /auth',
        () {
      final state = buildState('/profile');
      const shellState = AppShellState(isAuthReady: true, currentUser: null);

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, startsWith('/auth?from=%2Fprofile'));
    });

    test('Unauthenticated user accessing /cafe-edit -> Redirects to /auth', () {
      final state = buildState('/cafe-edit/123');
      const shellState = AppShellState(isAuthReady: true, currentUser: null);

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, startsWith('/auth'));
    });

    test('Unauthenticated user accessing public route -> Stays', () {
      final state = buildState('/auth');
      const shellState = AppShellState(isAuthReady: true, currentUser: null);

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, isNull);
    });

    test(
        'Authenticated normal user accessing public route -> Redirects to home',
        () {
      const user = CurrentUser(
          id: '1', email: 'test@test.com', name: 'Test', isAdmin: false);
      final state = buildState('/auth');
      const shellState = AppShellState(isAuthReady: true, currentUser: user);

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, '/');
    });

    test('Authenticated normal user accessing /admin -> Redirects to /profile',
        () {
      const user = CurrentUser(
          id: '1', email: 'test@test.com', name: 'Test', isAdmin: false);
      final state = buildState('/admin');
      const shellState =
          AppShellState(
            isAuthReady: true,
            currentUser: user,
            isAdmin: false,
            isAdminRoleResolved: true,
          );

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, '/profile');
    });

    test(
        'Authenticated normal user accessing /cafe-add -> Redirects to /profile',
        () {
      const user = CurrentUser(
          id: '1', email: 'test@test.com', name: 'Test', isAdmin: false);
      final state = buildState('/cafe-add');
      const shellState =
          AppShellState(
            isAuthReady: true,
            currentUser: user,
            isAdmin: false,
            isAdminRoleResolved: true,
          );

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, '/profile');
    });

    test(
        'Authenticated normal user accessing /cafe-edit/123 -> Redirects to /profile',
        () {
      const user = CurrentUser(
          id: '1', email: 'test@test.com', name: 'Test', isAdmin: false);
      final state = buildState('/cafe-edit/123');
      const shellState =
          AppShellState(
            isAuthReady: true,
            currentUser: user,
            isAdmin: false,
            isAdminRoleResolved: true,
          );

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, '/profile');
    });

    test('Unresolved admin role on /admin does not force redirect', () {
      const user = CurrentUser(
          id: '1', email: 'test@test.com', name: 'Test', isAdmin: false);
      final state = buildState('/admin');
      const shellState = AppShellState(
        isAuthReady: true,
        currentUser: user,
        isAdmin: false,
        isAdminRoleResolved: false,
        adminRoleStatusMessage: 'Admin status temporarily unavailable.',
      );

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, isNull);
    });

    test('safe in-app absolute from paths survive auth redirect', () {
      const user = CurrentUser(
          id: '1', email: 'test@test.com', name: 'Test', isAdmin: false);
      final state = buildState('/auth?from=%2Fcompare');
      const shellState = AppShellState(isAuthReady: true, currentUser: user);

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, '/compare');
    });

    test('safe in-app absolute from paths may keep allowed query params', () {
      const user = CurrentUser(
          id: '1', email: 'test@test.com', name: 'Test', isAdmin: false);
      final state = buildState('/auth?from=%2Ffilters%3Fscope%3Dmap');
      const shellState = AppShellState(isAuthReady: true, currentUser: user);

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, '/filters?scope=map');
    });

    test('unsafe from redirects fall back to home', () {
      const user = CurrentUser(
          id: '1', email: 'test@test.com', name: 'Test', isAdmin: false);
      const shellState = AppShellState(isAuthReady: true, currentUser: user);

      for (final rawFrom in [
        'https://evil.example/phish',
        '//evil.example/phish',
        'profile',
        '/unknown',
        '/auth',
        '/onboarding',
        r'/profile\evil',
      ]) {
        final state = buildState(
          '/auth?from=${Uri.encodeQueryComponent(rawFrom)}',
        );

        final result = appRouteGuardRedirect(shellState, state);
        expect(result, '/', reason: rawFrom);
      }
    });

    test('admin from redirects require an admin session', () {
      const user = CurrentUser(
          id: '1', email: 'test@test.com', name: 'Test', isAdmin: false);
      final state = buildState('/auth?from=%2Fadmin');
      const shellState = AppShellState(
        isAuthReady: true,
        currentUser: user,
        isAdmin: false,
      );

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, '/');
    });

    test('Admin user accessing /admin -> Allows access', () {
      const user = CurrentUser(
          id: '1', email: 'admin@test.com', name: 'Admin', isAdmin: true);
      final state = buildState('/admin');
      const shellState =
          AppShellState(isAuthReady: true, currentUser: user, isAdmin: true);

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, isNull);
    });

    test('Admin user accessing /cafe-add -> Allows access', () {
      const user = CurrentUser(
          id: '1', email: 'admin@test.com', name: 'Admin', isAdmin: true);
      final state = buildState('/cafe-add');
      const shellState =
          AppShellState(isAuthReady: true, currentUser: user, isAdmin: true);

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, isNull);
    });

    test('admin from redirects survive for admin sessions', () {
      const user = CurrentUser(
          id: '1', email: 'admin@test.com', name: 'Admin', isAdmin: true);
      final state = buildState('/auth?from=%2Fcafe-edit%2F123');
      const shellState =
          AppShellState(isAuthReady: true, currentUser: user, isAdmin: true);

      final result = appRouteGuardRedirect(shellState, state);
      expect(result, '/cafe-edit/123');
    });
  });
}

class _GoRouterStateMock implements GoRouterState {
  _GoRouterStateMock(this.locationStr);
  final String locationStr;

  late final uri = Uri.parse(locationStr);

  @override
  String get matchedLocation => uri.path;

  @override
  String get location => locationStr;

  @override
  Map<String, String> get queryParameters => uri.queryParameters;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
