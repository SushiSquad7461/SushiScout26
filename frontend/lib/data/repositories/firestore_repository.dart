import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/match_report.dart';
import 'scouting_repository.dart';

class FirestoreRepository implements ScoutingRepository {
  final FirebaseFirestore _firestore;

  FirestoreRepository(this._firestore);

  @override
  Stream<List<MatchReport>> watchMatches(String eventId) {
    return _firestore
        .collection('matches')
        .where('eventId', isEqualTo: eventId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MatchReport.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Stream<List<MatchReport>> watchTrash(String eventId) {
    return _firestore
        .collection('matches')
        .where('eventId', isEqualTo: eventId)
        .where('isDeleted', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MatchReport.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Future<List<MatchReport>> getMatches(String eventId) async {
    final snapshot = await _firestore
        .collection('matches')
        .where('eventId', isEqualTo: eventId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => MatchReport.fromFirestore(doc)).toList();
  }

  @override
  Future<void> createMatch(String eventId, MatchReport match) async {
    debugPrint('Writing match to: matches/${match.id}');

    await _ensureEventExists(eventId);

    final matchWithEventId = MatchReport(
      id: match.id,
      matchId: match.matchId,
      matchNumber: match.matchNumber,
      teamNumber: match.teamNumber,
      alliance: match.alliance,
      scouterName: match.scouterName,
      gameData: match.gameData,
      robotDied: match.robotDied,
      comments: match.comments,
      images: match.images,
      createdAt: match.createdAt,
      isSynced: match.isSynced,
      isDeleted: match.isDeleted,
      eventId: eventId,
      teamId: match.teamId,
    );

    await _firestore
        .collection('matches')
        .doc(match.id)
        .set(matchWithEventId.toFirestore(), SetOptions(merge: true));
  }

  /// Ensures the event document exists in Firestore.
  /// If it doesn't exist, creates it with default data from local or basic info.
  Future<void> _ensureEventExists(String eventId) async {
    try {
      final eventDoc = _firestore.collection('events').doc(eventId);
      debugPrint('Checking if event $eventId exists in Firestore...');
      final docSnapshot = await eventDoc.get();

      if (!docSnapshot.exists) {
        debugPrint('Event $eventId does not exist in Firestore, creating it...');
        // Create a basic event document - the actual event data
        // should be synced separately or created via an event management UI
        await eventDoc.set({
          'name': eventId,
          'programType': 'FRC',
          'tbaKey': eventId,
          'startDate': Timestamp.fromDate(DateTime.now()),
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'autoCreated': true,
        }, SetOptions(merge: true));
        debugPrint('Event $eventId created successfully in Firestore');
      } else {
        debugPrint('Event $eventId already exists in Firestore');
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR: Failed to ensure event exists: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> updateMatch(String eventId, MatchReport match) async {
    debugPrint('Updating match at: matches/${match.id}');
    final matchWithEventId = MatchReport(
      id: match.id,
      matchId: match.matchId,
      matchNumber: match.matchNumber,
      teamNumber: match.teamNumber,
      alliance: match.alliance,
      scouterName: match.scouterName,
      gameData: match.gameData,
      robotDied: match.robotDied,
      comments: match.comments,
      images: match.images,
      createdAt: match.createdAt,
      isSynced: match.isSynced,
      isDeleted: match.isDeleted,
      eventId: eventId,
      teamId: match.teamId,
    );
    await _firestore
        .collection('matches')
        .doc(match.id)
        .set(matchWithEventId.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<void> trashMatch(String eventId, String matchId) async {
    debugPrint('Trashing match at: matches/$matchId');
    await _firestore
        .collection('matches')
        .doc(matchId)
        .update({'isDeleted': true});
  }

  @override
  Future<void> restoreMatch(String eventId, String matchId) async {
    await _firestore
        .collection('matches')
        .doc(matchId)
        .update({'isDeleted': false});
  }

  @override
  Future<void> deleteMatch(String eventId, String matchId) async {
    await _firestore
        .collection('matches')
        .doc(matchId)
        .delete();
  }

  @override
  Future<Event?> getEvent(String eventId) async {
    final doc = await _firestore.collection('events').doc(eventId).get();
    if (doc.exists) {
      return Event.fromFirestore(doc);
    }
    return null;
  }

  @override
  Future<List<Event>> getEvents() async {
    final snapshot = await _firestore.collection('events').get();
    return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
  }
}
