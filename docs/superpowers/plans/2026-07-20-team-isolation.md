# Team Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make multiple teams fully independent in SushiScout by team-scoping event identity and replacing the `teamId == ''` global-access hole with Firebase custom-claims membership checks.

**Architecture:** Event identity becomes a composite `${teamId}_${eventCode}` carried in `Event.id` and `matches.eventId` (raw code stays in `Event.tbaKey` for public schedule/TBA lookups). Team membership is mirrored from `users/{uid}.teamMemberships` into a custom auth claim by a Firestore-triggered Cloud Function; Firestore rules and Cloud Functions read the claim instead of doing document reads. Dev data is wiped rather than migrated.

**Tech Stack:** Flutter + Riverpod (Dart), Firebase Cloud Functions (Python 3.11), Firestore security rules, `@firebase/rules-unit-testing` (Node, for the rules test only).

## Global Constraints

- Commit convention: `<type>(<scope>): <subject>`, imperative, lower-case, no trailing period, ≤50 char subject. Types: feat/fix/docs/refactor/test/chore. Scopes include: sync, frontend, backend, db, api, ui, auth, config, test.
- Commit message footer for every commit: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Work happens on the existing `team-isolation` branch (already checked out).
- Never hand-edit generated files (`*.g.dart`, `*.mocks.dart`). Regenerate instead.
- Dart tests: `cd frontend && flutter test`. Python tests: `cd functions && python -m pytest tests/`.
- The composite event id format is exactly `"${teamId}_${eventCode}"` (single underscore separator). `programType` (`FRC`/`FTC`) is NOT part of the id — it stays an authoritative field.
- The raw event code (never composite) is what keys the public `schedules`, `tba_cache`, and `ftc_cache` collections.

---

## Task 1: Custom-claims sync Cloud Function

Mirror `users/{uid}.teamMemberships` into the `teams` custom auth claim so rules and callables can check membership for free.

**Files:**
- Modify: `functions/main.py` (add `fb_auth` import near line 6; add `on_user_membership_changed` after `on_match_written`)
- Test: `functions/tests/test_membership_claims.py` (create)

**Interfaces:**
- Produces: `on_user_membership_changed(event: firestore_fn.Event) -> None` — Firestore `on_document_written` trigger on `users/{userId}`. Calls `fb_auth.set_custom_user_claims(uid, {'teams': <teamMemberships map>})` and stamps `users/{uid}.claimsRefreshedAt`. No-op when `teamMemberships` is unchanged.

- [ ] **Step 1: Write the failing test**

Create `functions/tests/test_membership_claims.py`:

```python
"""Tests for the on_user_membership_changed custom-claims trigger."""

import unittest
from unittest.mock import Mock, patch

with patch('firebase_admin.initialize_app'):
    import main  # noqa: E402


def _user_event(user_id, before, after):
    evt = Mock()
    evt.params = {'userId': user_id}
    evt.data = Mock()
    if before is None:
        evt.data.before = None
    else:
        evt.data.before = Mock()
        evt.data.before.to_dict.return_value = before
    if after is None:
        evt.data.after = None
    else:
        evt.data.after = Mock()
        evt.data.after.to_dict.return_value = after
    return evt


class TestOnUserMembershipChanged(unittest.TestCase):
    def setUp(self):
        main._db = None

    @patch('main.get_db')
    @patch('main.fb_auth')
    def test_sets_claim_when_memberships_added(self, mock_auth, mock_get_db):
        evt = _user_event(
            'uid1',
            before={'teamMemberships': {}},
            after={'teamMemberships': {'teamA': 'admin'}},
        )
        main.on_user_membership_changed.__wrapped__(evt)
        mock_auth.set_custom_user_claims.assert_called_once_with(
            'uid1', {'teams': {'teamA': 'admin'}}
        )

    @patch('main.get_db')
    @patch('main.fb_auth')
    def test_noop_when_memberships_unchanged(self, mock_auth, mock_get_db):
        evt = _user_event(
            'uid1',
            before={'teamMemberships': {'teamA': 'admin'}, 'displayName': 'A'},
            after={'teamMemberships': {'teamA': 'admin'}, 'displayName': 'B'},
        )
        main.on_user_membership_changed.__wrapped__(evt)
        mock_auth.set_custom_user_claims.assert_not_called()

    @patch('main.get_db')
    @patch('main.fb_auth')
    def test_revokes_claim_when_user_doc_deleted(self, mock_auth, mock_get_db):
        evt = _user_event(
            'uid1',
            before={'teamMemberships': {'teamA': 'admin'}},
            after=None,
        )
        main.on_user_membership_changed.__wrapped__(evt)
        mock_auth.set_custom_user_claims.assert_called_once_with('uid1', {'teams': {}})


if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && python -m pytest tests/test_membership_claims.py -v`
Expected: FAIL — `AttributeError: module 'main' has no attribute 'fb_auth'` / `on_user_membership_changed`.

- [ ] **Step 3: Write minimal implementation**

In `functions/main.py`, add the import next to the existing firebase_admin imports (near line 6):

```python
from firebase_admin import initialize_app, firestore, auth as fb_auth
```

(Replace the existing `from firebase_admin import initialize_app, firestore` line.)

Then add this function immediately after `on_match_written` (after line ~259):

```python
@firestore_fn.on_document_written(document="users/{userId}")
def on_user_membership_changed(event: firestore_fn.Event) -> None:
    """Mirror users/{uid}.teamMemberships into a custom auth claim so
    Firestore rules and callables can check team membership without a
    document read. Runs on every users/{uid} write but is a no-op unless
    the teamMemberships map actually changed."""
    user_id = event.params['userId']
    before = event.data.before.to_dict() if event.data and event.data.before else {}
    after = event.data.after.to_dict() if event.data and event.data.after else {}
    before_memberships = (before or {}).get('teamMemberships') or {}
    after_memberships = (after or {}).get('teamMemberships') or {}

    # Echo guard: the claimsRefreshedAt write below re-triggers this
    # function. Only act when the membership map actually changed,
    # otherwise it loops forever.
    if before_memberships == after_memberships:
        return

    fb_auth.set_custom_user_claims(user_id, {'teams': after_memberships})

    # Signal the client to force-refresh its ID token so the new claim
    # takes effect without waiting up to an hour for natural refresh.
    get_db().collection('users').document(user_id).set(
        {'claimsRefreshedAt': firestore.SERVER_TIMESTAMP},
        merge=True,
    )
    logger.info(
        f"Synced team claims for {user_id}: {list(after_memberships.keys())}"
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd functions && python -m pytest tests/test_membership_claims.py -v`
Expected: PASS (3 passed).

- [ ] **Step 5: Commit**

```bash
git add functions/main.py functions/tests/test_membership_claims.py
git commit -m "feat(auth): sync team memberships into custom claims

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Cloud Functions read membership from the token claim

Replace the Firestore read in `_is_team_member` with a free token-claim check, and update its two callers and the existing tests.

**Files:**
- Modify: `functions/main.py` (`_is_team_member` ~line 32; callers at ~line 305 and ~line 438)
- Modify: `functions/tests/test_main.py` (`TestIsTeamMember`, ~lines 13-45)

**Interfaces:**
- Consumes: `req.auth.token` (a dict) available inside callable functions.
- Produces: `_is_team_member(auth_token: dict | None, team_id: str) -> bool` — true iff `team_id` is a key in `auth_token['teams']`.

- [ ] **Step 1: Rewrite the failing tests**

Replace the entire `TestIsTeamMember` class in `functions/tests/test_main.py` (lines 13-45) with:

```python
class TestIsTeamMember(unittest.TestCase):
    """Membership is now read from the token's `teams` custom claim."""

    def test_none_token_returns_false(self):
        self.assertFalse(main._is_team_member(None, 'team1'))

    def test_empty_team_returns_false(self):
        self.assertFalse(main._is_team_member({'teams': {'team1': 'admin'}}, ''))

    def test_true_when_team_in_claim(self):
        self.assertTrue(main._is_team_member({'teams': {'team1': 'admin'}}, 'team1'))

    def test_false_when_team_not_in_claim(self):
        self.assertFalse(main._is_team_member({'teams': {'team2': 'member'}}, 'team1'))

    def test_false_when_no_teams_claim(self):
        self.assertFalse(main._is_team_member({'email': 'a@b.c'}, 'team1'))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && python -m pytest tests/test_main.py::TestIsTeamMember -v`
Expected: FAIL — the current `_is_team_member(uid, team_id)` reads Firestore, so `_is_team_member({'teams': ...}, 'team1')` returns False / errors.

- [ ] **Step 3: Rewrite `_is_team_member` and its callers**

Replace `_is_team_member` (lines 32-45) with:

```python
def _is_team_member(auth_token: dict | None, team_id: str) -> bool:
    """True if the caller's token carries `team_id` in its `teams` custom
    claim. Cloud Functions use the Admin SDK which bypasses Firestore
    rules, so callables must check membership themselves — but the claim
    (mirrored by on_user_membership_changed) makes it a free token read
    instead of a Firestore lookup."""
    if not auth_token or not team_id:
        return False
    return team_id in (auth_token.get('teams') or {})
```

In `backfill_event_to_sheets`, change the caller (~line 305) from:

```python
        if event_team_id and not _is_team_member(req.auth.uid, event_team_id):
```
to:
```python
        if event_team_id and not _is_team_member(req.auth.token, event_team_id):
```

In `update_match_from_sheets`, change the caller (~line 438) from:

```python
        if existing_team_id and not _is_team_member(req.auth.uid, existing_team_id):
```
to:
```python
        if existing_team_id and not _is_team_member(req.auth.token, existing_team_id):
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd functions && python -m pytest tests/test_main.py -v`
Expected: PASS (all `TestIsTeamMember` green; the rest of `test_main.py` unaffected).

- [ ] **Step 5: Commit**

```bash
git add functions/main.py functions/tests/test_main.py
git commit -m "refactor(auth): check membership via token claim in functions

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Rewrite Firestore rules + automated isolation test

Remove every `teamId == ''` branch and check membership via the `teams` claim. Add a `@firebase/rules-unit-testing` harness as the automated isolation gate (Node ships with the Firebase CLI you already use).

**Files:**
- Modify: `firestore.rules` (full replacement)
- Create: `test/firestore-rules/package.json`
- Create: `test/firestore-rules/rules.test.js`

**Interfaces:**
- Consumes: the claim shape `{ teams: { "<teamId>": "<role>" } }` from Task 1.
- Produces: rules where `events`/`matches` require `isTeamMember(teamId)` and `isTeamMember` reads `request.auth.token.teams`.

- [ ] **Step 1: Write the failing test harness**

Create `test/firestore-rules/package.json`:

```json
{
  "name": "sushiscout-rules-tests",
  "version": "1.0.0",
  "private": true,
  "scripts": { "test": "jest --runInBand" },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^3.0.4",
    "firebase": "^10.12.0",
    "jest": "^29.7.0"
  }
}
```

Create `test/firestore-rules/rules.test.js`:

```javascript
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc } = require('firebase/firestore');

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-sushiscout',
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '../../firestore.rules'),
        'utf8'
      ),
    },
  });
});

afterAll(() => testEnv.cleanup());
beforeEach(() => testEnv.clearFirestore());

// Alice is a member of teamA (via her custom claim); Bob is not.
const alice = () =>
  testEnv.authenticatedContext('alice', { teams: { teamA: 'admin' } }).firestore();
const bob = () =>
  testEnv.authenticatedContext('bob', { teams: { teamB: 'member' } }).firestore();

async function seedMatch(teamId) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'matches/m1'), {
      eventId: `${teamId}_2026casf`,
      teamId,
      isDeleted: false,
    });
  });
}

test('member reads own team match', async () => {
  await seedMatch('teamA');
  await assertSucceeds(getDoc(doc(alice(), 'matches/m1')));
});

test('non-member cannot read another team match', async () => {
  await seedMatch('teamA');
  await assertFails(getDoc(doc(bob(), 'matches/m1')));
});

test('empty teamId is NOT globally readable', async () => {
  await seedMatch('');
  await assertFails(getDoc(doc(alice(), 'matches/m1')));
});

test('member can create a match for own team', async () => {
  await assertSucceeds(
    setDoc(doc(alice(), 'matches/m2'), {
      eventId: 'teamA_2026casf',
      teamId: 'teamA',
      isDeleted: false,
    })
  );
});

test('member cannot create a match stamped for another team', async () => {
  await assertFails(
    setDoc(doc(alice(), 'matches/m3'), {
      eventId: 'teamB_2026casf',
      teamId: 'teamB',
      isDeleted: false,
    })
  );
});
```

- [ ] **Step 2: Install deps and run the test to verify it fails**

Run:
```bash
cd test/firestore-rules && npm install && cd ../.. \
  && firebase emulators:exec --only firestore "cd test/firestore-rules && npm test"
```
Expected: FAIL — current rules allow `teamId == ''` reads and use `exists()`, so `empty teamId is NOT globally readable` and the non-member test fail.

- [ ] **Step 3: Replace `firestore.rules`**

Replace the entire contents of `firestore.rules` with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() { return request.auth != null; }

    // Team memberships are mirrored into a custom claim by the
    // on_user_membership_changed Cloud Function. Reading the token is
    // free — no document read — unlike the old exists() check.
    function memberTeams() {
      return isSignedIn() ? request.auth.token.get('teams', {}) : {};
    }
    function isTeamMember(teamId) {
      return teamId != '' && teamId in memberTeams();
    }

    match /events/{eventId} {
      allow read, update, delete: if isTeamMember(resource.data.teamId);
      allow create:               if isTeamMember(request.resource.data.teamId);
    }

    match /matches/{reportId} {
      allow read, update, delete: if isTeamMember(resource.data.teamId);
      allow create:               if isTeamMember(request.resource.data.teamId);
    }

    match /users/{userId} {
      allow read, write: if isSignedIn() && request.auth.uid == userId;
    }

    match /teams/{teamId} {
      allow read:   if isTeamMember(teamId);
      allow create: if isSignedIn();               // bootstrap a new team
      allow update: if isTeamMember(teamId);

      match /members/{memberId} {
        allow read:           if isTeamMember(teamId);
        allow create:         if isSignedIn()
                                && (memberId == request.auth.uid || isTeamMember(teamId));
        allow update, delete: if isTeamMember(teamId);
      }
    }

    match /sync_tracking/{doc} { allow read, write: if false; }
    match /tba_cache/{doc}     { allow read: if isSignedIn(); allow write: if false; }
    match /ftc_cache/{doc}     { allow read: if isSignedIn(); allow write: if false; }
    match /schedules/{doc}     { allow read: if isSignedIn(); allow write: if false; }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
firebase emulators:exec --only firestore "cd test/firestore-rules && npm test"
```
Expected: PASS (5 passed).

- [ ] **Step 5: Commit**

```bash
git add firestore.rules test/firestore-rules/package.json test/firestore-rules/rules.test.js
git commit -m "fix(auth): team-scope rules and drop empty-teamId hatch

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Composite event-id providers

Add the single composition point: a pure `composeEventId` function plus the two providers.

**Files:**
- Create: `frontend/lib/presentation/providers/event_providers.dart`
- Test: `frontend/test/presentation/providers/event_providers_test.dart` (create)

**Interfaces:**
- Consumes: `currentTeamIdProvider` (from `auth_provider.dart`), `settingsProvider` + `PrefKeys.eventCode` (from `preferences.dart`).
- Produces:
  - `String composeEventId(String? teamId, String eventCode)` — `"${teamId}_$eventCode"`, or bare `eventCode` when `teamId` is null/empty.
  - `currentEventCodeProvider` → `String` (raw code, for schedules/TBA).
  - `currentEventIdProvider` → `String` (composite, for events/matches).

- [ ] **Step 1: Write the failing test**

Create `frontend/test/presentation/providers/event_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/providers/event_providers.dart';

void main() {
  group('composeEventId', () {
    test('combines team id and event code with an underscore', () {
      expect(composeEventId('aB3kZx9Q', '2026casf'), 'aB3kZx9Q_2026casf');
    });

    test('falls back to bare code when team id is null', () {
      expect(composeEventId(null, '2026casf'), '2026casf');
    });

    test('falls back to bare code when team id is empty', () {
      expect(composeEventId('', '2026casf'), '2026casf');
    });
  });
}
```

> Note: the Dart package name is `frontend` (from `frontend/pubspec.yaml`), hence `package:frontend/...`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/presentation/providers/event_providers_test.dart`
Expected: FAIL — `event_providers.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `frontend/lib/presentation/providers/event_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/preferences.dart';
import 'auth_provider.dart';

/// Composes the team-scoped event id used for `events` and `matches`.
///
/// Returns `"${teamId}_$eventCode"`. When no active team is known (pre-team
/// selection) it returns the bare code — no team-scoped write happens in
/// that state, so there is no cross-team leak.
String composeEventId(String? teamId, String eventCode) {
  if (teamId == null || teamId.isEmpty) return eventCode;
  return '${teamId}_$eventCode';
}

/// The raw event code the user entered. Use this for the PUBLIC schedule
/// and TBA/FTC lookups — those collections are keyed by raw code, not the
/// team-scoped composite.
final currentEventCodeProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings[PrefKeys.eventCode] ?? '2026TEST';
});

/// The team-scoped composite event id. Use this for all `events`/`matches`
/// repository operations.
final currentEventIdProvider = Provider<String>((ref) {
  final teamId = ref.watch(currentTeamIdProvider);
  final eventCode = ref.watch(currentEventCodeProvider);
  return composeEventId(teamId, eventCode);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/presentation/providers/event_providers_test.dart`
Expected: PASS (3 passed).

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/presentation/providers/event_providers.dart frontend/test/presentation/providers/event_providers_test.dart
git commit -m "feat(frontend): add composite event-id providers

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Route match/event call sites through the composite id

Switch every `events`/`matches` operation to `currentEventIdProvider`; keep the raw code (`currentEventCodeProvider` / `Event.tbaKey`) only for schedules and the settings display.

**Files:**
- Modify: `frontend/lib/presentation/screens/dashboard.dart`
- Modify: `frontend/lib/presentation/screens/trash_screen.dart`
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart` (`_loadSchedule`)
- Modify: `frontend/lib/presentation/screens/ftc_decode_form.dart` (`_loadSchedule`)

**Interfaces:**
- Consumes: `currentEventIdProvider`, `currentEventCodeProvider` (Task 4); `Event.id` (composite), `Event.tbaKey` (raw code).

- [ ] **Step 1: Route the dashboard**

Add the import to `dashboard.dart` (near the other provider imports, ~line 21):

```dart
import '../providers/event_providers.dart';
```

In `dashboard.dart`, replace **every** occurrence of this pattern used for a match/event repository call:

```dart
    final eventCode =
        ref.read(settingsProvider)[PrefKeys.eventCode] ?? "Unknown";
```
with:
```dart
    final eventId = ref.read(currentEventIdProvider);
```
and update the following call on each to use `eventId` instead of `eventCode`:
`watchMatches` (lines ~39, ~52, ~198), `getMatches` (lines ~60, ~110, ~239), `getEvent` (line ~540), `trashMatch`/`restoreMatch` (lines ~833, ~843).

For the settings-display label (line ~207 `final eventCode = settings[PrefKeys.eventCode] ...` feeding the chip at line ~397) KEEP it as the raw code — leave that block unchanged.

For the event-construction block (lines ~533-557) set the composite id but keep the raw code in `tbaKey`:

```dart
              final eventId = ref.read(currentEventIdProvider);
              final eventCode = ref.read(currentEventCodeProvider);
              // ...
              final dummyEvent = Event(
                id: eventId,          // composite: events/matches
                name: eventCode,
                programType: programType,
                tbaKey: eventCode,    // raw code: schedule/TBA
                startDate: DateTime.now(),
                teamId: ref.read(currentTeamIdProvider) ?? '',
              );
```

(Import `currentTeamIdProvider` is already available via `auth_provider.dart`, imported at line 21's neighborhood; if not, add `import '../providers/auth_provider.dart';`.)

- [ ] **Step 2: Route the trash screen**

In `trash_screen.dart`, add the import:

```dart
import '../providers/event_providers.dart';
```
Replace each `final eventCode = ref.read(settingsProvider)[PrefKeys.eventCode] ?? "";` (lines ~24, ~55, ~77) with:
```dart
    final eventId = ref.read(currentEventIdProvider);
```
and update the `watchTrash` (line ~25), `restoreMatch` (line ~57), `trashMatch` (line ~65), `deleteMatch` (line ~106) calls to pass `eventId`.

- [ ] **Step 3: Fix schedule lookups in both forms to use the raw code**

The forms receive `widget.eventId` = `Event.id` = the **composite** (used correctly for `createMatch` and doc ids at frc `_submit`/ftc `_submit`). But `_loadSchedule` must use the **raw** code, which is `widget.event.tbaKey`.

In `frc_rebuilt_form.dart` `_loadSchedule` (line ~86) change:
```dart
    final eventCode = widget.eventId;
```
to:
```dart
    final eventCode = widget.event.tbaKey;
```
and the Firestore schedules query at line ~110 already uses this `eventCode` local — leave it.

Apply the identical change in `ftc_decode_form.dart` `_loadSchedule` (line ~83).

- [ ] **Step 4: Verify it compiles and existing tests pass**

Run: `cd frontend && flutter analyze && flutter test`
Expected: analyze clean; all existing tests pass (any dashboard/trash widget tests still green because behavior is unchanged for a single team).

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/presentation/screens/dashboard.dart frontend/lib/presentation/screens/trash_screen.dart frontend/lib/presentation/screens/frc_rebuilt_form.dart frontend/lib/presentation/screens/ftc_decode_form.dart
git commit -m "fix(frontend): use team-scoped event id for match ops

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Force token refresh after create/join

After a membership change, the client must force-refresh its ID token so the new `teams` claim (set asynchronously by Task 1's trigger) takes effect before reading team data.

**Files:**
- Create: `frontend/lib/core/auth/claims_refresher.dart`
- Test: `frontend/test/core/auth/claims_refresher_test.dart` (create)
- Modify: `frontend/lib/core/auth/auth_service.dart` (add `forceRefreshClaims`)
- Modify: `frontend/lib/presentation/providers/auth_provider.dart` (`createTeam`, `joinTeam`)

**Interfaces:**
- Produces:
  - `Future<bool> waitForTeamClaim({required ClaimsFetcher fetchClaims, required String expectedTeamId, int maxAttempts, Duration delay, Future<void> Function(Duration)? sleep})` where `typedef ClaimsFetcher = Future<Map<String, dynamic>> Function();`
  - `AuthService.forceRefreshClaims() -> Future<Map<String, dynamic>>` — force-refreshes the ID token and returns its claims.

- [ ] **Step 1: Write the failing test for the polling helper**

Create `frontend/test/core/auth/claims_refresher_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/claims_refresher.dart';

void main() {
  group('waitForTeamClaim', () {
    test('returns true once the team appears in the teams claim', () async {
      var calls = 0;
      final result = await waitForTeamClaim(
        fetchClaims: () async {
          calls++;
          // Claim empty on first fetch, populated on the second.
          return calls >= 2 ? {'teams': {'teamA': 'admin'}} : {'teams': {}};
        },
        expectedTeamId: 'teamA',
        maxAttempts: 5,
        sleep: (_) async {}, // no real waiting in tests
      );
      expect(result, isTrue);
      expect(calls, 2);
    });

    test('returns false after exhausting attempts', () async {
      final result = await waitForTeamClaim(
        fetchClaims: () async => {'teams': {}},
        expectedTeamId: 'teamA',
        maxAttempts: 3,
        sleep: (_) async {},
      );
      expect(result, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/core/auth/claims_refresher_test.dart`
Expected: FAIL — `claims_refresher.dart` does not exist.

- [ ] **Step 3: Write the polling helper**

Create `frontend/lib/core/auth/claims_refresher.dart`:

```dart
/// Fetches the current user's ID-token claims (forcing a refresh).
typedef ClaimsFetcher = Future<Map<String, dynamic>> Function();

/// Polls [fetchClaims] until [expectedTeamId] appears in the `teams` claim
/// (mirrored by the on_user_membership_changed Cloud Function) or
/// [maxAttempts] is reached. Returns true if the claim arrived.
///
/// The custom claim is set asynchronously by a Firestore trigger, so an
/// immediate single refresh right after a membership write usually misses
/// it — hence the bounded poll. [sleep] is injectable for tests.
Future<bool> waitForTeamClaim({
  required ClaimsFetcher fetchClaims,
  required String expectedTeamId,
  int maxAttempts = 6,
  Duration delay = const Duration(milliseconds: 500),
  Future<void> Function(Duration)? sleep,
}) async {
  final wait = sleep ?? Future<void>.delayed;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final claims = await fetchClaims();
    final teams = (claims['teams'] as Map?) ?? const {};
    if (teams.containsKey(expectedTeamId)) return true;
    if (attempt < maxAttempts - 1) await wait(delay);
  }
  return false;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/core/auth/claims_refresher_test.dart`
Expected: PASS (2 passed).

- [ ] **Step 5: Add `forceRefreshClaims` to AuthService**

First read `frontend/lib/core/auth/auth_service.dart` to find the `FirebaseAuth` instance field name (commonly `_firebaseAuth` or `_auth`; if there is none, use `FirebaseAuth.instance`). Add this method to the `AuthService` class:

```dart
  /// Force-refreshes the ID token and returns its custom claims. Used after
  /// a team create/join so the new `teams` claim takes effect immediately.
  Future<Map<String, dynamic>> forceRefreshClaims() async {
    final user = _firebaseAuth.currentUser; // match the existing field name
    if (user == null) return const {};
    final result = await user.getIdTokenResult(true);
    return result.claims ?? const {};
  }
```

Ensure `import 'package:firebase_auth/firebase_auth.dart';` is present (it should be).

- [ ] **Step 6: Wire the refresh into create/join**

In `auth_provider.dart`, add the import:

```dart
import '../../core/auth/claims_refresher.dart';
```

In `AuthNotifier.createTeam`, capture the created team and wait for its claim before reloading the profile. Change:

```dart
      final teamRepo = ref.read(teamRepositoryProvider);
      await teamRepo.createTeam(
        name: name,
        createdBy: userId,
        isMasterTeam: isMasterTeam,
      );

      await _loadUserProfile();
```
to:
```dart
      final teamRepo = ref.read(teamRepositoryProvider);
      final team = await teamRepo.createTeam(
        name: name,
        createdBy: userId,
        isMasterTeam: isMasterTeam,
      );

      final authService = ref.read(authServiceProvider);
      await waitForTeamClaim(
        fetchClaims: authService.forceRefreshClaims,
        expectedTeamId: team.id,
      );

      await _loadUserProfile();
```

In `AuthNotifier.joinTeam`, change:

```dart
      final teamRepo = ref.read(teamRepositoryProvider);
      await teamRepo.joinTeamByCode(
        inviteCode: inviteCode,
        userId: userId,
      );

      await _loadUserProfile();
```
to:
```dart
      final teamRepo = ref.read(teamRepositoryProvider);
      final team = await teamRepo.joinTeamByCode(
        inviteCode: inviteCode,
        userId: userId,
      );

      if (team != null) {
        final authService = ref.read(authServiceProvider);
        await waitForTeamClaim(
          fetchClaims: authService.forceRefreshClaims,
          expectedTeamId: team.id,
        );
      }

      await _loadUserProfile();
```

- [ ] **Step 7: Verify analyze + full frontend suite**

Run: `cd frontend && flutter analyze && flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 8: Commit**

```bash
git add frontend/lib/core/auth/claims_refresher.dart frontend/test/core/auth/claims_refresher_test.dart frontend/lib/core/auth/auth_service.dart frontend/lib/presentation/providers/auth_provider.dart
git commit -m "feat(auth): refresh token after team create/join

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Remove the empty-teamId escape hatch from Dart/Python

Now that every write stamps a real `teamId` and rules reject empty ones, delete the defensive `teamId.isEmpty` allowances. Also fix `_getOrCreateEvent` to store the raw code in `tbaKey`.

**Files:**
- Modify: `frontend/lib/data/repositories/hybrid_repository.dart` (`_filterToActiveTeam` ~line 821)
- Modify: `frontend/lib/data/local/sync/sync_manager.dart` (cross-team gate ~line 207)
- Modify: `frontend/lib/data/repositories/firestore_repository.dart` (`_getOrCreateEvent` tbaKey ~line 124)

**Interfaces:**
- Consumes: nothing new. Behavior tightens: rows with empty `teamId` are no longer surfaced.

- [ ] **Step 1: Tighten `_filterToActiveTeam`**

In `hybrid_repository.dart`, change (line ~824):

```dart
    return rows
        .where((r) => r.teamId.isEmpty || r.teamId == activeTeamId)
        .toList();
```
to:
```dart
    return rows.where((r) => r.teamId == activeTeamId).toList();
```

- [ ] **Step 2: Tighten the sync-queue cross-team gate**

In `sync_manager.dart`, change the gate (lines ~207-213):

```dart
        if (activeTeamId != null &&
            activeTeamId.isNotEmpty &&
            match.teamId.isNotEmpty &&
            match.teamId != activeTeamId) {
          skippedCrossTeam++;
          continue;
        }
```
to:
```dart
        if (activeTeamId != null &&
            activeTeamId.isNotEmpty &&
            match.teamId != activeTeamId) {
          skippedCrossTeam++;
          continue;
        }
```

- [ ] **Step 3: Store the raw code in an auto-created event's tbaKey**

In `firestore_repository.dart` `_getOrCreateEvent` (auto-create block ~line 120-128), the incoming `eventId` is now the composite. Derive the raw code for `tbaKey`:

```dart
      _logger.i('Auto-creating event $eventId in Firestore');
      final rawCode = (teamId != null && teamId.isNotEmpty && eventId.startsWith('${teamId}_'))
          ? eventId.substring(teamId.length + 1)
          : eventId;
      await eventDoc.set({
        'name': rawCode,
        'programType': fallbackProgramType,
        'tbaKey': rawCode,
        'startDate': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'teamId': teamId ?? '',
        'autoCreated': true,
      }, SetOptions(merge: true));
```

- [ ] **Step 4: Verify analyze + full frontend suite**

Run: `cd frontend && flutter analyze && flutter test`
Expected: analyze clean; all tests pass. If any existing test seeded a match with an empty `teamId` and expected it to appear, update that fixture to stamp the active team id.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/data/repositories/hybrid_repository.dart frontend/lib/data/local/sync/sync_manager.dart frontend/lib/data/repositories/firestore_repository.dart
git commit -m "refactor(sync): drop empty-teamId compatibility branches

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Wipe dev data, verify full suites, deploy

Reset disposable dev data so no legacy empty-`teamId` docs remain, run both full suites, and deploy rules + functions.

**Files:** none (operational).

**Interfaces:** Consumes a Firebase CLI logged in to the project (the user's `firebase login`).

- [ ] **Step 1: Confirm login and project**

Run: `firebase projects:list && firebase use`
Expected: the SushiScout project is listed and selected. If not: `firebase use --add`.

- [ ] **Step 2: Wipe dev Firestore collections**

Run (answer yes at the prompt):
```bash
firebase firestore:delete matches --recursive
firebase firestore:delete events --recursive
firebase firestore:delete sync_tracking --recursive
firebase firestore:delete schedules --recursive
```
Expected: each reports deletion complete. (`schedules` will be repopulated from TBA/FTC on next fetch.)

- [ ] **Step 3: Clear local SQLite on any dev device**

In the running app, use the existing "clear all local data" affordance (Settings), or delete the app's SQLite file. This drops any locally cached rows that still carry a raw-code `eventId`.

- [ ] **Step 4: Run BOTH full test suites**

Run:
```bash
cd frontend && flutter analyze && flutter test
cd ../functions && python -m pytest tests/
```
Expected: analyze clean; Dart suite green (≥285); Python suite green (≥24 + the 3 new claims tests).

- [ ] **Step 5: Deploy rules and functions**

Run:
```bash
firebase deploy --only firestore:rules
firebase deploy --only functions
```
Expected: rules compile and deploy; `on_user_membership_changed` appears in the deployed function list.

- [ ] **Step 6: Manual smoke test (two teams)**

1. Sign in as user A, create Team Alpha, set event code `2026casf`, submit a match. Confirm it appears.
2. Sign in as user B (different account), create Team Beta, set the same event code `2026casf`. Confirm B sees **none** of A's matches and that the Sheet has separate tabs `<alphaId>_2026casf` and `<betaId>_2026casf`.
3. Confirm a freshly-created team can immediately read/write (token refresh worked).

- [ ] **Step 7: Commit any fixture updates and finalize**

```bash
git add -A
git commit -m "test(auth): finalize team isolation verification

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- §4 composite id → Tasks 4, 5. ✓
- §5 provider composition point → Task 4. ✓
- §6 schedules stay global (raw code) → Task 5 Step 3 (forms use `Event.tbaKey`), Task 4 (`currentEventCodeProvider`). ✓
- §7 custom claims (trigger, claim shape, CF check, client refresh, propagation) → Tasks 1, 2, 6. ✓
- §8 rules rewrite → Task 3. ✓
- §9 Dart/Python cleanup → Task 7 (+ Task 2 for the Python membership caller). ✓
- §10 local Drift composite eventId → covered implicitly: `eventId` values become composite via Task 5; no schema change needed. Wipe in Task 8. ✓
- §11 data wipe → Task 8. ✓
- §12 testing → per-task tests + Task 8 full-suite + rules test in Task 3. ✓
- §13 risks (claim latency) → Task 6 poll; (tbaKey) → Task 7 Step 3. ✓

**Placeholder scan:** no TBD/TODO; every code step shows complete code. The one "read the file to find the field name" note (Task 6 Step 5) is a concrete instruction with a named fallback (`FirebaseAuth.instance`), not a placeholder.

**Type consistency:** `_is_team_member(auth_token, team_id)` signature matches its callers (Task 2) and tests. `composeEventId`/`currentEventIdProvider`/`currentEventCodeProvider` names are identical across Tasks 4 and 5. `waitForTeamClaim`/`ClaimsFetcher`/`forceRefreshClaims` names match across Task 6 steps. `on_user_membership_changed` matches between Task 1 impl and test. ✓
