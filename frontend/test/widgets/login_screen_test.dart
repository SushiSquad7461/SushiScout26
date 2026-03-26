import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/presentation/screens/auth/login_screen.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';
import 'package:frontend/core/auth/auth_state.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('should display sign in button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('should display app title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.text('SushiScout 26'), findsOneWidget);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }
}
