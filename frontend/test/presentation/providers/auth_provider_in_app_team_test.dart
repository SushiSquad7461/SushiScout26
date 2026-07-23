import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/data/models/team.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/team_repository.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';

import 'auth_provider_in_app_team_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<AuthService>(),
  MockSpec<AuthRepository>(),
  MockSpec<TeamRepository>(),
  MockSpec<User>(),
])
void main() {
  late ProviderContainer container;
  late MockAuthService mockAuthService;
  late MockAuthRepository mockAuthRepository;
  late MockTeamRepository mockTeamRepository;

  Team team(String id) => Team(
        id: id,
        name: 'Team $id',
        inviteCode: 'CODE$id',
        createdBy: 'alice',
        createdAt: DateTime(2026, 1, 1),
        memberCount: 3,
      );

  setUp(() {
    mockAuthService = MockAuthService();
    mockAuthRepository = MockAuthRepository();
    mockTeamRepository = MockTeamRepository();
    container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(mockAuthService),
      authRepositoryProvider.overrideWithValue(mockAuthRepository),
      teamRepositoryProvider.overrideWithValue(mockTeamRepository),
    ]);
    when(mockAuthRepository.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
    final mockUser = MockUser();
    when(mockUser.uid).thenReturn('alice');
    when(mockAuthRepository.currentUser).thenReturn(mockUser);
    // _loadUserProfile runs mid-flow; keep it on a benign no-profile path so
    // it doesn't throw. (It won't overwrite our asserted currentTeamId because
    // switchTeam runs AFTER it.)
    when(mockAuthRepository.getCurrentUserProfile()).thenAnswer((_) async => null);
    when(mockAuthRepository.updateCurrentTeamId(any)).thenAnswer((_) async {});
    when(mockAuthService.forceRefreshClaims())
        .thenAnswer((_) async => {'teams': {'teamB': 'admin'}});
  });

  tearDown(() => container.dispose());

  void seedAuthed() {
    container.read(authProvider.notifier).state = container
        .read(authProvider)
        .copyWith(
          status: AuthStatus.authenticated,
          userId: 'alice',
          currentTeamId: 'teamA',
          teamMemberships: {'teamA': 'admin'},
        );
  }

  group('joinTeamInApp', () {
    test('joins, then auto-switches active team without ever going loading',
        () async {
      when(mockTeamRepository.joinTeamByCode(
        inviteCode: anyNamed('inviteCode'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async => team('teamB'));
      when(mockTeamRepository.getTeam('teamB'))
          .thenAnswer((_) async => team('teamB'));
      seedAuthed();

      final seen = <AuthStatus>[];
      container.listen(authProvider, (_, next) => seen.add(next.status));

      await container.read(authProvider.notifier).joinTeamInApp('CODE');

      verify(mockTeamRepository.joinTeamByCode(
              inviteCode: 'CODE', userId: 'alice'))
          .called(1);
      expect(container.read(authProvider).currentTeamId, 'teamB');
      expect(seen.contains(AuthStatus.loading), isFalse);
      expect(seen.contains(AuthStatus.error), isFalse);
    });

    test('rethrows on failure and leaves status authenticated', () async {
      when(mockTeamRepository.joinTeamByCode(
        inviteCode: anyNamed('inviteCode'),
        userId: anyNamed('userId'),
      )).thenThrow(Exception('bad code'));
      seedAuthed();

      await expectLater(
        container.read(authProvider.notifier).joinTeamInApp('NOPE'),
        throwsA(isA<Exception>()),
      );
      expect(container.read(authProvider).status, AuthStatus.authenticated);
    });
  });

  group('createTeamInApp', () {
    test('creates, then auto-switches active team without going loading',
        () async {
      when(mockTeamRepository.createTeam(
        name: anyNamed('name'),
        createdBy: anyNamed('createdBy'),
        isMasterTeam: anyNamed('isMasterTeam'),
      )).thenAnswer((_) async => team('teamB'));
      when(mockTeamRepository.getTeam('teamB'))
          .thenAnswer((_) async => team('teamB'));
      seedAuthed();

      final seen = <AuthStatus>[];
      container.listen(authProvider, (_, next) => seen.add(next.status));

      await container.read(authProvider.notifier).createTeamInApp('New Team');

      verify(mockTeamRepository.createTeam(
              name: 'New Team', createdBy: 'alice', isMasterTeam: false))
          .called(1);
      expect(container.read(authProvider).currentTeamId, 'teamB');
      expect(seen.contains(AuthStatus.loading), isFalse);
      expect(seen.contains(AuthStatus.error), isFalse);
    });
  });
}
