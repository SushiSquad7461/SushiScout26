import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_state.dart';

void main() {
  group('AuthState', () {
    test('should have correct default values', () {
      const state = AuthState();
      
      expect(state.status, AuthStatus.initial);
      expect(state.userId, isNull);
      expect(state.userEmail, isNull);
      expect(state.displayName, isNull);
      expect(state.photoUrl, isNull);
      expect(state.currentTeamId, isNull);
      expect(state.teamMemberships, isEmpty);
      expect(state.isMasterTeamMember, false);
      expect(state.errorMessage, isNull);
    });

    test('isAuthenticated should return true when status is authenticated', () {
      const state = AuthState(status: AuthStatus.authenticated);
      expect(state.isAuthenticated, true);
    });

    test('needsTeam should return true when status is needsTeamSelection', () {
      const state = AuthState(status: AuthStatus.needsTeamSelection);
      expect(state.needsTeam, true);
    });

    test('hasError should return true when status is error', () {
      const state = AuthState(status: AuthStatus.error, errorMessage: 'Test error');
      expect(state.hasError, true);
    });

    test('copyWith should create new instance with updated values', () {
      const state = AuthState(status: AuthStatus.initial);
      final newState = state.copyWith(
        status: AuthStatus.authenticated,
        userId: 'user123',
        displayName: 'Test User',
      );

      expect(newState.status, AuthStatus.authenticated);
      expect(newState.userId, 'user123');
      expect(newState.displayName, 'Test User');
      expect(newState.userEmail, isNull);
    });
  });

  group('AuthStatus', () {
    test('should have all expected values', () {
      expect(AuthStatus.values, contains(AuthStatus.initial));
      expect(AuthStatus.values, contains(AuthStatus.loading));
      expect(AuthStatus.values, contains(AuthStatus.authenticated));
      expect(AuthStatus.values, contains(AuthStatus.unauthenticated));
      expect(AuthStatus.values, contains(AuthStatus.needsTeamSelection));
      expect(AuthStatus.values, contains(AuthStatus.error));
    });
  });
}
