import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/services/export_service.dart';

MatchReport _frcMatch({
  String comments = '',
  String scouter = 'Alice',
  int teamNumber = 7461,
  int matchNumber = 5,
  String alliance = 'Red',
}) {
  return MatchReport(
    id: 'id-$matchNumber',
    matchId: 'qm$matchNumber',
    matchNumber: matchNumber,
    teamNumber: teamNumber,
    alliance: alliance,
    scouterName: scouter,
    gameData: const {
      'auto_fuel': 3,
      'auto_tower_l1': 1,
      'teleop_fuel': 12,
      'teleop_tower_level': 2,
      'defense_rating': 4,
      'driver_skill': 5,
      'robot_died': false,
    },
    comments: comments,
    createdAt: DateTime(2026, 1, 1),
  );
}

MatchReport _ftcMatch({
  String comments = '',
  String scouter = 'Bob',
  int teamNumber = 12345,
}) {
  return MatchReport(
    id: 'ftc-id',
    matchId: 'qm1',
    matchNumber: 1,
    teamNumber: teamNumber,
    alliance: 'Blue',
    scouterName: scouter,
    gameData: const {
      'leave': true,
      'artifacts_auto': 5,
      'indexing_auto': 1,
      'artifacts_teleop': 10,
      'indexing_teleop': 2,
      'base_expansion': false,
      'driver_quality': 4,
      'robot_died': false,
    },
    comments: comments,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ExportService.isFtc', () {
    test('detects FTC match via artifacts_auto key', () {
      expect(ExportService.isFtc(_ftcMatch()), isTrue);
    });

    test('rejects FRC match without FTC key', () {
      expect(ExportService.isFtc(_frcMatch()), isFalse);
    });
  });

  group('ExportService.headers', () {
    test('FRC headers contain Auto Fuel and Teleop Tower', () {
      final headers = ExportService.headers(ftc: false);
      expect(headers, contains('Auto Fuel'));
      expect(headers, contains('Teleop Tower'));
      expect(headers, isNot(contains('Artifacts Auto')));
    });

    test('FTC headers contain Artifacts and Base Expansion', () {
      final headers = ExportService.headers(ftc: true);
      expect(headers, contains('Artifacts Auto'));
      expect(headers, contains('Base Expansion'));
      expect(headers, isNot(contains('Auto Fuel')));
    });

    test('both headers start with Match, Team, Alliance, Scouter', () {
      for (final ftc in [true, false]) {
        final headers = ExportService.headers(ftc: ftc);
        expect(headers.take(4).toList(), ['Match', 'Team', 'Alliance', 'Scouter']);
      }
    });

    test('both headers end with Comments', () {
      for (final ftc in [true, false]) {
        final headers = ExportService.headers(ftc: ftc);
        expect(headers.last, 'Comments');
      }
    });
  });

  group('ExportService.buildCsvString', () {
    test('throws ArgumentError for empty matches', () {
      expect(
        () => ExportService.buildCsvString(<MatchReport>[]),
        throwsArgumentError,
      );
    });

    test('writes header row for FRC matches', () {
      final csv = ExportService.buildCsvString([_frcMatch()]);
      final firstLine = csv.split('\n').first;
      expect(firstLine, contains('Match'));
      expect(firstLine, contains('Auto Fuel'));
    });

    test('writes one row per match plus header', () {
      final csv = ExportService.buildCsvString([
        _frcMatch(matchNumber: 1),
        _frcMatch(matchNumber: 2),
        _frcMatch(matchNumber: 3),
      ]);
      // Header + 3 data rows + trailing newline → 4 non-empty lines.
      final nonEmptyLines =
          csv.split(RegExp(r'\r?\n')).where((l) => l.isNotEmpty).toList();
      expect(nonEmptyLines.length, 4);
    });

    test('embeds FRC gameData values', () {
      final csv = ExportService.buildCsvString([_frcMatch()]);
      // auto_fuel=3 and teleop_fuel=12 should appear.
      expect(csv, contains('3'));
      expect(csv, contains('12'));
    });

    test('embeds FTC gameData values', () {
      final csv = ExportService.buildCsvString([_ftcMatch()]);
      // artifacts_auto=5, artifacts_teleop=10.
      expect(csv, contains('5'));
      expect(csv, contains('10'));
    });

    test('detects FTC from first match', () {
      final csv = ExportService.buildCsvString([_ftcMatch()]);
      expect(csv, contains('Artifacts Auto'));
      expect(csv, isNot(contains('Auto Fuel')));
    });

    test('escapes comma in comments by wrapping in quotes', () {
      final csv = ExportService.buildCsvString([
        _frcMatch(comments: 'good auto, bad teleop'),
      ]);
      expect(csv, contains('"good auto, bad teleop"'));
    });

    test('escapes double-quote in comments by doubling it', () {
      final csv = ExportService.buildCsvString([
        _frcMatch(comments: 'said "fast"'),
      ]);
      expect(csv, contains('"said ""fast"""'));
    });

    test('escapes newline in comments by quoting field', () {
      final csv = ExportService.buildCsvString([
        _frcMatch(comments: 'line1\nline2'),
      ]);
      expect(csv, contains('"line1\nline2"'));
    });

    test('leaves plain comments unquoted', () {
      final csv = ExportService.buildCsvString([
        _frcMatch(comments: 'plain comment'),
      ]);
      expect(csv, contains('plain comment'));
      expect(csv, isNot(contains('"plain comment"')));
    });
  });
}
