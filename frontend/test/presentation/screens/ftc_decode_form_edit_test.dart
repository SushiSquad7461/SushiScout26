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
import 'package:frontend/presentation/widgets/counter_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<Widget> buildForm({MatchReport? existingMatch}) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
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
  });
}
