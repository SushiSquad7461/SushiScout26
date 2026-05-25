import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/auth/auth_exceptions.dart';
import '../models/team.dart';

class TeamRepository {
  final FirebaseFirestore _firestore;
  static final Random _random = Random();

  TeamRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Team> createTeam({
    required String name,
    required String createdBy,
    bool isMasterTeam = false,
  }) async {
    final inviteCode = _generateInviteCode();
    
    final teamRef = _firestore.collection('teams').doc();
    final team = Team(
      id: teamRef.id,
      name: name,
      inviteCode: inviteCode,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      isMasterTeam: isMasterTeam,
      memberCount: 1,
    );

    await _firestore.runTransaction((transaction) async {
      final existing = await _firestore
          .collection('teams')
          .where('inviteCode', isEqualTo: inviteCode)
          .get();
      
      if (existing.docs.isNotEmpty) {
        throw const AuthException('Invite code collision, please try again');
      }
      
      transaction.set(teamRef, team.toFirestore());

      // Write to members subcollection so isTeamMember() rule works
      final memberRef = teamRef.collection('members').doc(createdBy);
      transaction.set(memberRef, {
        'role': 'admin',
        'joinedAt': Timestamp.fromDate(DateTime.now()),
      });

      // set+merge instead of update so first-time team creation works
      // even if the user doc hasn't been bootstrapped yet.
      final userRef = _firestore.collection('users').doc(createdBy);
      transaction.set(userRef, {
        'currentTeamId': teamRef.id,
        'teamMemberships': {teamRef.id: 'admin'},
      }, SetOptions(merge: true));
    });

    return team;
  }

  Future<Team?> joinTeamByCode({
    required String inviteCode,
    required String userId,
  }) async {
    final teamQuery = await _firestore
        .collection('teams')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .get();

    if (teamQuery.docs.isEmpty) {
      throw const AuthExceptionInvalidInviteCode();
    }

    final teamDoc = teamQuery.docs.first;
    final team = Team.fromFirestore(teamDoc);

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();
    if (userData != null && userData['teamMemberships'] != null) {
      final memberships = Map<String, String>.from(userData['teamMemberships']);
      if (memberships.containsKey(team.id)) {
        throw const AuthExceptionAlreadyInTeam();
      }
    }

    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(userId);
      // set+merge so we don't fail if the user doc is missing.
      transaction.set(userRef, {
        'currentTeamId': team.id,
        'teamMemberships': {
          ...?userData?['teamMemberships'],
          team.id: 'member',
        },
      }, SetOptions(merge: true));

      final teamRef = _firestore.collection('teams').doc(team.id);
      transaction.update(teamRef, {
        'memberCount': FieldValue.increment(1),
      });

      // Write to members subcollection so isTeamMember() rule works
      final memberRef = teamRef.collection('members').doc(userId);
      transaction.set(memberRef, {
        'role': 'member',
        'joinedAt': Timestamp.fromDate(DateTime.now()),
      });
    });

    return team;
  }

  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    final teamDoc = await _firestore.collection('teams').doc(teamId).get();
    final team = Team.fromFirestore(teamDoc);
    
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();
    
    if (userData == null) return;
    
    final memberships = Map<String, String>.from(userData['teamMemberships'] ?? {});
    final currentRole = memberships[teamId];
    
    if (currentRole == 'admin' && team.memberCount == 1) {
      throw const AuthExceptionCannotLeaveTeam();
    }

    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(userId);
      memberships.remove(teamId);
      
      String? newCurrentTeamId = userData['currentTeamId'];
      if (newCurrentTeamId == teamId) {
        newCurrentTeamId = memberships.keys.firstOrNull;
      }
      
      transaction.update(userRef, {
        'currentTeamId': newCurrentTeamId,
        'teamMemberships': memberships,
      });

      final teamRef = _firestore.collection('teams').doc(teamId);
      transaction.update(teamRef, {
        'memberCount': FieldValue.increment(-1),
      });

      // Remove from members subcollection
      final memberRef = teamRef.collection('members').doc(userId);
      transaction.delete(memberRef);
    });
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
