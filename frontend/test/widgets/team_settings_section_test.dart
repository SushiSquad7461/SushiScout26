import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/data/models/team.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/team_repository.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';
import 'package:frontend/presentation/widgets/team_settings_section.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'team_settings_section_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<TeamRepository>(),
  MockSpec<AuthService>(),
  MockSpec<AuthRepository>(),
  MockSpec<User>(),
])
void main() {
  late MockTeamRepository mockTeamRepository;
  late MockAuthService mockAuthService;
  late MockAuthRepository mockAuthRepository;

  Team team(String id, {String? code}) => Team(
        id: id,
        name: 'Team $id',
        inviteCode: code ?? 'CODE$id',
        createdBy: 'alice',
        createdAt: DateTime(2026, 1, 1),
        memberCount: 3,
      );

  setUp(() {
    mockTeamRepository = MockTeamRepository();
    mockAuthService = MockAuthService();
    mockAuthRepository = MockAuthRepository();
    when(mockAuthRepository.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
    final mockUser = MockUser();
    when(mockUser.uid).thenReturn('alice');
    // _loadUserProfile runs mid-flow inside joinTeamInApp/createTeamInApp; it
    // must resolve userId to 'alice' (not null) via currentUser, matching
    // auth_provider_in_app_team_test.dart's pattern, so the switchTeam call
    // that follows isn't a no-op on a wiped userId.
    when(mockAuthRepository.currentUser).thenReturn(mockUser);
    when(mockAuthRepository.getCurrentUserProfile())
        .thenAnswer((_) async => null);
    when(mockAuthRepository.updateCurrentTeamId(any)).thenAnswer((_) async {});
    when(mockAuthService.forceRefreshClaims())
        .thenAnswer((_) async => {'teams': {'teamA': 'admin', 'teamB': 'member'}});
  });

  // Real authProvider + mocked repos; seed an authenticated two-team user.
  ProviderContainer authedContainer({String current = 'teamA'}) {
    final c = ProviderContainer(overrides: [
      teamRepositoryProvider.overrideWithValue(mockTeamRepository),
      authServiceProvider.overrideWithValue(mockAuthService),
      authRepositoryProvider.overrideWithValue(mockAuthRepository),
    ]);
    c.read(authProvider.notifier).state = c.read(authProvider).copyWith(
          status: AuthStatus.authenticated,
          userId: 'alice',
          currentTeamId: current,
          teamMemberships: {'teamA': 'admin', 'teamB': 'member'},
        );
    return c;
  }

  Widget wrap(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: TeamSettingsSection()),
          ),
        ),
      );

  Future<void> grow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows current team name, member count and invite code',
      (tester) async {
    await grow(tester);
    when(mockTeamRepository.getUserTeams('alice'))
        .thenAnswer((_) async => [team('teamA', code: 'ABC123'), team('teamB')]);

    await tester.pumpWidget(wrap(authedContainer()));
    await tester.pumpAndSettle();

    expect(find.text('Team teamA'), findsWidgets);
    expect(find.textContaining('ABC123'), findsOneWidget);
    // Active team teamA -> role 'admin', plus member count.
    expect(find.textContaining('Admin · 3 members'), findsOneWidget);
  });

  testWidgets('invite code is visible and Regenerate shows for an admin',
      (tester) async {
    await grow(tester);
    when(mockTeamRepository.getUserTeams('alice'))
        .thenAnswer((_) async => [team('teamA', code: 'ABC123')]);

    await tester.pumpWidget(wrap(authedContainer()));
    await tester.pumpAndSettle();

    expect(find.textContaining('ABC123'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Regenerate'), findsOneWidget);
  });

  testWidgets('Regenerate is hidden for a non-admin member', (tester) async {
    await grow(tester);
    when(mockTeamRepository.getUserTeams('alice'))
        .thenAnswer((_) async => [team('teamB', code: 'ABC123')]);

    await tester.pumpWidget(wrap(authedContainer(current: 'teamB')));
    await tester.pumpAndSettle();

    // Active team teamB -> role 'member' -> not admin.
    expect(find.textContaining('ABC123'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Regenerate'), findsNothing);
  });

  testWidgets('tapping a non-active team switches the active team',
      (tester) async {
    await grow(tester);
    when(mockTeamRepository.getUserTeams('alice'))
        .thenAnswer((_) async => [team('teamA'), team('teamB')]);
    when(mockTeamRepository.getTeam('teamB'))
        .thenAnswer((_) async => team('teamB'));

    final c = authedContainer(current: 'teamA');
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Team teamB'));
    await tester.pumpAndSettle();

    expect(c.read(authProvider).currentTeamId, 'teamB');
  });

  testWidgets('join with invite code calls the in-app join path',
      (tester) async {
    await grow(tester);
    when(mockTeamRepository.getUserTeams('alice'))
        .thenAnswer((_) async => [team('teamA')]);
    when(mockTeamRepository.joinTeamByCode(
      inviteCode: anyNamed('inviteCode'),
      userId: anyNamed('userId'),
    )).thenAnswer((_) async => team('teamB'));
    when(mockTeamRepository.getTeam('teamB'))
        .thenAnswer((_) async => team('teamB'));

    final c = authedContainer(current: 'teamA');
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Invite code'), 'JOINME');
    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await tester.pumpAndSettle();

    verify(mockTeamRepository.joinTeamByCode(
            inviteCode: 'JOINME', userId: 'alice'))
        .called(1);
    expect(c.read(authProvider).currentTeamId, 'teamB');
  });

  testWidgets('a failed join shows an inline error, not a screen swap',
      (tester) async {
    await grow(tester);
    when(mockTeamRepository.getUserTeams('alice'))
        .thenAnswer((_) async => [team('teamA')]);
    when(mockTeamRepository.joinTeamByCode(
      inviteCode: anyNamed('inviteCode'),
      userId: anyNamed('userId'),
    )).thenThrow(Exception('invalid code'));

    final c = authedContainer(current: 'teamA');
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Invite code'), 'NOPE');
    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await tester.pumpAndSettle();

    expect(find.textContaining('invalid code'), findsOneWidget);
    expect(c.read(authProvider).status, AuthStatus.authenticated);
  });

  testWidgets('a failed switch shows an inline error, not a screen swap',
      (tester) async {
    await grow(tester);
    when(mockTeamRepository.getUserTeams('alice'))
        .thenAnswer((_) async => [team('teamA'), team('teamB')]);
    when(mockTeamRepository.getTeam('teamB')).thenThrow(Exception('offline'));

    final c = authedContainer(current: 'teamA');
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Team teamB'));
    await tester.pumpAndSettle();

    expect(find.textContaining('offline'), findsOneWidget);
    expect(c.read(authProvider).status, AuthStatus.authenticated);
    expect(c.read(authProvider).currentTeamId, 'teamA');
  });

  testWidgets('create rejects a non-numeric team name inline and does not '
      'call createTeam', (tester) async {
    await grow(tester);
    when(mockTeamRepository.getUserTeams('alice'))
        .thenAnswer((_) async => [team('teamA')]);

    final c = authedContainer(current: 'teamA');
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'New team number'), 'Sushi Robotics');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Team number must be 1-5 digits'), findsOneWidget);
    verifyNever(mockTeamRepository.createTeam(
      name: anyNamed('name'),
      createdBy: anyNamed('createdBy'),
      isMasterTeam: anyNamed('isMasterTeam'),
    ));
  });

  testWidgets('create accepts a valid team number and calls createTeam',
      (tester) async {
    await grow(tester);
    when(mockTeamRepository.getUserTeams('alice'))
        .thenAnswer((_) async => [team('teamA')]);
    when(mockTeamRepository.createTeam(
      name: anyNamed('name'),
      createdBy: anyNamed('createdBy'),
      isMasterTeam: anyNamed('isMasterTeam'),
    )).thenAnswer((_) async => team('teamB'));
    when(mockTeamRepository.getTeam('teamB'))
        .thenAnswer((_) async => team('teamB'));

    final c = authedContainer(current: 'teamA');
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'New team number'), '254');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Team number must be 1-5 digits'), findsNothing);
    verify(mockTeamRepository.createTeam(
      name: '254', createdBy: 'alice', isMasterTeam: false,
    )).called(1);
  });
}
