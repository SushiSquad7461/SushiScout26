import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final bool isMasterTeam;
  final int memberCount;
  final DateTime? updatedAt;

  const Team({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.isMasterTeam = false,
    this.memberCount = 0,
    this.updatedAt,
  });

  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      id: doc.id,
      name: data['name'] ?? '',
      inviteCode: data['inviteCode'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMasterTeam: data['isMasterTeam'] ?? false,
      memberCount: data['memberCount'] ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'inviteCode': inviteCode,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isMasterTeam': isMasterTeam,
      'memberCount': memberCount,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  Team copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? createdBy,
    DateTime? createdAt,
    bool? isMasterTeam,
    int? memberCount,
    DateTime? updatedAt,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isMasterTeam: isMasterTeam ?? this.isMasterTeam,
      memberCount: memberCount ?? this.memberCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TeamSettings {
  final String teamId;
  final String? googleSheetId;
  final String? defaultEventCode;
  final Map<String, dynamic>? customFormConfig;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TeamSettings({
    required this.teamId,
    this.googleSheetId,
    this.defaultEventCode,
    this.customFormConfig,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory TeamSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeamSettings(
      teamId: doc.id,
      googleSheetId: data['googleSheetId'],
      defaultEventCode: data['defaultEventCode'],
      customFormConfig: data['customFormConfig'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'googleSheetId': googleSheetId,
      'defaultEventCode': defaultEventCode,
      'customFormConfig': customFormConfig,
      'createdBy': createdBy,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }
}
