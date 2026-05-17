import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SushiScout App Integration Tests', () {
    testWidgets('dashboard loads with app title and Scout Match FAB',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify dashboard loads with correct title
      expect(find.text('SushiScout 26'), findsOneWidget);

      // Verify the Scout Match FAB is present
      expect(find.text('Scout Match'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets(
        'tapping Scout Match navigates to scouting form with text fields',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Tap on Scout Match FAB
      await tester.tap(find.text('Scout Match'));
      await tester.pumpAndSettle();

      // Should show scouting form with input fields
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets(
        'scouting form accepts match number and team number then navigates back',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to scouting form
      await tester.tap(find.text('Scout Match'));
      await tester.pumpAndSettle();

      // Enter match number
      final matchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText?.toLowerCase().contains('match') ==
                true,
      );
      if (matchField.evaluate().isNotEmpty) {
        await tester.enterText(matchField.first, '1');
      }

      // Enter team number
      final teamField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText?.toLowerCase().contains('team') ==
                true,
      );
      if (teamField.evaluate().isNotEmpty) {
        await tester.enterText(teamField.first, '254');
      }

      await tester.pumpAndSettle();

      // Navigate back to dashboard
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Should be back on dashboard
      expect(find.text('SushiScout 26'), findsOneWidget);
    });

    testWidgets('overflow menu opens and shows Settings, Trash, Clear options',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Tap the overflow menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Verify menu items are present
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);
      expect(find.text('Clear Local Data'), findsOneWidget);
    });

    testWidgets(
        'opening settings shows scouter name and event code fields',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Open settings via overflow menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify settings fields are visible
      expect(find.text('Your Name'), findsOneWidget);
      expect(find.text('Event Code'), findsOneWidget);

      // Verify theme selector labels are present
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Verify Done button is present
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('entering scouter name persists after closing and reopening settings',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Open settings
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Enter scouter name
      final nameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Your Name',
      );
      await tester.enterText(nameField, 'Test Scouter');
      await tester.pumpAndSettle();

      // Close settings
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Reopen settings
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify name persisted
      final nameFieldAgain = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Your Name',
      );
      final TextField field = tester.widget(nameFieldAgain);
      expect(field.controller?.text, 'Test Scouter');
    });

    testWidgets('selecting Dark theme segment changes app brightness to dark',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Open settings
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Switch to dark theme via SegmentedButton
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      // tester.element() returns a fresh BuildContext from the live widget
      // tree, so this is safe despite the analyzer's async-gap warning.
      final scaffoldFinder = find.byType(Scaffold);
      // ignore: use_build_context_synchronously
      expect(Theme.of(tester.element(scaffoldFinder.first)).brightness,
          Brightness.dark);

      // Switch back to light
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      // ignore: use_build_context_synchronously
      expect(Theme.of(tester.element(scaffoldFinder.first)).brightness,
          Brightness.light);
    });

    testWidgets('empty state shows no-matches message on dashboard',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // On a fresh app with no matches, expect the empty state message
      expect(find.text('No matches scouted yet'), findsOneWidget);
      expect(
        find.text('Tap the button below to scout your first match'),
        findsOneWidget,
      );
    });

    testWidgets('search button is present in app bar', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify search icon button exists
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Verify export icon button exists
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });
  });
}
