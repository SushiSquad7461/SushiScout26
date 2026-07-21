# Design: Team Isolation (Step 1)

- **Date:** 2026-07-20
- **Status:** Approved (pending written-spec review)
- **Scope:** First step of the SushiScout simplification roadmap — make multiple
  teams fully independent and close the `teamId == ''` global-access hole.

## 1. Problem

SushiScout's stated long-term goal is a multi-team FRC/FTC scouting app where
each team operates independently. Two defects block that today:

1. **Event identity is global.** `events/{eventCode}` uses the raw competition
   code as the document ID (`firestore_repository.dart` `_getOrCreateEvent`), and
   the Google Sheet tab is derived from it (`sheet_name = event_id` in
   `functions/main.py`). Two teams scouting the same competition (e.g. `2026casf`)
   collide on the same event document and the same Sheet tab. Matches happen to be
   `teamId`-filtered, so this has not blown up yet, but the event doc and the
   export target are cross-team collision points.
2. **The `teamId == ''` escape hatch is a global-read hole.** Every rule in
   `firestore.rules` allows access when `resource.data.teamId == ''`. Any document
   with an empty `teamId` is readable/writable by *every* signed-in user across all
   teams. The same hatch is mirrored defensively throughout the Dart layer
   (`_filterToActiveTeam`, the sync-queue cross-team gate, `_stampSource`).

Separately, membership is currently checked with `exists()` in rules and a
Firestore read in Cloud Functions (`_is_team_member`), which costs a document read
on every check.

## 2. Goals / Non-goals

**Goals**
- Team-scope event identity so two teams never collide on an event doc or Sheet tab.
- Remove the `teamId == ''` escape hatch everywhere (rules + Dart + Python).
- Replace `exists()`-based membership checks with Firebase Auth **custom claims**
  (free in rules and Cloud Functions).
- Reset dev data (no migration — data is disposable).

**Non-goals (explicitly deferred to later roadmap steps)**
- Dropping Drift / collapsing to a single offline store (Step 3).
- Removing Google Sheets reverse-sync (Step 2).
- Schema/config-driven forms (Step 4).
- Any change to the venue transport model (QR/Bluetooth aggregation). See §11.

## 3. Prior-art validation

The FRC scouting community has solved multi-team scouting repeatedly; this design
was checked against both the offline and cloud-SaaS camps.

- **Cloud SaaS analogs** confirm the approach: **ScoutinFRC** (FRC 3824) is
  Flutter + Firestore multi-team — the same stack and goal. **Scoutradioz**
  (FRC 102) is a multi-org SaaS (MongoDB + AWS + TBA Firehose) with configurable
  surveys. **CyberapK 2026** uses admin/member **roles** — matching our
  role-bearing claim. **FRC 2135** uses a single DB spanning many events, filtered
  by the selected event — validating our single top-level `matches` collection +
  composite `eventId` filter over per-event collections or subcollections.
- **Firestore multi-tenancy guidance:** put the tenant id in every queryable
  filter and enforce it in rules; never rely on rules to "filter after fetch"
  (an unconstrained query is rejected, not trimmed). Our always-on `teamId`
  query filter satisfies this. `exists()`/`get()` in rules each cost a document
  read; **custom claims** are the recommended free alternative.
- **Offline camp** (Citrus Circuits 1678, QRScout 2713, FRC Krawler 2052) treats
  venue connectivity as absent and moves data via QR/Bluetooth aggregation. This
  does not affect Step 1 (isolation is needed regardless of transport) but informs
  the future transport decision — recorded in §11.

References are listed in §12.

## 4. Event identity — composite ID

The app-level event identifier becomes:

```
eventId = "${teamId}_${eventCode}"      // e.g. "aB3kZx9Q_2026casf"
```

- This is the `events` document ID, the value stored in `matches.eventId`, and —
  automatically, since `sheet_name = event_id` — the Google Sheet tab name.
- `programType` (`FRC`/`FTC`) stays an authoritative **field** on the event doc,
  as it is today. It is *not* encoded in the ID: FRC event codes come from The
  Blue Alliance and FTC codes from FIRST's own system, so a single team running an
  FRC and an FTC event with a byte-identical code is a non-scenario, and the
  backend already resolves the sheet schema from the `programType` field
  (`_resolve_event_program_type`).
- The security boundary is the `teamId` **field** + membership check (§6/§7). The
  composite ID is a client-side convenience that prevents doc-ID collisions; it is
  not itself the isolation mechanism.

The user still types only the bare event code; the app composes the ID.

## 5. Provider layer (single composition point)

Composition happens in exactly one place so it is testable and not duplicated:

- `currentEventCodeProvider` → the raw event code the user entered (from settings).
  Used for schedule lookup and TBA/FTC fetch, which are **global/public** data.
- `currentEventIdProvider` → `"${currentTeamId}_${currentEventCode}"`. Used for all
  `events`/`matches` operations.

Repository method signatures are unchanged — they keep taking an `eventId` string;
they simply receive the composite. Everything currently passing a bare event code
as an `eventId` (e.g. `dashboard.dart` reading `settings[PrefKeys.eventCode]`) is
routed through `currentEventIdProvider`. A grep sweep during planning will find all
such sites.

## 6. Schedules stay global

`schedules`, `tba_cache`, and `ftc_cache` are public — the schedule for `2026casf`
is identical for every team — so they remain keyed by **raw event code +
programType** (as today) and are **not** team-scoped. This is why the app carries
two values: the raw `eventCode` (schedule/TBA) and the composite `eventId`
(events/matches). `frc_rebuilt_form._loadSchedule` and its FTC counterpart continue
to query `schedules` by the raw code.

## 7. Team membership via custom claims

Replaces `exists()` in rules and the Firestore read in Cloud Functions.

**Claim shape** — mirror the existing `users/{uid}.teamMemberships` map:

```json
{ "teams": { "<teamId>": "admin", "<teamId2>": "member" } }
```

Well under the 1000-byte custom-claim limit for realistic team counts. The claim
carries the role, matching the admin/member RBAC used by other cloud scouters.

**Sync mechanism — server-side callables (NOT a client-writable source).**
> ⚠️ Security correction (supersedes an earlier trigger-based draft): membership
> must never be derived from anything the client can write. Both `users/{uid}` and
> a self-created `teams/{tid}/members/{uid}` doc are client-writable, so mirroring
> them into a claim would let any user self-assert membership in any team and read
> or write its data. Membership mutation therefore moves server-side.

Three callable Cloud Functions validate server-side and set the claim with the
Admin SDK:

- `create_team(name, isMasterTeam)` — generates a unique invite code, creates the
  team + `members/{uid}='admin'`, writes `users/{uid}.teamMemberships`, then sets
  the caller's `{teams: ...}` claim. Returns the team.
- `join_team(inviteCode)` — looks up the team by invite code **server-side** (the
  only proof of authorization), rejects if already a member, writes
  `members/{uid}='member'` + the user mirror, sets the claim. Returns the team.
- `leave_team(teamId)` — verifies the caller's `members/{uid}` doc, enforces
  "last admin can't leave", removes the member doc + user mirror, sets the claim.

`users/{uid}.teamMemberships` remains the claim source, but it is now written
**only** by these callables (Admin SDK) and rules forbid the client from touching
it (§8) — so it is trustworthy. No Firestore trigger, no echo guard, no
`claimsRefreshedAt`. `team_repository`'s three mutation methods change from
client-side Firestore transactions to callable invocations (reads stay
client-side).

**Rules** read the claim for free (see §8).

**Cloud Functions** `_is_team_member()` reads `req.auth.token` claims instead of a
Firestore read:

```python
def _is_team_member(auth_token: dict, team_id: str) -> bool:
    if not team_id:
        return False
    return team_id in (auth_token.get('teams') or {})
```

(Callers pass `req.auth.token` instead of `req.auth.uid`.)

**Token refresh — simpler now.** The callable sets the claim *before returning*, so
there is no async propagation gap: after `create_team`/`join_team` succeeds the
client makes a single `getIdToken(true)` and the new claim is present. A small
bounded retry is kept as a cheap safety net but normally succeeds on the first try.
`switchTeam` needs **no** refresh — the claim lists *all* the user's teams; the
active team is separate state (`currentTeamId`), used only to choose the query
filter.

**Offline alignment.** Members obtain connectivity before the competition (a stated
requirement), so they receive their token+claims then; Firebase's cached token stays
valid for offline writes, which Firestore validates on reconnect. Custom claims and
the "~1 hour offline" requirement do not conflict.

## 8. Firestore rules (`firestore.rules`)

Delete every `resource.data.teamId == '' || …` branch. Membership becomes a free
token read.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() { return request.auth != null; }

    // Team memberships mirrored into a custom claim by the membership
    // callables (create_team/join_team/leave_team). Free — no document read.
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
      // which bypasses rules) write member docs. A client-writable member doc
      // would let anyone self-join any team.
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

Notes:
- After the data wipe every doc has a real `teamId`; a missing/empty `teamId`
  resolves to *denied*, not the old global-allow.
- `teams` create stays open to any signed-in user (needed to bootstrap the first
  team). Optionally hardened with `request.resource.data.createdBy == request.auth.uid`
  — flagged, not required for this step.
- The `members/{memberId}` create rule still lets a creator write their own first
  member doc (`memberId == request.auth.uid`) before their claim exists.

## 9. Dart & Python cleanup

Remove the now-dead empty-`teamId` allowances (every write stamps a real `teamId`):
- `hybrid_repository.dart` `_filterToActiveTeam`: drop the `r.teamId.isEmpty ||` branch.
- `sync_manager.dart` cross-team gate: drop the empty-`teamId` allowance.
- `firestore_repository.dart` `_stampSource`: `teamId` is always present, so the
  conditional stamping simplifies.
- `functions/main.py`: where callables treat empty `event_team_id` as a bypass
  (`if event_team_id and not _is_team_member(...)`), require a real team and
  membership; switch the membership check to the token-claims form from §7.

## 10. Local Drift DB impact (no schema/migration change)

`LocalMatchReports.eventId` and `LocalEvents.id` now hold the composite value,
consistent with Firestore. This also **fixes a latent local-cache collision**:
`UNIQUE(event_id, match_id, team_number)` with a raw event code meant two teams
scouting the same robot in the same match of the same event collided in SQLite;
with a composite `event_id` they do not. No column change is needed, so no Drift
migration — the dev DB is cleared as part of the wipe (§11 below is data, this is
schema: schema is unchanged).

## 11. Data reset (no migration)

Data is dev/test only and disposable, so we reset rather than migrate:
- Wipe Firestore dev collections: `events`, `matches`, `sync_tracking`, and any
  legacy schedule-shaped docs left in `matches`. (Exact `firebase firestore:delete`
  commands provided in the plan; requires the CLI login the user is performing.)
- Clear local SQLite (`clearAllLocalData`, or delete the DB file).
- Reseed by using the app.

Because there is no legacy empty-`teamId` data to preserve, the `teamId == ''`
branches are deleted outright rather than deprecated.

## 12. Testing & verification

- **Dart unit:** `currentEventIdProvider` composes `${teamId}_${code}` and handles a
  missing/empty active team; `currentEventCodeProvider` returns the raw code. Update
  existing repo/sync tests that assumed a raw-code `eventId`.
- **Python:** the `create_team`/`join_team`/`leave_team` callables validate input,
  mutate membership, and set the claim (tested with Admin-SDK mocks, following the
  existing `test_main.py` mock style); `_is_team_member` reads token claims correctly.
- **Isolation check (rules):** an automated `@firebase/rules-unit-testing` harness
  run against the Firestore emulator verifies: Team B cannot read Team A's
  `events`/`matches`; empty-`teamId` docs are not globally readable; **a client
  cannot write `users/{uid}.teamMemberships`; a client cannot write a
  `teams/{tid}/members/**` doc** (the two escalation vectors this fix closes).
- **Regression:** full `flutter test` (currently 285) and `pytest` (currently 47)
  green before the step is considered done.

## 13. Risks / open questions

- **Membership authority moved to callables.** This is the security fix: the client
  can no longer write its own membership (rules block `users.teamMemberships` and
  `members/**`), so it cannot forge a claim. A stale token can still name a team the
  user just left until the next refresh, but Firestore rules re-evaluate the claim on
  every request and reads are also query-filtered by `teamId`, so a stale claim grants
  nothing a fresh one wouldn't within one token lifetime.
- **`create_team` bootstrap:** the very first team read after `create_team` needs the
  refreshed token; the callable returns the team data directly so the UI does not
  block on a read before the refresh lands.
- **Composite Sheet-tab names** are ugly (`aB3kZx9Q_2026casf`) but functional and
  read-only; they get cleaned up when Sheets moves to per-team spreadsheets
  (`teamSettings.googleSheetId` already exists) in a later step.
- **`teams/{teamId}/members` subcollection** is now the server-authoritative roster
  (write-locked to the callables) and enables a future roster view.
- **Transport model** (venue connectivity) is untouched; the FRC offline camp's
  QR/Bluetooth aggregation is prior art for a later transport brainstorm, not this
  step.

## 14. References

- Firestore multi-tenancy: https://wild.codes/candidate-toolkit-question/how-do-you-model-firestore-multi-tenant-data-for-speed-and-safety
- Firestore rules conditions (get/exists cost): https://firebase.google.com/docs/firestore/security/rules-conditions
- Custom claims control access: https://firebase.google.com/docs/auth/admin/custom-claims
- Custom-claims-with-Firestore sync pattern (Doug Stevenson): https://medium.com/firebase-developers/patterns-for-security-with-firebase-supercharged-custom-claims-with-firestore-and-cloud-functions-bb8f46b24e11
- ScoutinFRC (FRC 3824, Flutter + Firebase, multi-team): https://github.com/HVA-FRC-3824/ScoutinFRC
- Scoutradioz (FRC 102, multi-org SaaS): https://github.com/FIRSTTeam102/scoutradioz
- QRScout (FRC 2713, JSON config-driven forms): https://github.com/FRC2713/QRScout
- Citrus Circuits scouting whitepapers (FRC 1678): https://www.citruscircuits.org/scouting.html
- The Purple Standard (community scouting-data schema): https://www.chiefdelphi.com/t/the-purple-standard-a-unified-and-community-driven-standard-for-frc-scouting-data/449394
