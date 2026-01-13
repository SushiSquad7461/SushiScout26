import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:frontend/main.dart'; // Ensure this exposes MyApp or similar, need to check
import 'package:frontend/data/local/db.dart';
import 'package:frontend/presentation/screens/scouting_wizard.dart'; // Verify this import path

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Scouting Wizard step navigation and data entry', (
    WidgetTester tester,
  ) async {
    // We need to wrap in ProviderScope for Riverpod
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ScoutingWizard(db: db)),
      ),
    );

    // Step 1: Setup
    // Assuming ScoutingWizard starts at Setup step
    // Check if we need to find specific widgets.
    // The snippet used 'Scouter Name' text field.

    // Note: If ScoutingWizard expects arguments or specific providers, we might need to adjust.
    // Assuming ScoutingWizard takes `db` as a parameter based on the snippet.

    expect(
      find.text('Scouter Name'),
      findsOneWidget,
    ); // Verify we are on the page

    await tester.enterText(
      find.widgetWithText(TextField, 'Scouter Name'),
      'Tester',
    );
    // 'Match #' might be a TextField label
    await tester.enterText(find.widgetWithText(TextField, 'Match #'), '42');

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2: Auto
    expect(find.text('Autonomous'), findsOneWidget);
    // Assuming there is a button to add fuel. The snippet says `find.widgetWithIcon(FilledButton, Icons.add)`
    // We'll try to find an add icon.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3: Teleop
    expect(find.text('Teleop'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 4: Endgame
    // Maybe verify 'Endgame' text
    expect(find.text('Endgame'), findsOneWidget);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    // Verify saved
    final matches = await db.select(db.matchEntries).get();
    expect(matches.length, 1);
    expect(matches.first.matchNumber, 42);
  });
}
