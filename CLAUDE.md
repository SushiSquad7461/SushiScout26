# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SushiScout 26 is an FRC/FTC robotics scouting app. Scouts use the Flutter app to record match data at competitions, which syncs to Firestore and Google Sheets for analysis.

## Active roadmap

There is an in-progress simplification effort. **Before starting any refactor or
"why is this so complex" work, read
[`docs/superpowers/specs/2026-07-21-simplification-roadmap.md`](docs/superpowers/specs/2026-07-21-simplification-roadmap.md)** —
it holds the audit evidence, the requirements already decided with the user, FRC prior-art
research, and the scope of the remaining steps. Step 1 (team isolation), Step 2
(Sheets one-way), and Step 3 (collapse to a single offline store) are shipped on `master`;
Step 4 (schema-driven forms) is not started and still needs its own brainstorm → spec → plan.

## Architecture

**Frontend** (`frontend/`): Flutter app using Riverpod for state management. Targets Windows, macOS, Linux, Android, iOS, and web. Firebase Auth for team-scoped access.

**Backend** (`functions/`): Python 3.11 Firebase Cloud Functions. One-way exports Firestore match data to each team's own Google Sheet (Firestore -> Sheets only; there is no reverse path).

### Frontend Architecture (single store)

- **Single store**: Firestore is the only data store, with its own on-disk persistence (`persistenceEnabled`, `CACHE_SIZE_UNLIMITED`, set in `main.dart`) providing offline support. There is no local SQLite database and no sync queue — writes go straight to Firestore, which queues them durably on disk when the network is unreachable and flushes when the stream recovers. The UI reads through `firestoreRepositoryProvider` (`data/repositories/providers.dart`); `matchesViewProvider` is the single live matches subscription shared by the list and the connection-status widgets.

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
- `regenerate_invite_code` — admin-only callable that rotates a team's invite code. **The whole `teams/{teamId}` doc is server-authoritative**: rules deny every client update. This was previously a client-side Firestore transaction whose only check was `createdBy == uid`, against a field the same client could rewrite (the rule was `update: if isTeamMember(teamId)` with no field allowlist), and it generated 6-char codes with `dart:math` `Random()` with no uniqueness check. The invite code is the ONLY credential `join_team` accepts, and uniqueness matters because `join_team` resolves it with `where(...).limit(1)` — two teams sharing a code silently routes scouts into the wrong one. Never move this back to a client write.
- **Every callable must gate on `req.auth`.** Callables are public HTTPS endpoints and there is no App Check; `fetch_event_schedule`/`fetch_ftc_schedule` shipped without the check, leaving anonymous Firestore writes and free use of the TBA/FTC API credentials. `eventKey`/`eventCode` are also regex-validated (`^[A-Za-z0-9]{1,32}$`) since they become both a URL path segment and a Firestore document id.
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

- Firebase secrets used: `GOOGLE_SHEETS_CREDENTIALS`, `TBA_API_KEY`, `FTC_API_USERNAME`, `FTC_API_KEY`
- Firestore persistence is enabled with unlimited cache; it is the ONLY offline store (no Drift/SQLite)
- The `gameData` field on MatchReport is a flexible `Map<String, dynamic>` that varies by program type (FRC vs FTC)
- **Connection status comes from Firestore snapshot metadata** (`isFromCache`, `hasPendingWrites`), never from `connectivity_plus` (removed). Link-layer state reports "wifi" on a captive portal that blocks all traffic — the venue failure mode we actually face — so it lies exactly when it matters. `MatchReport.isSynced == !doc.metadata.hasPendingWrites`; the connection widget also surfaces a distinct error state on stream failure rather than silently claiming "all uploaded".
- `core/result/result.dart` provides a sealed `Result<T, E>` type used throughout data layer
- After merging branches, check for duplicate dependencies in `pubspec.yaml` and leftover conflict markers (`>>>>>>>`)
- Generated files (`*.g.dart`, `*.mocks.dart`) must never be hand-edited — run codegen or mockito instead
- Riverpod providers that need to react to state changes must use `overrideWith((ref) =>)`, not `overrideWithValue()`
- Firestore composite queries (teamId + eventId + isDeleted + createdAt) may require composite indexes — deploy with `firebase deploy --only firestore:indexes`
- **`functions/venv` must be Python 3.11**, matching `"runtime": "python311"` in `firebase.json`. The CLI looks for `venv/bin/python3.11` and otherwise fails with `Missing virtual environment at venv directory`. If the system lacks 3.11: `uv python install 3.11 && uv venv functions/venv --python 3.11`. A venv missing `bin/activate` (created when `python3-venv` isn't installed) also fails.
- **Never run the web app with `flutter run -d web-server`** — in debug it loads all ~1371 DDC modules with zero errors but `main()` waits on a Dart debugger handshake that only the Chrome extension satisfies, so you get a silent blank page. Use `flutter build web --release` + a static server, or `-d chrome`.
- **Web is a shipping platform, not a dev convenience.** `firebase.json` has a
  `hosting` block serving `frontend/build/web`, deployed by
  `.github/workflows/deploy-web.yml` on every push to `master`. iOS scouts
  install it from Safari as a PWA instead of paying for an Apple Developer
  account, so web regressions are user-facing. `hosting.predeploy` runs
  `flutter build web --release`, so never point `public` at a hand-built
  directory or the stale-build footgun comes back.
- **`index.html` and `flutter_service_worker.js` must stay `no-cache`** (set in
  `firebase.json` `hosting.headers`). Flutter's web output is not
  content-hashed; caching the bootstrap or service worker pins scouts to an old
  build with no way to recover but clearing site data.
- **`frontend/web/` icons are referenced by `index.html` and `manifest.json` and
  must actually exist.** They were missing entirely at first, which 404'd the
  apple-touch-icon and gave iOS home-screen installs a screenshot thumbnail.
  They are rasterized from `assets/mascots/peepo.svg` on the lilac plate
  `Mascots.plate()` assigns it, with the 1/8 clearance `BrandMascot` enforces --
  regenerate them from that SVG rather than drawing a new mark. The art sits
  inside the maskable safe zone, so both entries carry `purpose: "any maskable"`.
- **Firestore web persistence needs `WebPersistentMultipleTabManager`** (set in
  `main.dart`). Without it the persistent cache is owned by the first tab that
  claimed it and every other tab throws `failed-precondition`. The setting is
  web-only and ignored on other platforms, so it needs no `kIsWeb` guard.
- **Composite ids must be bound to the team on WRITE, not just trusted on read.** `events` and `matches` create/update rules both require the document's `eventId` to match `^{teamId}_`. Checking only the `teamId` *field* let anyone create `events/{victimTeamId}_{code}` owned by their own team, which permanently locked the victim out of an event id they could no longer read, update, or delete (event codes are public, so future competitions were pre-squattable).
- **CSV export must neutralize formulas, not just quote fields.** Excel/Sheets/LibreOffice evaluate a leading `= + - @` even inside a quoted field, and scout-supplied `comments`/`scouterName` reach that sink. `ExportService._escapeCsvField` prefixes `'` on those; all CSV must go through it rather than string interpolation. The backend Sheets export is safe for a different reason — `valueInputOption='RAW'` stores values literally — so don't "harmonize" it to `USER_ENTERED`.
- **Firestore rules: `resource` is null when the doc doesn't exist.** `allow read: if isTeamMember(resource.data.teamId)` throws `Null value error` (=> denied) on a get-or-create path. Guard with `resource == null ? <fallback> : <check>` — this broke the first match written to every new event.
- Deploying functions validates ALL secrets up front: one missing secret (e.g. `TBA_API_KEY`) blocks the whole deploy. Deploy a subset with `firebase deploy --only functions:name1,functions:name2`.

## Testing

- Run `flutter test` from `frontend/` for the full Dart suite (currently 371 tests). Repository tests use `fake_cloud_firestore`.
- Run `./venv/bin/python -m pytest tests/` from `functions/` for the Python suite (currently 117 tests).
- Firestore rules have an automated isolation suite (37 tests): `firebase emulators:exec --only firestore "cd test/firestore-rules && ./node_modules/.bin/jest --runInBand"` (run from repo root; `npm test` inside `emulators:exec` hits a shell-quoting bug on Linux — call the jest binary directly). Emulator is pinned to port 8099 so it doesn't collide with a local app server on 8080.
- Generated files (`*.g.dart`, `*.mocks.dart`, `*.freezed.dart`) are excluded from `flutter analyze` via `analysis_options.yaml`.

## Working on this repo with AI (Claude Code)

**Always fetch and pull the latest `master` from GitHub before starting work**
(`git fetch origin && git pull`, or fetch before branching off it). Architecture
and docs here move fast — stale state has already caused agents to "fix" things
against a copy of the repo that no longer matches reality (see the Step 3 roadmap
note above, which itself went stale this way).

Personal/ephemeral state (`settings.local.json`, ralph logs, `.superpowers/`,
`.opencode/`) is gitignored — set your own `settings.local.json` permissions.

For recommended plugins and first-time setup, see the `repo-ai-setup` skill
(`.claude/skills/repo-ai-setup/SKILL.md`).

This repo prioritizes the **`superpowers`** plugin for workflow — use its skills
(`brainstorming`, `writing-plans`, `test-driven-development`, `systematic-debugging`,
`requesting-code-review`/`receiving-code-review`, `finishing-a-development-branch`,
`using-git-worktrees`, `writing-skills`, `subagent-driven-development`,
`dispatching-parallel-agents`) over generic alternatives. Three plugins that
duplicate superpowers workflows are disabled at the project level
(`.claude/settings.json` `enabledPlugins`, overriding the user's global config)
even though they may be enabled globally — don't re-enable them here:
- `commit-commands` (commit/PR creation) — superseded by `finishing-a-development-branch`
- `ralph-loop` (autonomous agent looping) — superseded by `subagent-driven-development` / `dispatching-parallel-agents`
- `skill-creator` (skill authoring) — superseded by `writing-skills`

Superpowers' `brainstorming`/`writing-plans` output (specs and plans) lands in
`docs/superpowers/specs/` and `docs/superpowers/plans/`, which are tracked in
git (unlike the `.superpowers/` scratch directory — task briefs, review diffs,
per-task working state — which stays gitignored as ephemeral). **Commit new
spec/plan docs there as part of finishing the work**, so the whole team can see
prior design decisions, not just whoever ran the session. Scrub personal
identifiers (emails, tokens, machine paths) before committing.

**Agents** (`.claude/agents/`) — domain-specific reviewers superpowers doesn't
cover: `security-reviewer` (auth/team-isolation/rules changes), `sync-logic-reviewer`
(Firestore->Sheets export idempotency/team-scoping), `riverpod-provider-reviewer`
(provider override/dependency correctness, esp. the team/event chain).

**Skills** (`.claude/skills/`) — domain-specific wrappers superpowers doesn't
cover: `deploy-functions`, `firestore-rules-check`, `run-tests`.

**Plugins/MCP**: `firebase` and `playwright` stay enabled (Firestore/Functions
inspection, browser automation for the Flutter web build). A `github` MCP server
is configured user-locally only — not committed, since it embeds a personal
token; set it up yourself with
`claude mcp add --transport http github https://api.githubcopilot.com/mcp/ --header "Authorization: Bearer $(gh auth token)" -s local`.

**Hooks** (`.claude/settings.json`): dart format+analyze, a
`python3 -m py_compile` syntax check on `functions/*.py` edits, and a reminder
to run `firestore-rules-check` when `firestore.rules` changes all run on
relevant file edits; editing generated `*.g.dart`/`*.mocks.dart` is blocked
outright.

**CI**: `.github/workflows/test.yml` runs Flutter tests, pytest, and the
Firestore rules suite on every push/PR to `master`.

