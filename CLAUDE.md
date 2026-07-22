# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SushiScout 26 is an FRC/FTC robotics scouting app. Scouts use the Flutter app to record match data at competitions, which syncs to Firestore and Google Sheets for analysis.

## Active roadmap

There is an in-progress simplification effort. **Before starting any refactor or
"why is this so complex" work, read
[`docs/superpowers/specs/2026-07-21-simplification-roadmap.md`](docs/superpowers/specs/2026-07-21-simplification-roadmap.md)** —
it holds the audit evidence, the requirements already decided with the user, FRC prior-art
research, and the scope of the remaining steps. Step 1 (team isolation) and Step 2
(Sheets one-way) are shipped; Step 3 (collapse to a single offline store) and Step 4
(schema-driven forms) are not started. Each still needs its own brainstorm → spec → plan.

## Architecture

**Frontend** (`frontend/`): Flutter app using Riverpod for state management. Targets Windows, macOS, Linux, Android, iOS, and web. Firebase Auth for team-scoped access.

**Backend** (`functions/`): Python 3.11 Firebase Cloud Functions. One-way exports Firestore match data to each team's own Google Sheet (Firestore -> Sheets only; there is no reverse path).

### Frontend Architecture (offline-first)

- **Offline-first pattern**: Local Drift/SQLite DB is the source of truth for reads. Firestore syncs in background. App works fully offline.

### Firestore Collections

- `events` — competition events with programType (FRC/FTC), tbaKey, teamId
- `matches` — top-level collection of match reports with eventId field (recently refactored from subcollection)
- `tba_cache` — cached Blue Alliance API responses (24h TTL)

### Auth & Team Isolation

- Firebase Auth with Google Sign-In (mobile/web) and email/password (desktop)
- **Membership is server-authoritative.** Rules trust ONLY the `{teams: {teamId: role}}` custom auth claim, which is minted exclusively by the `create_team`/`join_team`/`leave_team` callables (Admin SDK). Clients CANNOT write `users/{uid}.teamMemberships` or `teams/{tid}/members/**` — rules deny both. Never "simplify" this back to a client write or a trigger mirroring a client-writable field: that is a privilege-escalation hole (any user could self-assert membership in any team).
- `team_repository`'s createTeam/joinTeamByCode/leaveTeam call those callables; reads stay client-side
- After create/join/leave, the client must force `getIdToken(true)` (`AuthService.forceRefreshClaims`) or the new claim isn't in the token yet
- `activeTeamIdProvider` → `currentTeamIdProvider` → `FirestoreRepository(teamId:)` — all queries filter by team
- `switchTeam` needs no token refresh (the claim lists all teams; active team is separate state)
- Event ids are composite `{teamId}_{eventCode}` (`currentEventIdProvider`); the RAW code (`currentEventCodeProvider` / `Event.tbaKey`) is only for the public `schedules`/TBA lookups
- Onboarding existing users to this model needs a one-time **claims backfill** — a data wipe alone leaves memberships in Firestore with no claim, and users get `permission-denied`

### Cloud Functions

- `create_team` / `join_team` / `leave_team` — callables that own ALL membership mutation: validate server-side (invite code, already-member, last-admin), write membership with the Admin SDK, then set the `{teams: ...}` custom claim. See Auth & Team Isolation above.
- `set_team_sheet` — admin-only callable that validates write access to a team-supplied spreadsheet (via a real write probe, not just a metadata read) and stores it as that team's `teamSettings/{teamId}.googleSheetId`. **`googleSheetId` is server-authoritative**: rules deny every client write to it (create, update, and removal via `diff().affectedKeys()`), so this callable is the only write path. Never "simplify" it back to a client write — that would let any member silently redirect the team's export to a spreadsheet they control, with no admin check and no write probe.
- `on_match_written` — Firestore trigger on `matches/{reportId}` that one-way exports creates/updates/deletes to the owning team's Google Sheet (no reverse path back into Firestore)
- `backfill_event_to_sheets` — callable function to bulk-export an event's matches into its team's sheet; idempotent (row identity is resolved by looking the report id up in the sheet itself)
- `fetch_event_schedule` (`tba_sync.py`) — callable that pulls FRC/FTC schedules from The Blue Alliance API (cached 24h in `tba_cache` collection)
- `functions/services/sheets_service.py` — Google Sheets API wrapper (different column schemas for FRC vs FTC); one-way export only, no row-tracking collection

## Commit Convention

Conventional Commits format: `<type>(<scope>): <subject>`

Types: feat, fix, docs, style, refactor, perf, test, chore, ci, revert
Scopes: frontend, backend, db, api, ui, theme, sync, test, config, deps

Subject: imperative mood, no capitalization, no trailing period, max 50 chars.

## Key Technical Details

- Drift database requires code generation — run `dart run build_runner build --delete-conflicting-outputs` after changing `tables.dart` or `app_database.dart`
- Firebase secrets used: `GOOGLE_SHEETS_CREDENTIALS`, `TBA_API_KEY`, `FTC_API_USERNAME`, `FTC_API_KEY`
- Firestore persistence is enabled with unlimited cache for offline-first reliability
- The `gameData` field on MatchReport is a flexible `Map<String, dynamic>` that varies by program type (FRC vs FTC)
- Drift SQLite has 4 tables: LocalMatchReports, LocalEvents, SyncQueue, SyncConflicts
- SyncManager runs periodic sync every 5 minutes with exponential backoff retry (max 5 attempts)
- `core/result/result.dart` provides a sealed `Result<T, E>` type used throughout data layer
- After merging branches, check for duplicate dependencies in `pubspec.yaml` and leftover conflict markers (`>>>>>>>`)
- Generated files (`*.g.dart`, `*.mocks.dart`) must never be hand-edited — run codegen or mockito instead
- Riverpod providers that need to react to state changes must use `overrideWith((ref) =>)`, not `overrideWithValue()`
- Firestore composite queries (teamId + eventId + isDeleted + createdAt) may require composite indexes — deploy with `firebase deploy --only firestore:indexes`
- **`functions/venv` must be Python 3.11**, matching `"runtime": "python311"` in `firebase.json`. The CLI looks for `venv/bin/python3.11` and otherwise fails with `Missing virtual environment at venv directory`. If the system lacks 3.11: `uv python install 3.11 && uv venv functions/venv --python 3.11`. A venv missing `bin/activate` (created when `python3-venv` isn't installed) also fails.
- **Never run the web app with `flutter run -d web-server`** — in debug it loads all ~1371 DDC modules with zero errors but `main()` waits on a Dart debugger handshake that only the Chrome extension satisfies, so you get a silent blank page. Use `flutter build web --release` + a static server, or `-d chrome`.
- **Firestore rules: `resource` is null when the doc doesn't exist.** `allow read: if isTeamMember(resource.data.teamId)` throws `Null value error` (=> denied) on a get-or-create path. Guard with `resource == null ? <fallback> : <check>` — this broke the first match written to every new event.
- Deploying functions validates ALL secrets up front: one missing secret (e.g. `TBA_API_KEY`) blocks the whole deploy. Deploy a subset with `firebase deploy --only functions:name1,functions:name2`.

## Testing

- Run `flutter test` from `frontend/` for the full Dart suite (currently 292 tests).
- Run `./venv/bin/python -m pytest tests/` from `functions/` for the Python suite (currently 56 tests).
- Firestore rules have an automated isolation suite (16 tests): `firebase emulators:exec --only firestore "cd test/firestore-rules && ./node_modules/.bin/jest --runInBand"` (run from repo root; `npm test` inside `emulators:exec` hits a shell-quoting bug on Linux — call the jest binary directly). Emulator is pinned to port 8099 so it doesn't collide with a local app server on 8080.
- Generated files (`*.g.dart`, `*.mocks.dart`, `*.freezed.dart`) are excluded from `flutter analyze` via `analysis_options.yaml`.

## Working on this repo with AI (Claude Code)

Personal/ephemeral state (`settings.local.json`, ralph logs, `.superpowers/`,
`.opencode/`) is gitignored — set your own `settings.local.json` permissions.

For recommended plugins and first-time setup, see the `repo-ai-setup` skill
(`.claude/skills/repo-ai-setup/SKILL.md`).

