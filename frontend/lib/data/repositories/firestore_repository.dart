import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/logger.dart';
import '../models/event.dart';
import '../models/match_report.dart';
import 'scouting_repository.dart';

/// A snapshot of an event's matches plus whether it came from the local cache.
///
/// `isFromCache` is Firestore's own answer to "am I reaching the server?" — it
/// is true when the stream is not live, including on a captive-portal network
/// where the device is associated with wifi but nothing gets through.
class MatchesView {
  final List<MatchReport> matches;
  final bool isFromCache;

  const MatchesView({required this.matches, required this.isFromCache});
}

class FirestoreRepository implements ScoutingRepository {
  final FirebaseFirestore _firestore;
  final String? teamId;
  final Logger _logger = const Logger('FIRESTORE');

  FirestoreRepository(this._firestore, {this.teamId});

  /// Builds a base query on the matches collection, filtered by eventId and
  /// optionally by teamId if one was provided at construction time.
  Query<Map<String, dynamic>> _matchesQuery(String eventId, {required bool isDeleted}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('matches')
        .where('eventId', isEqualTo: eventId)
        .where('isDeleted', isEqualTo: isDeleted);
    if (teamId != null && teamId!.isNotEmpty) {
      query = query.where('teamId', isEqualTo: teamId);
    }
    return query.orderBy('createdAt', descending: true);
  }

  /// Watches matches along with the snapshot metadata needed for connection
  /// status. Uses `includeMetadataChanges` so an online/offline transition
  /// emits even when no document changed.
  Stream<MatchesView> watchMatchesView(String eventId) {
    return _matchesQuery(eventId, isDeleted: false)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => MatchesView(
            matches: snapshot.docs
                .map((doc) => MatchReport.fromFirestore(doc))
                .toList(),
            isFromCache: snapshot.metadata.isFromCache,
          ),
        );
  }

  @override
  Stream<List<MatchReport>> watchMatches(String eventId) {
    return watchMatchesView(eventId).map((view) => view.matches);
  }

  @override
  Stream<List<MatchReport>> watchTrash(String eventId) {
    return _matchesQuery(eventId, isDeleted: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MatchReport.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Future<List<MatchReport>> getMatches(String eventId) async {
    final snapshot = await _matchesQuery(eventId, isDeleted: false).get();
    return snapshot.docs.map((doc) => MatchReport.fromFirestore(doc)).toList();
  }

  Future<List<MatchReport>> getDeletedMatches(String eventId) async {
    final snapshot = await _matchesQuery(eventId, isDeleted: true).get();
    return snapshot.docs.map((doc) => MatchReport.fromFirestore(doc)).toList();
  }

  @override
  Future<void> createMatch(String eventId, MatchReport match, {String? teamIdOverride}) async {
    _logger.d('Writing match to: matches/${match.id}');

    final effectiveTeamId = teamIdOverride ?? teamId;
    final programType = await _getOrCreateEvent(eventId, fallbackProgramType: match.programType, teamId: effectiveTeamId);

    final prepared = _prepareForFirestore(match, eventId, programType, teamId: effectiveTeamId);
    await _firestore
        .collection('matches')
        .doc(match.id)
        .set(_withTeamId(prepared.toFirestore()), SetOptions(merge: true));
  }

  /// Backfill teamId when it isn't already in the payload, so trash/restore
  /// writes that race a hard-delete (the doc no longer exists, so set+merge
  /// becomes a CREATE carrying only {isDeleted: ...}) still satisfy the
  /// matches/{id} create rule's isValidTeamId() check. createMatch and
  /// updateMatch already include teamId via _prepareForFirestore.
  Map<String, dynamic> _withTeamId(Map<String, dynamic> data) {
    final stamped = <String, dynamic>{...data};
    if (!stamped.containsKey('teamId') &&
        teamId != null &&
        teamId!.isNotEmpty) {
      stamped['teamId'] = teamId;
    }
    return stamped;
  }

  /// Prepares a match for Firestore by merging robot_died into gameData
  /// and setting eventId + programType + teamId.
  MatchReport _prepareForFirestore(MatchReport match, String eventId, String programType, {String? teamId}) {
    final gameData = Map<String, dynamic>.from(match.gameData)
      ..['robot_died'] = match.robotDied;
    return match.copyWith(
      gameData: gameData,
      eventId: eventId,
      programType: programType,
      teamId: teamId ?? match.teamId,
    );
  }

  /// Gets the event's programType, creating the event document if needed.
  /// Combines getEvent + ensureEventExists into a single read to avoid double-reads.
  Future<String> _getOrCreateEvent(String eventId, {String fallbackProgramType = 'FRC', String? teamId}) async {
    try {
      final eventDoc = _firestore.collection('events').doc(eventId);
      final docSnapshot = await eventDoc.get();

      if (docSnapshot.exists) {
        return Event.fromFirestore(docSnapshot).programType;
      }

      _logger.i('Auto-creating event $eventId in Firestore');
      final rawCode = (teamId != null && teamId.isNotEmpty && eventId.startsWith('${teamId}_'))
          ? eventId.substring(teamId.length + 1)
          : eventId;
      await eventDoc.set({
        'name': rawCode,
        'programType': fallbackProgramType,
        'tbaKey': rawCode,
        'startDate': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'teamId': teamId ?? '',
        'autoCreated': true,
      }, SetOptions(merge: true));
      return fallbackProgramType;
    } catch (e, stackTrace) {
      _logger.e('Failed to get or create event', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updateMatch(String eventId, MatchReport match, {String? teamIdOverride}) async {
    _logger.d('Updating match at: matches/${match.id}');

    final effectiveTeamId = teamIdOverride ?? teamId;
    final programType = await _getOrCreateEvent(eventId, fallbackProgramType: match.programType, teamId: effectiveTeamId);

    final prepared = _prepareForFirestore(match, eventId, programType, teamId: effectiveTeamId);
    await _firestore
        .collection('matches')
        .doc(match.id)
        .set(_withTeamId(prepared.toFirestore()), SetOptions(merge: true));
  }

  @override
  Future<void> trashMatch(String eventId, String matchId) async {
    _logger.d('Trashing match: $matchId');
    // set+merge so this doesn't throw NOT_FOUND when the matching create
    // op hasn't synced yet (offline queue) or when another client just
    // hard-deleted the doc. The on_match_written trigger keys off
    // isDeleted, so a self-healing re-creation here is acceptable.
    await _firestore
        .collection('matches')
        .doc(matchId)
        .set(_withTeamId({'isDeleted': true}), SetOptions(merge: true));
  }

  @override
  Future<void> restoreMatch(String eventId, String matchId) async {
    await _firestore
        .collection('matches')
        .doc(matchId)
        .set(_withTeamId({'isDeleted': false}), SetOptions(merge: true));
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
    Query<Map<String, dynamic>> query = _firestore.collection('events');
    if (teamId != null && teamId!.isNotEmpty) {
      query = query.where('teamId', isEqualTo: teamId);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
  }
}
