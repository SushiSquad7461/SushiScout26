import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/auth/auth_exceptions.dart';
import '../models/team.dart';

class TeamRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  TeamRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  /// Creates a team via the server-side `create_team` callable. Rules
  /// forbid clients from writing team/membership docs directly, and the
  /// callable is what sets the `teams` custom auth claim.
  Future<Team> createTeam({
    required String name,
    required String createdBy,
    bool isMasterTeam = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('create_team');
      final result = await callable.call<dynamic>({
        'name': name,
        'isMasterTeam': isMasterTeam,
      });
      return _teamFromCallable(result.data);
    } on FirebaseFunctionsException catch (e) {
      _mapFunctionsError(e);
    }
  }

  /// Joins a team via the server-side `join_team` callable.
  Future<Team?> joinTeamByCode({
    required String inviteCode,
    required String userId,
  }) async {
    try {
      final callable = _functions.httpsCallable('join_team');
      final result = await callable.call<dynamic>({'inviteCode': inviteCode});
      return _teamFromCallable(result.data);
    } on FirebaseFunctionsException catch (e) {
      _mapFunctionsError(e);
    }
  }

  /// Leaves a team via the server-side `leave_team` callable.
  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    try {
      final callable = _functions.httpsCallable('leave_team');
      await callable.call<dynamic>({'teamId': teamId});
    } on FirebaseFunctionsException catch (e) {
      _mapFunctionsError(e);
    }
  }

  Team _teamFromCallable(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    return Team(
      id: map['teamId'] as String,
      name: (map['name'] as String?) ?? '',
      inviteCode: (map['inviteCode'] as String?) ?? '',
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: DateTime.now(),
      isMasterTeam: (map['isMasterTeam'] as bool?) ?? false,
      memberCount: (map['memberCount'] as int?) ?? 1,
    );
  }

  /// Maps a callable error to the AuthException the UI already handles.
  Never _mapFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'not-found':
        throw const AuthExceptionInvalidInviteCode();
      case 'already-exists':
        throw const AuthExceptionAlreadyInTeam();
      case 'failed-precondition':
        throw const AuthExceptionCannotLeaveTeam();
      default:
        throw AuthException(e.message ?? 'Team operation failed');
    }
  }

  Future<Team?> getTeam(String teamId) async {
    final doc = await _firestore.collection('teams').doc(teamId).get();
    if (doc.exists) {
      return Team.fromFirestore(doc);
    }
    return null;
  }

  Future<List<Team>> getUserTeams(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();
    if (userData == null || userData['teamMemberships'] == null) {
      return [];
    }
    
    final teamIds = (userData['teamMemberships'] as Map).keys.toList();
    if (teamIds.isEmpty) return [];
    
    final teams = <Team>[];
    for (final teamId in teamIds) {
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      if (teamDoc.exists) {
        teams.add(Team.fromFirestore(teamDoc));
      }
    }
    return teams;
  }

  Future<TeamSettings?> getTeamSettings(String teamId) async {
    final doc = await _firestore.collection('teamSettings').doc(teamId).get();
    if (doc.exists) {
      return TeamSettings.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateTeamSettings({
    required String teamId,
    String? defaultEventCode,
  }) async {
    final ref = _firestore.collection('teamSettings').doc(teamId);

    // Only include fields the caller actually provided. Previously this
    // wrote `null` for any unspecified field, silently overwriting the
    // existing value.
    final data = <String, Object?>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (defaultEventCode != null) data['defaultEventCode'] = defaultEventCode;

    await ref.set(data, SetOptions(merge: true));
  }

  /// Point the team's Sheets export at [sheetId] (a full Sheets URL or a
  /// bare id). Server-side only: rules deny client writes to googleSheetId.
  ///
  /// Errors are intentionally left unmapped: `set_team_sheet`'s
  /// failed-precondition message names the exact service-account address
  /// the user must share the sheet with, and callers surface `e.toString()`
  /// verbatim. Routing this through `_mapFunctionsError` (written for the
  /// team create/join/leave flows) would replace that message with an
  /// unrelated generic one.
  Future<String> setTeamSheet({
    required String teamId,
    required String sheetId,
  }) async {
    final callable = _functions.httpsCallable('set_team_sheet');
    final result = await callable.call<Map<String, dynamic>>({
      'teamId': teamId,
      'sheetId': sheetId,
    });
    return result.data['googleSheetId'] as String;
  }

  /// Triggers a one-time backfill of an event's existing matches into the
  /// team's connected sheet via the `backfill_event_to_sheets` callable.
  Future<Map<String, dynamic>> backfillEventToSheets({
    required String eventId,
  }) async {
    final callable = _functions.httpsCallable('backfill_event_to_sheets');
    final result =
        await callable.call<Map<String, dynamic>>({'eventId': eventId});
    return result.data;
  }

  /// Rotates the team's invite code via the server-side
  /// `regenerate_invite_code` callable, and returns the new code.
  ///
  /// This was a direct client transaction on `teams/{teamId}` whose only
  /// authorization was a client-side `createdBy == requestingUserId` check —
  /// which the rules did not back, so any member could both bypass it and
  /// rewrite `createdBy` itself. The code was also generated with dart:math
  /// `Random()` (not a CSPRNG) over 6 characters, with no uniqueness check
  /// against other teams. All three are now the server's job.
  Future<String> regenerateInviteCode({
    required String teamId,
    required String requestingUserId,
  }) async {
    try {
      final callable = _functions.httpsCallable('regenerate_invite_code');
      final result =
          await callable.call<Map<String, dynamic>>({'teamId': teamId});
      return result.data['inviteCode'] as String;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AuthException(
            'Only a team admin can regenerate the invite code');
      }
      _mapFunctionsError(e);
    }
  }
}
