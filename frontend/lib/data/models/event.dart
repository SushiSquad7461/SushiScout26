import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String name;
  final String programType; // 'FRC' or 'FTC'
  final String tbaKey;
  final DateTime startDate;
  final String teamId;

  Event({
    required this.id,
    required this.name,
    required this.programType,
    required this.tbaKey,
    required this.startDate,
    this.teamId = '',
  });

  /// Strips the `{teamId}_` prefix from a composite event id (see CLAUDE.md's
  /// composite-id note), yielding the raw event code used for `name`/`tbaKey`
  /// and TBA/schedule lookups. Falls back to the id unchanged when it isn't
  /// prefixed by `teamId` (e.g. a pre-migration event, or `teamId` unknown).
  /// Single source of truth for this split — used both when auto-creating an
  /// event doc (`FirestoreRepository._getOrCreateEvent`) and when building a
  /// fallback `Event` for display (`MatchDetailsScreen._openEditForm`), so
  /// the two can't drift out of sync.
  static String rawCodeFromComposite(String compositeId, String? teamId) {
    if (teamId != null &&
        teamId.isNotEmpty &&
        compositeId.startsWith('${teamId}_')) {
      return compositeId.substring(teamId.length + 1);
    }
    return compositeId;
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      name: data['name'] ?? '',
      programType: data['programType'] ?? 'FRC',
      tbaKey: data['tbaKey'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      teamId: data['teamId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'programType': programType,
      'tbaKey': tbaKey,
      'startDate': Timestamp.fromDate(startDate),
      'teamId': teamId,
    };
  }

  Event copyWith({
    String? id,
    String? name,
    String? programType,
    String? tbaKey,
    DateTime? startDate,
    String? teamId,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      programType: programType ?? this.programType,
      tbaKey: tbaKey ?? this.tbaKey,
      startDate: startDate ?? this.startDate,
      teamId: teamId ?? this.teamId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          programType == other.programType &&
          tbaKey == other.tbaKey &&
          startDate == other.startDate &&
          teamId == other.teamId;

  @override
  int get hashCode =>
      Object.hash(id, name, programType, tbaKey, startDate, teamId);

  @override
  String toString() =>
      'Event(id: $id, name: $name, programType: $programType, '
      'tbaKey: $tbaKey, startDate: $startDate, teamId: $teamId)';
}
