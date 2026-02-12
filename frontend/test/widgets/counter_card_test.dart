import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/counter_card.dart';

void main() {
  group('CounterCard', () {
    // Use a simple theme that doesn't require Google Fonts
    Widget buildTestWidget({
      required int value,
      required Function(int) onChanged,
      String label = 'Test Counter',
      String? helperText,
      Color? accentColor,
      int minValue = 0,
      int maxValue = 999,
    }) {
      return MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          body: CounterCard(
            label: label,
            value: value,
            onChanged: onChanged,
            helperText: helperText,
            accentColor: accentColor,
            minValue: minValue,
            maxValue: maxValue,
          ),
        ),
      );
    }

    testWidgets('displays label correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(value: 5, onChanged: (_) {}, label: 'Fuel Count'),
      );

      expect(find.text('Fuel Count'), findsOneWidget);
    });

    testWidgets('displays value correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget(value: 42, onChanged: (_) {}));

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('displays helper text when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          value: 0,
          onChanged: (_) {},
          helperText: 'Pieces scored in auto',
        ),
      );

      expect(find.text('Pieces scored in auto'), findsOneWidget);
    });

    testWidgets('increment button increases value', (tester) async {
      int currentValue = 5;

      await tester.pumpWidget(
        buildTestWidget(
          value: currentValue,
          onChanged: (v) => currentValue = v,
        ),
      );

      // Find and tap the add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(currentValue, 6);
    });

    testWidgets('decrement button decreases value', (tester) async {
      int currentValue = 5;

      await tester.pumpWidget(
        buildTestWidget(
          value: currentValue,
          onChanged: (v) => currentValue = v,
        ),
      );

      // Find and tap the remove button
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(currentValue, 4);
    });

    testWidgets('decrement button is disabled at minValue', (tester) async {
      int currentValue = 0;
      bool wasCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          value: currentValue,
          onChanged: (v) {
            currentValue = v;
            wasCalled = true;
          },
          minValue: 0,
        ),
      );

      // Tap the remove button - should not call onChanged
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(wasCalled, isFalse);
      expect(currentValue, 0);
    });

    testWidgets('increment button is disabled at maxValue', (tester) async {
      int currentValue = 10;
      bool wasCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          value: currentValue,
          onChanged: (v) {
            currentValue = v;
            wasCalled = true;
          },
          maxValue: 10,
        ),
      );

      // Tap the add button - should not call onChanged
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(wasCalled, isFalse);
      expect(currentValue, 10);
    });

    testWidgets('buttons exist for interaction', (tester) async {
      await tester.pumpWidget(buildTestWidget(value: 5, onChanged: (_) {}));

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('applies accent color when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(value: 5, onChanged: (_) {}, accentColor: Colors.red),
      );

      expect(find.byType(CounterCard), findsOneWidget);
    });

    testWidgets('works with custom min/max values', (tester) async {
      int currentValue = 5;

      await tester.pumpWidget(
        buildTestWidget(
          value: currentValue,
          onChanged: (v) => currentValue = v,
          minValue: 3,
          maxValue: 7,
        ),
      );

      // Should decrement normally
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(currentValue, 4);
    });
  });
}
