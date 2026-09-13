import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/models/match_report.dart';

// Reuse the mocks generated for the stamp test — same mock surface
// (FirebaseFirestore / CollectionReference / DocumentReference / DocumentSnapshot).
import 'firestore_repository_stamp_test.mocks.dart';

/// Regression guard for the "[cloud_firestore/unavailable] Failed to get
/// document because the client is offline" save failure.
///
/// `_getOrCreateEvent` reads the event doc to resolve its canonical
/// `programType` (and auto-create the doc for a brand-new event). That read
/// can miss the local cache even when the *match* being edited is already
/// cached — the matches stream, not the events collection, is what usually
/// populates a device's cache, so a device that only ever saw this match via
/// the live matches subscription may never have cached its parent event.
/// Offline, that cache miss makes Firestore throw `unavailable`.
///
/// Per the app's write-path contract (writes are always durable/offline-safe
/// — see the sibling firestore_repository_offline_write_test.dart), an
/// ancillary consistency read must never abort the write itself: this read
/// exists only to double-check a `programType` the caller already supplies.
void main() {
  const teamId = 'team-42';
  const eventId = 'event-1';

  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockMatchesCollection;
  late MockCollectionReference mockEventsCollection;
  late MockDocumentReference mockMatchDocRef;
  late MockDocumentReference mockEventDocRef;
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
    programType: 'FRC',
  );

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockMatchesCollection = MockCollectionReference();
    mockEventsCollection = MockCollectionReference();
    mockMatchDocRef = MockDocumentReference();
    mockEventDocRef = MockDocumentReference();

    when(mockFirestore.collection('matches')).thenReturn(mockMatchesCollection);
    when(mockFirestore.collection('events')).thenReturn(mockEventsCollection);
    when(mockMatchesCollection.doc(any)).thenReturn(mockMatchDocRef);
    when(mockEventsCollection.doc(any)).thenReturn(mockEventDocRef);

    // The device never cached this event doc and is offline: exactly what
    // Firestore throws in that state.
    when(mockEventDocRef.get()).thenAnswer(
      (_) async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Failed to get document because the client is offline.',
      ),
    );

    when(mockMatchDocRef.set(any, any)).thenAnswer((_) async {});

    repo = FirestoreRepository(mockFirestore, teamId: teamId);
  });

  group('event-doc read unavailable while offline', () {
    test(
      "updateMatch still saves, falling back to the match's own programType",
      () async {
        await repo.updateMatch(eventId, match);

        verify(mockMatchDocRef.set(any, any)).called(1);
      },
    );

    test(
      "createMatch still saves, falling back to the match's own programType",
      () async {
        await repo.createMatch(eventId, match);

        verify(mockMatchDocRef.set(any, any)).called(1);
      },
    );

    test(
      'does not attempt to auto-create the event doc when its existence is unknown',
      () async {
        await repo.updateMatch(eventId, match);

        verifyNever(mockEventDocRef.set(any, any));
      },
    );
  });
}
