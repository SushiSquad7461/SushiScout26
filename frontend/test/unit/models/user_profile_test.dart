import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/user_profile.dart';

UserProfile _profile({
  String? currentTeamId,
  Map<String, String> teamMemberships = const {},
}) {
  return UserProfile(
    id: 'user-1',
    email: 'a@b.com',
    displayName: 'Alice',
    currentTeamId: currentTeamId,
    teamMemberships: teamMemberships,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('UserProfile.isInTeam', () {
    test('is true when currentTeamId is set', () {
      expect(_profile(currentTeamId: 't1').isInTeam, isTrue);
    });

    test('is false when currentTeamId is null', () {
      expect(_profile(currentTeamId: null).isInTeam, isFalse);
    });
  });

  group('UserProfile.isMemberOf', () {
    test('is true for a team in teamMemberships', () {
      final p = _profile(teamMemberships: const {'t1': 'member'});
      expect(p.isMemberOf('t1'), isTrue);
    });

    test('is false for a team not in teamMemberships', () {
      final p = _profile(teamMemberships: const {'t1': 'member'});
      expect(p.isMemberOf('t2'), isFalse);
    });

    test('is false when teamMemberships is empty', () {
      expect(_profile().isMemberOf('t1'), isFalse);
    });
  });

  group('UserProfile.isAdminOf', () {
    test('is true when role is admin', () {
      final p = _profile(teamMemberships: const {'t1': 'admin'});
      expect(p.isAdminOf('t1'), isTrue);
    });

    test('is false when role is member', () {
      final p = _profile(teamMemberships: const {'t1': 'member'});
      expect(p.isAdminOf('t1'), isFalse);
    });

    test('is false for a team the user is not in', () {
      final p = _profile(teamMemberships: const {'t1': 'admin'});
      expect(p.isAdminOf('t2'), isFalse);
    });

    test('is false when memberships are empty', () {
      expect(_profile().isAdminOf('t1'), isFalse);
    });
  });

  group('UserProfile.copyWith', () {
    test('overrides currentTeamId while preserving other fields', () {
      final original = _profile(currentTeamId: 't1');
      final updated = original.copyWith(currentTeamId: 't2');
      expect(updated.currentTeamId, 't2');
      expect(updated.id, original.id);
      expect(updated.email, original.email);
      expect(updated.displayName, original.displayName);
    });

    test('returns equal-field copy when no overrides are passed', () {
      final original = _profile(
        currentTeamId: 't1',
        teamMemberships: const {'t1': 'admin'},
      );
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.email, original.email);
      expect(copy.currentTeamId, original.currentTeamId);
      expect(copy.teamMemberships, original.teamMemberships);
      expect(copy.createdAt, original.createdAt);
    });

    test('can update teamMemberships', () {
      final original = _profile(teamMemberships: const {'t1': 'member'});
      final updated =
          original.copyWith(teamMemberships: const {'t1': 'admin', 't2': 'member'});
      expect(updated.teamMemberships, {'t1': 'admin', 't2': 'member'});
    });
  });

  group('UserProfile.toFirestore', () {
    test('writes expected keys', () {
      final p = _profile(
        currentTeamId: 't1',
        teamMemberships: const {'t1': 'admin'},
      );
      final firestore = p.toFirestore();
      expect(firestore['email'], 'a@b.com');
      expect(firestore['displayName'], 'Alice');
      expect(firestore['currentTeamId'], 't1');
      expect(firestore['teamMemberships'], {'t1': 'admin'});
      expect(firestore.containsKey('updatedAt'), isTrue);
    });

    test('writes null currentTeamId when not in a team', () {
      final firestore = _profile().toFirestore();
      expect(firestore['currentTeamId'], isNull);
    });
  });
}
