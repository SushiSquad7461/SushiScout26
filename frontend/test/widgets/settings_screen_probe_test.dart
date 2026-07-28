import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/data/local/preferences.dart';
import 'package:frontend/data/models/team.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/team_repository.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';
import 'package:frontend/presentation/screens/settings_screen.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/theme/team_brand.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_screen_probe_test.mocks.dart';

/// Reproduces the reported "garbled settings page" as an admin with a saved
/// sheet id, at the reporting device's logical size (1280x2856 @480dpi).
@GenerateNiceMocks([
  MockSpec<TeamRepository>(),
  MockSpec<AuthService>(),
  MockSpec<AuthRepository>(),
  MockSpec<User>(),
])
void main() {
  const brand = TeamBrands.fallback;
  const sheetId = 'hWGtisWeGpJh3g3FVlfKcQMb5rjyEjq_XhA-OeTvIOs';

  late MockTeamRepository teamRepo;
  late MockAuthService authService;
  late MockAuthRepository authRepo;

  setUp(() {
    teamRepo = MockTeamRepository();
    authService = MockAuthService();
    authRepo = MockAuthRepository();
    when(authRepo.authStateChanges).thenAnswer((_) => const Stream.empty());
    final user = MockUser();
    when(user.uid).thenReturn('alice');
    when(authRepo.currentUser).thenReturn(user);
    when(authRepo.getCurrentUserProfile()).thenAnswer((_) async => null);
    when(teamRepo.getTeam(any)).thenAnswer(
      (_) async => Team(
        id: 'teamA',
        name: 'Team 7461',
        inviteCode: 'CODE',
        createdBy: 'alice',
        createdAt: DateTime(2026, 1, 1),
        memberCount: 3,
      ),
    );
    when(teamRepo.getTeamSettings(any)).thenAnswer(
      (_) async => TeamSettings(
        teamId: 'teamA',
        googleSheetId: sheetId,
        createdBy: 'alice',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  });

  testWidgets('settings screen lays out without overflow', (tester) async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.scouterName: 'Varun',
      PrefKeys.eventCode: '2026TEST',
      PrefKeys.programType: 'FRC',
    });
    final prefs = await SharedPreferences.getInstance();

    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1280, 2856);
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        teamRepositoryProvider.overrideWithValue(teamRepo),
        authServiceProvider.overrideWithValue(authService),
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
    );
    addTearDown(container.dispose);
    container.read(authProvider.notifier).state = container
        .read(authProvider)
        .copyWith(
          status: AuthStatus.authenticated,
          userId: 'alice',
          currentTeamId: 'teamA',
          teamMemberships: {'teamA': 'admin'},
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(brand),
          home: const BrandScope(brand: brand, child: SettingsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.takeException(),
      isNull,
      reason: 'settings screen threw a layout error',
    );
  });
}
