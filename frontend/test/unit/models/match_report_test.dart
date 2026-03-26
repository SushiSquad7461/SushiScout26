import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/match_report.dart';

void main() {
  group('MatchReport', () {
    test('should create MatchReport with all required fields', () {
      final report = MatchReport(
        id: 'match123',
        matchId: 'qm1_254',
        matchNumber: 1,
        teamNumber: 254,
        alliance: 'Red',
        scouterName: 'Test Scouter',
        gameData: {'auto_fuel': 5, 'teleop_fuel': 10},
        createdAt: DateTime(2026, 3, 15, 14, 30),
      );

      expect(report.id, 'match123');
      expect(report.matchId, 'qm1_254');
      expect(report.matchNumber, 1);
      expect(report.teamNumber, 254);
      expect(report.alliance, 'Red');
      expect(report.scouterName, 'Test Scouter');
      expect(report.gameData, {'auto_fuel': 5, 'teleop_fuel': 10});
      expect(report.robotDied, false);
      expect(report.comments, '');
      expect(report.isSynced, false);
      expect(report.isDeleted, false);
    });

    test('should create MatchReport with optional fields', () {
      final report = MatchReport(
        id: 'match456',
        matchId: 'qm2_118',
        matchNumber: 2,
        teamNumber: 118,
        alliance: 'Blue',
        scouterName: 'Another Scouter',
        gameData: {'auto_fuel': 3, 'robot_died': true},
        comments: 'Robot had mechanical issues',
        createdAt: DateTime(2026, 3, 15, 15, 0),
        isSynced: true,
        isDeleted: true,
      );

      expect(report.robotDied, true);
      expect(report.comments, 'Robot had mechanical issues');
      expect(report.isSynced, true);
      expect(report.isDeleted, true);
    });

    test('should support different alliances', () {
      final redAlliance = MatchReport(
        id: 'red123',
        matchId: 'qm1',
        matchNumber: 1,
        teamNumber: 1,
        alliance: 'Red',
        scouterName: 'Scouter',
        gameData: {},
        createdAt: DateTime.now(),
      );

      final blueAlliance = MatchReport(
        id: 'blue123',
        matchId: 'qm2',
        matchNumber: 2,
        teamNumber: 2,
        alliance: 'Blue',
        scouterName: 'Scouter',
        gameData: {},
        createdAt: DateTime.now(),
      );

      expect(redAlliance.alliance, 'Red');
      expect(blueAlliance.alliance, 'Blue');
    });

    test('should handle empty game data', () {
      final report = MatchReport(
        id: 'empty123',
        matchId: 'qm3',
        matchNumber: 3,
        teamNumber: 3,
        alliance: 'Red',
        scouterName: 'Scouter',
        gameData: {},
        createdAt: DateTime.now(),
      );

      expect(report.gameData, isEmpty);
    });

    test('should handle complex game data', () {
      final complexData = {
        'auto_fuel': 5,
        'teleop_fuel': 15,
        'defense_rating': 4,
        'driver_skill': 5,
        'artifacts_auto': 3,
        'artifacts_teleop': 8,
        'climbed': true,
        'parked': false,
      };

      final report = MatchReport(
        id: 'complex123',
        matchId: 'qm4',
        matchNumber: 4,
        teamNumber: 4,
        alliance: 'Blue',
        scouterName: 'Scouter',
        gameData: complexData,
        createdAt: DateTime.now(),
      );

      expect(report.gameData['auto_fuel'], 5);
      expect(report.gameData['defense_rating'], 4);
      expect(report.gameData['climbed'], true);
      expect(report.gameData.length, 8);
    });

    test('should handle multiline comments', () {
      final report = MatchReport(
        id: 'comment123',
        matchId: 'qm5',
        matchNumber: 5,
        teamNumber: 5,
        alliance: 'Red',
        scouterName: 'Scouter',
        gameData: {},
        comments: 'Line 1\nLine 2\nLine 3',
        createdAt: DateTime.now(),
      );

      expect(report.comments, 'Line 1\nLine 2\nLine 3');
    });

    test('should handle special characters in comments', () {
      final report = MatchReport(
        id: 'special123',
        matchId: 'qm6',
        matchNumber: 6,
        teamNumber: 6,
        alliance: 'Blue',
        scouterName: 'Scouter',
        gameData: {},
        comments: 'Special chars: !@#\$%^&*()_+-=[]{}|;\':",./<>?',
        createdAt: DateTime.now(),
      );

      expect(report.comments.contains('!@#'), true);
    });

    group('default values', () {
      test('should have correct default values', () {
        final report = MatchReport(
          id: 'defaults123',
          matchId: 'qm7',
          matchNumber: 7,
          teamNumber: 7,
          alliance: 'Red',
          scouterName: 'Scouter',
          gameData: {},
          createdAt: DateTime.now(),
        );

        expect(report.robotDied, false);
        expect(report.comments, '');
        expect(report.isSynced, false);
        expect(report.isDeleted, false);
      });
    });

    group('sync status', () {
      test('should track synced status', () {
        final unsyncedReport = MatchReport(
          id: 'unsynced',
          matchId: 'qm8',
          matchNumber: 8,
          teamNumber: 8,
          alliance: 'Red',
          scouterName: 'Scouter',
          gameData: {},
          createdAt: DateTime.now(),
          isSynced: false,
        );

        final syncedReport = MatchReport(
          id: 'synced',
          matchId: 'qm9',
          matchNumber: 9,
          teamNumber: 9,
          alliance: 'Blue',
          scouterName: 'Scouter',
          gameData: {},
          createdAt: DateTime.now(),
          isSynced: true,
        );

        expect(unsyncedReport.isSynced, false);
        expect(syncedReport.isSynced, true);
      });
    });

    group('trash status', () {
      test('should track deleted status', () {
        final activeReport = MatchReport(
          id: 'active',
          matchId: 'qm10',
          matchNumber: 10,
          teamNumber: 10,
          alliance: 'Red',
          scouterName: 'Scouter',
          gameData: {},
          createdAt: DateTime.now(),
          isDeleted: false,
        );

        final deletedReport = MatchReport(
          id: 'deleted',
          matchId: 'qm11',
          matchNumber: 11,
          teamNumber: 11,
          alliance: 'Blue',
          scouterName: 'Scouter',
          gameData: {},
          createdAt: DateTime.now(),
          isDeleted: true,
        );

        expect(activeReport.isDeleted, false);
        expect(deletedReport.isDeleted, true);
      });
    });
    group('JSON serialization', () {
      test('should serialize to JSON correctly', () {
        final report = MatchReport(
          id: 'json123',
          matchId: 'qm12',
          matchNumber: 12,
          teamNumber: 12,
          alliance: 'Red',
          scouterName: 'Scouter',
          gameData: {'fuel': 10},
          createdAt: DateTime(2026, 3, 15, 16, 0),
          isSynced: true,
          isDeleted: false,
        );

        final json = report.toJson();

        expect(json['id'], 'json123');
        expect(json['matchId'], 'qm12');
        expect(json['matchNumber'], 12);
        expect(json['gameData'], {'fuel': 10});
        expect(json['createdAt'], report.createdAt.toIso8601String());
        expect(json['isSynced'], true);
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'id': 'json456',
          'matchId': 'qm13',
          'matchNumber': 13,
          'teamNumber': 13,
          'alliance': 'Blue',
          'scouterName': 'Scouter',
          'gameData': {'fuel': 20},
          'createdAt': DateTime(2026, 3, 15, 17, 0).toIso8601String(),
          'isSynced': false,
          'isDeleted': true,
        };

        final report = MatchReport.fromJson(json);

        expect(report.id, 'json456');
        expect(report.matchId, 'qm13');
        expect(report.matchNumber, 13);
        expect(report.gameData, {'fuel': 20});
        expect(report.createdAt, DateTime(2026, 3, 15, 17, 0));
        expect(report.isSynced, false);
        expect(report.isDeleted, true);
      });
    });
  });
}
