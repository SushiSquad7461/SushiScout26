import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/presentation/screens/statistics_screen.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/repositories/hybrid_repository.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/presentation/theme/app_theme.dart';

// Create a Fake repository since we can't easily run build_runner in this env
class FakeHybridRepository implements HybridRepository {
  final Stream<List<MatchReport>> _matchStream;

  FakeHybridRepository(this._matchStream);

  @override
  Stream<List<MatchReport>> watchMatches(String eventId) {
    return _matchStream;
  }

  // Implement other members with throws UnimplementedError or dummy returns
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      PrefKeys.eventCode: 'test_event',
    });
  });

  testWidgets('StatisticsScreen renders with empty matches', (tester) async {
    final fakeRepo = FakeHybridRepository(Stream.value([]));
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hybridRepositoryProvider.overrideWithValue(fakeRepo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: StatisticsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No matches recorded yet.'), findsOneWidget);
  });

  testWidgets('StatisticsScreen renders with matches', (tester) async {
    final matches = [
      MatchReport(
        id: '1',
        matchId: 'm1',
        matchNumber: 1,
        teamNumber: 1234,
        alliance: 'red',
        scouterName: 'Test',
        gameData: {'auto_fuel': 5, 'teleop_fuel': 10, 'teleop_tower_level': 1, 'defense_rating': 3},
        robotDied: false,
        comments: '',
        images: [],
        createdAt: DateTime.now(),
        isSynced: false,
        isDeleted: false,
      ),
    ];

    final fakeRepo = FakeHybridRepository(Stream.value(matches));
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hybridRepositoryProvider.overrideWithValue(fakeRepo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: StatisticsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Fuel Scoring Trend'), findsOneWidget);
    expect(find.text('Climb Distribution'), findsOneWidget);
    expect(find.text('Avg Auto'), findsOneWidget);
  });
}
