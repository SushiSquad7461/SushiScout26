import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/repositories/providers.dart';
import 'package:frontend/presentation/screens/match_details.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/theme/team_brand.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _eventId = 'teamA_2026test';
const _brand = TeamBrands.fallback;

MatchReport _frcMatch() {
  return MatchReport(
    id: 'm1',
    matchId: '${_eventId}_qm1',
    matchNumber: 1,
    teamNumber: 4198,
    alliance: 'Red',
    scouterName: 'original scout',
    gameData: {'auto_fuel': 3, 'teleop_fuel': 7},
    comments: '',
    createdAt: DateTime(2026, 7, 22),
    eventId: _eventId,
    teamId: 'teamA',
    programType: 'FRC',
  );
}

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(fake, teamId: 'teamA');
    await fake.collection('events').doc(_eventId).set({
      'name': '2026 Test Event',
      'programType': 'FRC',
      'tbaKey': '2026test',
      'startDate': Timestamp.fromDate(DateTime(2026, 7, 1)),
      'teamId': 'teamA',
    });
  });

  testWidgets(
    'tapping the edit icon opens the wizard, and saving pops back past the details screen',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final match = _frcMatch();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            firestoreRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(_brand),
            home: BrandScope(
              brand: _brand,
              child: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MatchDetailsScreen(match: match),
                        ),
                      ),
                      child: const Text('open details'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open details'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('autonomous'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('next'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(find.text('open details'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping edit on a legacy match with no eventId shows an error instead of a broken wizard',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final match = _frcMatch().copyWith(eventId: '');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            firestoreRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(_brand),
            home: BrandScope(
              brand: _brand,
              child: MatchDetailsScreen(match: match),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // No wizard opened — its app bar title never appears — and the scout
      // was told why. ("autonomous" isn't a safe negative check here: the
      // details screen itself has a same-named section card.)
      expect(find.textContaining('edit •'), findsNothing);
      expect(find.textContaining("Can't edit this match"), findsOneWidget);
    },
  );
}
