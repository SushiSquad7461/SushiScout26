# SushiScout Simplification Roadmap (audit + Steps 2–4 handoff)

- **Date:** 2026-07-21 (Step 2 marked shipped 2026-07-21)
- **Status:** Steps 1 and 2 shipped. Steps 3–4 not started.
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

## 5. Step 2 — Make Google Sheets a one-way export

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

## 6. Step 3 — Collapse to a single offline store (the big cut)

**Why:** this is the ~40–50% code reduction and the fix for the churn in §2.

**Delete:**
- `data/local/sync/sync_manager.dart` (665 lines) — queue, retry/backoff, connectivity listener
- `SyncQueue` + `SyncConflicts` Drift tables (the latter already dead)
- Drift/SQLite entirely, *or* demote it to a pure read-cache (see below)
- The **web/native fork** in `hybrid_repository.dart` — every method is currently written twice
- The reconciliation defenses that only exist because two stores disagree:
  `_pendingMatchIdsForEvent` skip filters, the requeue-on-startup routine

**Two viable shapes — needs a brainstorm to choose:**
1. **Firestore-only** (recommended by the audit): delete Drift + SyncManager; rely on Firestore
   offline persistence. Web already proves this works. Biggest reduction.
2. **Drift as a pure read-cache**: writes go straight to Firestore; local DB is filled
   one-directionally and never pushes competing truth. Keeps cold-start offline reads at the
   cost of keeping the table.

**Do not skip:** whatever survives needs tests. Today the most complex, most-churned code
(`hybrid_repository`, `sync_manager`) has **essentially no test coverage** — that is why the
same area kept regressing.

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

**The one open strategic question:** every battle-tested offline system treats venue
connectivity as **absent**, not intermittent, and moves data peer-to-central via QR/Bluetooth.
Our "cloud live-sync at the venue" model is the road less traveled. The stated requirement
(§3) permits it, but if real competition use proves flaky, a **QR aggregation escape hatch**
is the community's proven answer. Worth its own brainstorm before Step 3 locks in a transport.

## 9. Suggested order

1. **Step 2** (Sheets one-way) — smallest, lowest risk, immediate deletion, independent of Step 3.
2. **Step 3** (storage collapse) — biggest win; do it behind tests.
3. **Step 4** (schema-driven forms) — kills the annual rewrite tax.

Steps 2 and 3 are independent; 2 first only because it is cheaper and de-risks the diff.
