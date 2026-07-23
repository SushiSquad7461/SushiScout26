# SushiScout Simplification Roadmap (audit + Steps 2–4 handoff)

- **Date:** 2026-07-21 (Step 2 shipped 2026-07-21; Step 3 implemented 2026-07-22)
- **Status:** Steps 1 and 2 shipped. Step 3 implemented on branch `single-offline-store`, not yet
  merged/deployed (awaits a human-present session). Step 4 not started.
- **Purpose:** This is a **handoff document**, written so a future session (or teammate)
  can pick up Steps 2–4 without re-deriving the analysis. It records the audit evidence,
  the decisions already made, and the scope of each remaining step. It is deliberately
  **not** an implementation plan — each step should still get its own brainstorm → spec →
  plan cycle, because the details need a human in the loop.

## 0. How to use this

Start a new session with roughly:

> Read `docs/superpowers/specs/2026-07-21-simplification-roadmap.md` and `CLAUDE.md`,
> then brainstorm Step 2 (or 3).

Read `CLAUDE.md` too — it carries the current architecture and the environment gotchas
(Python 3.11 venv, `flutter run -d web-server` never boots, null-`resource` rules trap).

---

## 1. The original complaint

The app "feels big/complex for a pretty simple scouting app", the UI is poor, and the
backend keeps breaking. Long-term goal: an FRC/FTC scouting app where **multiple teams
each use the app independently**.

## 2. Audit evidence (measured, not vibes)

Taken at commit `ff39996` (before Step 1).

**Size:** ~15k lines Dart (excl. generated) + ~2.5k Python. Not huge — but carrying far
more architecture than the requirements need.

**Churn concentrates in the sync layer** (`git log` analysis):

| Signal | Value |
|---|---|
| `fix` commits vs `feat` commits | **70 vs 55** — more repairing than building |
| Commits scoped `(sync)` | **35** — the largest single scope |
| Most-churned files | `sync_manager.dart` 24, `dashboard.dart` 24, `hybrid_repository.dart` 23, `main.py` 20 |

**Largest files:** `dashboard.dart` 1137, `frc_rebuilt_form.dart` 853, `hybrid_repository.dart` 850,
`ftc_decode_form.dart` 795, `sync_manager.dart` 665.

**Root cause of the backend pain:** three sources of truth kept in sync *bidirectionally* —
local SQLite (Drift) ↔ Firestore ↔ Google Sheets. Nearly every hard-won comment in the
sync code is a scar from a distributed-consistency bug (echo guards, pending-op skip
filters, row-number tracking, `lastSyncSource` tagging).

**Dead code found:** the `SyncConflicts` table plus `recordConflict` / `getUnresolvedConflicts`
are never invoked — sync is pure last-write-wins via `set(merge)`. A whole 4th Drift table
and resolution plumbing that never runs.

**Key leverage observation:** the **web build already runs Firestore-only** (every method in
`hybrid_repository` has a `_isWeb` branch that skips Drift entirely). That is existence proof
that the local DB + sync queue is optional, not load-bearing.

## 3. Decisions already made (do not re-litigate without the user)

- **Offline requirement:** members have connectivity *before* the competition; the app must
  tolerate connectivity **drops of up to ~1 hour**. It does **not** need cold-start-with-empty-cache
  offline. → Firestore's own offline persistence is sufficient; the second local store is not.
- **Google Sheets is READ-ONLY** (analysts view, never edit back). In-app analysis is wanted
  *later*, not now.
- **Multi-team is the north star**: teams must be fully independent (delivered in Step 1).
- Step 1 was deliberately scoped to security/correctness and is **net-neutral on code size** —
  the user explicitly chose to keep it focused rather than fold cleanups in.

## 4. Step 1 — DONE (context for what changed)

Team isolation: composite event ids `{teamId}_{eventCode}`, membership moved behind
server-side callables that mint a custom auth claim, rules locked so clients cannot forge
membership. See `2026-07-20-team-isolation-design.md`. Verified end-to-end in production.

**Two post-deploy bugs, same root cause — worth remembering:** the rules were validated only
against *seeded* data, never the **empty-database first-run path** a fresh deploy starts in.
Both failures (orphaned claims for pre-existing users; `resource` being null on a
get-or-create read) were first-run-only. **Test the empty-DB path.**

**Not carried over:** existing deployments with real users need a one-time **claims backfill**
(`set_custom_user_claims` from `users/{uid}.teamMemberships`), not just a wipe.

---

## 5. Step 2 — Make Google Sheets a one-way export — **DONE (shipped 2026-07-22)**

Design: [`2026-07-21-sheets-one-way-export-design.md`](2026-07-21-sheets-one-way-export-design.md).
Plan: [`../plans/2026-07-21-sheets-one-way-export.md`](../plans/2026-07-21-sheets-one-way-export.md).
Merged as `5fca203`, deployed, and verified end-to-end against the real Sheets API on an empty
database. Everything below is the original scope; it shipped as written except where noted.

**What differed from this section's plan, and why it matters to Step 3:**
- `googleSheetId` lives on `teamSettings/{teamId}`, not `teams/{teamId}`.
- `sync_tracking` was deleted entirely, not trimmed: row identity is now resolved by searching
  the sheet for the report id. One less store to drift.
- Added (not in the original scope): `set_team_sheet`, an admin-only callable that validates a
  team's spreadsheet with a real write probe before storing the id, plus rules denying every
  client write to that field.
- `_stampSource` was renamed, not deleted — its `teamId` backfill is load-bearing for the
  trash/restore-races-hard-delete path.

**Process lessons worth carrying into Step 3:**
1. **All three Critical/Important defects came from the PLAN's sample code, not from the
   implementers.** A write probe that only proved read access; a rules guard that let field
   removal through; a service-account address silently ellipsized by a Flutter default. Treat
   code in a plan as a starting point to be reviewed, never as pre-validated.
2. **Mocked tests cannot validate an external API.** The Sheets integration was 100% green
   locally while never having touched Google. Budget for real end-to-end verification.
3. **The empty-DB first-run path keeps producing bugs** — three times now across Steps 1 and 2.
   Test the cold start explicitly, on a brand-new team with no documents.
4. Wiping team data requires deleting `users/` docs too, or `create_team` re-mints the custom
   claim from the surviving `teamMemberships` map and resurrects the dead team id.

**Why:** Sheets is read-only by decision (§3), but the code still treats it as a bidirectional
peer. That bidirectionality is the single largest source of backend complexity and bugs.

**Delete (net code reduction):**
- `update_match_from_sheets` callable (`functions/main.py`)
- `sync_from_sheets_http` HTTP endpoint (same file)
- The `lastSyncSource == 'sheets'` **echo guard** in `on_match_written`, and the
  `_stampSource` `lastSyncSource: 'app'` stamping in `firestore_repository.dart` that exists
  only to feed it
- Most of `sync_tracking` (row-number mapping) — keep only what one-way append/update needs
- The `SYNC_API_KEY` secret

**Keep:** `on_match_written` (Firestore → Sheets) and `backfill_event_to_sheets`.

**Fold in while here:** move to **per-team spreadsheets** using the existing (currently unused)
`teamSettings.googleSheetId` field. This also cleans up the ugly composite Sheet tab names
(`{teamId}_{eventCode}`) that Step 1 introduced — see the Step 1 spec §13.

**Risk:** low. Nothing in the app reads from Sheets.

## 6. Step 3 — Collapse to a single offline store — **DONE (implemented 2026-07-22)**

Design: [`2026-07-22-single-offline-store-design.md`](2026-07-22-single-offline-store-design.md).
Plan: [`../plans/2026-07-22-single-offline-store.md`](../plans/2026-07-22-single-offline-store.md).
Branch `single-offline-store`, 8 tasks, each reviewed. **Not deployed** — merge/deploy pending a
human-present session (nothing is in prod, so no migration was needed; the Drift DB was deleted
outright).

**Shape chosen: 1 (Firestore-only).** Drift, `SyncManager`, and `HybridRepository` deleted; Firestore's
own on-disk persistence is the single offline store. The read-cache hedge (shape 2) was rejected for
three reasons captured in the design §2: Drift is equally empty on a cold start (its only edge was
surviving cache eviction, which `CACHE_SIZE_UNLIMITED` already covers); a future QR escape hatch can
enumerate unsynced docs via `Source.cache` + `hasPendingWrites` without keeping the table; and a "pure
read-cache" is one refactor away from re-growing an outbox and the two-store skew bugs that caused the
churn.

**Actual reduction: ~42% of total lines, but ~22% of hand-written lines.** The headline 40–50% counted
the 4,117-line generated Drift file (`app_database.g.dart`). The net diff was ≈ −7,600 lines. Still the
largest cut available and it landed exactly on the churn hotspot, but hand-maintained code shrank by
about a fifth, not a half — recorded so the next reader isn't misled by the original estimate.

**Two live defects were found in the code being deleted** (not regressions — pre-existing):
- `connectivity_plus` treated access-point association as internet reachability, so on a captive portal
  (the actual venue failure mode) the app reported "online" and fired sync into a wall. Connection status
  now derives from Firestore snapshot metadata (`isFromCache`/`hasPendingWrites`) instead.
- `sync_manager.dart` broke its batch after 5 failures with `_processSyncOperation`'s exponential backoff
  nested inside, inside a 5-minute periodic timer — machinery reimplementing, less reliably, what the
  Firestore SDK does underneath it.

**Process note for Step 4:** across Steps 2 and 3, *seven* Critical/Important defects originated in the
plan's own sample code versus zero from implementers. Treat code in a plan as pseudocode to be reviewed,
never as pre-validated. Running a live probe of any new test dependency during planning (as Step 3 did with
`fake_cloud_firestore`) is what kept the test tasks themselves clean. The empty-DB first-run path got its
own named test file — it had produced bugs three times before and produced none this time.

**What survived and is now tested** (25 repository tests where there were zero): `FirestoreRepository`,
covering CRUD, team-scoped reads, trash lifecycle, and the empty-DB first-run path, via `fake_cloud_firestore`.

## 7. Step 4 — Schema-driven scouting forms

**Why:** FRC/FTC games change **every year**, and the forms hardcode a field per game element
(`_autoFuel`, `_trenchTraverse`, `_shootingRangeClose`…). Every season is a hand-rewrite of an
~850-line file. `gameData` is already `Map<String, dynamic>`, so the *data model already
supports this* — only the UI is hardcoded.

**Shape:** define each game as data (`sections → fields[{key, label, type, required}]`) and
render one generic form. Also split `dashboard.dart` (1137 lines) and give the app a real
event picker (event selection is currently a global preference string).

**Proven field taxonomy to copy** (from QRScout, see §8): `counter`, `multi-counter`, `timer`,
`boolean`, `range`, `select`, `multi-select`, `text`, plus TBA-backed match/team pickers.

## 8. Prior art (researched 2026-07-20 — don't redo this)

Validated the design against both camps of FRC scouting apps.

**Cloud/SaaS (closest analogs):**
- **ScoutinFRC** (FRC 3824) — Flutter + Firebase, multi-team. Nearly the same stack and goal:
  https://github.com/HVA-FRC-3824/ScoutinFRC
- **Scoutradioz** (FRC 102) — multi-org SaaS, MongoDB + AWS Lambda + TBA Firehose,
  "modular & configurable pit/match surveys": https://github.com/FIRSTTeam102/scoutradioz
- **CyberapK 2026** — admin/member **roles**, TBA + Statbotics analysis
- **FRC 2135** — one DB spanning many events, filtered by selected event (validates our
  single-collection + filter model over per-event collections)

**Offline camp (they distrust venue wifi entirely):**
- **Citrus Circuits** (FRC 1678) — tablets → **QR codes** → central aggregator + Bluetooth:
  https://www.citruscircuits.org/scouting.html
- **QRScout** (FRC 2713) — **JSON config-driven forms**, QR → spreadsheet, no internet:
  https://github.com/FRC2713/QRScout
- **FRC Krawler** (2052) — Bluetooth sync

**Interop standard:** The Purple Standard, a community scouting-data schema:
https://www.chiefdelphi.com/t/the-purple-standard-a-unified-and-community-driven-standard-for-frc-scouting-data/449394

**The one open strategic question — RESOLVED 2026-07-22.** Every battle-tested offline system treats
venue connectivity as **absent**, not intermittent, and moves data peer-to-central via QR/Bluetooth.
Our "cloud live-sync at the venue" model is the road less traveled.

The user characterized the real conditions: venue wifi is almost always technically present, but it is
high-school wifi the team does not control, failing in three ways — (a) gated behind a captive-portal
login we lack, (b) throttled under competition-day traffic, (c) random outages. All three are "the socket
does not work," which Firestore's on-disk persistence handles by design (durable write queue, no retry cap,
flush on stream recovery). Step 3 committed to cloud-live-sync rather than building QR transport now.

**Trip-wire (the escape hatch, deferred not discarded):** if a competition produces reports that never
land, or scouts cannot authenticate past a portal, QR aggregation gets its own brainstorm — with real data
on which of (a)/(b)/(c) actually bit. A QR exporter is buildable on the Firestore-only app: query with
`Source.cache` and filter on `snapshot.metadata.hasPendingWrites` to enumerate exactly the unsynced set.
So the option stays open without keeping any code alive for it.

**Operational precondition (cannot be solved in software):** a fresh install in the venue parking lot
cannot authenticate if the portal blocks login, and no storage choice changes that. Firebase Auth persists
sessions locally, so scouts who sign in before leaving stay signed in. "Install and sign in before we leave
for the competition" is an operational rule the team must enforce, not something the app can guarantee.

## 9. Suggested order

1. **Step 2** (Sheets one-way) — smallest, lowest risk, immediate deletion, independent of Step 3.
2. **Step 3** (storage collapse) — biggest win; do it behind tests.
3. **Step 4** (schema-driven forms) — kills the annual rewrite tax.

Steps 2 and 3 are independent; 2 first only because it is cheaper and de-risks the diff.
