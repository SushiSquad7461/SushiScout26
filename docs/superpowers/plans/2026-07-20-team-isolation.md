# Team Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make multiple teams fully independent in SushiScout by team-scoping event identity and replacing the `teamId == ''` global-access hole with Firebase custom-claims membership checks.

**Architecture:** Event identity becomes a composite `${teamId}_${eventCode}` carried in `Event.id` and `matches.eventId` (raw code stays in `Event.tbaKey` for public schedule/TBA lookups). Team membership is **server-authoritative**: `create_team`/`join_team`/`leave_team` callable Cloud Functions validate and mutate membership with the Admin SDK and set a `{teams: {...}}` custom auth claim; Firestore rules read the claim (free) and forbid clients from writing `users/{uid}.teamMemberships` or `teams/{tid}/members/**`. Dev data is wiped rather than migrated.

> **Security note (why callables, not a trigger):** an earlier draft mirrored the client-writable `users/{uid}.teamMemberships` into the claim via a Firestore trigger. That is a privilege-escalation hole — a user could self-assert membership in any team and read/write its data. Membership mutation therefore lives in server-side callables, and the claim source is write-locked to them.

**Tech Stack:** Flutter + Riverpod (Dart), Firebase Cloud Functions (Python 3.12), Firestore security rules, `@firebase/rules-unit-testing` (Node, for the rules test only).

## Global Constraints

- Commit convention: `<type>(<scope>): <subject>`, imperative, lower-case, no trailing period, ≤50 char subject. Types: feat/fix/docs/refactor/test/chore. Scopes include: sync, frontend, backend, db, api, ui, auth, config, test.
- Commit message footer for every commit: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Work happens on the existing `team-isolation` branch (already checked out).
- Never hand-edit generated files (`*.g.dart`, `*.mocks.dart`). Regenerate instead.
- **This machine's test commands:** Dart → `cd frontend && flutter test` (flutter is on PATH). Python → `cd functions && ./venv/bin/python -m pytest tests/` (use the venv, NOT bare `python`). Rules → `firebase emulators:exec --only firestore "cd test/firestore-rules && npm test"`.
- Membership claim shape is exactly `{ "teams": { "<teamId>": "<role>" } }` where role is `"admin"` or `"member"`.
- Membership is server-authoritative: clients never write `users/{uid}.teamMemberships` or `teams/{tid}/members/**`; only the callables do (Admin SDK).
- The composite event id format is exactly `"${teamId}_${eventCode}"` (single underscore separator). `programType` (`FRC`/`FTC`) is NOT part of the id — it stays an authoritative field.
- The raw event code (never composite) is what keys the public `schedules`, `tba_cache`, and `ftc_cache` collections.

---

## Task 1: Membership callable Cloud Functions

Membership must be server-authoritative (see the Architecture security note). Add three callable functions that validate + mutate membership with the Admin SDK and set the `{teams: {...}}` custom claim. This ports the logic currently in `frontend/lib/data/repositories/team_repository.dart` (`createTeam`/`joinTeamByCode`/`leaveTeam`) to the backend.

> This is an integration/port task, not pure transcription. The implementation code below is complete; the test file gives the required behavioral assertions — you adapt the Admin-SDK mock plumbing (following the existing `functions/tests/test_main.py` chained-`Mock` style) to drive RED→GREEN. The behaviors asserted are the contract; do not weaken them.

**Files:**
- Modify: `functions/main.py` (add `auth as fb_auth` import near line 6; add helpers + three `@https_fn.on_call` functions after `on_match_written`)
- Test: `functions/tests/test_membership_callables.py` (create)
- Read for reference: `frontend/lib/data/repositories/team_repository.dart` (the logic being ported — invite-code format `[A-Z0-9]{6}`, already-member rejection, last-admin-can't-leave, currentTeamId/teamMemberships maintenance)

**Interfaces:**
- Produces (all `@https_fn.on_call`, callable from the Flutter app):
  - `create_team(req)` — data `{name, isMasterTeam?}` → creates team + `members/{uid}='admin'` + user mirror, sets claim; returns `{teamId, name, inviteCode, createdBy, isMasterTeam, memberCount}`.
  - `join_team(req)` — data `{inviteCode}` → validates code server-side, rejects if already a member, writes `members/{uid}='member'` + user mirror, sets claim; returns the same team dict shape.
  - `leave_team(req)` — data `{teamId}` → verifies membership, enforces last-admin rule, removes member + user mirror, sets claim; returns `{success: true, currentTeamId}`.
  - Helpers `_generate_invite_code() -> str` and `_set_team_claims(uid: str, memberships: dict) -> None` (wraps `fb_auth.set_custom_user_claims(uid, {'teams': memberships})`).

- [ ] **Step 1: Write the failing tests**

Create `functions/tests/test_membership_callables.py`. These assert the security-critical behaviors; adapt the mock plumbing (chained `MagicMock`, following `test_main.py`) so they run:

```python
"""Tests for the membership callables: create_team / join_team / leave_team."""

import unittest
from unittest.mock import MagicMock, Mock, patch

with patch('firebase_admin.initialize_app'):
    import main  # noqa: E402

from firebase_functions import https_fn  # noqa: E402


def _req(uid, data):
    r = Mock()
    r.auth = Mock(uid=uid) if uid else None
    r.data = data
    return r


class TestCreateTeam(unittest.TestCase):
    def setUp(self):
        main._db = None

    def test_unauthenticated_raises(self):
        with self.assertRaises(https_fn.HttpsError):
            main.create_team.__wrapped__(_req(None, {'name': 'Alpha'}))

    @patch('main._set_team_claims')
    @patch('main._generate_invite_code', return_value='ABC123')
    @patch('main.get_db')
    def test_creates_team_and_sets_admin_claim(self, mock_db, mock_code, mock_claims):
        db = mock_db.return_value
        # no invite collision
        db.collection.return_value.where.return_value.limit.return_value.get.return_value = []
        # new team ref with a generated id
        team_ref = MagicMock()
        team_ref.id = 'team_new'
        # user doc has no prior memberships
        user_ref = MagicMock()
        user_ref.get.return_value = Mock(exists=False)
        # route document() calls: teams.document() -> team_ref, users.document(uid) -> user_ref
        db.collection.return_value.document.side_effect = lambda *a: team_ref if not a else user_ref
        db.batch.return_value = MagicMock()

        result = main.create_team.__wrapped__(_req('uid1', {'name': 'Alpha'}))

        # The caller's claim must include the new team as admin.
        mock_claims.assert_called_once_with('uid1', {'team_new': 'admin'})
        self.assertEqual(result['teamId'], 'team_new')
        self.assertEqual(result['inviteCode'], 'ABC123')


class TestJoinTeam(unittest.TestCase):
    def setUp(self):
        main._db = None

    @patch('main._set_team_claims')
    @patch('main.get_db')
    def test_rejects_when_already_member(self, mock_db, mock_claims):
        db = mock_db.return_value
        team_doc = Mock(id='team_x')
        team_doc.to_dict.return_value = {'name': 'X', 'memberCount': 2}
        db.collection.return_value.where.return_value.limit.return_value.get.return_value = [team_doc]
        # member doc already exists -> ALREADY_EXISTS
        db.collection.return_value.document.return_value.collection.return_value.document.return_value.get.return_value = Mock(exists=True)

        with self.assertRaises(https_fn.HttpsError):
            main.join_team.__wrapped__(_req('uid1', {'inviteCode': 'ABC123'}))
        mock_claims.assert_not_called()

    @patch('main._set_team_claims')
    @patch('main.get_db')
    def test_invalid_code_raises(self, mock_db, mock_claims):
        db = mock_db.return_value
        db.collection.return_value.where.return_value.limit.return_value.get.return_value = []
        with self.assertRaises(https_fn.HttpsError):
            main.join_team.__wrapped__(_req('uid1', {'inviteCode': 'NOPE00'}))


class TestLeaveTeam(unittest.TestCase):
    def setUp(self):
        main._db = None

    @patch('main._set_team_claims')
    @patch('main.get_db')
    def test_last_admin_cannot_leave(self, mock_db, mock_claims):
        db = mock_db.return_value
        team_ref = MagicMock()
        team_ref.get.return_value = Mock(exists=True, **{'to_dict.return_value': {'memberCount': 1}})
        member_snap = Mock(exists=True)
        member_snap.to_dict.return_value = {'role': 'admin'}
        team_ref.collection.return_value.document.return_value.get.return_value = member_snap
        db.collection.return_value.document.return_value = team_ref

        with self.assertRaises(https_fn.HttpsError):
            main.leave_team.__wrapped__(_req('uid1', {'teamId': 'team_x'}))
        mock_claims.assert_not_called()


if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && ./venv/bin/python -m pytest tests/test_membership_callables.py -v`
Expected: FAIL — `create_team`/`join_team`/`leave_team` and the helpers do not exist yet.

- [ ] **Step 3: Write the implementation**

In `functions/main.py`, replace the firebase_admin import line with:

```python
from firebase_admin import initialize_app, firestore, auth as fb_auth
```

Add these helpers and callables after `on_match_written`:

```python
import random  # (top of file with the other imports)


def _generate_invite_code() -> str:
    chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    return ''.join(random.choice(chars) for _ in range(6))


def _set_team_claims(uid: str, memberships: dict) -> None:
    """Mirror a user's team memberships into their auth token. The claim is
    the ONLY membership signal Firestore rules trust, and it is written only
    here (server-side) — clients cannot forge it."""
    fb_auth.set_custom_user_claims(uid, {'teams': memberships})


def _user_memberships(db, uid: str) -> dict:
    snap = db.collection('users').document(uid).get()
    if not snap.exists:
        return {}
    return dict((snap.to_dict() or {}).get('teamMemberships') or {})


@https_fn.on_call()
def create_team(req: https_fn.CallableRequest) -> dict:
    """Create a team, make the caller its admin, and set their claim."""
    if not req.auth:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Must be authenticated")
    data = req.data or {}
    name = data.get('name')
    if not name:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "Missing team name")
    is_master = bool(data.get('isMasterTeam'))
    uid = req.auth.uid
    db = get_db()

    invite_code = _generate_invite_code()
    while list(db.collection('teams').where('inviteCode', '==', invite_code).limit(1).get()):
        invite_code = _generate_invite_code()

    team_ref = db.collection('teams').document()
    team_id = team_ref.id
    now = firestore.SERVER_TIMESTAMP
    memberships = _user_memberships(db, uid)
    memberships[team_id] = 'admin'

    batch = db.batch()
    batch.set(team_ref, {
        'name': name, 'inviteCode': invite_code, 'createdBy': uid,
        'createdAt': now, 'isMasterTeam': is_master, 'memberCount': 1,
    })
    batch.set(team_ref.collection('members').document(uid),
              {'role': 'admin', 'userId': uid, 'joinedAt': now})
    batch.set(db.collection('users').document(uid),
              {'currentTeamId': team_id, 'teamMemberships': memberships}, merge=True)
    batch.commit()

    _set_team_claims(uid, memberships)
    return {'teamId': team_id, 'name': name, 'inviteCode': invite_code,
            'createdBy': uid, 'isMasterTeam': is_master, 'memberCount': 1}


@https_fn.on_call()
def join_team(req: https_fn.CallableRequest) -> dict:
    """Join a team by invite code. The code is verified server-side — it is
    the only proof of authorization, so this must never be a client write."""
    if not req.auth:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Must be authenticated")
    code = ((req.data or {}).get('inviteCode') or '').upper()
    if not code:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "Missing invite code")
    uid = req.auth.uid
    db = get_db()

    teams = list(db.collection('teams').where('inviteCode', '==', code).limit(1).get())
    if not teams:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.NOT_FOUND, "Invalid invite code")
    team_doc = teams[0]
    team_id = team_doc.id
    team = team_doc.to_dict() or {}

    team_ref = db.collection('teams').document(team_id)
    member_ref = team_ref.collection('members').document(uid)
    if member_ref.get().exists:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.ALREADY_EXISTS, "Already a member of this team")

    memberships = _user_memberships(db, uid)
    memberships[team_id] = 'member'

    batch = db.batch()
    batch.set(member_ref, {'role': 'member', 'userId': uid, 'joinedAt': firestore.SERVER_TIMESTAMP})
    batch.update(team_ref, {'memberCount': firestore.Increment(1)})
    batch.set(db.collection('users').document(uid),
              {'currentTeamId': team_id, 'teamMemberships': memberships}, merge=True)
    batch.commit()

    _set_team_claims(uid, memberships)
    return {'teamId': team_id, 'name': team.get('name'), 'inviteCode': code,
            'createdBy': team.get('createdBy'),
            'isMasterTeam': team.get('isMasterTeam', False),
            'memberCount': team.get('memberCount', 0) + 1}


@https_fn.on_call()
def leave_team(req: https_fn.CallableRequest) -> dict:
    """Leave a team. Blocks the last admin from orphaning the team."""
    if not req.auth:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Must be authenticated")
    team_id = (req.data or {}).get('teamId')
    if not team_id:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "Missing teamId")
    uid = req.auth.uid
    db = get_db()

    team_ref = db.collection('teams').document(team_id)
    team_snap = team_ref.get()
    if not team_snap.exists:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.NOT_FOUND, "Team not found")
    team = team_snap.to_dict() or {}

    member_ref = team_ref.collection('members').document(uid)
    member_snap = member_ref.get()
    if not member_snap.exists:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.PERMISSION_DENIED, "Not a member of this team")
    if (member_snap.to_dict() or {}).get('role') == 'admin' and team.get('memberCount', 0) <= 1:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                                  "The last admin cannot leave the team")

    user_snap = db.collection('users').document(uid).get()
    user_data = user_snap.to_dict() or {} if user_snap.exists else {}
    memberships = dict(user_data.get('teamMemberships') or {})
    memberships.pop(team_id, None)
    current = user_data.get('currentTeamId')
    new_current = current if current != team_id else next(iter(memberships), None)

    batch = db.batch()
    batch.delete(member_ref)
    batch.update(team_ref, {'memberCount': firestore.Increment(-1)})
    batch.set(db.collection('users').document(uid),
              {'currentTeamId': new_current, 'teamMemberships': memberships}, merge=True)
    batch.commit()

    _set_team_claims(uid, memberships)
    return {'success': True, 'currentTeamId': new_current}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd functions && ./venv/bin/python -m pytest tests/test_membership_callables.py -v` then the full suite `./venv/bin/python -m pytest tests/`
Expected: new tests pass; full suite still green (baseline 47).

- [ ] **Step 5: Commit**

```bash
git add functions/main.py functions/tests/test_membership_callables.py
git commit -m "feat(auth): add server-side membership callables

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

// --- The two privilege-escalation vectors this fix closes ---

test('client cannot write its own teamMemberships (claim-source escalation)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice'), {
      displayName: 'Alice',
      teamMemberships: {},
    });
  });
  // She may update her profile...
  await assertSucceeds(
    setDoc(doc(alice(), 'users/alice'), { displayName: 'Al' }, { merge: true })
  );
  // ...but NOT teamMemberships (the claim source is server-only).
  await assertFails(
    setDoc(doc(alice(), 'users/alice'), { teamMemberships: { teamB: 'admin' } }, { merge: true })
  );
});

test('client cannot self-insert a team member doc (self-join escalation)', async () => {
  await assertFails(
    setDoc(doc(alice(), 'teams/teamB/members/alice'), { role: 'admin', userId: 'alice' })
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

    // Team memberships are mirrored into a custom claim by the membership
    // callables (create_team/join_team/leave_team). Reading the token is
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
      allow read:   if isSignedIn() && request.auth.uid == userId;
      allow create: if isSignedIn() && request.auth.uid == userId;
      // teamMemberships is the claim source — a client may update its own
      // profile / currentTeamId but NEVER teamMemberships (server-only, set
      // by the membership callables). This is the core of the isolation fix.
      allow update: if isSignedIn() && request.auth.uid == userId
                      && !('teamMemberships' in
                           request.resource.data.diff(resource.data).affectedKeys());
    }

    match /teams/{teamId} {
      allow read:   if isTeamMember(teamId);
      allow create: if false;                      // create_team callable only
      allow update: if isTeamMember(teamId);       // e.g. invite-code regen

      // Membership is server-authoritative: only the callables (Admin SDK,
      // which bypasses rules) write member docs. A client-writable member
      // doc would let anyone self-join any team.
      match /members/{memberId} {
        allow read:  if isTeamMember(teamId);
        allow write: if false;
      }
    }

    match /teamSettings/{teamId} {
      allow read, write: if isTeamMember(teamId);
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
Expected: PASS (7 passed).

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

## Task 6: Route team_repository through the callables + refresh token

`team_repository`'s mutation methods must stop writing membership client-side and instead call the Task 1 callables (`create_team`/`join_team`/`leave_team`). After the callable returns (claim already set server-side), the client force-refreshes its ID token so the new `teams` claim takes effect before reading team data.

**Files:**
- Create: `frontend/lib/core/auth/claims_refresher.dart`
- Test: `frontend/test/core/auth/claims_refresher_test.dart` (create)
- Modify: `frontend/lib/data/repositories/team_repository.dart` (`createTeam`, `joinTeamByCode`, `leaveTeam` → callables; keep read methods client-side)
- Modify: `frontend/lib/core/auth/auth_service.dart` (add `forceRefreshClaims`)
- Modify: `frontend/lib/presentation/providers/auth_provider.dart` (`createTeam`, `joinTeam`)

**Interfaces:**
- Consumes: the `create_team`/`join_team`/`leave_team` callables from Task 1 (return shapes documented there).
- Produces:
  - `Future<bool> waitForTeamClaim({required ClaimsFetcher fetchClaims, required String expectedTeamId, int maxAttempts, Duration delay, Future<void> Function(Duration)? sleep})` where `typedef ClaimsFetcher = Future<Map<String, dynamic>> Function();`
  - `AuthService.forceRefreshClaims() -> Future<Map<String, dynamic>>` — force-refreshes the ID token and returns its claims.
  - `team_repository.dart` keeps its existing method signatures (`createTeam`/`joinTeamByCode` return `Team`/`Team?`, `leaveTeam` returns void) — only the bodies change to invoke callables.

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
/// (set by the membership callables) or [maxAttempts] is reached. Returns
/// true if the claim arrived.
///
/// The callable sets the claim before returning, so the first refresh
/// normally already has it — the bounded poll is a cheap safety net against
/// token-refresh lag. [sleep] is injectable for tests.
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

- [ ] **Step 6: Route team_repository mutations through the callables**

`team_repository`'s `createTeam`/`joinTeamByCode`/`leaveTeam` must stop writing membership client-side (rules now forbid it) and call the Task 1 callables. Read methods (`getTeam`, `getUserTeams`, `getTeamSettings`, `updateTeamSettings`, `regenerateInviteCode`) stay as-is. `Team` and the `AuthException*` types are already imported; `cloud_functions` is already a dependency (schedule_service uses callables — obtain the callable the same way it does, so the Functions region matches).

Add to `frontend/lib/data/repositories/team_repository.dart`:

```dart
import 'package:cloud_functions/cloud_functions.dart';
```

Replace the bodies of the three mutation methods (keep their existing signatures), deleting the `_firestore.runTransaction(...)` blocks they contained:

```dart
  Future<Team> createTeam({
    required String name,
    required String createdBy,
    bool isMasterTeam = false,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('create_team');
      final result = await callable.call<dynamic>({
        'name': name,
        'isMasterTeam': isMasterTeam,
      });
      return _teamFromCallable(result.data);
    } on FirebaseFunctionsException catch (e) {
      _mapFunctionsError(e);
    }
  }

  Future<Team?> joinTeamByCode({
    required String inviteCode,
    required String userId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('join_team');
      final result = await callable.call<dynamic>({'inviteCode': inviteCode});
      return _teamFromCallable(result.data);
    } on FirebaseFunctionsException catch (e) {
      _mapFunctionsError(e);
    }
  }

  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('leave_team');
      await callable.call<dynamic>({'teamId': teamId});
    } on FirebaseFunctionsException catch (e) {
      _mapFunctionsError(e);
    }
  }

  Team _teamFromCallable(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    return Team(
      id: map['teamId'] as String,
      name: (map['name'] as String?) ?? '',
      inviteCode: (map['inviteCode'] as String?) ?? '',
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: DateTime.now(),
      isMasterTeam: (map['isMasterTeam'] as bool?) ?? false,
      memberCount: (map['memberCount'] as int?) ?? 1,
    );
  }

  /// Maps a callable error to the AuthException the UI already handles.
  Never _mapFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'not-found':
        throw const AuthExceptionInvalidInviteCode();
      case 'already-exists':
        throw const AuthExceptionAlreadyInTeam();
      case 'failed-precondition':
        throw const AuthExceptionCannotLeaveTeam();
      default:
        throw AuthException(e.message ?? 'Team operation failed');
    }
  }
```

Verify with `cd frontend && flutter analyze` before moving on.

- [ ] **Step 7: Wire the refresh into create/join**

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

- [ ] **Step 8: Verify analyze + full frontend suite**

Run: `cd frontend && flutter analyze && flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 9: Commit**

```bash
git add frontend/lib/core/auth/claims_refresher.dart frontend/test/core/auth/claims_refresher_test.dart frontend/lib/data/repositories/team_repository.dart frontend/lib/core/auth/auth_service.dart frontend/lib/presentation/providers/auth_provider.dart
git commit -m "feat(auth): route team membership through callables

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
