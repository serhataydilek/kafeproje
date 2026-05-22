import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_provider.dart';

class AdminRouteGuard extends ConsumerWidget {
  const AdminRouteGuard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthReady = ref.watch(isAuthReadyProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return FutureBuilder<void>(
      future: Future<void>.value(),
      builder: (context, snapshot) {
        if (!isAuthReady || snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (currentUser == null) {
          return const _GuardRedirect(target: '/auth');
        }

        if (!isAdmin) {
          return const _GuardRedirect(target: '/profile');
        }

        return child;
      },
    );
  }
}

class _GuardRedirect extends StatefulWidget {
  const _GuardRedirect({
    required this.target,
  });

  final String target;

  @override
  State<_GuardRedirect> createState() => _GuardRedirectState();
}

class _GuardRedirectState extends State<_GuardRedirect> {
  late final Future<void> _redirectFuture;

  @override
  void initState() {
    super.initState();
    _redirectFuture = Future<void>(() {
      if (mounted) {
        context.go(widget.target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _redirectFuture,
      builder: (context, snapshot) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
