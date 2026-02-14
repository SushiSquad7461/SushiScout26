import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/match_report.dart';

class ExportService {
  static Future<void> exportToExcel(List<MatchReport> matches) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Matches'];

    // Header
    sheet.appendRow([
      TextCellValue('Match'),
      TextCellValue('Team'),
      TextCellValue('Alliance'),
      TextCellValue('Scouter'),
      TextCellValue('Auto Fuel'),
      TextCellValue('Teleop Fuel'),
      TextCellValue('Climb'),
      TextCellValue('Comments'),
    ]);

    // Data
    for (var m in matches) {
      sheet.appendRow([
        IntCellValue(m.matchNumber),
        IntCellValue(m.teamNumber),
        TextCellValue(m.alliance),
        TextCellValue(m.scouterName),
        IntCellValue(m.gameData['auto_fuel'] ?? 0),
        IntCellValue(m.gameData['teleop_fuel'] ?? 0),
        IntCellValue(m.gameData['teleop_tower_level'] ?? 0),
        TextCellValue(m.comments),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/sushiscout_export.xlsx');
    await file.writeAsBytes(fileBytes);

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  static Future<void> exportToPdf(List<MatchReport> matches) async {
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: ttf,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text("SushiScout Match Reports"),
            ),
            pw.Table.fromTextArray(
              context: context,
              data: <List<String>>[
                <String>['Match', 'Team', 'Alliance', 'Auto', 'Teleop', 'Climb'],
                ...matches.map((m) => [
                  m.matchNumber.toString(),
                  m.teamNumber.toString(),
                  m.alliance,
                  (m.gameData['auto_fuel'] ?? 0).toString(),
                  (m.gameData['teleop_fuel'] ?? 0).toString(),
                  (m.gameData['teleop_tower_level'] ?? 0).toString(),
                ]),
              ],
            ),
          ];
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/sushiscout_export.pdf');
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}
