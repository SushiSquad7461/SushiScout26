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
  final List<String> images;
  final DateTime createdAt;
  final bool isSynced;
  final bool isDeleted;
  final String teamId;

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
    this.images = const [],
    required this.createdAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.teamId = '',
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
      images: List<String>.from(data['images'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSynced: !doc.metadata.hasPendingWrites,
      isDeleted: data['isDeleted'] ?? false,
      teamId: data['teamId'] ?? '',
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
      images: List<String>.from(json['images'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isSynced: json['isSynced'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      teamId: json['teamId'] ?? '',
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
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
      'teamId': teamId,
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
      'robotDied': robotDied,
      'comments': comments,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced,
      'isDeleted': isDeleted,
      'teamId': teamId,
    };
  }
}
