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
import 'package:frontend/presentation/screens/frc_rebuilt_form.dart';
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

const _eventId = 'teamA_2026test';

MatchReport _frcMatch({String id = 'm1'}) {
  return MatchReport(
    id: id,
    matchId: '${_eventId}_qm1',
    matchNumber: 1,
    teamNumber: 4198,
    alliance: 'Red',
    scouterName: 'original scout',
    gameData: {
      'auto_fuel': 3,
      'auto_tower_l1': true,
      'teleop_fuel': 7,
      'teleop_tower_level': 2,
      'defense_rating': 4,
      'driver_skill': 5,
      'robot_died': false,
      'trench_traverse': true,
      'bump_traverse': false,
      'shooting_range_close': true,
      'shooting_range_mid': false,
      'shooting_range_far': false,
    },
    comments: 'played great defense',
    createdAt: DateTime(2026, 7, 22),
    eventId: _eventId,
    teamId: 'teamA',
    programType: 'FRC',
  );
}

final _event = Event(
  id: _eventId,
  name: '2026 Test Event',
  programType: 'FRC',
  tbaKey: '2026test',
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
        home: FrcRebuiltForm(
          eventId: _eventId,
          event: _event,
          existingMatch: existingMatch,
        ),
      ),
    );
  }

  group('FrcRebuiltForm edit mode', () {
    testWidgets(
      'skips the setup page and opens directly on autonomous with prefilled values',
      (tester) async {
        await tester.pumpWidget(await buildForm(existingMatch: _frcMatch()));
        await tester.pumpAndSettle();

        expect(find.text('setup'), findsNothing);
        expect(find.text('autonomous'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);

        expect(
          find.descendant(
            of: find.byType(CounterCard),
            matching: find.text('3'),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );
      },
    );

    testWidgets('the final page button reads save, not submit', (
      tester,
    ) async {
      await tester.pumpWidget(await buildForm(existingMatch: _frcMatch()));
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('save'), findsOneWidget);
      expect(find.text('submit'), findsNothing);
    });

    testWidgets(
      'saving updates the existing document instead of creating a new one',
      (tester) async {
        await repo.createMatch(_eventId, _frcMatch());

        await tester.pumpWidget(await buildForm(existingMatch: _frcMatch()));
        await tester.pumpAndSettle();

        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('next'));
          await tester.pumpAndSettle();
        }

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
            existingMatch: _frcMatch(),
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
  });
}
