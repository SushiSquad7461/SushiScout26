import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String name;
  final String programType; // 'FRC' or 'FTC'
  final String tbaKey;
  final DateTime startDate;

  Event({
    required this.id,
    required this.name,
    required this.programType,
    required this.tbaKey,
    required this.startDate,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      name: data['name'] ?? '',
      programType: data['programType'] ?? 'FRC',
      tbaKey: data['tbaKey'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'programType': programType,
      'tbaKey': tbaKey,
      'startDate': Timestamp.fromDate(startDate),
    };
  }
}
