import 'package:cloud_firestore/cloud_firestore.dart';

class MatchReport {
  final String id;
  final String matchId; // e.g. "qm1_4198"
  final int matchNumber;
  final int teamNumber;
  final String alliance; // 'Red' or 'Blue'
  final String scouterName;
  final Map<String, dynamic> gameData; // Polymorphic data
  final bool robotDied;
  final String comments;
  final DateTime createdAt;
  final bool isSynced;
  final bool isDeleted;

  MatchReport({
    required this.id,
    required this.matchId,
    required this.matchNumber,
    required this.teamNumber,
    required this.alliance,
    required this.scouterName,
    required this.gameData,
    this.robotDied = false,
    this.comments = '',
    required this.createdAt,
    this.isSynced = false,
    this.isDeleted = false,
  });

  factory MatchReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MatchReport(
      id: doc.id,
      matchId: data['matchId'] ?? '',
      matchNumber: data['matchNumber'] ?? 0,
      teamNumber: data['teamNumber'] ?? 0,
      alliance: data['alliance'] ?? 'Red',
      scouterName: data['scouterName'] ?? '',
      gameData: data['gameData'] as Map<String, dynamic>? ?? {},
      robotDied: data['robotDied'] ?? false,
      comments: data['comments'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSynced: !doc.metadata.hasPendingWrites,
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  factory MatchReport.fromJson(Map<String, dynamic> json) {
    return MatchReport(
      id: json['id'] ?? '',
      matchId: json['matchId'] ?? '',
      matchNumber: json['matchNumber'] ?? 0,
      teamNumber: json['teamNumber'] ?? 0,
      alliance: json['alliance'] ?? 'Red',
      scouterName: json['scouterName'] ?? '',
      gameData: json['gameData'] as Map<String, dynamic>? ?? {},
      robotDied: json['robotDied'] ?? false,
      comments: json['comments'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isSynced: json['isSynced'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
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
      'robotDied': robotDied,
      'comments': comments,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
    };
  }
}
