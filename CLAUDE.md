# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SushiScout 26 is an FRC/FTC robotics scouting app. Scouts use the Flutter app to record match data at competitions, which syncs to Firestore and Google Sheets for analysis.

## Architecture

**Frontend** (`frontend/`): Flutter app using Riverpod for state management. Targets Windows, macOS, Linux, Android, iOS, and web. Firebase Auth for team-scoped access.

**Backend** (`functions/`): Python 3.11 Firebase Cloud Functions. Syncs Firestore match data bidirectionally with Google Sheets.

### Frontend Architecture (offline-first)

- **Offline-first pattern**: Local Drift/SQLite DB is the source of truth for reads. Firestore syncs in background. App works fully offline.
- `data/repositories/scouting_repository.dart` — abstract interface for data operations
- `data/repositories/hybrid_repository.dart` — combines local SQLite + Firestore; reads from local, queues writes for sync
- `data/repositories/firestore_repository.dart` — direct Firestore operations
- `data/local/sync/sync_manager.dart` — handles offline queue and connectivity-aware sync
- `data/local/database/` — Drift (SQLite) database with code generation
- `presentation/factories/scouting_form_factory.dart` — factory that returns FRC or FTC form based on `event.programType`
- Two scouting forms: `frc_rebuilt_form.dart` (FRC) and `ftc_decode_form.dart` (FTC)

### Firestore Collections

- `events` — competition events with programType (FRC/FTC), tbaKey, teamId
- `matches` — top-level collection of match reports with eventId field (recently refactored from subcollection)
- `sync_tracking` — maps report IDs to Google Sheets row numbers for sync idempotency
- `tba_cache` — cached Blue Alliance API responses (24h TTL)

### Auth & Team Isolation

- Firebase Auth with Google Sign-In (mobile/web) and email/password (desktop)
- Team membership stored in `teams/{teamId}/members/{userId}` subcollection — Firestore rules check this
- `activeTeamIdProvider` → `currentTeamIdProvider` → `FirestoreRepository(teamId:)` — all queries filter by team
- `createTeam`/`joinTeam`/`leaveTeam` must always write/delete the `members` subcollection doc
- `switchTeam` must persist `currentTeamId` to Firestore user doc (not just local state)

### Cloud Functions

- `on_match_written` — Firestore trigger on `matches/{reportId}` that syncs creates/updates/deletes to Google Sheets
- `backfill_event_to_sheets` — callable function to bulk-sync an event's matches
- `update_match_from_sheets` / `sync_from_sheets_http` — reverse sync from Sheets back to Firestore
- `fetch_event_schedule` (`tba_sync.py`) — callable that pulls FRC/FTC schedules from The Blue Alliance API (cached 24h in `tba_cache` collection)
- `functions/services/sheets_service.py` — Google Sheets API wrapper (different column schemas for FRC vs FTC)
- `functions/services/sync_tracker.py` — tracks row numbers in `sync_tracking` collection for Firestore↔Sheets mapping

## Common Commands

### Frontend (Flutter)
```bash
cd frontend
flutter run -d windows --hot     # Run on Windows with hot reload
flutter test                     # Run all tests
flutter test test/widgets/counter_card_test.dart  # Run single test
flutter analyze                  # Static analysis
flutter pub get                  # Install dependencies
dart run build_runner build      # Regenerate Drift/Riverpod code (*.g.dart files)
```

### Cloud Functions (Python)
```bash
cd functions
python -m venv venv && source venv/Scripts/activate  # Windows venv
pip install -r requirements.txt
python -m pytest tests/          # Run function tests
firebase deploy --only functions # Deploy functions
firebase emulators:start         # Local emulator
```

### Firebase
```bash
firebase deploy --only firestore:rules   # Deploy Firestore rules
firebase deploy --only firestore:indexes # Deploy indexes
```

## Commit Convention

Conventional Commits format: `<type>(<scope>): <subject>`

Types: feat, fix, docs, style, refactor, perf, test, chore, ci, revert
Scopes: frontend, backend, db, api, ui, theme, sync, test, config, deps

Subject: imperative mood, no capitalization, no trailing period, max 50 chars.

## Key Technical Details

- Drift database requires code generation — run `dart run build_runner build --delete-conflicting-outputs` after changing `tables.dart` or `app_database.dart`
- Firebase secrets used: `GOOGLE_SHEETS_CREDENTIALS`, `MASTER_SPREADSHEET_ID`, `SYNC_API_KEY`, `TBA_API_KEY`
- Firestore persistence is enabled with unlimited cache for offline-first reliability
- The `gameData` field on MatchReport is a flexible `Map<String, dynamic>` that varies by program type (FRC vs FTC)
- Drift SQLite has 4 tables: LocalMatchReports, LocalEvents, SyncQueue, SyncConflicts
- SyncManager runs periodic sync every 5 minutes with exponential backoff retry (max 5 attempts)
- `core/result/result.dart` provides a sealed `Result<T, E>` type used throughout data layer
- After merging branches, check for duplicate dependencies in `pubspec.yaml` and leftover conflict markers (`>>>>>>>`)
- Generated files (`*.g.dart`, `*.mocks.dart`) must never be hand-edited — run codegen or mockito instead
- Riverpod providers that need to react to state changes must use `overrideWith((ref) =>)`, not `overrideWithValue()`
- Firestore composite queries (teamId + eventId + isDeleted + createdAt) may require composite indexes — deploy with `firebase deploy --only firestore:indexes`

## Testing

- Run `flutter test` from `frontend/` for the full Dart suite (currently 285 tests).
- Run `python -m pytest tests/` from `functions/` for the Python suite (currently 24 tests).
- Generated files (`*.g.dart`, `*.mocks.dart`, `*.freezed.dart`) are excluded from `flutter analyze` via `analysis_options.yaml`.

## Working on this repo with AI (Claude Code)

This repo ships shared Claude Code config in `.claude/` so collaborators get a
consistent AI setup on clone:
- **Hooks** (`settings.json`): auto `dart format` + `flutter analyze` on `.dart`
  edits, and a guard that blocks edits to generated `*.g.dart` / `*.mocks.dart`.
- **Agents** (`.claude/agents/`): `security-reviewer`, `sync-logic-reviewer`,
  `drift-migration-reviewer` — invoke after touching the matching code.
- **Skills** (`.claude/skills/`): `/run-tests`, `/drift-codegen`,
  `/deploy-functions`, `/firestore-rules-check`.

Personal/ephemeral state (`settings.local.json`, ralph logs, `.superpowers/`,
`.opencode/`) is gitignored — set your own `settings.local.json` permissions.

### Recommended plugins (installed per-user, not via clone)

Plugins live in `~/.claude/`, so they are not pulled in by cloning. Add the
marketplaces, then install:

```bash
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add mksglu/context-mode

# Core for this repo
claude plugin install firebase@claude-plugins-official        # enabled via settings.json
claude plugin install superpowers@claude-plugins-official     # TDD/debugging/review disciplines
claude plugin install context-mode@context-mode               # keeps large tool output out of context
claude plugin install context7@claude-plugins-official        # live library docs (Flutter/Firebase/Riverpod)
claude plugin install commit-commands@claude-plugins-official # /commit, /commit-push-pr
claude plugin install code-review@claude-plugins-official     # /code-review
```

