import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/team.dart';

Team _team({
  String id = 't1',
  String name = 'Sushi Squad',
  String inviteCode = 'ABC123',
  bool isMasterTeam = false,
  int memberCount = 1,
}) {
  return Team(
    id: id,
    name: name,
    inviteCode: inviteCode,
    createdBy: 'user-1',
    createdAt: DateTime(2026, 1, 1),
    isMasterTeam: isMasterTeam,
    memberCount: memberCount,
  );
}

void main() {
  group('Team.copyWith', () {
    test('overrides name while preserving other fields', () {
      final t = _team(name: 'Original');
      final updated = t.copyWith(name: 'Updated');
      expect(updated.name, 'Updated');
      expect(updated.id, t.id);
      expect(updated.inviteCode, t.inviteCode);
      expect(updated.createdBy, t.createdBy);
      expect(updated.createdAt, t.createdAt);
    });

    test('overrides memberCount independently', () {
      final t = _team(memberCount: 1);
      expect(t.copyWith(memberCount: 5).memberCount, 5);
    });

    test('overrides isMasterTeam', () {
      final t = _team(isMasterTeam: false);
      expect(t.copyWith(isMasterTeam: true).isMasterTeam, isTrue);
    });

    test('returns equal-field copy when no overrides are passed', () {
      final t = _team();
      final copy = t.copyWith();
      expect(copy.id, t.id);
      expect(copy.name, t.name);
      expect(copy.inviteCode, t.inviteCode);
      expect(copy.createdBy, t.createdBy);
      expect(copy.createdAt, t.createdAt);
      expect(copy.isMasterTeam, t.isMasterTeam);
      expect(copy.memberCount, t.memberCount);
    });
  });

  group('Team.toFirestore', () {
    test('writes expected keys', () {
      final t = _team(name: 'Sushi', isMasterTeam: true, memberCount: 7);
      final firestore = t.toFirestore();
      expect(firestore['name'], 'Sushi');
      expect(firestore['inviteCode'], 'ABC123');
      expect(firestore['createdBy'], 'user-1');
      expect(firestore['isMasterTeam'], isTrue);
      expect(firestore['memberCount'], 7);
      expect(firestore.containsKey('createdAt'), isTrue);
      expect(firestore.containsKey('updatedAt'), isTrue);
    });

    test('does not include id field (id is the doc reference)', () {
      final firestore = _team().toFirestore();
      expect(firestore.containsKey('id'), isFalse);
    });
  });

  group('Team defaults', () {
    test('isMasterTeam defaults to false', () {
      final t = Team(
        id: 't1',
        name: 'X',
        inviteCode: 'ABC',
        createdBy: 'u',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(t.isMasterTeam, isFalse);
    });

    test('memberCount defaults to 0', () {
      final t = Team(
        id: 't1',
        name: 'X',
        inviteCode: 'ABC',
        createdBy: 'u',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(t.memberCount, 0);
    });
  });
}
