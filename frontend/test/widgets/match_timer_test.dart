import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/match_timer.dart';

void main() {
  group('MatchTimer', () {
    // Use a simple theme that doesn't require Google Fonts
    Widget buildTestWidget({
      MatchTimerController? controller,
      VoidCallback? onMatchFinished,
      ValueChanged<Color>? onPhaseChanged,
    }) {
      return MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Test'),
            bottom: MatchTimer(
              controller: controller,
              onMatchFinished: onMatchFinished,
              onPhaseChanged: onPhaseChanged,
            ),
          ),
          body: const SizedBox(),
        ),
      );
    }

    testWidgets('displays initial timer at 2:33', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('2:33'), findsOneWidget);
    });

    testWidgets('displays PRE-MATCH phase initially', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('pre-match'), findsOneWidget);
    });

    testWidgets('shows play button initially', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('toggles to pause button when started', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('timer decrements when running', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('2:31'), findsOneWidget);
    });

    testWidgets('controller can start timer', (tester) async {
      final controller = MatchTimerController();

      await tester.pumpWidget(buildTestWidget(controller: controller));

      expect(find.text('2:33'), findsOneWidget);

      controller.start();
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('phase changes to AUTO when started', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(find.text('auto'), findsOneWidget);
    });

    testWidgets('has proper preferred size', (tester) async {
      const timer = MatchTimer();
      expect(timer.preferredSize, const Size.fromHeight(64));
    });

    testWidgets('progress indicator is present', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('can pause running timer', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Start
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Pause
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('exposes the total duration as a public constant', (
      tester,
    ) async {
      expect(MatchTimer.totalDurationSeconds, 153);
    });

    testWidgets(
      'does not call onPhaseChanged for the initial PRE-MATCH -> AUTO transition',
      (tester) async {
        Color? flashed;
        await tester.pumpWidget(
          buildTestWidget(onPhaseChanged: (c) => flashed = c),
        );

        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pump();

        expect(flashed, isNull);
      },
    );

    testWidgets('calls onPhaseChanged when AUTO changes to TRANSITION', (
      tester,
    ) async {
      Color? flashed;
      await tester.pumpWidget(
        buildTestWidget(onPhaseChanged: (c) => flashed = c),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(seconds: 15));

      expect(find.text('transition'), findsOneWidget);
      expect(flashed, isNotNull);
    });

    testWidgets('calls onPhaseChanged when reset returns the phase to PRE-MATCH', (
      tester,
    ) async {
      Color? flashed;
      await tester.pumpWidget(
        buildTestWidget(onPhaseChanged: (c) => flashed = c),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(seconds: 1));
      flashed = null;

      await tester.tap(find.byIcon(Icons.replay_rounded));
      await tester.pump();

      expect(find.text('pre-match'), findsOneWidget);
      expect(flashed, isNotNull);
    });

    testWidgets("controller's secondsRemaining updates as the timer ticks", (
      tester,
    ) async {
      final controller = MatchTimerController();
      await tester.pumpWidget(buildTestWidget(controller: controller));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(seconds: 3));

      expect(
        controller.secondsRemaining.value,
        MatchTimer.totalDurationSeconds - 3,
      );
    });
  });

  group('MatchTimerController', () {
    test('secondsRemaining starts at the total match duration', () {
      final controller = MatchTimerController();
      expect(controller.secondsRemaining.value, MatchTimer.totalDurationSeconds);
    });

    test('notifies listeners when start is called', () {
      final controller = MatchTimerController();
      bool wasNotified = false;

      controller.addListener(() {
        wasNotified = true;
      });

      controller.start();

      expect(wasNotified, isTrue);
    });

    test('can add and remove listeners', () {
      final controller = MatchTimerController();
      int callCount = 0;

      void listener() => callCount++;

      controller.addListener(listener);
      controller.start();
      expect(callCount, 1);

      controller.removeListener(listener);
      controller.start();
      expect(callCount, 1); // Still 1, listener was removed
    });
  });
}
