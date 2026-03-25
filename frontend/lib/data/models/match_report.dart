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

  // Common
  bool get robotDied => gameData['robot_died'] ?? false;
  bool get isFtc => programType == 'FTC' || gameData.containsKey('artifacts_auto');

  // FRC getters
  int get autoFuel => gameData['auto_fuel'] ?? 0;
  bool get autoTowerL1 => gameData['auto_tower_l1'] ?? false;
  int get teleopFuel => gameData['teleop_fuel'] ?? 0;
  int get teleopTowerLevel => gameData['teleop_tower_level'] ?? 0;
  int get defenseRating => gameData['defense_rating'] ?? 0;
  int get driverSkill => gameData['driver_skill'] ?? 0;
  bool get trenchTraverse => gameData['trench_traverse'] ?? false;
  bool get bumpTraverse => gameData['bump_traverse'] ?? false;
  bool get shootingRangeClose => gameData['shooting_range_close'] ?? false;
  bool get shootingRangeMid => gameData['shooting_range_mid'] ?? false;
  bool get shootingRangeFar => gameData['shooting_range_far'] ?? false;

  // FTC getters
  bool get leave => gameData['leave'] ?? false;
  int get artifactsAuto => gameData['artifacts_auto'] ?? 0;
  bool get indexingAuto => gameData['indexing_auto'] ?? false;
  int get artifactsTeleop => gameData['artifacts_teleop'] ?? 0;
  bool get indexingTeleop => gameData['indexing_teleop'] ?? false;
  String get baseExpansion => gameData['base_expansion'] ?? 'None';
  double get driverQuality => (gameData['driver_quality'] ?? 0).toDouble();

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

  MatchReport copyWith({
    String? id,
    String? matchId,
    int? matchNumber,
    int? teamNumber,
    String? alliance,
    String? scouterName,
    Map<String, dynamic>? gameData,
    String? comments,
    DateTime? createdAt,
    bool? isSynced,
    bool? isDeleted,
    String? eventId,
    String? teamId,
    String? programType,
  }) {
    return MatchReport(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      matchNumber: matchNumber ?? this.matchNumber,
      teamNumber: teamNumber ?? this.teamNumber,
      alliance: alliance ?? this.alliance,
      scouterName: scouterName ?? this.scouterName,
      gameData: gameData ?? this.gameData,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      eventId: eventId ?? this.eventId,
      teamId: teamId ?? this.teamId,
      programType: programType ?? this.programType,
    );
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
