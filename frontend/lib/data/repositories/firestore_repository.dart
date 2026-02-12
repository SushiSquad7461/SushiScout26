import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/match_report.dart';
import 'scouting_repository.dart';

class FirestoreRepository implements ScoutingRepository {
  final FirebaseFirestore _firestore;

  FirestoreRepository(this._firestore);

  @override
  @override
  Stream<List<MatchReport>> watchMatches(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('matches')
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
        .collection('events')
        .doc(eventId)
        .collection('matches')
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
        .collection('events')
        .doc(eventId)
        .collection('matches')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => MatchReport.fromFirestore(doc)).toList();
  }

  @override
  Future<void> createMatch(String eventId, MatchReport match) async {
    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('matches')
        .add(match.toFirestore());
  }

  @override
  Future<void> trashMatch(String eventId, String matchId) async {
    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('matches')
        .doc(matchId)
        .update({'isDeleted': true});
  }

  @override
  Future<void> restoreMatch(String eventId, String matchId) async {
    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('matches')
        .doc(matchId)
        .update({'isDeleted': false});
  }

  @override
  Future<void> deleteMatch(String eventId, String matchId) async {
    await _firestore
        .collection('events')
        .doc(eventId)
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
