# Step 2 — Google Sheets as a one-way, per-team export (design)

- **Date:** 2026-07-21
- **Status:** Design approved, not implemented
- **Roadmap:** Step 2 of [`2026-07-21-simplification-roadmap.md`](2026-07-21-simplification-roadmap.md)
- **Depends on:** Step 1 (team isolation) — shipped
- **Independent of:** Steps 3 and 4

## 1. Goal

Google Sheets is read-only by decision (roadmap §3): analysts view it, nobody edits back.
The code still treats it as a bidirectional peer, and that bidirectionality is the largest
single source of backend complexity and bugs. This step makes the flow strictly
Firestore → Sheets, and moves each team onto its own spreadsheet.

Net effect is deletion: two endpoints, one Firestore collection, one service module, one
secret, and the echo-guard machinery on both sides. The one addition is a small
`set_team_sheet` callable, justified in §4.

## 2. Decisions made with the user

| Question | Decision |
|---|---|
| How does a team get a spreadsheet? | **Team admin pastes a Sheet URL/ID** they own and share with the service account. No Drive-API creation — the service account must never own a team's data. |
| No sheet configured? | **Silent no-op in the backend, visible state in the UI.** Export is opt-in; scouting works without it. |
| What replaces `sync_tracking`? | **Nothing.** Row lookup by `reportId` against the sheet itself. |
| Existing data? | **Wipe it.** All current data is test data. No migration script. |
| Who may set the sheet ID? | **Team admins only, via a callable with a write probe.** Clients cannot write the field directly. |
| Where does the config UI live? | **A section in the existing settings bottom sheet**, shown only to admins. |

## 3. Backend

### 3.1 Deleted

From `functions/main.py`:
- `update_match_from_sheets` callable (currently ~533–616)
- `sync_from_sheets_http` HTTP endpoint (currently ~618–683)
- The `lastSyncSource == 'sheets'` echo guard in `on_match_written` (currently ~220–230).
  With no writer stamping `'sheets'`, the branch is dead by construction.
- `SYNC_API_KEY`, including its entry in `firebase.json`
- `MASTER_SPREADSHEET_ID` and `get_master_spreadsheet_id()`, replaced by per-team IDs

Deleted outright:
- `functions/services/sync_tracker.py`
- The `sync_tracking` Firestore collection (data wiped)

From `frontend/lib/data/repositories/firestore_repository.dart`:
- The `lastSyncSource: 'app'` stamp inside `_stampSource` (currently ~85–92).

  **Correction to the brainstorm:** `_stampSource` does *two* jobs, and only one of them
  is echo-guard machinery. It also backfills `teamId` when absent, so that a trash/restore
  write racing a hard-delete (where `set+merge` degrades into a CREATE carrying only
  `{isDeleted: ...}`) still satisfies the `matches/{id}` create rule's `isValidTeamId()`
  check. Deleting the whole helper would reintroduce that bug. Keep the teamId half and
  rename the helper to `_withTeamId`; delete only the `lastSyncSource` line.

### 3.2 The write path

`on_match_written` and `backfill_event_to_sheets` resolve their target identically:

1. Read the match's `teamId` — falling back to the event doc's `teamId` when the match
   field is missing, the same way `_resolve_event_program_type` already treats the event
   doc as authoritative for legacy and externally-written docs. Then read
   `teamSettings/{teamId}.googleSheetId`. Absent or empty → log at debug level and return.
   Not an error, not retried.

   **Correction to the brainstorm:** the field lives on the separate `teamSettings/{teamId}`
   document (`TeamSettings` in `data/models/team.dart`), not on `teams/{teamId}`. Everything
   the brainstorm said about `teams/{teamId}` applies to `teamSettings/{teamId}` instead.
2. Tab name is the **bare event code**, not the composite `{teamId}_{eventCode}`.
   The workbook is already team-scoped, so the composite name Step 1 introduced
   (roadmap §5) is redundant. Derive it by stripping the `{teamId}_` prefix from the
   composite event id.
3. Resolve the row against the sheet itself:
   - `find_row_by_report_id(spreadsheet_id, tab, reportId)` — already implemented,
     reads only columns A:D.
   - Found → `update_row`. Not found → `append_row`.
   - `isDeleted: true` → find, then `delete_row`.

This is the entire idempotency story. The sheet answers "is this report already here?",
so there is no second store that can drift out of agreement with it.

### 3.3 Why the tracker goes away

`sync_tracking` was a row-number map, and it carried a live bug: `delete_row` shifts every
row below it up by one, but stored `rowNumber`s were never adjusted. After any delete,
subsequent updates wrote to the wrong row. Looking the row up by `reportId` at use time
makes that class of bug structurally impossible, at the cost of one extra Sheets read per
write.

`SheetsService` otherwise keeps its API. The `append_rows` / `update_rows` batch helpers
should be removed only if backfill genuinely no longer calls them — verify at
implementation time rather than assuming.

## 4. Configuring the sheet

New callable `set_team_sheet(teamId, sheetIdOrUrl)`:

1. Reject unless the caller's `teams[teamId]` custom claim is `admin`.
2. Accept either a full Sheets URL or a bare ID; extract the ID. People paste the URL.
3. **Write probe.** Open the spreadsheet with the service account and confirm write access.
   On failure, return `failed-precondition` with a message naming the service-account
   email, so the UI can say *"share this sheet with `<sa>@<project>.iam.gserviceaccount.com`
   as Editor"*.
4. Only after the probe passes, write `teamSettings/{teamId}.googleSheetId`.

This is the one place Step 2 adds code rather than removing it. It earns its place twice
over: it is the same server-authoritative pattern Step 1 established for anything
security-relevant, and validating at configure time converts a competition-day mystery
("why is nothing exporting?") into an inline, actionable error.

Rules changes in `firestore.rules`:
- `teamSettings/{teamId}` is currently `allow read, write: if isTeamMember(teamId)`. Split
  it: reads stay member-gated, writes stay member-gated *except* that no client write may
  create or change `googleSheetId`.
- Delete the now-dead `match /sync_tracking/{doc} { allow read, write: if false; }` rule
  along with the collection.

No `isTeamAdmin()` rules helper is added. The admin check lives in the callable, which uses
the Admin SDK and bypasses rules anyway; the UI gate reads the claim client-side. A rules
helper here would have no caller — add one when something actually needs it.

## 5. Frontend

- Extract `_SettingsSheet` from `dashboard.dart` (currently ~862+) into
  `presentation/widgets/settings_sheet.dart` with no behavior change. `dashboard.dart` is
  already 1137 lines and Step 4 wants it split; this keeps the step from making that worse.
- Add a **Sheets export** section to that sheet, rendered only when the active team's claim
  role is `admin`:
  - Status: *Not configured* / *Connected*, the latter linking out to the sheet.
  - A paste field wired to `set_team_sheet`, with the service-account error surfaced inline.
  - A **Backfill this event** button calling the existing `backfill_event_to_sheets`.
    This is what stops a team that configures its sheet mid-competition from ending up with
    a silently half-empty workbook.
- `team_repository` gains `setTeamSheet()` calling the callable. `updateTeamSettings()`
  drops its `googleSheetId` parameter, since clients can no longer write that field.
- A new `isTeamAdminProvider` derives admin-ness from the existing
  `AuthState.teamMemberships` map (`teamId → role`), so no extra fetch is needed.

## 6. Testing

Step 1 shipped two production bugs with the same root cause: the rules were validated only
against seeded data, never the empty-database first-run path. Both failures were
first-run-only. Every area below therefore includes its unconfigured / empty case.

**Python** (`functions/tests/`):
- No `googleSheetId` on the team → `on_match_written` no-ops, raises nothing, retries nothing.
- Report absent from the sheet → appended. Report present → updated in place.
- `isDeleted: true` → row found and deleted.
- Tab name is the bare event code, not the composite id.
- `set_team_sheet`: rejects a non-admin; rejects a sheet the service account cannot write,
  with the SA email in the message; accepts both a full URL and a bare ID.
- Deleted-endpoint tests in `test_main.py` removed alongside their subjects.

**Firestore rules** (`test/firestore-rules/rules.test.js`):
- A member cannot write `googleSheetId` on `teamSettings/{teamId}`.
- An admin cannot write it either — the callable is the only path.
- A member can still write `defaultEventCode` on the same doc.
- Non-members remain denied on `teamSettings/{teamId}` entirely.

**Dart** (`frontend/test/`):
- `settings_sheet` renders the export section for an admin and hides it for a member.
- `firestore_repository` no longer writes `lastSyncSource` on create, update, soft-delete,
  or restore — while still backfilling `teamId` on trash/restore (the `_withTeamId`
  behavior preserved in §3.1).

## 7. Rollout

Order matters — rules before functions, so no window exists where a client could write the
field.

1. Deploy rules: `firebase deploy --only firestore:rules`
2. Deploy functions, naming them explicitly (deploying all validates all secrets, and
   `SYNC_API_KEY` is being removed):
   `firebase deploy --only functions:on_match_written,functions:backfill_event_to_sheets,functions:set_team_sheet`
   Removed functions need an explicit delete via the Firebase console or CLI.
3. Delete the `sync_tracking` collection.
4. Remove the `SYNC_API_KEY` and `MASTER_SPREADSHEET_ID` secrets.
5. Each team admin pastes a sheet ID and runs a backfill per event.

The master spreadsheet is abandoned in place, not migrated. Firestore holds everything it
holds.

## 8. Risk

Low. Nothing in the app reads from Sheets, so the deleted reverse path has no in-app
consumer. The realistic failure modes are:

- **A team forgets to share the sheet with the service account.** Caught at configure time
  by the write probe (§4), which is the reason it exists.
- **Sheets API quota** on the extra read-per-write from §3.2. Scouting write volume is a
  few hundred rows per event across a handful of scouts, well inside the per-minute quota,
  but worth watching in logs during the first competition.

## 9. Out of scope

- In-app analysis (roadmap §3 defers this deliberately).
- Steps 3 and 4. This step touches `firestore_repository.dart` only to delete
  `_stampSource`; it does not begin the storage collapse.
