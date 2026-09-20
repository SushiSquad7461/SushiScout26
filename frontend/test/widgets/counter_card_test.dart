import 'package:flutter/gestures.dart';
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
      // Mirrors `value` into local state via StatefulBuilder, so a
      // CounterCard held down across multiple ticks sees its own prior
      // writes on the next tick — matching how a real (Riverpod-backed)
      // caller rebuilds this widget after every onChanged call. Without
      // this, `value` stays frozen at its initial argument, onPressed's
      // closure never sees a fresh base value, and a hold that fires
      // onChanged three times would compute the same `value + 1` each
      // time instead of accumulating.
      int displayValue = value;
      return MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CounterCard(
                label: label,
                value: displayValue,
                onChanged: (v) {
                  setState(() => displayValue = v);
                  onChanged(v);
                },
                helperText: helperText,
                accentColor: accentColor,
                minValue: minValue,
                maxValue: maxValue,
              );
            },
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

    testWidgets('holding the increment button repeats once per second', (
      tester,
    ) async {
      int currentValue = 0;

      await tester.pumpWidget(
        buildTestWidget(
          value: currentValue,
          onChanged: (v) => currentValue = v,
          maxValue: 999,
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.add)),
      );
      await tester.pump(kLongPressTimeout);
      // Pump each second separately, not one 3-second pump. A single
      // multi-second pump elapses the whole fake clock — and fires every
      // due Timer.periodic tick — before the one frame at its end, so all
      // ticks would read the same pre-hold `onPressed` closure. Pumping a
      // frame after each second lets CounterCard rebuild in between, so
      // each tick's onPressed closes over the value the previous tick
      // just wrote.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();

      expect(currentValue, 3);
    });

    testWidgets('releasing the button stops the repeat', (tester) async {
      int currentValue = 0;

      await tester.pumpWidget(
        buildTestWidget(value: currentValue, onChanged: (v) => currentValue = v),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.add)),
      );
      await tester.pump(kLongPressTimeout);
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));

      expect(currentValue, 1);
    });

    testWidgets('a plain tap still increments by one, not by the repeat timer', (
      tester,
    ) async {
      int currentValue = 5;

      await tester.pumpWidget(
        buildTestWidget(value: currentValue, onChanged: (v) => currentValue = v),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(currentValue, 6);
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
