import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/auth/auth_exceptions.dart';
import '../models/team.dart';

class TeamRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  static final Random _random = Random();

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
    String? googleSheetId,
    String? defaultEventCode,
  }) async {
    final ref = _firestore.collection('teamSettings').doc(teamId);

    // Only include fields the caller actually provided. Previously this
    // wrote `null` for any unspecified field, silently overwriting the
    // existing value — e.g. updating only googleSheetId would clear
    // defaultEventCode.
    final data = <String, Object?>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (googleSheetId != null) data['googleSheetId'] = googleSheetId;
    if (defaultEventCode != null) data['defaultEventCode'] = defaultEventCode;

    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> regenerateInviteCode({
    required String teamId,
    required String requestingUserId,
  }) async {
    final newCode = _generateInviteCode();
    
    await _firestore.runTransaction((transaction) async {
      final teamRef = _firestore.collection('teams').doc(teamId);
      final teamDoc = await transaction.get(teamRef);
      final team = Team.fromFirestore(teamDoc);
      
      if (team.createdBy != requestingUserId) {
        throw const AuthException('Only team creator can regenerate invite code');
      }
      
      transaction.update(teamRef, {
        'inviteCode': newCode,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }
}
