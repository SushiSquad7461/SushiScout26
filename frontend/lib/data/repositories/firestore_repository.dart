import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/logger.dart';
import '../models/event.dart';
import '../models/match_report.dart';
import 'scouting_repository.dart';

class FirestoreRepository implements ScoutingRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger = const Logger('FIRESTORE');

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
    _logger.d('Writing match to: matches/${match.id}');

    final programType = await _getOrCreateEvent(eventId, fallbackProgramType: match.programType);

    final prepared = _prepareForFirestore(match, eventId, programType);
    await _firestore
        .collection('matches')
        .doc(match.id)
        .set(prepared.toFirestore(), SetOptions(merge: true));
  }

  /// Prepares a match for Firestore by merging robot_died into gameData
  /// and setting eventId + programType.
  MatchReport _prepareForFirestore(MatchReport match, String eventId, String programType) {
    final gameData = Map<String, dynamic>.from(match.gameData)
      ..['robot_died'] = match.robotDied;
    return match.copyWith(
      gameData: gameData,
      eventId: eventId,
      programType: programType,
    );
  }

  /// Gets the event's programType, creating the event document if needed.
  /// Combines getEvent + ensureEventExists into a single read to avoid double-reads.
  Future<String> _getOrCreateEvent(String eventId, {String fallbackProgramType = 'FRC'}) async {
    try {
      final eventDoc = _firestore.collection('events').doc(eventId);
      final docSnapshot = await eventDoc.get();

      if (docSnapshot.exists) {
        return Event.fromFirestore(docSnapshot).programType;
      }

      _logger.i('Auto-creating event $eventId in Firestore');
      await eventDoc.set({
        'name': eventId,
        'programType': fallbackProgramType,
        'tbaKey': eventId,
        'startDate': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'autoCreated': true,
      }, SetOptions(merge: true));
      return fallbackProgramType;
    } catch (e, stackTrace) {
      _logger.e('Failed to get or create event', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updateMatch(String eventId, MatchReport match) async {
    _logger.d('Updating match at: matches/${match.id}');

    final programType = await _getOrCreateEvent(eventId, fallbackProgramType: match.programType);

    final prepared = _prepareForFirestore(match, eventId, programType);
    await _firestore
        .collection('matches')
        .doc(match.id)
        .set(prepared.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<void> trashMatch(String eventId, String matchId) async {
    _logger.d('Trashing match: $matchId');
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
