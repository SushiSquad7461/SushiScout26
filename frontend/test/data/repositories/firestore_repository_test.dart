import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';

MatchReport buildMatch({
  required String id,
  int teamNumber = 4198,
  Map<String, dynamic>? gameData,
  String programType = 'FRC',
  String teamId = '',
}) {
  return MatchReport(
    id: id,
    matchId: 'qm1_$teamNumber',
    matchNumber: 1,
    teamNumber: teamNumber,
    alliance: 'Red',
    scouterName: 'scout',
    gameData: gameData ?? {'auto_fuel': 3},
    createdAt: DateTime(2026, 7, 22),
    programType: programType,
    teamId: teamId,
  );
}

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(fake, teamId: 'teamA');
  });

  group('create and read', () {
    test('createMatch writes a readable match', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final matches = await repo.getMatches('teamA_evt');

      expect(matches, hasLength(1));
      expect(matches.single.id, 'm1');
      expect(matches.single.teamNumber, 4198);
    });

    test('createMatch stamps the repository teamId onto the document', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final matches = await repo.getMatches('teamA_evt');

      expect(matches.single.teamId, 'teamA');
    });

    test('robotDied round-trips through gameData', () async {
      await repo.createMatch(
        'teamA_evt',
        buildMatch(id: 'm1', gameData: {'auto_fuel': 3, 'robot_died': true}),
      );

      final matches = await repo.getMatches('teamA_evt');

      expect(matches.single.robotDied, isTrue);
    });

    test('programType is persisted rather than inferred', () async {
      await repo.createMatch(
        'teamA_evt',
        buildMatch(id: 'm1', programType: 'FTC', gameData: {'artifacts_auto': 2}),
      );

      final matches = await repo.getMatches('teamA_evt');

      expect(matches.single.programType, 'FTC');
    });

    test('updateMatch overwrites fields on the existing document', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      await repo.updateMatch(
        'teamA_evt',
        buildMatch(id: 'm1', gameData: {'auto_fuel': 9}),
      );

      final matches = await repo.getMatches('teamA_evt');
      expect(matches, hasLength(1));
      expect(matches.single.autoFuel, 9);
    });
  });

  group('trash lifecycle', () {
    test('trashMatch removes the match from the active list', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      await repo.trashMatch('teamA_evt', 'm1');

      expect(await repo.getMatches('teamA_evt'), isEmpty);
    });

    test('trashMatch moves the match into the trash list', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      await repo.trashMatch('teamA_evt', 'm1');

      final trashed = await repo.getDeletedMatches('teamA_evt');
      expect(trashed, hasLength(1));
      expect(trashed.single.id, 'm1');
    });

    test('restoreMatch returns the match to the active list', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));
      await repo.trashMatch('teamA_evt', 'm1');

      await repo.restoreMatch('teamA_evt', 'm1');

      expect(await repo.getMatches('teamA_evt'), hasLength(1));
      expect(await repo.getDeletedMatches('teamA_evt'), isEmpty);
    });

    test('deleteMatch removes the document entirely', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));
      await repo.trashMatch('teamA_evt', 'm1');

      await repo.deleteMatch('teamA_evt', 'm1');

      expect(await repo.getDeletedMatches('teamA_evt'), isEmpty);
      final raw = await fake.collection('matches').doc('m1').get();
      expect(raw.exists, isFalse);
    });
  });

  // Scope note: these cover READ-side isolation only, which is the part
  // FirestoreRepository enforces itself (via _matchesQuery's teamId filter).
  //
  // Write-side isolation is NOT tested here and cannot be: trashMatch,
  // restoreMatch, and deleteMatch address matches/{id} directly with no
  // ownership check, delegating enforcement entirely to Firestore rules.
  // FakeFirebaseFirestore does not evaluate rules, so a test asserting that
  // team B cannot trash team A's match would fail against correct code.
  // That guarantee is covered by test/firestore-rules/rules.test.js instead.
  group('team isolation (read side)', () {
    test('a repository scoped to another team cannot read these matches', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final repoB = FirestoreRepository(fake, teamId: 'teamB');

      expect(await repoB.getMatches('teamA_evt'), isEmpty);
    });

    test('getEvents only returns events belonging to the active team', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));
      final repoB = FirestoreRepository(fake, teamId: 'teamB');
      await repoB.createMatch('teamB_evt', buildMatch(id: 'm2'));

      final eventsA = await repo.getEvents();

      expect(eventsA.map((e) => e.id), ['teamA_evt']);
    });

    test('watchMatches only emits matches for the active team', () async {
      final repoB = FirestoreRepository(fake, teamId: 'teamB');
      await repo.createMatch('shared_evt', buildMatch(id: 'm1'));
      await repoB.createMatch('shared_evt', buildMatch(id: 'm2'));

      final emitted = await repo.watchMatches('shared_evt').first;

      expect(emitted.map((m) => m.id), ['m1']);
    });
  });

  group('streams', () {
    test('watchTrash emits only trashed matches', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));
      await repo.createMatch('teamA_evt', buildMatch(id: 'm2', teamNumber: 254));
      await repo.trashMatch('teamA_evt', 'm2');

      final emitted = await repo.watchTrash('teamA_evt').first;

      expect(emitted.map((m) => m.id), ['m2']);
    });
  });
}
