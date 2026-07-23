# Team Settings Section Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Team" section to the settings sheet that lets a signed-in user view their current team + invite code, switch between teams they belong to, and join/create teams — all without leaving the sheet.

**Architecture:** A new `TeamSettingsSection` widget (own file) is embedded in `settings_sheet.dart`. It reads teams from a new reactive `userTeamsProvider` and drives switch/join/create through `AuthNotifier`. Join/create use new `AuthNotifier` methods (`joinTeamInApp`/`createTeamInApp`) that do the real work but never set global `AuthStatus.loading`, so `AuthWrapper` doesn't swap the screen out from under the open modal.

**Tech Stack:** Flutter, Riverpod (Notifier/FutureProvider), mockito for unit/widget tests, `fake_cloud_firestore` (repo tests).

## Global Constraints

- Riverpod providers that react to state changes MUST use `overrideWith((ref) => …)`, never `overrideWithValue()` (per CLAUDE.md). `overrideWithValue` is only acceptable for plain `Provider`s holding a fixed instance (as the existing leave-team test does for repositories).
- Membership is server-authoritative — do NOT add any client write to `users/{uid}.teamMemberships` or `teams/*/members/**`. All membership mutation stays in the existing callables via `TeamRepository`.
- `googleSheetId` and existing Sheets/backfill code are out of scope — do not touch them.
- Conventional Commits: `<type>(frontend): <subject>`, imperative, lowercase, no trailing period, ≤50 chars.
- Run `flutter test` from `frontend/`. Regenerate mocks with `dart run build_runner build --delete-conflicting-outputs` when adding a `@GenerateNiceMocks` spec or a new mocked method.

---

## Existing code this plan builds on (verbatim signatures)

From `frontend/lib/presentation/providers/auth_provider.dart` — `AuthNotifier`:
- `Future<void> switchTeam(String teamId)` — persists `currentTeamId`, updates state, no `loading`.
- `Future<void> joinTeam(String inviteCode)` — sets `status = loading`; used by onboarding only.
- `Future<void> createTeam(String name, {bool isMasterTeam = false})` — sets `status = loading`.
- `Future<void> _loadUserProfile()` — private; reloads profile, sets `status = authenticated`.
- Providers: `currentTeamIdProvider` (`Provider<String?>`), `isTeamAdminProvider` (`Provider<bool>`), `teamRepositoryProvider`, `authServiceProvider`, `authRepositoryProvider`.

From `frontend/lib/data/repositories/team_repository.dart`:
- `Future<List<Team>> getUserTeams(String userId)`
- `Future<Team?> getTeam(String teamId)`
- `Future<Team?> joinTeamByCode({required String inviteCode, required String userId})`
- `Future<Team> createTeam({required String name, required String createdBy, bool isMasterTeam = false})`
- `Future<void> regenerateInviteCode({required String teamId, required String requestingUserId})`

From `frontend/lib/core/auth/claims_refresher.dart`:
- `Future<bool> waitForTeamClaim({required ClaimsFetcher fetchClaims, required String expectedTeamId, ...})`

From `frontend/lib/core/auth/auth_service.dart`:
- `Future<Map<String, dynamic>> forceRefreshClaims()`

`Team` (`frontend/lib/data/models/team.dart`) fields: `id`, `name`, `inviteCode`, `createdBy`, `memberCount`.

`AuthState.copyWith` uses an `_unset` sentinel; seed test state via `copyWith(userId: 'alice', currentTeamId: 'teamA', teamMemberships: {...}, status: AuthStatus.authenticated)`.

---

## File Structure

- **Create** `frontend/lib/presentation/widgets/team_settings_section.dart` — the `TeamSettingsSection` widget.
- **Modify** `frontend/lib/presentation/providers/auth_provider.dart` — add `userTeamsProvider`, `joinTeamInApp`, `createTeamInApp`.
- **Modify** `frontend/lib/presentation/widgets/settings_sheet.dart` — embed the section under a "Team" header.
- **Create** `frontend/test/presentation/providers/auth_provider_in_app_team_test.dart` — notifier unit tests.
- **Create** `frontend/test/widgets/team_settings_section_test.dart` — widget tests.

---

## Task 1: Notifier methods + `userTeamsProvider`

**Files:**
- Modify: `frontend/lib/presentation/providers/auth_provider.dart`
- Test: `frontend/test/presentation/providers/auth_provider_in_app_team_test.dart`

**Interfaces:**
- Consumes: `TeamRepository.getUserTeams/joinTeamByCode/createTeam`, `switchTeam`, `_loadUserProfile`, `waitForTeamClaim`, `forceRefreshClaims`.
- Produces:
  - `final userTeamsProvider = FutureProvider.autoDispose<List<Team>>(...)`
  - `Future<void> AuthNotifier.joinTeamInApp(String inviteCode)` — joins, waits for claim, reloads profile, auto-switches to the joined team. Never sets `status = loading` or `status = error`. Throws on failure.
  - `Future<void> AuthNotifier.createTeamInApp(String name)` — creates, waits for claim, reloads profile, auto-switches to the new team. Never sets `status = loading`/`error`. Throws on failure.

- [ ] **Step 1: Write the failing tests**

Create `frontend/test/presentation/providers/auth_provider_in_app_team_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
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
    when(mockAuthRepository.currentUser).thenReturn(null);
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
```

- [ ] **Step 2: Generate mocks, run tests to verify they fail**

Run: `cd frontend && dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/presentation/providers/auth_provider_in_app_team_test.dart`
Expected: FAIL — `joinTeamInApp`/`createTeamInApp` not defined on `AuthNotifier`.

- [ ] **Step 3: Add `userTeamsProvider` and the two methods**

In `frontend/lib/presentation/providers/auth_provider.dart`, add the import at the top (alongside existing imports):

```dart
import '../../data/models/team.dart';
```

Inside the `AuthNotifier` class, add these two methods (next to `switchTeam`):

```dart
  /// Joins a team from inside the authenticated app. Same work as [joinTeam]
  /// (callable -> wait for claim -> reload profile) but deliberately never
  /// sets `status = loading`/`error`: the caller is the settings sheet, a
  /// modal over the dashboard, and AuthWrapper swaps the whole screen to a
  /// spinner whenever status is loading — which would tear the sheet down.
  /// Reports failure by throwing so the section can show it inline. Auto-
  /// switches the active team to the joined one on success.
  Future<void> joinTeamInApp(String inviteCode) async {
    final userId = state.userId;
    if (userId == null) throw const AuthException('Not signed in');

    final teamRepo = ref.read(teamRepositoryProvider);
    final team = await teamRepo.joinTeamByCode(
      inviteCode: inviteCode,
      userId: userId,
    );
    if (team == null) throw const AuthException('Could not join team');

    await waitForTeamClaim(
      fetchClaims: ref.read(authServiceProvider).forceRefreshClaims,
      expectedTeamId: team.id,
    );
    await _loadUserProfile();
    await switchTeam(team.id);
  }

  /// Creates a team from inside the authenticated app. See [joinTeamInApp]
  /// for why this avoids the global loading/error status. Auto-switches to
  /// the new team on success.
  Future<void> createTeamInApp(String name) async {
    final userId = state.userId;
    if (userId == null) throw const AuthException('Not signed in');

    final teamRepo = ref.read(teamRepositoryProvider);
    final team = await teamRepo.createTeam(name: name, createdBy: userId);

    await waitForTeamClaim(
      fetchClaims: ref.read(authServiceProvider).forceRefreshClaims,
      expectedTeamId: team.id,
    );
    await _loadUserProfile();
    await switchTeam(team.id);
  }
```

At the bottom of the file (with the other top-level providers), add:

```dart
/// Every team the signed-in user belongs to, for the Team settings section.
/// Re-runs when the active team changes (join/create/switch) so the list and
/// the active highlight stay in sync. autoDispose so it refetches each time
/// the settings sheet reopens.
final userTeamsProvider = FutureProvider.autoDispose<List<Team>>((ref) async {
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return const <Team>[];
  ref.watch(currentTeamIdProvider); // refresh when the active team changes
  return ref.read(teamRepositoryProvider).getUserTeams(userId);
});
```

Confirm `AuthException` is imported in this file (it is — used by existing methods). If the `_loadUserProfile` no-profile path in a test would set `needsTeamSelection`, note that `switchTeam` runs afterward and restores `currentTeamId`; the tests assert the final state, so this is fine.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd frontend && flutter test test/presentation/providers/auth_provider_in_app_team_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/presentation/providers/auth_provider.dart \
        frontend/test/presentation/providers/auth_provider_in_app_team_test.dart
git commit -m "feat(frontend): add in-app join/create team + userTeamsProvider"
```

---

## Task 2: `TeamSettingsSection` widget

**Files:**
- Create: `frontend/lib/presentation/widgets/team_settings_section.dart`
- Test: `frontend/test/widgets/team_settings_section_test.dart`

**Interfaces:**
- Consumes: `userTeamsProvider`, `currentTeamIdProvider`, `isTeamAdminProvider`, `authProvider` (`userId`), `AuthNotifier.switchTeam/joinTeamInApp/createTeamInApp`, `TeamRepository.regenerateInviteCode`.
- Produces: `class TeamSettingsSection extends ConsumerStatefulWidget` (const constructor), rendering the full Team section.

**Design notes for the implementer:**
- The active team's invite code is read from the matching `Team` in the `userTeamsProvider` list — no extra fetch.
- After a successful join / create / regenerate, call `ref.invalidate(userTeamsProvider)` so the list and code refresh. (Switch alone refreshes automatically via `currentTeamIdProvider`, but invalidating again is harmless.)
- Join/create show a **local** spinner on their own button (`_busy` bool in State) and render errors inline in a `Text` with `colorScheme.error`. They must NOT read `authProvider.status`.
- Regenerate is admin-only and shows a confirmation dialog first.

- [ ] **Step 1: Write the failing widget tests**

Create `frontend/test/widgets/team_settings_section_test.dart`:

```dart
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
    when(mockAuthRepository.currentUser).thenReturn(null);
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
}
```

- [ ] **Step 2: Generate mocks, run tests to verify they fail**

Run: `cd frontend && dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/widgets/team_settings_section_test.dart`
Expected: FAIL — `team_settings_section.dart` / `TeamSettingsSection` does not exist.

- [ ] **Step 3: Implement the widget**

Create `frontend/lib/presentation/widgets/team_settings_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/team.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// "Team" section of the settings sheet: shows the active team + invite code,
/// lists all teams the user belongs to (tap to switch), and lets the user join
/// or create another team inline. Join/create keep their loading + error state
/// local so the surrounding modal is never torn down (see joinTeamInApp).
class TeamSettingsSection extends ConsumerStatefulWidget {
  const TeamSettingsSection({super.key});

  @override
  ConsumerState<TeamSettingsSection> createState() =>
      _TeamSettingsSectionState();
}

class _TeamSettingsSectionState extends ConsumerState<TeamSettingsSection> {
  final _joinCtrl = TextEditingController();
  final _createCtrl = TextEditingController();
  bool _joining = false;
  bool _creating = false;
  bool _regenerating = false;
  String? _error;

  @override
  void dispose() {
    _joinCtrl.dispose();
    _createCtrl.dispose();
    super.dispose();
  }

  Future<void> _switch(String teamId) async {
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).switchTeam(teamId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _join() async {
    final code = _joinCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).joinTeamInApp(code);
      if (!mounted) return;
      _joinCtrl.clear();
      ref.invalidate(userTeamsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _create() async {
    final name = _createCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).createTeamInApp(name);
      if (!mounted) return;
      _createCtrl.clear();
      ref.invalidate(userTeamsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _regenerate(String teamId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate invite code?'),
        content: const Text(
            'The current code stops working immediately. Anyone with the old '
            'code will no longer be able to join.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Regenerate')),
        ],
      ),
    );
    if (confirmed != true) return;

    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    setState(() {
      _regenerating = true;
      _error = null;
    });
    try {
      await ref.read(teamRepositoryProvider).regenerateInviteCode(
            teamId: teamId,
            requestingUserId: userId,
          );
      if (!mounted) return;
      ref.invalidate(userTeamsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final teamsAsync = ref.watch(userTeamsProvider);
    final currentTeamId = ref.watch(currentTeamIdProvider);
    final isAdmin = ref.watch(isTeamAdminProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        teamsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppTheme.spacingMd),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            "Couldn't load your teams",
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.error),
          ),
          data: (teams) => _buildBody(
              context, teams, currentTeamId, isAdmin, theme, colorScheme),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<Team> teams,
    String? currentTeamId,
    bool isAdmin,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    Team? current;
    for (final t in teams) {
      if (t.id == currentTeamId) current = t;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current team + invite code.
        if (current != null) ...[
          Text(current.name, style: theme.textTheme.titleMedium),
          Text(
            '${isAdmin ? 'Admin' : 'Member'} · ${current.memberCount} members',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Row(
            children: [
              Text('Invite code: ',
                  style: theme.textTheme.bodyMedium),
              SelectableText(
                current.inviteCode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              IconButton(
                tooltip: 'Copy invite code',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: current!.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied')),
                  );
                },
              ),
            ],
          ),
          if (isAdmin)
            TextButton(
              onPressed:
                  _regenerating ? null : () => _regenerate(current!.id),
              child: Text(_regenerating ? 'Regenerating…' : 'Regenerate'),
            ),
          const SizedBox(height: AppTheme.spacingMd),
        ],

        // Team list.
        Text('Your teams',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppTheme.spacingXs),
        ...teams.map((t) {
          final active = t.id == currentTeamId;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(active
                ? Icons.check_circle
                : Icons.circle_outlined),
            title: Text(t.name),
            subtitle: Text('${t.memberCount} members'),
            enabled: !active,
            onTap: active ? null : () => _switch(t.id),
          );
        }),

        const SizedBox(height: AppTheme.spacingMd),

        // Add a team (join / create).
        Text('Add a team',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppTheme.spacingXs),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _joinCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            FilledButton(
              onPressed: _joining ? null : _join,
              child: _joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Join'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _createCtrl,
                decoration: const InputDecoration(
                  labelText: 'New team name',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            OutlinedButton(
              onPressed: _creating ? null : _create,
              child: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd frontend && flutter test test/widgets/team_settings_section_test.dart`
Expected: PASS (6 tests). If the "shows current team name" test finds `Team teamA` in both the header and the list (`findsWidgets` allows that), that's intentional.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/presentation/widgets/team_settings_section.dart \
        frontend/test/widgets/team_settings_section_test.dart
git commit -m "feat(frontend): add team settings section widget"
```

---

## Task 3: Embed the section in the settings sheet

**Files:**
- Modify: `frontend/lib/presentation/widgets/settings_sheet.dart`
- Test: `frontend/test/widgets/settings_sheet_test.dart`

**Interfaces:**
- Consumes: `TeamSettingsSection` (Task 2).
- Produces: the settings sheet renders a "Team" section between "Appearance" and the admin-only "Sheets export" block.

- [ ] **Step 1: Add a failing test to the existing settings-sheet suite**

In `frontend/test/widgets/settings_sheet_test.dart`, the existing `baseOverrides()` overrides `currentTeamIdProvider` and `teamRepositoryProvider`. The new section also reads `userTeamsProvider`. Add an override so the section renders deterministically. Add this import near the top:

```dart
import 'package:frontend/data/models/team.dart';
```

Then extend `baseOverrides()` to include the teams list (add the line inside the returned list):

```dart
      userTeamsProvider.overrideWith((ref) async => [
            Team(
              id: 'team1',
              name: 'Team One',
              inviteCode: 'ABC123',
              createdBy: 'alice',
              createdAt: DateTime(2026, 1, 1),
              memberCount: 4,
            ),
          ]),
```

Add this test to the file (inside `main`):

```dart
  testWidgets('shows the Team section', (tester) async {
    await growViewport(tester);
    when(mockTeamRepository.getUserTeams(any)).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(await baseOverrides()));
    await tester.pumpAndSettle();

    expect(find.text('Team'), findsOneWidget);
    expect(find.textContaining('ABC123'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/widgets/settings_sheet_test.dart -n "shows the Team section"`
Expected: FAIL — no `Team` header / `ABC123` yet (also a compile error until the import + override resolve, which they now do, so the failure is the missing UI).

- [ ] **Step 3: Embed the section**

In `frontend/lib/presentation/widgets/settings_sheet.dart`, add the import at the top with the other relative imports:

```dart
import 'team_settings_section.dart';
```

Then insert the section into the build tree, immediately after the Appearance block's `_buildColorSelector(context)` and before the `if (ref.watch(isTeamAdminProvider)) ...[` Sheets export block. Locate:

```dart
            _buildColorSelector(context),

            if (ref.watch(isTeamAdminProvider)) ...[
```

Replace it with:

```dart
            _buildColorSelector(context),

            const SizedBox(height: AppTheme.spacingXl),

            // Team section (current team, invite code, switch/join/create).
            const TeamSettingsSection(),

            if (ref.watch(isTeamAdminProvider)) ...[
```

- [ ] **Step 4: Run the settings-sheet suite to verify it passes**

Run: `cd frontend && flutter test test/widgets/settings_sheet_test.dart`
Expected: PASS (all existing tests + the new "shows the Team section").

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/presentation/widgets/settings_sheet.dart \
        frontend/test/widgets/settings_sheet_test.dart
git commit -m "feat(frontend): show team section in settings sheet"
```

---

## Task 4: Full-suite verification

**Files:** none (verification only).

- [ ] **Step 1: Run the whole Dart suite**

Run: `cd frontend && flutter test`
Expected: PASS — all tests (existing 340 + the new ones from Tasks 1–3) green.

- [ ] **Step 2: Analyze**

Run: `cd frontend && flutter analyze`
Expected: No new errors/warnings in the created/modified files.

- [ ] **Step 3: Commit any analyzer fixups (only if needed)**

```bash
git add -A && git commit -m "chore(frontend): clean up team settings analyzer nits"
```

---

## Self-Review Notes (author)

- **Spec coverage:** view current team + role/member count → Task 2 body; invite code visible to all, admin-only regenerate → Task 2 (`isAdmin` gating) + rules already permit regen; switch between teams → Task 2 list + `switchTeam`; join/create in-app without screen swap → Task 1 (`joinTeamInApp`/`createTeamInApp`, no `loading` status) + Task 2 UI; auto-switch on join/create → Task 1 (`switchTeam` after); inline expandable add-team → Task 2 fields; reactive list → `userTeamsProvider` (Task 1); embed in sheet → Task 3; tests → Tasks 1–3; full verification → Task 4.
- **No backend/rules changes** — consistent with spec "Out of scope".
- **Type consistency:** `joinTeamInApp(String)`, `createTeamInApp(String)`, `userTeamsProvider` (`FutureProvider.autoDispose<List<Team>>`), `TeamSettingsSection` const widget — names identical across tasks. `regenerateInviteCode({teamId, requestingUserId})` matches the repo. `switchTeam(String)` matches existing.
- **Role display:** the current team's role (Admin/Member) is shown on the current-team line via `isTeamAdminProvider` (active-team admin status), honoring the spec. Per-row role on non-active teams is intentionally omitted (spec only asked for role on the current team) to avoid extra per-team lookups.
```
