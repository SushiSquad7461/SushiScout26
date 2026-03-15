import 'package:cloud_firestore/cloud_firestore.dart';

class MatchReport {
  final String id;
  final String matchId; // e.g. "qm1_4198"
  final int matchNumber;
  final int teamNumber;
  final String alliance; // 'Red' or 'Blue'
  final String scouterName;
  final Map<String, dynamic> gameData; // Includes robot_died, auto_fuel, teleop_fuel, etc.
  final String comments;
  final DateTime createdAt;
  final bool isSynced;
  final bool isDeleted;
  final String eventId;
  final String teamId;
  final String programType; // 'FRC' or 'FTC'

  bool get robotDied => gameData['robot_died'] ?? false;
  bool get trenchTraverse => gameData['trench_traverse'] ?? false;
  bool get bumpTraverse => gameData['bump_traverse'] ?? false;
  bool get shootingRangeClose => gameData['shooting_range_close'] ?? false;
  bool get shootingRangeMid => gameData['shooting_range_mid'] ?? false;
  bool get shootingRangeFar => gameData['shooting_range_far'] ?? false;

  MatchReport({
    required this.id,
    required this.matchId,
    required this.matchNumber,
    required this.teamNumber,
    required this.alliance,
    required this.scouterName,
    required this.gameData,
    this.comments = '',
    required this.createdAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.eventId = '',
    this.teamId = '',
    this.programType = 'FRC',
  });

  factory MatchReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final gameData = data['gameData'] as Map<String, dynamic>? ?? {};
    return MatchReport(
      id: doc.id,
      matchId: data['matchId'] ?? '',
      matchNumber: data['matchNumber'] ?? 0,
      teamNumber: data['teamNumber'] ?? 0,
      alliance: data['alliance'] ?? 'Red',
      scouterName: data['scouterName'] ?? '',
      gameData: gameData,
      comments: data['comments'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSynced: !doc.metadata.hasPendingWrites,
      isDeleted: data['isDeleted'] ?? false,
      eventId: data['eventId'] ?? '',
      teamId: data['teamId'] ?? '',
      programType: data['programType'] ?? 'FRC',
    );
  }

  factory MatchReport.fromJson(Map<String, dynamic> json) {
    final gameData = json['gameData'] as Map<String, dynamic>? ?? {};
    return MatchReport(
      id: json['id'] ?? '',
      matchId: json['matchId'] ?? '',
      matchNumber: json['matchNumber'] ?? 0,
      teamNumber: json['teamNumber'] ?? 0,
      alliance: json['alliance'] ?? 'Red',
      scouterName: json['scouterName'] ?? '',
      gameData: gameData,
      comments: json['comments'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isSynced: json['isSynced'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      eventId: json['eventId'] ?? '',
      teamId: json['teamId'] ?? '',
      programType: json['programType'] ?? 'FRC',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'matchId': matchId,
      'matchNumber': matchNumber,
      'teamNumber': teamNumber,
      'alliance': alliance,
      'scouterName': scouterName,
      'gameData': gameData,
      'comments': comments,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
      'eventId': eventId,
      'teamId': teamId,
      'programType': programType,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'matchId': matchId,
      'matchNumber': matchNumber,
      'teamNumber': teamNumber,
      'alliance': alliance,
      'scouterName': scouterName,
      'gameData': gameData,
      'comments': comments,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced,
      'isDeleted': isDeleted,
      'eventId': eventId,
      'teamId': teamId,
      'programType': programType,
    };
  }
}
