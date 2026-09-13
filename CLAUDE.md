# CLAUDE.md

This file gives guidance to Claude Code (claude.ai/code) for work in this
repository.

## Project Overview

SushiScout 26 is an FRC/FTC robotics scouting app. Scouts use the Flutter
app to record match data at competitions. The app syncs this data to
Firestore and to Google Sheets for analysis.

## Active roadmap

A simplification effort is in progress. **Before you start any refactor,
or any "why is this so complex" work, read
[`docs/superpowers/specs/2026-07-21-simplification-roadmap.md`](docs/superpowers/specs/2026-07-21-simplification-roadmap.md).**
That document holds the audit evidence, the requirements the user already
decided, FRC prior-art research, and the scope of the remaining steps.
Step 1 (team isolation), Step 2 (Sheets one-way export), and Step 3
(collapse to a single offline store) are shipped on `master`. Step 4
(schema-driven forms) has not started. It still needs its own brainstorm,
spec, and plan.

## Documentation Style

Write new docs, specs, and plans in **ASD-STE100 Simplified Technical
English (STE)**. Apply these rules:

- Write one instruction per sentence.
- Use active voice. Reserve passive voice for cases where the actor truly
  does not matter.
- Use only simple verb tenses: infinitive, imperative, simple present,
  simple past, and simple future. Do not use compound tenses such as "has
  been" or "will have."
- Keep sentences to about 20 words for instructions, and about 25 words
  for descriptive text.
- Do not use phrasal verbs (verb plus preposition, such as "set up" or
  "carry out"). Use one plain verb instead.
- Do not use semicolons. Write two separate sentences instead.
- Do not stack more than three nouns in a row as a modifier.
- Use numbered or bulleted lists for a sequence, a condition, or an
  enumeration, instead of writing it as one long sentence.
- Keep every technical fact, warning, and caveat exact. Simplify
  sentence structure only. Do not remove or soften a security warning, a
  number, or a scope qualifier to shorten a sentence.
- Repo-specific technical terms (Firestore, Riverpod, callable, and
  similar terms) stay as-is. STE's plain-word dictionary is a guide for
  prose, not a hard rule for this repo's technical vocabulary.

This rule applies to new files under `docs/superpowers/specs/` and
`docs/superpowers/plans/`, and to READMEs and other prose docs. It does
not apply retroactively to specs and plans already committed — those stay
as a historical record.

## Architecture

**Frontend** (`frontend/`): a Flutter app. It uses Riverpod for state
management. It targets Windows, macOS, Linux, Android, iOS, and the web.
Firebase Auth grants team-scoped access.

**Backend** (`functions/`): Python 3.11 Firebase Cloud Functions. These
functions export Firestore match data, one way, to each team's own
Google Sheet. Data flows from Firestore to Sheets only. There is no
reverse path.

### Frontend Architecture (single store)

Firestore is the app's only data store. Firestore's own on-disk
persistence (`persistenceEnabled`, `CACHE_SIZE_UNLIMITED`, set in
`main.dart`) provides offline support. The app has no local SQLite
database and no sync queue. Writes go straight to Firestore. When the
network is unreachable, Firestore queues each write durably on disk, then
sends it once the stream recovers. The UI reads through
`firestoreRepositoryProvider` (`data/repositories/providers.dart`).
`matchesViewProvider` is the single live matches subscription. Both the
match list and the connection-status widgets share this subscription.

### Firestore Collections

- `events` — competition events, each with a `programType` (FRC or FTC),
  a `tbaKey`, and a `teamId`
- `matches` — a top-level collection of match reports, each with an
  `eventId` field (this collection was recently refactored out of a
  subcollection)
- `tba_cache` — cached Blue Alliance API responses, with a 24-hour TTL

### Auth & Team Isolation

- Firebase Auth grants access two ways: Google Sign-In (on mobile and
  web) and email/password (on desktop).
- **The server, not the client, owns membership.** Firestore rules trust
  only the `{teams: {teamId: role}}` custom auth claim. Only the
  `create_team`, `join_team`, and `leave_team` callables can mint this
  claim, and they do so through the Admin SDK. A client **cannot** write
  `users/{uid}.teamMemberships` or `teams/{tid}/members/**` — rules deny
  both writes. Do not "simplify" this back to a client write, and do not
  add a trigger that mirrors a client-writable field into the claim.
  Either change would open a privilege-escalation hole: any user could
  then assert membership in any team.
- `team_repository`'s `createTeam`, `joinTeamByCode`, and `leaveTeam`
  methods call those callables. Reads stay client-side.
- After a create, join, or leave, the client must force a token refresh:
  call `getIdToken(true)`, exposed as `AuthService.forceRefreshClaims`.
  Without this call, the new claim is not yet in the token.
- The provider chain `activeTeamIdProvider` → `currentTeamIdProvider` →
  `FirestoreRepository(teamId:)` filters every query by team.
- `switchTeam` needs no token refresh. The claim already lists every
  team the user belongs to. The active team is separate state.
- Event ids are composite: `{teamId}_{eventCode}`
  (`currentEventIdProvider`). The raw code
  (`currentEventCodeProvider` / `Event.tbaKey`) serves only the public
  `schedules` and TBA lookups.
- Onboarding an existing user to this model needs a one-time **claims
  backfill**. A data wipe alone is not enough: it leaves memberships in
  Firestore with no matching claim, and the user then gets a
  `permission-denied` error.

### Cloud Functions

- `create_team`, `join_team`, and `leave_team` — these callables own all
  membership changes. Each one validates the request server-side (the
  invite code, an already-member check, a last-admin check), writes the
  membership through the Admin SDK, then sets the `{teams: ...}` custom
  claim. See "Auth & Team Isolation" above.
- `regenerate_invite_code` — an admin-only callable that rotates a
  team's invite code. **The whole `teams/{teamId}` document is
  server-authoritative:** rules deny every client update to it. This
  logic used to run as a client-side Firestore transaction. That
  transaction checked only `createdBy == uid`, against a field the same
  client could rewrite (the rule read `update: if isTeamMember(teamId)`,
  with no field allowlist). It also generated a 6-character code with
  `dart:math`'s `Random()`, with no uniqueness check. The invite code is
  the only credential `join_team` accepts, and uniqueness matters
  because `join_team` resolves the code with `where(...).limit(1)`. If
  two teams shared a code, `join_team` would silently route a scout into
  the wrong team. Do not move this logic back to a client write.
- **Every callable must gate on `req.auth`.** Callables are public HTTPS
  endpoints, and this project has no App Check. `fetch_event_schedule`
  and `fetch_ftc_schedule` shipped without this gate at first. That gap
  let an anonymous caller write to Firestore for free, and use the
  TBA/FTC API credentials for free. `eventKey` and `eventCode` also go
  through a regex check (`^[A-Za-z0-9]{1,32}$`), because both values
  become a URL path segment and a Firestore document id.
- `set_team_sheet` — an admin-only callable. It validates write access
  to a team-supplied spreadsheet with a real write probe, not just a
  metadata read, then stores the sheet id as that team's
  `teamSettings/{teamId}.googleSheetId`. **`googleSheetId` is
  server-authoritative:** rules deny every client write to this field —
  a create, an update, and a removal through
  `diff().affectedKeys()`. This callable is the only write path. Do not
  "simplify" it back to a client write. That change would let any member
  silently redirect the team's export to a spreadsheet they control,
  with no admin check and no write probe.
- `on_match_written` — a Firestore trigger on `matches/{reportId}`. It
  exports each create, update, and delete, one way, to the owning team's
  Google Sheet. There is no path back into Firestore.
- `backfill_event_to_sheets` — a callable that bulk-exports an event's
  matches into that event's team sheet. This function is idempotent: it
  resolves row identity by looking up the report id inside the sheet
  itself.
- `fetch_event_schedule` (in `tba_sync.py`) — a callable that pulls FRC
  and FTC schedules from The Blue Alliance API. It caches each response
  for 24 hours, in the `tba_cache` collection.
- `functions/services/sheets_service.py` — a wrapper around the Google
  Sheets API. It uses a different column schema for FRC and for FTC.
  This wrapper only exports data one way. It keeps no row-tracking
  collection.

## Commit Convention

This project follows the Conventional Commits format:
`<type>(<scope>): <subject>`

- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
  `chore`, `ci`, `revert`
- Scopes: `frontend`, `backend`, `db`, `api`, `ui`, `theme`, `sync`,
  `test`, `config`, `deps`

Write the subject in the imperative mood. Do not capitalize the first
letter. Do not add a trailing period. Keep the subject to 50 characters
or fewer.

## Key Technical Details

- Firebase secrets in use: `GOOGLE_SHEETS_CREDENTIALS`, `TBA_API_KEY`,
  `FTC_API_USERNAME`, `FTC_API_KEY`.
- Firestore persistence is on, with an unlimited cache. It is the
  **only** offline store — this project has no Drift and no SQLite.
- The `gameData` field on `MatchReport` is a flexible
  `Map<String, dynamic>`. Its shape varies by program type (FRC or FTC).
- **Connection status comes from Firestore's snapshot metadata**
  (`isFromCache`, `hasPendingWrites`), never from `connectivity_plus`
  (removed from this project). Link-layer state reports "wifi" even on a
  captive portal that blocks all traffic — this is the venue failure mode
  we actually face, so link-layer state lies exactly when it matters
  most. `MatchReport.isSynced` equals `!doc.metadata.hasPendingWrites`.
  The connection widget also shows a distinct error state on a stream
  failure, instead of falsely reporting "all uploaded."
- `core/result/result.dart` defines a sealed `Result<T, E>` type. The
  data layer uses this type throughout.
- After you merge branches, check `pubspec.yaml` for duplicate
  dependencies and for leftover conflict markers (`>>>>>>>`).
- Never hand-edit a generated file (`*.g.dart`, `*.mocks.dart`). Run
  codegen or mockito instead.
- A Riverpod provider that must react to state changes needs
  `overrideWith((ref) =>)`. Do not use `overrideWithValue()` for this
  case.
- A Firestore composite query (`teamId` + `eventId` + `isDeleted` +
  `createdAt`) may need a composite index. Deploy indexes with
  `firebase deploy --only firestore:indexes`.
- **`functions/venv` must run Python 3.11.** This matches
  `"runtime": "python311"` in `firebase.json`. The Firebase CLI looks for
  `venv/bin/python3.11` and fails with `Missing virtual environment at
  venv directory` if that path is missing. If the system has no Python
  3.11, run `uv python install 3.11 && uv venv functions/venv --python
  3.11`. A venv with no `bin/activate` script (this happens when
  `python3-venv` is not installed) also fails.
- **Never run the web app with `flutter run -d web-server`.** In debug
  mode, this command loads all ~1371 DDC modules with no error, but
  `main()` then waits for a Dart debugger handshake that only the Chrome
  extension can complete. The result is a silent blank page. Use
  `flutter build web --release` with a static server instead, or use
  `-d chrome`.
- **The web build is a shipping platform, not a developer convenience.**
  `firebase.json` has a `hosting` block that serves
  `frontend/build/web`. `.github/workflows/deploy-web.yml` deploys this
  build on every push to `master`. iOS scouts install this build from
  Safari as a PWA, instead of paying for an Apple Developer account, so
  a regression in the web build is user-facing. `hosting.predeploy` runs
  `flutter build web --release` for every deploy, so never point
  `public` at a hand-built directory — that would bring back the
  stale-build failure mode. The deploy job also runs `flutter analyze`
  and `flutter test` first. Note that `test.yml` shares the same trigger
  but runs as an independent workflow, so it cannot block a deploy.
- **A Hosting `headers[].source` rule matches the request path, not the
  file the server sends.** A scout who loads `https://…web.app/`
  requests the path `/`, and that path does NOT match a `/index.html`
  glob. This gap once shipped the app shell with Hosting's default
  `max-age=3600`. `firebase.json`'s `hosting.headers` list both `/` and
  `/index.html` — keep both entries together.
- **Flutter 3.41's `flutter_service_worker.js` is an 815-byte stub that
  unregisters itself.** It precaches nothing, and `flutter build web` no
  longer has a `--pwa-strategy` flag to change that. So the browser's
  HTTP cache is the only thing that lets the app open when venue wifi
  drops. For this reason, the shell files (`/`, `/index.html`,
  `flutter_bootstrap.js`, `flutter.js`, `main.dart.js`) carry
  `max-age=300, must-revalidate`, not `no-store`. A `no-store` setting
  would guarantee a blank page offline, and would also force a fresh
  1.27 MB download of `main.dart.js` on every single load. Five minutes
  of staleness is the price of that grace period. A real offline launch
  needs a hand-written service worker — see the README. Flutter's
  bootstrap code fights any such worker, so this is not a drop-in
  change.
- **This project deliberately has no SPA rewrite rule.** A `"**" ->
  /index.html` catch-all would turn every missing asset request into a
  `200` response of `text/html`. A stale service worker could then cache
  that HTML in place of real JS, and hand the scout a blank page. This
  app has no router (no `go_router`, no named routes, no
  `setUrlStrategy`), so nothing needs a deep link, and Hosting's
  directory index already serves `/` correctly. If routing is ever
  added, bring the rewrite back — and narrow it to extension-less paths
  only.
- **The icon files under `frontend/web/` must exist.** `index.html` and
  `manifest.json` both reference them. These files were missing
  entirely at first. That gap 404'd the apple-touch-icon, and gave iOS
  home-screen installs a plain screenshot thumbnail instead of an icon.
  The icons are rasterized from `assets/mascots/peepo.svg`, on the lilac
  plate that `Mascots.plate()` assigns to it, with the 1/8 clearance that
  `BrandMascot` enforces. Regenerate these icons from that SVG. Do not
  draw a new mark. The art sits inside the maskable safe zone, so both
  manifest entries carry `purpose: "any maskable"`.
- **Firestore's web persistence needs
  `WebPersistentMultipleTabManager`** (set in `main.dart`). Without this
  setting, only the first tab to claim the persistent cache can use it —
  every other open tab then throws `failed-precondition`. This setting
  applies to web only, and other platforms ignore it, so it needs no
  `kIsWeb` guard.
- **A write must bind a composite id to its team, not just trust a
  field on read.** The `events` and `matches` create/update rules both
  require the document's `eventId` to match `^{teamId}_`. Checking only
  the `teamId` field once let any user create
  `events/{victimTeamId}_{code}`, owned by their own team. That gap
  permanently locked the victim team out of an event id it could no
  longer read, update, or delete. Event codes are public, so an attacker
  could pre-squat future competitions this way.
- **A CSV export must neutralize a formula, not just quote the field.**
  Excel, Sheets, and LibreOffice all evaluate a leading `=`, `+`, `-`, or
  `@` character, even inside a quoted field, and scout-supplied
  `comments` and `scouterName` values reach that sink.
  `ExportService._escapeCsvField` prefixes a `'` character on those
  values — send every CSV field through this function, not through
  plain string interpolation. The backend Sheets export needs no such
  guard, for a different reason: it sets `valueInputOption='RAW'`, which
  stores every value literally. Do not "harmonize" that setting to
  `USER_ENTERED`.
- **In Firestore rules, `resource` is null when the document does not
  yet exist.** A rule such as
  `allow read: if isTeamMember(resource.data.teamId)` throws a
  `Null value error` on a get-or-create path, and that error resolves to
  a denial. Guard this case with
  `resource == null ? <fallback> : <check>`. This bug once broke the
  first match written to every new event.
- Deploying functions validates every secret up front. One missing
  secret (for example, `TBA_API_KEY`) blocks the entire deploy. To
  deploy a subset instead, run
  `firebase deploy --only functions:name1,functions:name2`.

## Testing

- Run `flutter test` from `frontend/` to run the full Dart suite
  (currently 371 tests). The repository tests use `fake_cloud_firestore`.
- Run `./venv/bin/python -m pytest tests/` from `functions/` to run the
  Python suite (currently 117 tests).
- The Firestore rules have an automated isolation suite (37 tests). Run
  it with `firebase emulators:exec --only firestore "cd
  test/firestore-rules && ./node_modules/.bin/jest --runInBand"`, from
  the repo root. Do not run `npm test` inside `emulators:exec` — that
  command hits a shell-quoting bug on Linux. Call the jest binary
  directly instead. The emulator is pinned to port 8099, so it does not
  collide with a local app server on port 8080.
- `analysis_options.yaml` excludes generated files (`*.g.dart`,
  `*.mocks.dart`, `*.freezed.dart`) from `flutter analyze`.

## Working on this repo with AI (Claude Code)

**Always fetch and pull the latest `master` from GitHub before you start
work.** Run `git fetch origin && git pull`, or fetch before you branch
off `master`. This repo's architecture and docs change fast — stale
local state has already caused an agent to "fix" something against a
copy of the repo that no longer matched reality. (See the Step 3 roadmap
note above — that note itself went stale the same way.)

Personal and ephemeral state (`settings.local.json`, ralph logs,
`.superpowers/`, `.opencode/`) is gitignored. Set your own
`settings.local.json` permissions.

For recommended plugins and first-time setup, see the `repo-ai-setup`
skill (`.claude/skills/repo-ai-setup/SKILL.md`).

This repo prioritizes the **`superpowers`** plugin for its workflow. Use
its skills — `brainstorming`, `writing-plans`, `test-driven-development`,
`systematic-debugging`, `requesting-code-review`,
`receiving-code-review`, `finishing-a-development-branch`,
`using-git-worktrees`, `writing-skills`, `subagent-driven-development`,
and `dispatching-parallel-agents` — instead of a generic alternative.
This project disables three plugins that duplicate superpowers
workflows, at the project level
(`.claude/settings.json`'s `enabledPlugins`, which overrides the user's
global config), even where the user's global config enables them. Do not
re-enable these plugins here:

- `commit-commands` (commit and PR creation) — superseded by
  `finishing-a-development-branch`
- `ralph-loop` (autonomous agent looping) — superseded by
  `subagent-driven-development` and `dispatching-parallel-agents`
- `skill-creator` (skill authoring) — superseded by `writing-skills`

The `brainstorming` and `writing-plans` skills write their output (specs
and plans) to `docs/superpowers/specs/` and `docs/superpowers/plans/`.
Git tracks both directories. This differs from the `.superpowers/`
scratch directory — task briefs, review diffs, and per-task working
state — which stays gitignored, because that content is ephemeral.
**Commit a new spec or plan document to those tracked directories as
part of finishing the work,** so the whole team can see a prior design
decision, not only the person who ran that session. Scrub personal
identifiers (emails, tokens, machine paths) before you commit.

**Agents** (`.claude/agents/`) — domain-specific reviewers that
superpowers does not cover: `security-reviewer` (for auth, team
isolation, and rules changes), `sync-logic-reviewer` (for
Firestore-to-Sheets export idempotency and team-scoping), and
`riverpod-provider-reviewer` (for provider override and dependency
correctness, especially the team/event chain).

**Skills** (`.claude/skills/`) — domain-specific wrappers that
superpowers does not cover: `deploy-functions`, `firestore-rules-check`,
and `run-tests`.

**Plugins and MCP servers:** keep `firebase` and `playwright` enabled
(for Firestore/Functions inspection, and for browser automation on the
Flutter web build). A `github` MCP server is configured user-locally
only, and stays uncommitted, because it embeds a personal token. Set it
up yourself with this command:
`claude mcp add --transport http github
https://api.githubcopilot.com/mcp/ --header "Authorization: Bearer
$(gh auth token)" -s local`.

**Hooks** (`.claude/settings.json`): a dart format-and-analyze hook, a
`python3 -m py_compile` syntax check on `functions/*.py` edits, and a
reminder to run `firestore-rules-check` when `firestore.rules` changes —
all three run on the matching file edit. Editing a generated
`*.g.dart` or `*.mocks.dart` file is blocked outright.

**CI**: `.github/workflows/test.yml` runs the Flutter tests, the pytest
suite, and the Firestore rules suite on every push and pull request to
`master`.
