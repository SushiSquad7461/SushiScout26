import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/scouting_form_widget.dart';

void main() {
  group('ScoutingWizardBottomSlot', () {
    testWidgets('renders at the fixed slot width regardless of child size', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ScoutingWizardBottomSlot(child: Text('back')),
                ScoutingWizardBottomSlot(
                  child: FilledButton(onPressed: null, child: Text('submit')),
                ),
              ],
            ),
          ),
        ),
      );

      final sizes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((box) => box.width == kWizardBottomBarSlotWidth)
          .toList();

      expect(sizes.length, 2);
    });
  });

  group('PhaseFlashOverlay', () {
    testWidgets('shows no flash before controller.flash is called', (
      tester,
    ) async {
      final controller = PhaseFlashController();
      await tester.pumpWidget(
        MaterialApp(
          home: PhaseFlashOverlay(
            controller: controller,
            child: const Scaffold(body: Text('content')),
          ),
        ),
      );

      expect(find.text('content'), findsOneWidget);
      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('shows a colored glow once controller.flash is called', (
      tester,
    ) async {
      final controller = PhaseFlashController();
      await tester.pumpWidget(
        MaterialApp(
          home: PhaseFlashOverlay(
            controller: controller,
            child: const Scaffold(body: Text('content')),
          ),
        ),
      );

      controller.flash(Colors.red);
      await tester.pump();

      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      expect(
        decoratedBoxes.any((box) {
          final decoration = box.decoration as BoxDecoration;
          return decoration.border?.top.color == Colors.red;
        }),
        isTrue,
      );
    });

    testWidgets('the glow ignores pointer events', (tester) async {
      final controller = PhaseFlashController();
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PhaseFlashOverlay(
            controller: controller,
            child: Scaffold(
              body: GestureDetector(
                // Opaque, so an empty SizedBox still registers the tap —
                // GestureDetector defaults to deferToChild, and an
                // uncolored child never self-registers a hit.
                behavior: HitTestBehavior.opaque,
                onTap: () => tapped = true,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      controller.flash(Colors.red);
      await tester.pump();

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });
  });
}
