import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/presentation/screens/auth/login_screen.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('shows Google Sign-In button on mobile platforms', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.textContaining('Google'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('shows email and password fields on Windows/Linux', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('shows Forgot Password button on desktop', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.textContaining('Forgot'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('shows Sign In button on desktop', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.textContaining('Sign In'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }
}
