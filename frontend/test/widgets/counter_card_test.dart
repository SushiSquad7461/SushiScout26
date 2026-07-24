import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

    testWidgets('keeps a 3-digit value on a single line under text scaling', (
      tester,
    ) async {
      // "some phones" = larger accessibility text scale + a narrow value slot.
      // A 3-digit score must stay on one row, never wrap into a second line.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: CounterCard(
                label: 'Score',
                value: 100,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(find.text('100'));
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
      final distinctLineTops = boxes.map((b) => b.top.round()).toSet();
      expect(
        distinctLineTops.length,
        1,
        reason: '3-digit value must render on a single line, not wrap',
      );

      // ...and it must be SCALED to fit the 80px slot, not clamped-and-clipped.
      // Under the FittedBox the paragraph lays out at its natural width (wider
      // than the slot), and the FittedBox's scale transform shrinks the painted
      // result to fit. Both together fail if the FittedBox were dropped (a plain
      // SizedBox would instead clamp the paragraph to 80 and clip the overflow).
      expect(
        paragraph.size.width,
        greaterThan(80.0),
        reason: 'value must lay out at natural width, then be scaled to fit',
      );
      final onScreenWidth = tester.getRect(find.text('100')).width;
      expect(
        onScreenWidth,
        lessThanOrEqualTo(80.0),
        reason: '3-digit value must fit the fixed slot on screen, not overflow',
      );
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
