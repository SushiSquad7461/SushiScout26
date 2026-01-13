import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:frontend/data/local/db.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/presentation/screens/scouting_wizard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Scouting Wizard step navigation and data entry', (
    WidgetTester tester,
  ) async {
    // 1. Initialize SharedPreferences (mocked)
    final prefs = await SharedPreferences.getInstance();

    // 2. Pump Widget with ProviderScope
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(home: ScoutingWizard(db: db)),
      ),
    );
    await tester.pumpAndSettle(); // Ensure everything settles

    // 3. Verify Setup Page
    expect(find.text('Scouter Name'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Scouter Name'),
      'Tester',
    );

    expect(find.text('Match #'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Match #'), '42');

    expect(find.text('Team #'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Team #'), '254');

    // 4. Next Page (Auto)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Autonomous'), findsOneWidget);
    // Find Add button for Auto Fuel (CounterCard)
    await tester.tap(
      find
          .descendant(of: find.byType(Card), matching: find.byIcon(Icons.add))
          .first,
    );
    await tester.pump();

    // 5. Next Page (Teleop)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Teleop'), findsOneWidget);

    // 6. Next Page (Endgame)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Endgame'), findsOneWidget);

    // 7. Submit
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    // 8. Verify DB
    final matches = await db.select(db.matchEntries).get();
    expect(matches.length, 1);
    expect(matches.first.matchNumber, 42);
    expect(matches.first.teamNumber, 254);
  });
}
