import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/repositories/hybrid_repository.dart';
import 'package:frontend/presentation/screens/statistics_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  late MockHybridRepository mockRepo;
  late ProviderContainer container;

  setUp(() async {
    mockRepo = MockHybridRepository();
    SharedPreferences.setMockInitialValues({
      PrefKeys.eventCode: '2026test',
    });
    
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        hybridRepositoryProvider.overrideWithValue(mockRepo),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  testWidgets('StatisticsScreen shows charts when data is available', (tester) async {
    // Arrange
    final match1 = MatchReport(
      id: '1',
      matchId: 'm1',
      matchNumber: 1,
      teamNumber: 254,
      alliance: 'Red',
      scouterName: 'Test',
      gameData: {'auto_fuel': 5, 'teleop_fuel': 10, 'teleop_tower_level': 3, 'defense_rating': 4},
      createdAt: DateTime.now(),
    );
    
    final match2 = MatchReport(
      id: '2',
      matchId: 'm2',
      matchNumber: 2,
      teamNumber: 1678,
      alliance: 'Blue',
      scouterName: 'Test',
      gameData: {'auto_fuel': 6, 'teleop_fuel': 12, 'teleop_tower_level': 2, 'defense_rating': 3},
      createdAt: DateTime.now(),
    );

    when(mockRepo.getMatches('2026test'))
        .thenAnswer((_) async => [match1, match2]);

    // Act
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StatisticsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Fuel Scoring Trend'), findsOneWidget);
    expect(find.text('Climb Distribution'), findsOneWidget);
    expect(find.text('Avg Auto'), findsOneWidget);
    
    // Check calculations (Avg Auto = (5+6)/2 = 5.5)
    expect(find.text('5.5'), findsOneWidget);
    // Avg Teleop = (10+12)/2 = 11.0
    expect(find.text('11.0'), findsOneWidget);
  });

  testWidgets('StatisticsScreen shows empty state when no matches', (tester) async {
    // Arrange
    when(mockRepo.getMatches('2026test'))
        .thenAnswer((_) async => []);

    // Act
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StatisticsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('No matches recorded yet.'), findsOneWidget);
  });
}
