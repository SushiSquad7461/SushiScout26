import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/event.dart';

void main() {
  group('Event', () {
    test('should create Event with all required fields', () {
      final event = Event(
        id: '2026casj',
        name: 'Silicon Valley Regional',
        programType: 'FRC',
        tbaKey: '2026casj',
        startDate: DateTime(2026, 3, 15),
      );

      expect(event.id, '2026casj');
      expect(event.name, 'Silicon Valley Regional');
      expect(event.programType, 'FRC');
      expect(event.tbaKey, '2026casj');
      expect(event.startDate, DateTime(2026, 3, 15));
    });

    test('should create Event with FTC program type', () {
      final event = Event(
        id: '2026uscaftc',
        name: 'California FTC Championship',
        programType: 'FTC',
        tbaKey: '2026uscaftc',
        startDate: DateTime(2026, 2, 20),
      );

      expect(event.programType, 'FTC');
    });

    test('should support different program types', () {
      final frcEvent = Event(
        id: 'frc123',
        name: 'FRC Event',
        programType: 'FRC',
        tbaKey: 'frc123',
        startDate: DateTime.now(),
      );

      final ftcEvent = Event(
        id: 'ftc456',
        name: 'FTC Event',
        programType: 'FTC',
        tbaKey: 'ftc456',
        startDate: DateTime.now(),
      );

      expect(frcEvent.programType, 'FRC');
      expect(ftcEvent.programType, 'FTC');
    });

    test('should handle empty strings', () {
      final event = Event(
        id: '',
        name: '',
        programType: '',
        tbaKey: '',
        startDate: DateTime.now(),
      );

      expect(event.id, '');
      expect(event.name, '');
      expect(event.programType, '');
      expect(event.tbaKey, '');
    });

    test('should handle future dates', () {
      final futureDate = DateTime(2030, 12, 31);
      final event = Event(
        id: 'future',
        name: 'Future Event',
        programType: 'FRC',
        tbaKey: 'future',
        startDate: futureDate,
      );

      expect(event.startDate, futureDate);
    });

    test('should handle past dates', () {
      final pastDate = DateTime(2020, 1, 1);
      final event = Event(
        id: 'past',
        name: 'Past Event',
        programType: 'FRC',
        tbaKey: 'past',
        startDate: pastDate,
      );

      expect(event.startDate, pastDate);
    });
  });
}
