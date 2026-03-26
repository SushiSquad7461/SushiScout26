import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? currentTeamId;
  final Map<String, String> teamMemberships;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.currentTeamId,
    this.teamMemberships = const {},
    required this.createdAt,
    this.lastLoginAt,
  });

  bool get isInTeam => currentTeamId != null;
  bool isAdminOf(String teamId) => teamMemberships[teamId] == 'admin';
  bool isMemberOf(String teamId) => teamMemberships.containsKey(teamId);

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoURL'],
      currentTeamId: data['currentTeamId'],
      teamMemberships: Map<String, String>.from(data['teamMemberships'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoUrl,
      'currentTeamId': currentTeamId,
      'teamMemberships': teamMemberships,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? currentTeamId,
    Map<String, String>? teamMemberships,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      currentTeamId: currentTeamId ?? this.currentTeamId,
      teamMemberships: teamMemberships ?? this.teamMemberships,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
