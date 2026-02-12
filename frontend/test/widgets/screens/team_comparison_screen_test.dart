import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/repositories/hybrid_repository.dart';
import 'package:frontend/presentation/screens/team_comparison_screen.dart';
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

  testWidgets('TeamComparisonScreen selects teams and shows data', (tester) async {
    // Arrange
    final match1 = MatchReport(
      id: '1',
      matchId: 'm1',
      matchNumber: 1,
      teamNumber: 254,
      alliance: 'Red',
      scouterName: 'Test',
      gameData: {'auto_fuel': 10, 'teleop_fuel': 20, 'defense_rating': 5, 'teleop_tower_level': 3},
      createdAt: DateTime.now(),
    );
    
    final match2 = MatchReport(
      id: '2',
      matchId: 'm2',
      matchNumber: 2,
      teamNumber: 1678,
      alliance: 'Blue',
      scouterName: 'Test',
      gameData: {'auto_fuel': 8, 'teleop_fuel': 18, 'defense_rating': 4, 'teleop_tower_level': 2},
      createdAt: DateTime.now(),
    );

    when(mockRepo.getMatches('2026test'))
        .thenAnswer((_) async => [match1, match2]);

    // Act
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TeamComparisonScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Assert initial state
    expect(find.text('Select two teams to compare'), findsOneWidget);
    
    // Select Team A (254)
    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Team A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('254').last);
    await tester.pumpAndSettle();

    // Select Team B (1678)
    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Team B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1678').last);
    await tester.pumpAndSettle();

    // Assert comparison view
    expect(find.text('Select two teams to compare'), findsNothing);
    
    // Check for stats table
    expect(find.text('Avg Auto'), findsOneWidget);
    // 254 Auto = 10.0
    expect(find.text('10.0'), findsOneWidget);
    // 1678 Auto = 8.0
    expect(find.text('8.0'), findsOneWidget);
  });
}
