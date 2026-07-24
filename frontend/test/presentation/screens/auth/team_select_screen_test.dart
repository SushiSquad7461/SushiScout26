import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/team_repository.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';
import 'package:frontend/presentation/screens/auth/team_select_screen.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'team_select_screen_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<TeamRepository>(),
  MockSpec<AuthService>(),
  MockSpec<AuthRepository>(),
])
void main() {
  late MockTeamRepository mockTeamRepository;
  late MockAuthService mockAuthService;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockTeamRepository = MockTeamRepository();
    mockAuthService = MockAuthService();
    mockAuthRepository = MockAuthRepository();
    when(mockAuthRepository.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
    when(mockAuthRepository.currentUser).thenReturn(null);
    when(mockAuthRepository.getCurrentUserProfile())
        .thenAnswer((_) async => null);
  });

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      teamRepositoryProvider.overrideWithValue(mockTeamRepository),
      authServiceProvider.overrideWithValue(mockAuthService),
      authRepositoryProvider.overrideWithValue(mockAuthRepository),
    ]);
    c.read(authProvider.notifier).state = c.read(authProvider).copyWith(
          status: AuthStatus.needsTeamSelection,
          userId: 'alice',
        );
    return c;
  }

  Widget wrap(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: TeamSelectScreen()),
      );

  Future<void> openCreateTab(WidgetTester tester) async {
    await tester.tap(find.text('Create Team'));
    await tester.pumpAndSettle();
  }

  testWidgets('rejects a non-numeric team name inline; does not call createTeam',
      (tester) async {
    final c = container();
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();
    await openCreateTab(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Team Number'), 'Sushi Robotics');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Team'));
    await tester.pumpAndSettle();

    expect(find.text('Team number must be 1-5 digits'), findsOneWidget);
    verifyNever(mockTeamRepository.createTeam(
      name: anyNamed('name'),
      createdBy: anyNamed('createdBy'),
      isMasterTeam: anyNamed('isMasterTeam'),
    ));
  });
}
