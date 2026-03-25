import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/match_report.dart';

class ExportService {
  /// Detects whether match data is FTC based on the presence of FTC-specific keys.
  static bool _isFtc(MatchReport m) =>
      m.gameData.containsKey('artifacts_auto');

  /// Returns column headers appropriate for the program type.
  static List<String> _headers(bool ftc) => ftc
      ? [
          'Match',
          'Team',
          'Alliance',
          'Scouter',
          'Leave',
          'Artifacts Auto',
          'Indexing Auto',
          'Artifacts Teleop',
          'Indexing Teleop',
          'Base Expansion',
          'Driver Quality',
          'Robot Died',
          'Comments',
        ]
      : [
          'Match',
          'Team',
          'Alliance',
          'Scouter',
          'Auto Fuel',
          'Auto Tower L1',
          'Teleop Fuel',
          'Teleop Tower',
          'Defense',
          'Driver Skill',
          'Robot Died',
          'Comments',
        ];

  /// Extracts a row of string values from a match report.
  static List<String> _rowStrings(MatchReport m, bool ftc) {
    final gd = m.gameData;
    if (ftc) {
      return [
        m.matchNumber.toString(),
        m.teamNumber.toString(),
        m.alliance,
        m.scouterName,
        (gd['leave'] ?? false).toString(),
        (gd['artifacts_auto'] ?? 0).toString(),
        (gd['indexing_auto'] ?? 0).toString(),
        (gd['artifacts_teleop'] ?? 0).toString(),
        (gd['indexing_teleop'] ?? 0).toString(),
        (gd['base_expansion'] ?? false).toString(),
        (gd['driver_quality'] ?? 0).toString(),
        (gd['robot_died'] ?? false).toString(),
        m.comments,
      ];
    }
    return [
      m.matchNumber.toString(),
      m.teamNumber.toString(),
      m.alliance,
      m.scouterName,
      (gd['auto_fuel'] ?? 0).toString(),
      (gd['auto_tower_l1'] ?? 0).toString(),
      (gd['teleop_fuel'] ?? 0).toString(),
      (gd['teleop_tower_level'] ?? 0).toString(),
      (gd['defense_rating'] ?? 0).toString(),
      (gd['driver_skill'] ?? 0).toString(),
      (gd['robot_died'] ?? false).toString(),
      m.comments,
    ];
  }

  // ---------------------------------------------------------------------------
  // CSV
  // ---------------------------------------------------------------------------

  /// Exports match reports to a CSV file and opens the share dialog.
  ///
  /// Throws [ArgumentError] if [matches] is empty.
  /// Throws [Exception] on file-system or sharing errors.
  static Future<void> exportToCsv(List<MatchReport> matches) async {
    if (matches.isEmpty) {
      throw ArgumentError('Cannot export an empty match list to CSV.');
    }

    try {
      final ftc = _isFtc(matches.first);
      final headers = _headers(ftc);

      final buffer = StringBuffer();
      buffer.writeln(headers.map(_escapeCsvField).join(','));
      for (final m in matches) {
        buffer.writeln(_rowStrings(m, ftc).map(_escapeCsvField).join(','));
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/sushiscout_export.csv');
      await file.writeAsString(buffer.toString());

      await SharePlus.instance
          .share(ShareParams(files: [XFile(file.path)]));
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  /// Wraps a CSV field in quotes if it contains commas, quotes, or newlines.
  static String _escapeCsvField(String field) {
    if (field.contains(RegExp(r'[,"\n\r]'))) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // ---------------------------------------------------------------------------
  // Excel
  // ---------------------------------------------------------------------------

  /// Exports match reports to an Excel (.xlsx) file and opens the share dialog.
  ///
  /// Throws [ArgumentError] if [matches] is empty.
  /// Throws [Exception] on file-system or sharing errors.
  static Future<void> exportToExcel(List<MatchReport> matches) async {
    if (matches.isEmpty) {
      throw ArgumentError('Cannot export an empty match list to Excel.');
    }

    try {
      final ftc = _isFtc(matches.first);
      final excel = Excel.createExcel();
      final Sheet sheet = excel['Matches'];

      // Header
      sheet.appendRow(_headers(ftc).map((h) => TextCellValue(h)).toList());

      // Data rows
      for (final m in matches) {
        final values = _rowStrings(m, ftc);
        sheet.appendRow(values.map((v) => TextCellValue(v)).toList());
      }

      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Excel encoding returned null bytes.');
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/sushiscout_export.xlsx');
      await file.writeAsBytes(fileBytes);

      await SharePlus.instance
          .share(ShareParams(files: [XFile(file.path)]));
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------------

  /// Exports match reports to a PDF file and opens the share dialog.
  ///
  /// Throws [ArgumentError] if [matches] is empty.
  /// Throws [Exception] on font-loading, file-system, or sharing errors.
  static Future<void> exportToPdf(List<MatchReport> matches) async {
    if (matches.isEmpty) {
      throw ArgumentError('Cannot export an empty match list to PDF.');
    }

    try {
      final ftc = _isFtc(matches.first);
      final headers = _headers(ftc);
      // PDF table does not need Comments column (too wide); drop it.
      final pdfHeaders = headers.where((h) => h != 'Comments').toList();

      final fontData =
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: ttf),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('SushiScout Match Reports'),
              ),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  pdfHeaders,
                  ...matches.map((m) {
                    final row = _rowStrings(m, ftc);
                    // Remove the last element (Comments) to match pdfHeaders.
                    return row.sublist(0, row.length - 1);
                  }),
                ],
              ),
            ];
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/sushiscout_export.pdf');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance
          .share(ShareParams(files: [XFile(file.path)]));
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }
}
