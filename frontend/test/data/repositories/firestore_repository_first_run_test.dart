import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';

MatchReport buildMatch({required String id, String programType = 'FRC'}) {
  return MatchReport(
    id: id,
    matchId: 'qm1_4198',
    matchNumber: 1,
    teamNumber: 4198,
    alliance: 'Red',
    scouterName: 'scout',
    gameData: const {'auto_fuel': 3},
    createdAt: DateTime(2026, 7, 22),
    programType: programType,
  );
}

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(fake, teamId: 'teamA');
  });

  group('reads against a completely empty database', () {
    test('getMatches returns an empty list rather than throwing', () async {
      expect(await repo.getMatches('teamA_evt'), isEmpty);
    });

    test('getDeletedMatches returns an empty list rather than throwing', () async {
      expect(await repo.getDeletedMatches('teamA_evt'), isEmpty);
    });

    test('getEvents returns an empty list rather than throwing', () async {
      expect(await repo.getEvents(), isEmpty);
    });

    test('getEvent returns null for a missing event', () async {
      expect(await repo.getEvent('teamA_evt'), isNull);
    });

    test('watchMatches emits an empty list rather than erroring', () async {
      expect(await repo.watchMatches('teamA_evt').first, isEmpty);
    });
  });

  group('the very first match written to a new event', () {
    test('auto-creates the missing event document', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final event = await fake.collection('events').doc('teamA_evt').get();
      expect(event.exists, isTrue);
      expect(event.data()!['autoCreated'], isTrue);
    });

    test('strips the team prefix when deriving the event name and tbaKey', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final event = await fake.collection('events').doc('teamA_evt').get();
      expect(event.data()!['name'], 'evt');
      expect(event.data()!['tbaKey'], 'evt');
    });

    test('stamps the owning team onto the auto-created event', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final event = await fake.collection('events').doc('teamA_evt').get();
      expect(event.data()!['teamId'], 'teamA');
    });

    test('adopts the match programType when auto-creating the event', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1', programType: 'FTC'));

      final event = await fake.collection('events').doc('teamA_evt').get();
      expect(event.data()!['programType'], 'FTC');
    });

    test('a pre-existing event keeps its programType instead of being overwritten', () async {
      await fake.collection('events').doc('teamA_evt').set({
        'name': 'evt',
        'programType': 'FTC',
        'tbaKey': 'evt',
        'teamId': 'teamA',
      });

      await repo.createMatch('teamA_evt', buildMatch(id: 'm1', programType: 'FRC'));

      final matches = await repo.getMatches('teamA_evt');
      expect(matches.single.programType, 'FTC');
    });
  });

  group('writes that race a missing document', () {
    test('trashMatch on a match that does not exist still stamps teamId', () async {
      await repo.trashMatch('teamA_evt', 'ghost');

      final doc = await fake.collection('matches').doc('ghost').get();
      expect(doc.data()!['teamId'], 'teamA');
      expect(doc.data()!['isDeleted'], isTrue);
    });

    test('restoreMatch on a match that does not exist still stamps teamId', () async {
      await repo.restoreMatch('teamA_evt', 'ghost');

      final doc = await fake.collection('matches').doc('ghost').get();
      expect(doc.data()!['teamId'], 'teamA');
      expect(doc.data()!['isDeleted'], isFalse);
    });
  });
}
