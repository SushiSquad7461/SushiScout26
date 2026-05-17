import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_state.dart';

AuthState _state({
  AuthStatus status = AuthStatus.authenticated,
  String? userId = 'user-1',
  String? errorMessage,
  String? currentTeamId = 't1',
}) {
  return AuthState(
    status: status,
    userId: userId,
    userEmail: 'a@b.com',
    displayName: 'Alice',
    currentTeamId: currentTeamId,
    teamMemberships: const {'t1': 'admin'},
    errorMessage: errorMessage,
  );
}

void main() {
  group('AuthState convenience getters', () {
    test('isAuthenticated true only for authenticated status', () {
      expect(_state(status: AuthStatus.authenticated).isAuthenticated, isTrue);
      expect(_state(status: AuthStatus.unauthenticated).isAuthenticated,
          isFalse);
      expect(_state(status: AuthStatus.loading).isAuthenticated, isFalse);
    });

    test('needsTeam true only for needsTeamSelection status', () {
      expect(_state(status: AuthStatus.needsTeamSelection).needsTeam, isTrue);
      expect(_state(status: AuthStatus.authenticated).needsTeam, isFalse);
    });

    test('hasError true only for error status', () {
      expect(_state(status: AuthStatus.error).hasError, isTrue);
      expect(_state(status: AuthStatus.authenticated).hasError, isFalse);
    });
  });

  group('AuthState.copyWith leaves untouched fields alone', () {
    test('only status is updated when only status is passed', () {
      final original = _state(
        status: AuthStatus.authenticated,
        errorMessage: 'old error',
      );
      final updated = original.copyWith(status: AuthStatus.loading);
      expect(updated.status, AuthStatus.loading);
      expect(updated.userId, original.userId);
      expect(updated.userEmail, original.userEmail);
      expect(updated.errorMessage, 'old error');
      expect(updated.currentTeamId, original.currentTeamId);
    });

    test('no-arg copyWith returns equivalent state', () {
      final original = _state(errorMessage: 'msg');
      final copy = original.copyWith();
      expect(copy.status, original.status);
      expect(copy.userId, original.userId);
      expect(copy.errorMessage, original.errorMessage);
      expect(copy.currentTeamId, original.currentTeamId);
    });
  });

  group('AuthState.copyWith clears nullable fields when null passed', () {
    test('errorMessage: null clears the error message', () {
      final original = _state(errorMessage: 'something failed');
      final cleared = original.copyWith(errorMessage: null);
      expect(cleared.errorMessage, isNull);
      // Other fields preserved.
      expect(cleared.userId, original.userId);
      expect(cleared.status, original.status);
    });

    test('userId: null clears the user id', () {
      final original = _state(userId: 'user-1');
      final cleared = original.copyWith(userId: null);
      expect(cleared.userId, isNull);
    });

    test('currentTeamId: null clears the current team', () {
      final original = _state(currentTeamId: 't1');
      final cleared = original.copyWith(currentTeamId: null);
      expect(cleared.currentTeamId, isNull);
    });

    test('passing a new value updates the field', () {
      final updated = _state().copyWith(errorMessage: 'new error');
      expect(updated.errorMessage, 'new error');
    });
  });

  group('AuthState.copyWith for non-nullable fields', () {
    test('teamMemberships ?? falls back to current value when not passed', () {
      final original = _state();
      final copy = original.copyWith(status: AuthStatus.loading);
      expect(copy.teamMemberships, {'t1': 'admin'});
    });

    test('teamMemberships override works', () {
      final original = _state();
      final updated = original
          .copyWith(teamMemberships: const {'t2': 'member'});
      expect(updated.teamMemberships, {'t2': 'member'});
    });

    test('isMasterTeamMember override works', () {
      final updated = _state().copyWith(isMasterTeamMember: true);
      expect(updated.isMasterTeamMember, isTrue);
    });
  });
}
