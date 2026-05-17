import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_state.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/team_select_screen.dart';
import '../screens/dashboard.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    switch (authState.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const _LoadingScreen();

      case AuthStatus.unauthenticated:
        return const LoginScreen();

      case AuthStatus.error:
        // If no user session at all, show login
        if (authState.userId == null) {
          return const LoginScreen();
        }
        // If user exists but has no team, show team selection (with error)
        if (authState.currentTeamId == null) {
          return const TeamSelectScreen();
        }
        // User has team — show dashboard (error banner shown there)
        return const DashboardScreen();

      case AuthStatus.needsTeamSelection:
        return const TeamSelectScreen();

      case AuthStatus.authenticated:
        return const DashboardScreen();
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
