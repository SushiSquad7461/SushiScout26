# Step 3 — Collapse to a Single Offline Store (design)

- **Date:** 2026-07-22
- **Status:** Approved, not implemented
- **Branch:** `single-offline-store`
- **Roadmap:** [`2026-07-21-simplification-roadmap.md`](2026-07-21-simplification-roadmap.md) §6
- **Predecessors:** Step 1 (team isolation) and Step 2 (Sheets one-way) shipped.

## 1. Decision

Delete Drift/SQLite and the hand-rolled sync queue. **Firestore, with its own on-disk
persistence, becomes the single store** on every platform. This is shape 1 of the two the
roadmap named ("Firestore-only"), not shape 2 ("Drift demoted to a read-cache").

The web build already runs this way — every method in `hybrid_repository.dart` has a `_isWeb`
branch that skips Drift entirely — so the target architecture is the one half our platforms
already use in production.

## 2. Why not keep Drift as a read-cache

The roadmap left this open. Three findings closed it:

1. **Drift buys nothing the offline requirement needs.** On a cold start with an empty cache,
   Drift is empty too. Its only edge over Firestore's cache is surviving cache eviction, and
   `main.dart:20` already sets `CACHE_SIZE_UNLIMITED`. Both are local disk; we were paying two
   stores' worth of skew bugs for one store's worth of durability.
2. **A future QR escape hatch does not need Drift.** Firestore can enumerate the unsynced set
   directly: query with `Source.cache` and filter on `snapshot.metadata.hasPendingWrites`. The
   outbox already exists, maintained by the SDK. This was the strongest argument for keeping the
   table, and it does not hold.
3. **A "pure read-cache" is one refactor away from re-growing an outbox.** The moment someone
   needs an offline write, the second source of truth returns — along with the class of bug that
   produced the churn in roadmap §2.

## 3. The venue-connectivity question (roadmap §8)

The roadmap flagged that every battle-tested offline FRC system (Citrus Circuits, QRScout, FRC
Krawler) treats venue connectivity as **absent** and moves data peer-to-central via QR or
Bluetooth, while we sync live to the cloud. Resolved with the user on 2026-07-22.

**The real conditions:** wifi is almost always technically present, but it is high-school wifi we
do not control, and it fails in three ways — (a) gated behind a captive-portal login we do not
have, (b) throttled under competition-day traffic, (c) random outages.

**All three are variations of "the socket does not work,"** which Firestore's persistence layer
handles by design: writes land in an on-disk queue, unbounded, with no retry cap, flushed when
the stream actually recovers.

**Case (a) already defeats the code we are deleting.** `sync_manager.dart:158` treats any
`ConnectivityResult != none` as "connectivity restored" and fires a sync. `ConnectivityResult.wifi`
means *associated with an access point*, not *reaching the internet* — so on a captive portal the
app reports online and syncs into a wall. `isOnlineProvider` (`sync_manager.dart:71`) shares the
flaw and feeds the sync UI. The hand-rolled queue is worst precisely where our worst case lives.

**Case (b) argues against the current design, not for it.** The hybrid layer does not reduce
network usage, it adds to it: `getMatches()` returns from Drift *and* fires a background
`_refreshFromFirestore` (`hybrid_repository.dart:407`), on top of a live `watchMatches` listener
*and* a second `watchTrash` listener per event. Under throttling that is the worst shape —
repeated full re-reads competing with a snapshot stream. Firestore-only ships deltas via resume
tokens.

**Decision:** commit to cloud-live-sync, with a written trip-wire instead of speculative
architecture. If a competition produces reports that never land, or scouts cannot authenticate
past a portal, QR aggregation gets its own brainstorm — with real data on which of (a)/(b)/(c)
actually bit. To be recorded in the roadmap.

**Operational precondition:** a fresh install in the venue parking lot cannot authenticate if the
portal blocks login, and no storage choice changes that. Firebase Auth persists sessions locally,
so scouts who sign in before leaving stay signed in. "Install and sign in before we leave" is an
operational rule, not something the app can enforce.

## 4. Scope of the cut

| File | Lines | Fate |
|---|---|---|
| `data/local/database/app_database.g.dart` | 4117 | delete (generated) |
| `data/repositories/hybrid_repository.dart` | 847 | delete |
| `data/local/sync/sync_manager.dart` | 663 | delete |
| `presentation/widgets/sync_status_indicator.dart` | 525 | replace (~100 lines) |
| `data/local/database/app_database.dart` | 391 | delete |
| `data/local/database/tables.dart` + `connection/*` | 129 | delete |

≈6,670 of 15,967 total lines (**42%**), but only ≈2,555 of ~11,850 **hand-written** lines
(**22%**). The roadmap's "40–50% reduction" counts the generated Drift file. Recorded here so
the payoff is not overstated: this is still the largest cut available and it lands exactly on the
churn hotspot, but hand-maintained code shrinks by about a fifth, not a half.

Dependencies `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `drift_dev` (dev), and
`connectivity_plus` leave `pubspec.yaml` — verified as the complete set. The Drift `build_runner`
step disappears. `connectivity_plus` has exactly one import site (`sync_manager.dart:5`), so its
removal is clean.

### Supporting evidence for the cut

- **`app_database.dart` is almost entirely unused by the app.** `searchMatches`,
  `getMatchesByTeamNumber`, `getMatchCount`, `getTrashCount`, `purgeOldDeletedMatches`, and the
  whole `SyncConflicts` block have zero callers outside the file. The only live consumers are
  `getUnsyncedMatches`/`getUnsyncedCount`, called by SyncManager — the local DB exists mainly to
  serve the sync queue that exists to serve the local DB.
- **Two competing `SyncStatus` types** exist: a sealed hierarchy at `sync_manager.dart:589` and
  an unrelated one at `sync_status_indicator.dart:510`.
- **`SyncingPulseIndicator`** (`sync_status_indicator.dart:453-508`) is dead.
- **The retry machinery carries its own confession.** `app_database.dart:194-202` documents that a
  previous retry-count filter stranded sync operations forever. `sync_manager.dart:424` breaks the
  batch after 5 failures, with `_processSyncOperation`'s own exponential backoff nested inside
  that loop, inside a 5-minute periodic timer.
- **No test coverage.** No test file references `hybrid_repository` or `sync_manager` except a
  mock. This is why the area kept regressing (roadmap §6).

## 5. Target architecture

```
UI  →  scoutingRepositoryProvider  →  FirestoreRepository  →  cloud_firestore (persistence)
```

One code path for web and native; the `_isWeb` fork disappears, so tests finally cover the same
code the web build runs. `FirestoreRepository` (194 lines) already implements the full
`ScoutingRepository` interface and becomes the only implementation. `HybridRepository` is
deleted, not refactored.

Three pieces of complexity vanish for free, because they were artifacts of having two stores
rather than features:

- `_filterToActiveTeam` — needed because one SQLite file was shared across team switches. The
  Firestore query already filters `.where('teamId', isEqualTo:)`.
- `_toMatchReport`'s program-type guess (`gameData.containsKey('artifacts_auto') ? 'FTC' : 'FRC'`)
  — Drift had no `programType` column; Firestore stores it.
- `_pendingMatchIdsForEvent` skip filters and the requeue-on-startup routine — both exist only to
  referee disagreements between two stores.

### Provider relocation (startup trap)

`activeTeamIdProvider` (`sync_manager.dart:57`) and `firestoreRepositoryProvider`
(`sync_manager.dart:60`) are **declared inside the file being deleted** and are overridden in
`main.dart:28-32`. They move to a new `lib/data/repositories/providers.dart`, joined by
`scoutingRepositoryProvider`. Deleting `sync_manager.dart` before relocating them breaks app
startup.

## 6. Connection status (replaces the connectivity lie)

Status is derived from **Firestore's own snapshot metadata**, which reflects whether the server
stream is actually alive, rather than from link-layer state:

- `snapshot.metadata.isFromCache` → not reaching Firestore, regardless of the wifi icon.
- `docs.where((d) => d.metadata.hasPendingWrites)` → reports saved locally, not yet uploaded.

This requires `watchMatches` to subscribe with `snapshots(includeMetadataChanges: true)`; it
currently does not, so metadata-only transitions would not emit. `connectivity_plus`,
`isOnlineProvider`, and `connectivityProvider` are deleted.

**Known bound (accepted, not a defect):** a query snapshot reports pending writes only for the
docs that query covers — the current event. A report saved against a different event is not
counted. Scouts work one event at a time; a second listener is not worth the traffic.

### UX

The badge states what is true — **"3 reports on this device — not uploaded yet"** — plus an
offline indicator when `isFromCache` is set. Both current call sites are replaced:
`SyncStatusIndicator(compact: true)` (`dashboard.dart:227`) and `SyncStatusBar()`
(`dashboard.dart:210`).

Removed: the **force-sync button**, because there is nothing to force — Firestore flushes when
the stream recovers, and a button implying otherwise is how the current UI misleads. Also removed:
**`clearAllLocalData`** (`dashboard.dart:314`), which cleared the Drift cache. It is not
repointed at `clearPersistence()`, which throws unless the client is stopped.

## 7. Traffic reduction (case b)

- Drop the background `_refreshFromFirestore` fired on every `getMatches()`.
- Stop running `watchTrash` alongside `watchMatches` for the same event.
- Dashboard calls both `watchMatches()` and `getMatches()` at four sites
  (`dashboard.dart:39, 58, 107, 235`); consolidate onto the stream.

Net effect under throttling: one delta-synced listener per screen instead of a listener plus
repeated full re-reads.

## 8. Testing

What survives is `FirestoreRepository` — 194 lines previously exercised only by the web build,
which nothing tests. Tests come **first**, against the code that is staying, so the deletion is
verified by a suite that already passes rather than validated by hope.

**Layer 1 — `FirestoreRepository` against `fake_cloud_firestore`** (verified to resolve against
current constraints; 27 dependency changes, no conflicts). CRUD, trash/restore/hard-delete,
`_getOrCreateEvent`, `robotDied` round-trip, and team scoping — a Team B query must not see Team
A's reports. That guarantee is currently protected only by rules tests, never by client tests.

**Layer 2 — the empty-DB first-run path, as named tests.** Roadmap §5 lesson 3: this has produced
bugs three times across Steps 1 and 2. First match written to a brand-new event; first read on a
team with zero documents; `_getOrCreateEvent` when the event doc does not exist.

**Layer 3 — connection status through a seam.** `fake_cloud_firestore` is expected to return
default metadata (`hasPendingWrites: false`, `isFromCache: false`) and cannot simulate offline.
The logic splits into a pure function over `{isFromCache, pendingCount}`, fully unit-tested, and a
thin extraction at the Firestore edge that is not. **Task 1 must verify what the fake actually
reports rather than assume**; the seam is correct either way.

**Layer 4 — manual, and unavoidable.** Roadmap §5 lesson 2: mocked tests cannot validate an
external system. Green tests will not prove Firestore's offline queue behaves. Before merge, a
physical airplane-mode run: submit reports offline → confirm the badge counts them → restore
connectivity → confirm they reach Firestore *and* the Sheet via `on_match_written`.

**Coverage limitation, stated rather than papered over:** airplane mode tests "no socket"; a
captive portal tests "a socket that lies." The closest cheap proxy is a network with no internet
egress. We do not have honest coverage of case (a) short of a real venue.

## 9. Migration

**None.** Confirmed with the user on 2026-07-22: there are no real users and nothing is in
production, so the Drift database may be deleted outright. No drain pass, no first-launch
migration — the branch stays a pure subtraction.

## 10. Risks

| Risk | Handling |
|---|---|
| Deleting `sync_manager.dart` breaks startup (declares providers `main.dart` overrides) | Relocation is its own task, before any deletion |
| Firestore's write queue behaves differently than assumed under long outages | Layer 4 airplane-mode E2E; this assumption is what the whole step rests on |
| `robotDied` is a Drift column but lives in `gameData` in Firestore | Round-trip test in Task 1, before Drift is removed |
| Losing offline reads on a genuinely cold start | Already true today — Drift is equally empty on first run. No regression; it is why the §3 operational precondition stands |
| Plan sample code carrying defects (roadmap §5 lesson 1 — all three Step 2 defects originated there) | The plan states intent and test expectations, not paste-ready implementations; every task reviewed |

## 11. Task sequence

Eight tasks, review after each, whole-branch review at the end. Tasks 1–2 are pure addition, 3–4
are reversible, 5–7 are the subtraction; the branch is bisectable throughout.

1. **Safety net** — add `fake_cloud_firestore`; test `FirestoreRepository` (CRUD, team scoping,
   trash/restore, `robotDied` round-trip); verify what the fake reports for snapshot metadata.
2. **Empty-DB first-run tests** — named and separate, per §5 lesson 3.
3. **Relocate providers** to `data/repositories/providers.dart`; add `scoutingRepositoryProvider`.
   No behavior change; the app still runs on `HybridRepository`.
4. **Repoint the UI** — dashboard, both scouting forms, trash screen move to
   `scoutingRepositoryProvider`. `HybridRepository` still compiles but is orphaned.
5. **The cut** — delete `HybridRepository`, `SyncManager`, the Drift layer and its generated file;
   drop `drift`/`drift_flutter`/`sqlite3_flutter_libs`/`drift_dev`.
6. **Connection status** — pure status function plus `connection_status.dart`; delete
   `sync_status_indicator.dart`, `connectivity_plus`, and both `SyncStatus` hierarchies; add
   `includeMetadataChanges: true`.
7. **Traffic trim** — remove the background refresh and the duplicate `getMatches()`/
   `watchMatches()` calls at the four dashboard sites; remove `clearAllLocalData`.
8. **Docs** — `CLAUDE.md` (drop the Drift codegen rule, the 4-tables note, the offline-first
   description; retire the `drift-migration-reviewer` agent) and the roadmap (mark Step 3 shipped,
   record the QR trip-wire from §3).

## 12. Out of scope

- Splitting `dashboard.dart` and schema-driven forms — that is Step 4.
- Any deploy. Nothing ships without the user present.
- Building QR aggregation. Recorded as a trip-wire only (§3).
