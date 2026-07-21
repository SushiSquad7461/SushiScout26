import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/team_repository.dart';

import 'auth_provider_leave_team_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<AuthService>(),
  MockSpec<AuthRepository>(),
  MockSpec<TeamRepository>(),
])
void main() {
  late ProviderContainer container;
  late MockAuthService mockAuthService;
  late MockAuthRepository mockAuthRepository;
  late MockTeamRepository mockTeamRepository;

  setUp(() {
    mockAuthService = MockAuthService();
    mockAuthRepository = MockAuthRepository();
    mockTeamRepository = MockTeamRepository();
    container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(mockAuthService),
      authRepositoryProvider.overrideWithValue(mockAuthRepository),
      teamRepositoryProvider.overrideWithValue(mockTeamRepository),
    ]);

    when(mockAuthRepository.authStateChanges).thenAnswer((_) => const Stream.empty());
    when(mockAuthRepository.currentUser).thenReturn(null);
    // _loadUserProfile is invoked after leaveTeam; give it a no-profile path.
    when(mockAuthRepository.getCurrentUserProfile()).thenAnswer((_) async => null);
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthNotifier.leaveTeam', () {
    test('force-refreshes claims after leaving, before reloading profile', () async {
      when(mockTeamRepository.leaveTeam(
        teamId: anyNamed('teamId'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async {});
      when(mockAuthService.forceRefreshClaims())
          .thenAnswer((_) async => <String, dynamic>{});

      // Seed a userId onto state so leaveTeam doesn't bail out early.
      container.read(authProvider.notifier).state =
          container.read(authProvider).copyWith(userId: 'alice');

      await container.read(authProvider.notifier).leaveTeam('teamA');

      verify(mockTeamRepository.leaveTeam(teamId: 'teamA', userId: 'alice')).called(1);
      verify(mockAuthService.forceRefreshClaims()).called(1);
      verify(mockAuthRepository.getCurrentUserProfile()).called(1);
    });

    test('a failed claims refresh does not prevent the profile reload', () async {
      when(mockTeamRepository.leaveTeam(
        teamId: anyNamed('teamId'),
        userId: anyNamed('userId'),
      )).thenAnswer((_) async {});
      when(mockAuthService.forceRefreshClaims())
          .thenThrow(Exception('token refresh failed'));

      container.read(authProvider.notifier).state =
          container.read(authProvider).copyWith(userId: 'alice');

      await container.read(authProvider.notifier).leaveTeam('teamA');

      verify(mockAuthService.forceRefreshClaims()).called(1);
      // Despite the refresh throwing, the profile reload still ran.
      verify(mockAuthRepository.getCurrentUserProfile()).called(1);
    });
  });
}
