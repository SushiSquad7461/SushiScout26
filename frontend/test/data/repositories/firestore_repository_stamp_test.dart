import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/models/match_report.dart';

import 'firestore_repository_stamp_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFirestore>(),
  MockSpec<CollectionReference<Map<String, dynamic>>>(),
  MockSpec<DocumentReference<Map<String, dynamic>>>(),
  MockSpec<DocumentSnapshot<Map<String, dynamic>>>(),
])
void main() {
  const teamId = 'team-42';
  const eventId = 'event-1';

  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockMatchesCollection;
  late MockCollectionReference mockEventsCollection;
  late MockDocumentReference mockMatchDocRef;
  late MockDocumentReference mockEventDocRef;
  late MockDocumentSnapshot mockEventSnapshot;
  late FirestoreRepository repo;

  final match = MatchReport(
    id: 'match-1',
    matchId: 'qm1_4198',
    matchNumber: 1,
    teamNumber: 4198,
    alliance: 'Red',
    scouterName: 'Scout',
    gameData: const {},
    createdAt: DateTime(2026, 1, 1),
    eventId: eventId,
    teamId: teamId,
  );

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockMatchesCollection = MockCollectionReference();
    mockEventsCollection = MockCollectionReference();
    mockMatchDocRef = MockDocumentReference();
    mockEventDocRef = MockDocumentReference();
    mockEventSnapshot = MockDocumentSnapshot();

    when(mockFirestore.collection('matches')).thenReturn(mockMatchesCollection);
    when(mockFirestore.collection('events')).thenReturn(mockEventsCollection);
    when(mockMatchesCollection.doc(any)).thenReturn(mockMatchDocRef);
    when(mockEventsCollection.doc(any)).thenReturn(mockEventDocRef);
    when(mockEventDocRef.get()).thenAnswer((_) async => mockEventSnapshot);
    when(mockEventSnapshot.exists).thenReturn(true);
    when(mockEventSnapshot.data()).thenReturn({'programType': 'FRC'});
    when(mockMatchDocRef.set(any, any)).thenAnswer((_) async {});
    when(mockEventDocRef.set(any, any)).thenAnswer((_) async {});

    repo = FirestoreRepository(mockFirestore, teamId: teamId);
  });

  group('write payloads', () {
    test('createMatch does not write lastSyncSource', () async {
      await repo.createMatch(eventId, match);

      final captured = verify(mockMatchDocRef.set(captureAny, any)).captured.single
          as Map<String, dynamic>;
      expect(captured.containsKey('lastSyncSource'), isFalse);
    });

    test('updateMatch does not write lastSyncSource', () async {
      await repo.updateMatch(eventId, match);

      final captured = verify(mockMatchDocRef.set(captureAny, any)).captured.single
          as Map<String, dynamic>;
      expect(captured.containsKey('lastSyncSource'), isFalse);
    });

    test('trashMatch does not write lastSyncSource', () async {
      await repo.trashMatch(eventId, match.id);

      final captured = verify(mockMatchDocRef.set(captureAny, any)).captured.single
          as Map<String, dynamic>;
      expect(captured.containsKey('lastSyncSource'), isFalse);
    });

    test('restoreMatch does not write lastSyncSource', () async {
      await repo.restoreMatch(eventId, match.id);

      final captured = verify(mockMatchDocRef.set(captureAny, any)).captured.single
          as Map<String, dynamic>;
      expect(captured.containsKey('lastSyncSource'), isFalse);
    });

    test('trashMatch still backfills teamId so the create rule passes', () async {
      // set+merge degrades to a CREATE when the doc was hard-deleted by
      // another client; the matches/{id} create rule requires teamId.
      await repo.trashMatch(eventId, 'never-created');

      final captured = verify(mockMatchDocRef.set(captureAny, any)).captured.single
          as Map<String, dynamic>;
      expect(captured['teamId'], equals(teamId));
    });

    test('restoreMatch still backfills teamId', () async {
      await repo.restoreMatch(eventId, 'never-created');

      final captured = verify(mockMatchDocRef.set(captureAny, any)).captured.single
          as Map<String, dynamic>;
      expect(captured['teamId'], equals(teamId));
    });
  });
}
