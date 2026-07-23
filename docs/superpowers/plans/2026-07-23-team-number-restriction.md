# Team-Number Restriction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restrict team creation so a new team's name must be a team number (1–5 digits, `1`–`99999`, no leading zeros), enforced on both client create paths and in the `create_team` Cloud Function.

**Architecture:** One shared client validator (`FormValidators.teamName`) is called on submit by both create fields (in-app settings section + onboarding screen), showing an inline error and not calling the create notifier on failure. The `create_team` callable mirrors the same regex as the real server-side guard, raising `INVALID_ARGUMENT`.

**Tech Stack:** Flutter, Riverpod, mockito (Dart tests); Python 3.11 Firebase Functions, unittest (Python tests).

## Global Constraints

- The rule is the regex `^[1-9]\d{0,4}$` (1–5 digits, no leading zeros, `1`–`99999`). Use this EXACT pattern on both client and server.
- Client error message string, used verbatim in code and tests: `Team number must be 1-5 digits` (plain hyphen, not an en-dash). Empty-input message: `Team number is required`.
- Do NOT modify `FormValidators.teamNumber` (used by match reports) or `join_team`.
- Reactive Riverpod providers overridden in tests via `overrideWith((ref) => …)`; plain `Provider`s holding a fixed instance (repos) use `overrideWithValue` (established repo pattern).
- Run `flutter test` from `frontend/`; run `./venv/bin/python -m pytest tests/` (or the repo's pytest invocation) from `functions/`.
- Conventional Commits: `<type>(<scope>): <subject>`, imperative, lowercase, no trailing period, ≤50 chars. Scopes: frontend, backend, test.
- Backend deploy: `firebase deploy --only functions:create_team` (subset avoids the all-secrets-validated blocker).

---

## Existing code this builds on (verbatim)

`frontend/lib/core/validation/form_validators.dart` — a `FormValidators` class of static `String?` validators (`required`, `number`, `teamNumber`, `eventCode`, `compose`).

`create_team` callable (`functions/main.py:361`):
```python
def create_team(req: https_fn.CallableRequest) -> dict:
    if not req.auth:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Must be authenticated")
    data = req.data or {}
    name = data.get('name')
    if not name:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "Missing team name")
    ...
```

`TeamSettingsSection._create` (`frontend/lib/presentation/widgets/team_settings_section.dart`) — reads `_createCtrl.text.trim()`, sets `_creating`/`_error`, calls `ref.read(authProvider.notifier).createTeamInApp(name)`, on success clears the field + invalidates `userTeamsProvider`.

`TeamSelectScreen` create tab (`frontend/lib/presentation/screens/auth/team_select_screen.dart`) — `_teamNameController`, a `FilledButton.icon` whose `onPressed` does `if (name.isNotEmpty) ref.read(authProvider.notifier).createTeam(name)`. Errors render in a container gated on `authState.hasError`.

`create_team` is tested in `functions/tests/test_membership_callables.py`; `_req(uid, data)` builds a mock request, and callables are invoked via `main.create_team.__wrapped__.__wrapped__(...)`. **The existing `test_creates_team_and_sets_admin_claim` passes `{'name': 'Alpha'}`** — invalid under the new rule; Task 4 updates it.

---

## File Structure

- **Modify** `frontend/lib/core/validation/form_validators.dart` — add `teamName`.
- **Modify** `frontend/lib/presentation/widgets/team_settings_section.dart` — validate in `_create`.
- **Modify** `frontend/lib/presentation/screens/auth/team_select_screen.dart` — validate in the create tab, add a local error.
- **Modify** `functions/main.py` — validate `name` in `create_team`.
- **Test**: `frontend/test/unit/validation/form_validators_test.dart` (create or extend), `frontend/test/widgets/team_settings_section_test.dart` (extend), `frontend/test/presentation/screens/auth/team_select_screen_test.dart` (create), `functions/tests/test_membership_callables.py` (extend).

---

## Task 1: `FormValidators.teamName` + unit tests

**Files:**
- Modify: `frontend/lib/core/validation/form_validators.dart`
- Test: `frontend/test/unit/validation/form_validators_test.dart` (create if absent)

**Interfaces:**
- Produces: `static String? FormValidators.teamName(String? value)` — returns `null` when valid, else an error message string.

- [ ] **Step 1: Write the failing test**

Create `frontend/test/unit/validation/form_validators_test.dart` (if it already exists, add this `group` inside its `main`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/validation/form_validators.dart';

void main() {
  group('FormValidators.teamName', () {
    test('accepts 1-5 digit team numbers', () {
      expect(FormValidators.teamName('1'), isNull);
      expect(FormValidators.teamName('254'), isNull);
      expect(FormValidators.teamName('1114'), isNull);
      expect(FormValidators.teamName('99999'), isNull);
      expect(FormValidators.teamName('  254  '), isNull); // trimmed
    });

    test('rejects empty / whitespace with the required message', () {
      expect(FormValidators.teamName(''), 'Team number is required');
      expect(FormValidators.teamName(null), 'Team number is required');
      expect(FormValidators.teamName('   '), 'Team number is required');
    });

    test('rejects non-numeric, too-long, zero, and leading-zero values', () {
      expect(FormValidators.teamName('abc'), 'Team number must be 1-5 digits');
      expect(FormValidators.teamName('12a'), 'Team number must be 1-5 digits');
      expect(FormValidators.teamName('0'), 'Team number must be 1-5 digits');
      expect(FormValidators.teamName('00042'), 'Team number must be 1-5 digits');
      expect(FormValidators.teamName('123456'), 'Team number must be 1-5 digits');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/unit/validation/form_validators_test.dart`
Expected: FAIL — `teamName` is not defined on `FormValidators`.

- [ ] **Step 3: Implement the validator**

In `frontend/lib/core/validation/form_validators.dart`, add this method inside the `FormValidators` class (e.g. after `teamNumber`):

```dart
  /// Validates a team name for team CREATION: must be a team number,
  /// 1-5 digits, no leading zeros (1-99999). Stricter than [teamNumber]
  /// (which allows leading zeros for match-report entry) because a created
  /// team's number is canonical and will later be matched against the
  /// registered-team list.
  static String? teamName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Team number is required';
    if (!RegExp(r'^[1-9]\d{0,4}$').hasMatch(trimmed)) {
      return 'Team number must be 1-5 digits';
    }
    return null;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/unit/validation/form_validators_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/core/validation/form_validators.dart \
        frontend/test/unit/validation/form_validators_test.dart
git commit -m "feat(frontend): add teamName validator (1-5 digits)"
```

---

## Task 2: Enforce in the in-app create field (`TeamSettingsSection`)

**Files:**
- Modify: `frontend/lib/presentation/widgets/team_settings_section.dart`
- Test: `frontend/test/widgets/team_settings_section_test.dart`

**Interfaces:**
- Consumes: `FormValidators.teamName` (Task 1).

- [ ] **Step 1: Write the failing tests**

In `frontend/test/widgets/team_settings_section_test.dart`, add these two tests inside `main` (the helpers `team()`, `grow()`, `authedContainer()`, `wrap()` and `mockTeamRepository` already exist there; add the import if missing: `import 'package:frontend/core/validation/form_validators.dart';` is NOT needed — assert on the visible message text):

```dart
  testWidgets('create rejects a non-numeric team name inline and does not '
      'call createTeam', (tester) async {
    await grow(tester);
    when(mockTeamRepository.getUserTeams('alice'))
        .thenAnswer((_) async => [team('teamA')]);

    final c = authedContainer(current: 'teamA');
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'New team name'), 'Sushi Robotics');
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
        find.widgetWithText(TextField, 'New team name'), '254');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Team number must be 1-5 digits'), findsNothing);
    verify(mockTeamRepository.createTeam(
      name: '254', createdBy: 'alice', isMasterTeam: false,
    )).called(1);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd frontend && flutter test test/widgets/team_settings_section_test.dart -n "create rejects"`
Expected: FAIL — the invalid name is currently passed straight to `createTeamInApp`, so no inline message appears (and `createTeam` IS called).

- [ ] **Step 3: Add the guard to `_create`**

In `frontend/lib/presentation/widgets/team_settings_section.dart`, add the import at the top with the other relative imports:

```dart
import '../../core/validation/form_validators.dart';
```

Then, in the `_create` method, insert the validation immediately after reading and trimming the name and before the `setState(() { _creating = true; ... })` block. The method's top becomes:

```dart
  Future<void> _create() async {
    final name = _createCtrl.text.trim();
    if (name.isEmpty) return;
    final validationError = FormValidators.teamName(name);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    // ... unchanged remainder (await createTeamInApp, clear field, invalidate, catch, finally)
  }
```

(Leave the rest of `_create` exactly as-is.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd frontend && flutter test test/widgets/team_settings_section_test.dart`
Expected: PASS (all existing + the 2 new).

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/presentation/widgets/team_settings_section.dart \
        frontend/test/widgets/team_settings_section_test.dart
git commit -m "feat(frontend): validate team number in create field"
```

---

## Task 3: Enforce in the onboarding create tab (`TeamSelectScreen`)

**Files:**
- Modify: `frontend/lib/presentation/screens/auth/team_select_screen.dart`
- Test: `frontend/test/presentation/screens/auth/team_select_screen_test.dart` (create)

**Interfaces:**
- Consumes: `FormValidators.teamName` (Task 1).

- [ ] **Step 1: Write the failing test**

Create `frontend/test/presentation/screens/auth/team_select_screen_test.dart`:

```dart
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
        find.widgetWithText(TextField, 'Team Name'), 'Sushi Robotics');
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
```

Note: the tab label and the button share the text "Create Team". `find.text('Create Team')` matches both the `Tab` and the `FilledButton`; `openCreateTab` taps the first match (the Tab). The later `find.widgetWithText(FilledButton, 'Create Team')` targets only the button.

- [ ] **Step 2: Generate mocks, run test to verify it fails**

Run: `cd frontend && dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/presentation/screens/auth/team_select_screen_test.dart`
Expected: FAIL — no validation yet, so the invalid name is sent to `createTeam` and no inline message appears.

- [ ] **Step 3: Add validation + local error to the create tab**

In `frontend/lib/presentation/screens/auth/team_select_screen.dart`:

(a) Add the import with the other imports:
```dart
import '../../../core/validation/form_validators.dart';
```

(b) Add a local error field to `_TeamSelectScreenState` (next to the controllers):
```dart
  String? _createError;
```

(c) In `_buildCreateTab`, change the button's `onPressed` to validate and set `_createError`. Replace:
```dart
                : () {
                    final name = _teamNameController.text.trim();
                    if (name.isNotEmpty) {
                      ref.read(authProvider.notifier).createTeam(name);
                    }
                  },
```
with:
```dart
                : () {
                    final name = _teamNameController.text.trim();
                    final error = FormValidators.teamName(name);
                    if (error != null) {
                      setState(() => _createError = error);
                      return;
                    }
                    setState(() => _createError = null);
                    ref.read(authProvider.notifier).createTeam(name);
                  },
```

(d) Render `_createError` in the create tab. In `_buildCreateTab`, immediately BEFORE the existing `if (authState.hasError) ...[` block, add:
```dart
          if (_createError != null) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.spacingSm),
              ),
              child: Text(
                _createError!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/presentation/screens/auth/team_select_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/presentation/screens/auth/team_select_screen.dart \
        frontend/test/presentation/screens/auth/team_select_screen_test.dart
git commit -m "feat(frontend): validate team number on onboarding create"
```

---

## Task 4: Enforce in the `create_team` callable

**Files:**
- Modify: `functions/main.py`
- Test: `functions/tests/test_membership_callables.py`

**Interfaces:**
- Consumes: nothing new (`import re` already present at `functions/main.py:4`).

- [ ] **Step 1: Write/adjust the failing tests**

In `functions/tests/test_membership_callables.py`:

(a) Update the existing happy-path test to use a valid team number — change its request name from `'Alpha'` to `'254'`. Replace:
```python
        result = main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': 'Alpha'}))
```
with:
```python
        result = main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': '254'}))
```

(b) Add rejection tests to the `TestCreateTeam` class:
```python
    def test_rejects_non_numeric_name(self):
        with self.assertRaises(https_fn.HttpsError):
            main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': 'Alpha'}))

    def test_rejects_too_long_name(self):
        with self.assertRaises(https_fn.HttpsError):
            main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': '123456'}))

    def test_rejects_leading_zero_name(self):
        with self.assertRaises(https_fn.HttpsError):
            main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': '00042'}))

    def test_rejects_empty_name(self):
        with self.assertRaises(https_fn.HttpsError):
            main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': ''}))
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `functions/`): `./venv/bin/python -m pytest tests/test_membership_callables.py -k CreateTeam -v`
Expected: the new rejection tests FAIL (no validation yet, so `'Alpha'`/`'123456'`/`'00042'` currently proceed past the name check and raise for other reasons or succeed). `test_rejects_empty_name` already passes (existing `if not name` guard) — that's fine.

- [ ] **Step 3: Add the regex guard to `create_team`**

In `functions/main.py`'s `create_team`, replace:
```python
    data = req.data or {}
    name = data.get('name')
    if not name:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "Missing team name")
```
with:
```python
    data = req.data or {}
    name = (data.get('name') or '').strip()
    if not re.fullmatch(r'[1-9]\d{0,4}', name):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            "Team number must be 1-5 digits")
```

(The batch write already uses `name`; it now stores the stripped, validated value.)

- [ ] **Step 4: Run tests to verify they pass**

Run (from `functions/`): `./venv/bin/python -m pytest tests/test_membership_callables.py -k CreateTeam -v`
Expected: PASS (updated happy-path + 4 rejection tests).

- [ ] **Step 5: Commit**

```bash
git add functions/main.py functions/tests/test_membership_callables.py
git commit -m "feat(backend): require team number on create_team"
```

---

## Task 5: Full verification + deploy

**Files:** none (verification + deploy).

- [ ] **Step 1: Full Dart suite + analyze**

Run: `cd frontend && flutter test`
Expected: all pass (prior count + the new tests).
Run: `cd frontend && flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Full Python suite**

Run (from `functions/`): `./venv/bin/python -m pytest tests/`
Expected: all pass.

- [ ] **Step 3: Deploy the callable**

Run: `firebase deploy --only functions:create_team`
Expected: deploy succeeds. If it fails on a missing secret, that is the all-secrets-validated blocker — the subset `--only functions:create_team` should avoid it; if not, report the exact error rather than deploying everything.

- [ ] **Step 4: Report**

Report the Dart/Python suite results and the deploy outcome (revision or error). No commit.

---

## Self-Review Notes (author)

- **Spec coverage:** rule `^[1-9]\d{0,4}$` → Task 1 (validator) + Task 4 (server); in-app create field → Task 2; onboarding create tab → Task 3; server guard + `INVALID_ARGUMENT` + strip → Task 4; message strings verbatim (Global Constraints); not touching `teamNumber`/`join_team` (Global Constraints); tests at all layers → Tasks 1–4; deploy → Task 5.
- **Type consistency:** `FormValidators.teamName(String?)` used identically in Tasks 2 and 3; message `Team number must be 1-5 digits` and `Team number is required` identical across validator, widgets, and tests; server pattern identical to client (`[1-9]\d{0,4}`).
- **Landmine flagged:** the existing `test_creates_team_and_sets_admin_claim` uses `name: 'Alpha'` (now invalid) — Task 4 Step 1(a) updates it, else the suite breaks.
