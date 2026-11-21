import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/services/export_service.dart';

const _fontAsset = 'assets/fonts/Roboto-Regular.ttf';

MatchReport _frcMatch({int matchNumber = 5, String scouter = 'Alice'}) {
  return MatchReport(
    id: 'frc-$matchNumber',
    matchId: 'qm$matchNumber',
    matchNumber: matchNumber,
    teamNumber: 7461,
    alliance: 'Red',
    scouterName: scouter,
    gameData: const {
      'auto_fuel': 3,
      'auto_tower_l1': 1,
      'teleop_fuel': 12,
      'teleop_tower_level': 2,
      'defense_rating': 4,
      'driver_skill': 5,
      'robot_died': true,
      'drivetrain_speed': 3,
      'intake_speed': 2,
      'shooter_speed': 4,
      'defense_cause': 'broke',
      'died_at_seconds': 95,
      'died_reason': 'battery died',
    },
    comments: 'fast cycles',
    createdAt: DateTime(2026, 1, 1),
  );
}

MatchReport _ftcMatch({int matchNumber = 1}) {
  return MatchReport(
    id: 'ftc-$matchNumber',
    matchId: 'qm$matchNumber',
    matchNumber: matchNumber,
    teamNumber: 12345,
    alliance: 'Blue',
    scouterName: 'Bob',
    programType: 'FTC',
    gameData: const {
      'leave': true,
      'hive_tips_auto': 2,
      'hive_tips_teleop': 5,
      'flower_score': true,
      'flower_descore': false,
      'pollen_shooter': true,
      'nectar_shooter': true,
      'park': true,
      'driver_quality': 4.0,
      'robot_died': false,
      'defense_rating': 3,
      'drivetrain_speed': 1,
      'intake_speed': 5,
      'shooter_speed': 2,
      'defense_cause': 'strategic',
      'died_at_seconds': 42,
      'died_reason': 'tipped over',
    },
    comments: '',
    createdAt: DateTime(2026, 1, 1),
  );
}

bool _startsWithPdfMagic(Uint8List bytes) =>
    bytes.length > 5 && ascii.decode(bytes.sublist(0, 5)) == '%PDF-';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled PDF font asset', () {
    test('is a TrueType font, not an HTML page or other file', () async {
      final data = await rootBundle.load(_fontAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      // A TrueType font starts with the sfnt version 0x00010000, or the tag
      // 'true'. An OpenType font with CFF outlines starts with 'OTTO'.
      final tag = ascii.decode(bytes.sublist(0, 4), allowInvalid: true);
      final isTrueType =
          (bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0) ||
          tag == 'true' ||
          tag == 'OTTO';
      expect(
        isTrueType,
        isTrue,
        reason: 'Roboto-Regular.ttf must be a real font. First bytes: $tag',
      );
      expect(bytes.length, greaterThan(50 * 1024));
    });
  });

  group('ExportService.buildPdfBytes', () {
    test('builds a PDF for FRC matches with the bundled font', () async {
      final bytes = await ExportService.buildPdfBytes([
        _frcMatch(matchNumber: 1),
        _frcMatch(matchNumber: 2),
      ]);

      expect(_startsWithPdfMagic(bytes), isTrue);
    });

    test('builds a PDF for FTC matches with the bundled font', () async {
      final bytes = await ExportService.buildPdfBytes([_ftcMatch()]);

      expect(_startsWithPdfMagic(bytes), isTrue);
    });

    test('builds a PDF when a scouter name has non-ASCII characters', () async {
      final bytes = await ExportService.buildPdfBytes([
        _frcMatch(scouter: 'José Ñandú'),
      ]);

      expect(_startsWithPdfMagic(bytes), isTrue);
    });

    test('builds a multi-page PDF for a long match list', () async {
      final bytes = await ExportService.buildPdfBytes([
        for (var i = 1; i <= 80; i++) _frcMatch(matchNumber: i),
      ]);

      expect(_startsWithPdfMagic(bytes), isTrue);
    });

    test('throws ArgumentError for an empty match list', () async {
      await expectLater(
        ExportService.buildPdfBytes(const []),
        throwsArgumentError,
      );
    });
  });
}
