import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/data/models/event.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/repositories/providers.dart';
import 'package:frontend/presentation/screens/ftc_decode_form.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/widgets/counter_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository whose write path always fails the way Firestore does when a
/// scout is offline on a device that never cached the event doc (e.g. a
/// fresh mobile-web session): a raw [FirebaseException], not an [AppError].
class _OfflineUnavailableRepository extends FirestoreRepository {
  _OfflineUnavailableRepository(super.firestore, {super.teamId});

  Never _throwUnavailable() => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'unavailable',
    message: 'Failed to get document because the client is offline.',
  );

  @override
  Future<void> createMatch(String eventId, MatchReport match) async =>
      _throwUnavailable();

  @override
  Future<void> updateMatch(String eventId, MatchReport match) async =>
      _throwUnavailable();
}

const _eventId = 'teamA_2026ftc';

MatchReport _ftcMatch({String id = 'm1'}) {
  return MatchReport(
    id: id,
    matchId: '${_eventId}_qm1',
    matchNumber: 1,
    teamNumber: 4198,
    alliance: 'Blue',
    scouterName: 'original scout',
    gameData: {
      'leave': true,
      'artifacts_auto': 5,
      'indexing_auto': true,
      'artifacts_teleop': 9,
      'indexing_teleop': false,
      'base_expansion': 'Full',
      'driver_quality': 4.0,
      'robot_died': false,
    },
    comments: 'consistent scoring',
    createdAt: DateTime(2026, 7, 22),
    eventId: _eventId,
    teamId: 'teamA',
    programType: 'FTC',
  );
}

final _event = Event(
  id: _eventId,
  name: '2026 FTC Test Event',
  programType: 'FTC',
  tbaKey: '2026ftc',
  startDate: DateTime(2026, 7, 1),
  teamId: 'teamA',
);

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(fake, teamId: 'teamA');
  });

  Future<Widget> buildForm({
    MatchReport? existingMatch,
    FirestoreRepository? repoOverride,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreRepositoryProvider.overrideWithValue(repoOverride ?? repo),
      ],
      child: MaterialApp(
        // The app's real theme, not MaterialApp's default one: the review
        // banner colour bug only shows up under AppTheme's hand-written
        // colour scheme.
        theme: AppTheme.dark(AppTheme.brandFor(null)),
        home: FtcDecodeForm(
          eventId: _eventId,
          event: _event,
          existingMatch: existingMatch,
        ),
      ),
    );
  }

  group('FtcDecodeForm edit mode', () {
    testWidgets(
      'skips the setup page and opens directly on autonomous with prefilled values',
      (tester) async {
        await tester.pumpWidget(await buildForm(existingMatch: _ftcMatch()));
        await tester.pumpAndSettle();

        expect(find.text('setup'), findsNothing);
        expect(find.text('autonomous'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);

        expect(
          find.descendant(
            of: find.byType(CounterCard),
            matching: find.text('5'),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue,
        );
      },
    );

    testWidgets(
      'saving updates the existing document instead of creating a new one',
      (tester) async {
        await repo.createMatch(_eventId, _ftcMatch());

        await tester.pumpWidget(await buildForm(existingMatch: _ftcMatch()));
        await tester.pumpAndSettle();

        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('next'));
          await tester.pumpAndSettle();
        }

        expect(find.text('save'), findsOneWidget);
        await tester.tap(find.text('save'));
        await tester.pumpAndSettle();

        final matches = await repo.getMatches(_eventId);
        expect(matches, hasLength(1));
        expect(matches.single.id, 'm1');
      },
    );

    testWidgets(
      'a raw FirebaseException on save shows a friendly message, not the exception text',
      (tester) async {
        await tester.pumpWidget(
          await buildForm(
            existingMatch: _ftcMatch(),
            repoOverride: _OfflineUnavailableRepository(fake, teamId: 'teamA'),
          ),
        );
        await tester.pumpAndSettle();

        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('next'));
          await tester.pumpAndSettle();
        }

        await tester.tap(find.text('save'));
        await tester.pump();

        expect(find.textContaining('cloud_firestore'), findsNothing);
        expect(find.textContaining('client is offline'), findsNothing);
        expect(
          find.textContaining('check your internet'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the robot died banner text is legible against its own background',
      (tester) async {
        final match = _ftcMatch();
        final diedMatch = match.copyWith(
          gameData: {...match.gameData, 'robot_died': true},
        );

        await tester.pumpWidget(await buildForm(existingMatch: diedMatch));
        await tester.pumpAndSettle();

        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('next'));
          await tester.pumpAndSettle();
        }

        final textFinder = find.text('Robot Died');
        expect(textFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(textFinder);
        final container = tester.widget<Container>(
          find
              .ancestor(of: textFinder, matching: find.byType(Container))
              .first,
        );
        final background = (container.decoration as BoxDecoration).color!;
        final foreground = textWidget.style!.color!;

        final bgLuminance = background.computeLuminance();
        final fgLuminance = foreground.computeLuminance();
        final contrastRatio =
            (max(bgLuminance, fgLuminance) + 0.05) /
            (min(bgLuminance, fgLuminance) + 0.05);

        expect(
          contrastRatio,
          greaterThanOrEqualTo(3.0),
          reason:
              'Robot Died banner text must be legible against its own '
              'background, not just invisible-but-technically-present',
        );
      },
    );

    testWidgets(
      'restores a saved died-at time and reason, and lets the scout edit the reason',
      (tester) async {
        final match = _ftcMatch();
        final diedMatch = match.copyWith(
          gameData: {
            ...match.gameData,
            'robot_died': true,
            'died_at_seconds': 65,
            'died_reason': 'tipped over on the ramp',
          },
        );

        await tester.pumpWidget(await buildForm(existingMatch: diedMatch));
        await tester.pumpAndSettle();

        // Edit mode's 4 pages are autonomous(0) -> teleop(1) -> endgame(2)
        // -> review(3) — one tap of "next" from the initial page reaches
        // teleop, where the Robot Died toggle and this control live.
        await tester.tap(find.text('next'));
        await tester.pumpAndSettle();

        expect(find.textContaining('1:05'), findsOneWidget);
        expect(find.text('tipped over on the ramp'), findsOneWidget);
      },
    );

    testWidgets(
      'saving with the died time and reason set writes both into gameData',
      (tester) async {
        await repo.createMatch(_eventId, _ftcMatch());

        await tester.pumpWidget(await buildForm(existingMatch: _ftcMatch()));
        await tester.pumpAndSettle();

        // One tap reaches teleop, where the Robot Died toggle lives.
        await tester.tap(find.text('next'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Robot Died / Disabled'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('mark now'));
        await tester.tap(find.text('mark now'));
        await tester.pumpAndSettle();
        final reasonField = find.widgetWithText(TextField, 'Reason (optional)');
        await tester.ensureVisible(reasonField);
        await tester.enterText(reasonField, 'wheel fell off');
        await tester.pumpAndSettle();

        // Two more taps of "next" reach review, where "save" lives.
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('next'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('save'));
        await tester.pumpAndSettle();

        final matches = await repo.getMatches(_eventId);
        expect(matches, hasLength(1));
        // The timer was never started, so it's still at the full duration.
        expect(matches.single.gameData['died_at_seconds'], 153);
        expect(matches.single.gameData['died_reason'], 'wheel fell off');
      },
    );

    testWidgets(
      'unchecking robot died clears a previously set died time and reason before save',
      (tester) async {
        await repo.createMatch(_eventId, _ftcMatch());

        final match = _ftcMatch();
        final diedMatch = match.copyWith(
          gameData: {
            ...match.gameData,
            'robot_died': true,
            'died_at_seconds': 65,
            'died_reason': 'tipped over on the ramp',
          },
        );

        await tester.pumpWidget(await buildForm(existingMatch: diedMatch));
        await tester.pumpAndSettle();

        await tester.tap(find.text('next'));
        await tester.pumpAndSettle();

        // Uncheck the toggle: the control (and its stale values) should
        // no longer be part of what gets submitted.
        await tester.tap(find.text('Robot Died / Disabled'));
        await tester.pumpAndSettle();

        expect(find.textContaining('1:05'), findsNothing);
        expect(find.text('tipped over on the ramp'), findsNothing);

        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('next'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('save'));
        await tester.pumpAndSettle();

        final matches = await repo.getMatches(_eventId);
        expect(matches, hasLength(1));
        expect(matches.single.gameData['died_at_seconds'], isNull);
        expect(matches.single.gameData['died_reason'], '');
      },
    );
  });
}
