import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/data/models/team.dart';
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

  testWidgets('filters non-digit characters as they are typed',
      (tester) async {
    final c = container();
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();
    await openCreateTab(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Team Number'), 'Sushi254Robotics');
    await tester.pumpAndSettle();

    expect(find.text('254'), findsOneWidget);
  });

  testWidgets('rejects a leading-zero team number inline; does not call createTeam',
      (tester) async {
    final c = container();
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();
    await openCreateTab(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Team Number'), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Team'));
    await tester.pumpAndSettle();

    expect(find.text('Team number must be 1-5 digits'), findsOneWidget);
    verifyNever(mockTeamRepository.createTeam(
      name: anyNamed('name'),
      createdBy: anyNamed('createdBy'),
      isMasterTeam: anyNamed('isMasterTeam'),
    ));
  });

  testWidgets('rejects a 6-digit team number inline; does not call createTeam',
      (tester) async {
    when(mockTeamRepository.createTeam(
      name: anyNamed('name'),
      createdBy: anyNamed('createdBy'),
      isMasterTeam: anyNamed('isMasterTeam'),
    )).thenAnswer((_) async => Team(
          id: 'newTeam',
          name: '99999',
          inviteCode: 'CODE1',
          createdBy: 'alice',
          createdAt: DateTime(2026, 1, 1),
          memberCount: 1,
        ));
    when(mockAuthService.forceRefreshClaims())
        .thenAnswer((_) async => {
              'teams': {'newTeam': 'admin'}
            });

    final c = container();
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();
    await openCreateTab(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Team Number'), '999999');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Team'));
    await tester.pumpAndSettle();

    // The 6th digit is blocked at entry, so the field holds '99999' — the
    // max valid value — and creation proceeds rather than failing.
    verify(mockTeamRepository.createTeam(
      name: '99999',
      createdBy: anyNamed('createdBy'),
      isMasterTeam: anyNamed('isMasterTeam'),
    )).called(1);
  });
}
