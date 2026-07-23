import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/models/match_report.dart';

// Reuse the mocks generated for the stamp test — same mock surface
// (FirebaseFirestore / CollectionReference / DocumentReference / DocumentSnapshot).
import 'firestore_repository_stamp_test.mocks.dart';

/// Regression guard for the offline-save hang.
///
/// Firestore's `set()`/`delete()` Future only resolves when the SERVER
/// acknowledges the write. Offline, that ack never arrives. The mutating repo
/// methods must therefore NOT `await` it — they issue the write fire-and-forget
/// (`_fireWrite`), relying on Firestore persisting to its on-disk cache
/// synchronously. If someone reintroduces an `await` on the write Future,
/// offline saves freeze the scouting form's "Saving…" spinner forever.
///
/// `fake_cloud_firestore` cannot catch this: it always resolves writes
/// immediately (i.e. it is always "online"). So we drive the repository with a
/// mockito mock whose `set()` returns a Completer that is never completed, and
/// assert the call still returns promptly.
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

  // The write Future that Firestore hands back from set(). It is NEVER
  // completed here — reproducing an offline write whose server ack never lands.
  late Completer<void> neverAcked;

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
    neverAcked = Completer<void>();

    when(mockFirestore.collection('matches')).thenReturn(mockMatchesCollection);
    when(mockFirestore.collection('events')).thenReturn(mockEventsCollection);
    when(mockMatchesCollection.doc(any)).thenReturn(mockMatchDocRef);
    when(mockEventsCollection.doc(any)).thenReturn(mockEventDocRef);

    // The event doc is already cached (the scout loaded its matches before
    // going offline), so this read resolves instantly even offline — the
    // normal cache-hit path. Only the write ack is what stalls offline.
    when(mockEventDocRef.get()).thenAnswer((_) async => mockEventSnapshot);
    when(mockEventSnapshot.exists).thenReturn(true);
    when(mockEventSnapshot.data()).thenReturn({'programType': 'FRC'});

    // The offline condition: the write is applied to local cache but the
    // server ack never arrives. If the repo awaits this, the call hangs.
    when(mockMatchDocRef.set(any, any)).thenAnswer((_) => neverAcked.future);
    when(mockEventDocRef.set(any, any)).thenAnswer((_) => neverAcked.future);

    repo = FirestoreRepository(mockFirestore, teamId: teamId);
  });

  group('offline writes never block the caller', () {
    test('createMatch returns promptly even when the server never acks', () async {
      await repo.createMatch(eventId, match).timeout(
            const Duration(seconds: 2),
            onTimeout: () => fail(
              'createMatch hung on the server ack — the non-blocking _fireWrite '
              'contract regressed; offline saves would freeze the form.',
            ),
          );

      // The write was still issued (durable to the on-disk cache in the real
      // SDK), it just was not awaited.
      verify(mockMatchDocRef.set(any, any)).called(1);
      expect(neverAcked.isCompleted, isFalse,
          reason: 'the write Future should remain unresolved (still offline)');
    });

    test('updateMatch returns promptly even when the server never acks', () async {
      await repo.updateMatch(eventId, match).timeout(
            const Duration(seconds: 2),
            onTimeout: () => fail(
              'updateMatch hung on the server ack — non-blocking write regressed.',
            ),
          );

      verify(mockMatchDocRef.set(any, any)).called(1);
      expect(neverAcked.isCompleted, isFalse);
    });

    test('trashMatch returns promptly even when the server never acks', () async {
      await repo.trashMatch(eventId, match.id).timeout(
            const Duration(seconds: 2),
            onTimeout: () => fail('trashMatch hung on the server ack.'),
          );

      verify(mockMatchDocRef.set(any, any)).called(1);
    });
  });
}
