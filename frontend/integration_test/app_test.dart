import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;
import 'package:frontend/data/repositories/scouting_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SushiScout App Integration Tests', () {
    testWidgets('complete match scouting flow', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Verify dashboard loads
      expect(find.text('SushiScout 26'), findsOneWidget);

      // Tap on Scout Match button
      await tester.tap(find.text('Scout Match'));
      await tester.pumpAndSettle();

      // Should show scouting form
      expect(find.byType(TextField), findsWidgets);

      // Enter match data
      await tester.enterText(
        find.byWidgetPredicate((widget) => 
          widget is TextField && 
          widget.decoration?.labelText?.toLowerCase().contains('match') == true
        ).first,
        '1',
      );

      await tester.enterText(
        find.byWidgetPredicate((widget) => 
          widget is TextField && 
          widget.decoration?.labelText?.toLowerCase().contains('team') == true
        ).first,
        '254',
      );

      await tester.pumpAndSettle();

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Should be back on dashboard
      expect(find.text('SushiScout 26'), findsOneWidget);
    });

    testWidgets('settings persistence', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Open settings
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Enter scouter name
      await tester.enterText(
        find.byWidgetPredicate((widget) => 
          widget is TextField && 
          widget.decoration?.labelText?.contains('Name') == true
        ),
        'Test Scouter',
      );

      await tester.pumpAndSettle();

      // Close settings
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Settings should persist (restart app)
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify name persisted
      final nameField = find.byWidgetPredicate((widget) => 
        widget is TextField && 
        widget.decoration?.labelText?.contains('Name') == true
      );
      
      final TextField field = tester.widget(nameField);
      expect(field.controller?.text, 'Test Scouter');
    });

    testWidgets('theme switching', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Open settings
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Switch to dark theme
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      // Verify theme changed
      final BuildContext context = tester.element(find.byType(Scaffold));
      expect(Theme.of(context).brightness, Brightness.dark);

      // Switch back to light
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
    });
  });
}
