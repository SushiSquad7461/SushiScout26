import 'dart:async';

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

  /// Issues a Firestore write WITHOUT blocking on the server acknowledgement.
  ///
  /// Firestore applies a mutation to its on-disk cache synchronously, so the
  /// data is durable the instant `set`/`delete` is called and local listeners
  /// fire right away. The returned Future only completes when the SERVER acks
  /// the write — which never happens while offline — so `await`-ing it hangs
  /// the UI forever (the scouting form's "Saving…" spinner never stops at a
  /// venue with no connectivity). We fire the write and log any eventual
  /// failure instead. This is the offline-first contract the deleted
  /// SyncManager used to provide with its local queue; without it, collapsing
  /// to Firestore-only would regress offline saves. Verified on-device
  /// (airplane mode) because no mock can reproduce the offline-never-resolves
  /// behaviour — fake_cloud_firestore always resolves writes immediately.
  void _fireWrite(Future<void> write) {
    unawaited(write.catchError((Object e) {
      _logger.w('Deferred Firestore write failed', error: e);
    }));
  }

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
  Future<void> createMatch(String eventId, MatchReport match) async {
    _logger.d('Writing match to: matches/${match.id}');

    final programType = await _getOrCreateEvent(eventId, fallbackProgramType: match.programType, teamId: teamId);

    final prepared = _prepareForFirestore(match, eventId, programType, teamId: teamId);
    _fireWrite(_firestore
        .collection('matches')
        .doc(match.id)
        .set(_withTeamId(prepared.toFirestore()), SetOptions(merge: true)));
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
      // This read is the one remaining place a write path can block on the
      // network. In clean airplane mode a default get() falls back to cache
      // instantly, and the event doc is almost always already cached (the
      // scout loaded its matches), so a cache hit needs no network even on a
      // captive-portal/black-hole network. The residual hang is only the
      // narrow cache-miss-on-portal case (first match to a brand-new event,
      // never loaded online, on a network that swallows the socket). Left as a
      // known limitation — see the roadmap §8 captive-portal note.
      final docSnapshot = await eventDoc.get();

      if (docSnapshot.exists) {
        return Event.fromFirestore(docSnapshot).programType;
      }

      _logger.i('Auto-creating event $eventId in Firestore');
      final rawCode = (teamId != null && teamId.isNotEmpty && eventId.startsWith('${teamId}_'))
          ? eventId.substring(teamId.length + 1)
          : eventId;
      _fireWrite(eventDoc.set({
        'name': rawCode,
        'programType': fallbackProgramType,
        'tbaKey': rawCode,
        'startDate': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'teamId': teamId ?? '',
        'autoCreated': true,
      }, SetOptions(merge: true)));
      return fallbackProgramType;
    } catch (e, stackTrace) {
      _logger.e('Failed to get or create event', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updateMatch(String eventId, MatchReport match) async {
    _logger.d('Updating match at: matches/${match.id}');

    final programType = await _getOrCreateEvent(eventId, fallbackProgramType: match.programType, teamId: teamId);

    final prepared = _prepareForFirestore(match, eventId, programType, teamId: teamId);
    _fireWrite(_firestore
        .collection('matches')
        .doc(match.id)
        .set(_withTeamId(prepared.toFirestore()), SetOptions(merge: true)));
  }

  @override
  Future<void> trashMatch(String eventId, String matchId) async {
    _logger.d('Trashing match: $matchId');
    // set+merge so this doesn't throw NOT_FOUND when the matching create
    // op hasn't synced yet (offline queue) or when another client just
    // hard-deleted the doc. The on_match_written trigger keys off
    // isDeleted, so a self-healing re-creation here is acceptable.
    _fireWrite(_firestore
        .collection('matches')
        .doc(matchId)
        .set(_withTeamId({'isDeleted': true}), SetOptions(merge: true)));
  }

  @override
  Future<void> restoreMatch(String eventId, String matchId) async {
    _fireWrite(_firestore
        .collection('matches')
        .doc(matchId)
        .set(_withTeamId({'isDeleted': false}), SetOptions(merge: true)));
  }

  @override
  Future<void> deleteMatch(String eventId, String matchId) async {
    _fireWrite(_firestore
        .collection('matches')
        .doc(matchId)
        .delete());
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
