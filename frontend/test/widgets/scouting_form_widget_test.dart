import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/match_timer.dart';
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

      // The glow must actually cover the screen, not just exist somewhere
      // in the tree — a DecoratedBox with no child sizes to Size.zero
      // inside a Stack's loose constraints unless explicitly positioned to
      // fill, in which case its border paints nothing.
      final glowSize = tester.getSize(find.byType(DecoratedBox));
      final screenSize = tester.getSize(find.byType(MaterialApp));
      expect(glowSize, screenSize);
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

  group('ScoutingFormBrandBand onPhaseChanged', () {
    testWidgets(
      'invokes onPhaseChanged when the inner MatchTimer crosses a phase boundary',
      (tester) async {
        Color? flashed;
        final timerController = MatchTimerController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Test'),
                bottom: ScoutingFormBrandBand(
                  timerController: timerController,
                  onPhaseChanged: (c) => flashed = c,
                ),
              ),
              body: const SizedBox(),
            ),
          ),
        );

        expect(flashed, isNull);

        // Same technique as match_timer_test.dart's phase-change tests:
        // start the timer, then advance a real duration far enough to
        // cross the AUTO -> TRANSITION boundary (durationless pump() never
        // advances the fake clock, so Timer.periodic would never fire).
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pump(const Duration(seconds: 15));

        expect(find.text('transition'), findsOneWidget);
        expect(flashed, isNotNull);

        timerController.dispose();
      },
    );
  });

  group('RobotDiedTimeAndReason', () {
    testWidgets('shows a "mark now" button when no time is set yet', (
      tester,
    ) async {
      final liveSeconds = ValueNotifier<int>(120);
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RobotDiedTimeAndReason(
              diedAtSeconds: null,
              liveSecondsRemaining: liveSeconds,
              onDiedAtSecondsChanged: (s) => captured = s,
              reasonController: TextEditingController(),
            ),
          ),
        ),
      );

      expect(find.text('mark now'), findsOneWidget);

      await tester.tap(find.text('mark now'));
      await tester.pump();

      expect(captured, 120);
    });

    testWidgets('shows the formatted mm:ss once a time is set', (
      tester,
    ) async {
      final liveSeconds = ValueNotifier<int>(90);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RobotDiedTimeAndReason(
              diedAtSeconds: 65,
              liveSecondsRemaining: liveSeconds,
              onDiedAtSecondsChanged: (_) {},
              reasonController: TextEditingController(),
            ),
          ),
        ),
      );

      expect(find.textContaining('1:05'), findsOneWidget);
    });

    testWidgets('reason text field forwards input to its controller', (
      tester,
    ) async {
      final liveSeconds = ValueNotifier<int>(120);
      final reasonController = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RobotDiedTimeAndReason(
              diedAtSeconds: 100,
              liveSecondsRemaining: liveSeconds,
              onDiedAtSecondsChanged: (_) {},
              reasonController: reasonController,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'defense collision');
      expect(reasonController.text, 'defense collision');
    });
  });

  group('DefenseCauseSelector', () {
    testWidgets('shows the label and both segments', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefenseCauseSelector(cause: null, onChanged: (_) {}),
          ),
        ),
      );

      expect(find.text('cause of defense'), findsOneWidget);
      expect(find.text('robot broke'), findsOneWidget);
      expect(find.text('strategic'), findsOneWidget);
    });

    testWidgets('tapping "robot broke" calls onChanged with broke', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefenseCauseSelector(
              cause: null,
              onChanged: (v) => selected = v,
            ),
          ),
        ),
      );

      await tester.tap(find.text('robot broke'));
      await tester.pump();

      expect(selected, 'broke');
    });

    testWidgets('tapping "strategic" calls onChanged with strategic', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefenseCauseSelector(
              cause: null,
              onChanged: (v) => selected = v,
            ),
          ),
        ),
      );

      await tester.tap(find.text('strategic'));
      await tester.pump();

      expect(selected, 'strategic');
    });

    testWidgets('tapping the already-selected segment deselects it', (
      tester,
    ) async {
      String? selected = 'sentinel-unset';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefenseCauseSelector(
              cause: 'broke',
              onChanged: (v) => selected = v,
            ),
          ),
        ),
      );

      await tester.tap(find.text('robot broke'));
      await tester.pump();

      expect(selected, isNull);
    });
  });
}
