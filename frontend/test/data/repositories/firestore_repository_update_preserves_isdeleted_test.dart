import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';

/// Regression guard: editing a match must never resurrect a concurrent
/// trash. The edit wizard freezes `isDeleted` from whenever it was opened
/// (see match_details.dart's _openEditForm doc comment) — if another scout
/// trashes the match while the edit is in flight, updateMatch's write must
/// not carry that stale `false` back to the server.
void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(fake, teamId: 'teamA');
  });

  test(
    'updateMatch does not overwrite a concurrently-trashed isDeleted flag',
    () async {
      final original = MatchReport(
        id: 'm1',
        matchId: 'qm1_4198',
        matchNumber: 1,
        teamNumber: 4198,
        alliance: 'Red',
        scouterName: 'scout',
        gameData: const {'auto_fuel': 3},
        createdAt: DateTime(2026, 7, 22),
        eventId: 'teamA_evt',
        teamId: 'teamA',
        programType: 'FRC',
      );
      await repo.createMatch('teamA_evt', original);

      // A scout trashes the match while another scout is mid-edit.
      await repo.trashMatch('teamA_evt', 'm1');

      // The mid-edit save carries the frozen (pre-trash) isDeleted: false.
      final edited = original.copyWith(comments: 'edited while trashed');
      await repo.updateMatch('teamA_evt', edited);

      final doc = await fake.collection('matches').doc('m1').get();
      expect(doc.data()!['isDeleted'], isTrue);
      expect(doc.data()!['comments'], 'edited while trashed');
    },
  );

  test('updateMatch still updates content fields normally', () async {
    final original = MatchReport(
      id: 'm1',
      matchId: 'qm1_4198',
      matchNumber: 1,
      teamNumber: 4198,
      alliance: 'Red',
      scouterName: 'scout',
      gameData: const {'auto_fuel': 3},
      createdAt: DateTime(2026, 7, 22),
      eventId: 'teamA_evt',
      teamId: 'teamA',
      programType: 'FRC',
    );
    await repo.createMatch('teamA_evt', original);

    final edited = original.copyWith(comments: 'updated');
    await repo.updateMatch('teamA_evt', edited);

    final doc = await fake.collection('matches').doc('m1').get();
    expect(doc.data()!['isDeleted'], isFalse);
    expect(doc.data()!['comments'], 'updated');
  });
}
