# Single Offline Store (Step 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete Drift/SQLite and the hand-rolled sync queue so Firestore — with its own on-disk persistence — is the single store on every platform.

**Architecture:** `UI → firestoreRepositoryProvider → FirestoreRepository → cloud_firestore (persistence)`. The `_isWeb` fork in `HybridRepository` disappears, so web and native run one code path. Connection status is derived from Firestore snapshot metadata (`isFromCache`, `hasPendingWrites`) instead of link-layer state from `connectivity_plus`.

**Tech Stack:** Flutter, Riverpod 3, `cloud_firestore`, `fake_cloud_firestore` (new, test-only).

**Spec:** [`../specs/2026-07-22-single-offline-store-design.md`](../specs/2026-07-22-single-offline-store-design.md)

## Global Constraints

- Branch is `single-offline-store`. Already created. Do not merge or deploy — **nothing ships without the user present.**
- Commit convention: `<type>(<scope>): <subject>` — imperative, lowercase, no trailing period, max 50 chars. Scopes used here: `frontend`, `test`, `sync`, `db`, `ui`, `deps`, `docs`.
- Run the full suite from `frontend/` with `flutter test`. Baseline before this plan: **308 tests passing** (measured 2026-07-22 — `CLAUDE.md` says 292 and is stale; Task 8 corrects it). The count grows in Tasks 1–3 and shrinks in Task 5 (two obsolete tests deleted).
- `flutter analyze` must be clean before every commit.
- Never hand-edit generated files (`*.g.dart`, `*.mocks.dart`).
- There are **no real users and nothing in production** — the Drift database may be deleted outright. No migration or drain code anywhere in this plan.
- Do not run `flutter run -d web-server` (silent blank page — see CLAUDE.md).

## Verified Facts (do not re-derive)

These were confirmed against the real code and a live `fake_cloud_firestore` probe on 2026-07-22. Trust them.

- `MatchReport.fromFirestore` (`match_report.dart:75`) already sets `isSynced: !doc.metadata.hasPendingWrites`. **The pending-write signal is already on every `MatchReport`** — no new plumbing is needed to count unsynced reports.
- `fake_cloud_firestore` supports `doc.metadata` and `snapshot.metadata` without throwing, but **always** reports `hasPendingWrites: false` / `isFromCache: false`. It cannot simulate offline. This is why Task 5 puts the status logic behind a pure function.
- `fake_cloud_firestore` correctly handles the `where + where + where + orderBy` composite query in `_matchesQuery`, and correctly scopes by `teamId`.
- `activeTeamIdProvider` (`sync_manager.dart:57`) and `firestoreRepositoryProvider` (`sync_manager.dart:60`) are declared **inside the file being deleted** and are overridden in `main.dart:28-32`. Task 3 relocates them before any deletion.
- `connectivity_plus` has exactly one import site: `sync_manager.dart:5`.
- Drift-related dependencies, complete set: `drift`, `drift_flutter`, `sqlite3_flutter_libs` (all `dependencies`), `drift_dev` (`dev_dependencies`).
- `SyncingPulseIndicator` is dead. `SyncStatusBar` is live at `dashboard.dart:210`. `SyncStatusIndicator(compact: true)` is live at `dashboard.dart:227`.

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `test/data/repositories/firestore_repository_test.dart` | CREATE — safety net for the code that survives | 1 |
| `test/data/repositories/firestore_repository_first_run_test.dart` | CREATE — empty-DB cold start, isolated by design | 2 |
| `lib/data/repositories/providers.dart` | CREATE — owns `activeTeamIdProvider`, `firestoreRepositoryProvider` | 3 |
| `lib/presentation/screens/dashboard.dart` | MODIFY — repoint, then consolidate onto one stream | 4, 7 |
| `lib/presentation/screens/{frc_rebuilt_form,ftc_decode_form,trash_screen}.dart` | MODIFY — repoint | 4 |
| `lib/presentation/widgets/connection_status.dart` | CREATE — pure status fn + two widgets | 5 |
| `lib/presentation/widgets/sync_status_indicator.dart` | DELETE | 5 |
| `lib/data/repositories/firestore_repository.dart` | MODIFY — add `watchMatchesView` | 5 |
| `lib/data/repositories/hybrid_repository.dart` | DELETE | 6 |
| `lib/data/local/sync/sync_manager.dart` | DELETE | 6 |
| `lib/data/local/database/**` | DELETE | 6 |
| `CLAUDE.md`, roadmap spec | MODIFY | 8 |

---

### Task 1: Safety net — characterize `FirestoreRepository`

`FirestoreRepository` is the code that survives, and today nothing tests it (the web build is its only exercise). These tests go in **before** anything is deleted, so the deletion is verified by a suite that already passes.

**These are characterization tests, not TDD.** The behavior already exists, so they pass on first run. That is the expected outcome — a RED here means a genuine pre-existing bug.

**Files:**
- Modify: `frontend/pubspec.yaml` (`dev_dependencies`)
- Create: `frontend/test/data/repositories/firestore_repository_test.dart`

**Interfaces:**
- Consumes: `FirestoreRepository(FirebaseFirestore, {String? teamId})` from `lib/data/repositories/firestore_repository.dart`; `MatchReport` from `lib/data/models/match_report.dart`.
- Produces: `buildMatch({required String id, ...})` — a test helper other tasks' test files re-declare locally rather than import (test helpers are not shared across files in this codebase).

- [ ] **Step 1: Add the test-only dependency**

```bash
cd frontend && flutter pub add --dev fake_cloud_firestore
```

Expected: `Changed 27 dependencies!` with no version conflicts. This was verified on 2026-07-22.

- [ ] **Step 2: Write the characterization tests**

Create `frontend/test/data/repositories/firestore_repository_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';

MatchReport buildMatch({
  required String id,
  int teamNumber = 4198,
  Map<String, dynamic>? gameData,
  String programType = 'FRC',
  String teamId = '',
}) {
  return MatchReport(
    id: id,
    matchId: 'qm1_$teamNumber',
    matchNumber: 1,
    teamNumber: teamNumber,
    alliance: 'Red',
    scouterName: 'scout',
    gameData: gameData ?? {'auto_fuel': 3},
    createdAt: DateTime(2026, 7, 22),
    programType: programType,
    teamId: teamId,
  );
}

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(fake, teamId: 'teamA');
  });

  group('create and read', () {
    test('createMatch writes a readable match', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final matches = await repo.getMatches('teamA_evt');

      expect(matches, hasLength(1));
      expect(matches.single.id, 'm1');
      expect(matches.single.teamNumber, 4198);
    });

    test('createMatch stamps the repository teamId onto the document', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final matches = await repo.getMatches('teamA_evt');

      expect(matches.single.teamId, 'teamA');
    });

    test('robotDied round-trips through gameData', () async {
      await repo.createMatch(
        'teamA_evt',
        buildMatch(id: 'm1', gameData: {'auto_fuel': 3, 'robot_died': true}),
      );

      final matches = await repo.getMatches('teamA_evt');

      expect(matches.single.robotDied, isTrue);
    });

    test('programType is persisted rather than inferred', () async {
      await repo.createMatch(
        'teamA_evt',
        buildMatch(id: 'm1', programType: 'FTC', gameData: {'artifacts_auto': 2}),
      );

      final matches = await repo.getMatches('teamA_evt');

      expect(matches.single.programType, 'FTC');
    });

    test('updateMatch overwrites fields on the existing document', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      await repo.updateMatch(
        'teamA_evt',
        buildMatch(id: 'm1', gameData: {'auto_fuel': 9}),
      );

      final matches = await repo.getMatches('teamA_evt');
      expect(matches, hasLength(1));
      expect(matches.single.autoFuel, 9);
    });
  });

  group('trash lifecycle', () {
    test('trashMatch removes the match from the active list', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      await repo.trashMatch('teamA_evt', 'm1');

      expect(await repo.getMatches('teamA_evt'), isEmpty);
    });

    test('trashMatch moves the match into the trash list', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      await repo.trashMatch('teamA_evt', 'm1');

      final trashed = await repo.getDeletedMatches('teamA_evt');
      expect(trashed, hasLength(1));
      expect(trashed.single.id, 'm1');
    });

    test('restoreMatch returns the match to the active list', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));
      await repo.trashMatch('teamA_evt', 'm1');

      await repo.restoreMatch('teamA_evt', 'm1');

      expect(await repo.getMatches('teamA_evt'), hasLength(1));
      expect(await repo.getDeletedMatches('teamA_evt'), isEmpty);
    });

    test('deleteMatch removes the document entirely', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));
      await repo.trashMatch('teamA_evt', 'm1');

      await repo.deleteMatch('teamA_evt', 'm1');

      expect(await repo.getDeletedMatches('teamA_evt'), isEmpty);
      final raw = await fake.collection('matches').doc('m1').get();
      expect(raw.exists, isFalse);
    });
  });

  group('team isolation', () {
    test('a repository scoped to another team cannot read these matches', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final repoB = FirestoreRepository(fake, teamId: 'teamB');

      expect(await repoB.getMatches('teamA_evt'), isEmpty);
    });

    test('getEvents only returns events belonging to the active team', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));
      final repoB = FirestoreRepository(fake, teamId: 'teamB');
      await repoB.createMatch('teamB_evt', buildMatch(id: 'm2'));

      final eventsA = await repo.getEvents();

      expect(eventsA.map((e) => e.id), ['teamA_evt']);
    });

    test('watchMatches only emits matches for the active team', () async {
      final repoB = FirestoreRepository(fake, teamId: 'teamB');
      await repo.createMatch('shared_evt', buildMatch(id: 'm1'));
      await repoB.createMatch('shared_evt', buildMatch(id: 'm2'));

      final emitted = await repo.watchMatches('shared_evt').first;

      expect(emitted.map((m) => m.id), ['m1']);
    });
  });

  group('streams', () {
    test('watchTrash emits only trashed matches', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));
      await repo.createMatch('teamA_evt', buildMatch(id: 'm2', teamNumber: 254));
      await repo.trashMatch('teamA_evt', 'm2');

      final emitted = await repo.watchTrash('teamA_evt').first;

      expect(emitted.map((m) => m.id), ['m2']);
    });
  });
}
```

- [ ] **Step 3: Run the tests**

Run: `cd frontend && flutter test test/data/repositories/firestore_repository_test.dart`
Expected: **PASS** (13 tests). These characterize existing behavior.

**If any test fails, STOP.** You have found a real pre-existing bug in code that is about to become the app's only storage path. Report it to the user with the failure output rather than adjusting the test to match the bug.

- [ ] **Step 4: Verify the full suite still passes**

Run: `cd frontend && flutter test`
Expected: 321 tests passing (308 baseline + 13).

- [ ] **Step 5: Verify analysis is clean**

Run: `cd frontend && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd frontend && git add pubspec.yaml pubspec.lock test/data/repositories/firestore_repository_test.dart
git commit -m "test(frontend): characterize firestore repository"
```

---

### Task 2: Empty-database first-run tests

Roadmap §5 lesson 3: the empty-DB cold-start path has produced bugs **three times** across Steps 1 and 2. It gets its own file so it cannot be diluted into general CRUD coverage.

**Files:**
- Create: `frontend/test/data/repositories/firestore_repository_first_run_test.dart`

**Interfaces:**
- Consumes: same `FirestoreRepository` surface as Task 1. Re-declare `buildMatch` locally — do not import it from Task 1's file.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the first-run tests**

Create `frontend/test/data/repositories/firestore_repository_first_run_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/match_report.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';

MatchReport buildMatch({required String id, String programType = 'FRC'}) {
  return MatchReport(
    id: id,
    matchId: 'qm1_4198',
    matchNumber: 1,
    teamNumber: 4198,
    alliance: 'Red',
    scouterName: 'scout',
    gameData: const {'auto_fuel': 3},
    createdAt: DateTime(2026, 7, 22),
    programType: programType,
  );
}

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(fake, teamId: 'teamA');
  });

  group('reads against a completely empty database', () {
    test('getMatches returns an empty list rather than throwing', () async {
      expect(await repo.getMatches('teamA_evt'), isEmpty);
    });

    test('getDeletedMatches returns an empty list rather than throwing', () async {
      expect(await repo.getDeletedMatches('teamA_evt'), isEmpty);
    });

    test('getEvents returns an empty list rather than throwing', () async {
      expect(await repo.getEvents(), isEmpty);
    });

    test('getEvent returns null for a missing event', () async {
      expect(await repo.getEvent('teamA_evt'), isNull);
    });

    test('watchMatches emits an empty list rather than erroring', () async {
      expect(await repo.watchMatches('teamA_evt').first, isEmpty);
    });
  });

  group('the very first match written to a new event', () {
    test('auto-creates the missing event document', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final event = await fake.collection('events').doc('teamA_evt').get();
      expect(event.exists, isTrue);
      expect(event.data()!['autoCreated'], isTrue);
    });

    test('strips the team prefix when deriving the event name and tbaKey', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final event = await fake.collection('events').doc('teamA_evt').get();
      expect(event.data()!['name'], 'evt');
      expect(event.data()!['tbaKey'], 'evt');
    });

    test('stamps the owning team onto the auto-created event', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1'));

      final event = await fake.collection('events').doc('teamA_evt').get();
      expect(event.data()!['teamId'], 'teamA');
    });

    test('adopts the match programType when auto-creating the event', () async {
      await repo.createMatch('teamA_evt', buildMatch(id: 'm1', programType: 'FTC'));

      final event = await fake.collection('events').doc('teamA_evt').get();
      expect(event.data()!['programType'], 'FTC');
    });

    test('a pre-existing event keeps its programType instead of being overwritten', () async {
      await fake.collection('events').doc('teamA_evt').set({
        'name': 'evt',
        'programType': 'FTC',
        'tbaKey': 'evt',
        'teamId': 'teamA',
      });

      await repo.createMatch('teamA_evt', buildMatch(id: 'm1', programType: 'FRC'));

      final matches = await repo.getMatches('teamA_evt');
      expect(matches.single.programType, 'FTC');
    });
  });

  group('writes that race a missing document', () {
    test('trashMatch on a match that does not exist still stamps teamId', () async {
      await repo.trashMatch('teamA_evt', 'ghost');

      final doc = await fake.collection('matches').doc('ghost').get();
      expect(doc.data()!['teamId'], 'teamA');
      expect(doc.data()!['isDeleted'], isTrue);
    });

    test('restoreMatch on a match that does not exist still stamps teamId', () async {
      await repo.restoreMatch('teamA_evt', 'ghost');

      final doc = await fake.collection('matches').doc('ghost').get();
      expect(doc.data()!['teamId'], 'teamA');
      expect(doc.data()!['isDeleted'], isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `cd frontend && flutter test test/data/repositories/firestore_repository_first_run_test.dart`
Expected: **PASS** (12 tests).

The `teamId` stamping tests cover `_withTeamId` (`firestore_repository.dart:79-87`), which exists so a trash/restore racing a hard-delete still satisfies the Firestore rules' `isValidTeamId()` check on create. If they fail, that rules path is broken — stop and report.

- [ ] **Step 3: Verify the full suite**

Run: `cd frontend && flutter test`
Expected: 333 tests passing.

- [ ] **Step 4: Commit**

```bash
cd frontend && git add test/data/repositories/firestore_repository_first_run_test.dart
git commit -m "test(frontend): cover empty-db first-run path"
```

---

### Task 3: Relocate providers out of the doomed file

`sync_manager.dart` declares two providers that `main.dart` overrides at startup. Deleting the file without moving them first breaks app launch. This task is pure relocation — **no behavior changes**.

`scoutingRepositoryProvider` is deliberately **not** introduced: with one implementation left, it would be a pure alias for `firestoreRepositoryProvider`. The UI uses `firestoreRepositoryProvider` directly.

**Files:**
- Create: `frontend/lib/data/repositories/providers.dart`
- Modify: `frontend/lib/data/local/sync/sync_manager.dart:57-63` (remove declarations, add import)
- Modify: `frontend/lib/main.dart:9` (import)
- Create: `frontend/test/data/repositories/providers_test.dart`

**Interfaces:**
- Produces: `activeTeamIdProvider` (`Provider<String?>`) and `firestoreRepositoryProvider` (`Provider<FirestoreRepository>`), both exported from `lib/data/repositories/providers.dart`. Tasks 4, 6, and 7 import them from there.

- [ ] **Step 1: Create the new provider file**

Create `frontend/lib/data/repositories/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firestore_repository.dart';

/// The team whose data the app is currently showing.
///
/// Overridden in `main.dart` from `currentTeamIdProvider`. Defaults to null so
/// widget tests can construct a container without auth.
final activeTeamIdProvider = Provider<String?>((ref) => null);

/// The app's single data repository.
///
/// Overridden in `main.dart` with a real `FirebaseFirestore` instance scoped to
/// the active team. Firestore's own on-disk persistence is the offline store —
/// there is no second local database.
final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  throw UnimplementedError('Initialize with proper Firebase instance');
});
```

- [ ] **Step 2: Remove the declarations from `sync_manager.dart`**

Delete lines 56-63 of `frontend/lib/data/local/sync/sync_manager.dart` — the block declaring `activeTeamIdProvider` and `firestoreRepositoryProvider`, including their doc comments:

```dart
/// Provider for the active team ID
final activeTeamIdProvider = Provider<String?>((ref) => null);

final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  // This should be initialized with proper Firebase instance
  throw UnimplementedError('Initialize with proper Firebase instance');
});
```

Then add this import alongside the existing imports at the top of the file:

```dart
import '../../repositories/providers.dart';
```

Note: `sync_manager.dart` lives at `lib/data/local/sync/`, so the relative path to `lib/data/repositories/` is `../../repositories/providers.dart`. It still references `firestoreRepositoryProvider` at line 30 — that now resolves through the import.

- [ ] **Step 3: Update the import in `main.dart`**

In `frontend/lib/main.dart`, replace line 9:

```dart
import 'data/local/sync/sync_manager.dart';
```

with:

```dart
import 'data/repositories/providers.dart';
```

`main.dart` uses only `activeTeamIdProvider` and `firestoreRepositoryProvider` from that import, both of which now live in the new file.

- [ ] **Step 4: Verify it compiles**

Run: `cd frontend && flutter analyze`
Expected: `No issues found!`

A `Undefined name 'firestoreRepositoryProvider'` error means a file that referenced it still needs the new import — `hybrid_repository.dart:20` gets it transitively via its `sync_manager.dart` import, so it should not need changing. Add the import if analyze says otherwise.

- [ ] **Step 5: Write a test proving the overrides still work**

Create `frontend/test/data/repositories/providers_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/repositories/providers.dart';

void main() {
  test('firestoreRepositoryProvider throws until it is overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(firestoreRepositoryProvider),
      throwsUnimplementedError,
    );
  });

  test('the main.dart override wiring produces a team-scoped repository', () {
    final fake = FakeFirebaseFirestore();
    final container = ProviderContainer(
      overrides: [
        activeTeamIdProvider.overrideWith((ref) => 'teamA'),
        firestoreRepositoryProvider.overrideWith((ref) {
          final teamId = ref.watch(activeTeamIdProvider);
          return FirestoreRepository(fake, teamId: teamId);
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(firestoreRepositoryProvider).teamId, 'teamA');
  });
}
```

- [ ] **Step 6: Run the tests**

Run: `cd frontend && flutter test`
Expected: 335 tests passing.

- [ ] **Step 7: Commit**

```bash
cd frontend && git add lib/data/repositories/providers.dart lib/data/local/sync/sync_manager.dart lib/main.dart test/data/repositories/providers_test.dart
git commit -m "refactor(frontend): move providers out of sync manager"
```

---

### Task 4: Repoint the UI at `FirestoreRepository`

Every UI call site moves from `hybridRepositoryProvider` to `firestoreRepositoryProvider`. After this task `HybridRepository` still compiles but nothing uses it, so Task 5 is a clean deletion.

The one call that does not survive is `clearAllLocalData()` — it cleared the Drift cache and has no Firestore equivalent (`clearPersistence()` throws unless the client is stopped). Its settings action is removed here, since it is part of repointing rather than a separate concern.

**Files:**
- Modify: `frontend/lib/presentation/screens/dashboard.dart` (lines 39, 51, 58, 107, 194, 235, 314, 535, 829)
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart:797`
- Modify: `frontend/lib/presentation/screens/ftc_decode_form.dart:739`
- Modify: `frontend/lib/presentation/screens/trash_screen.dart` (lines 25, 56, 106)

**Interfaces:**
- Consumes: `firestoreRepositoryProvider` from Task 3.
- Produces: nothing new. `FirestoreRepository` already implements every method these call sites use — `watchMatches`, `watchTrash`, `getMatches`, `getEvent`, `createMatch`, `trashMatch`, `restoreMatch`, `deleteMatch`.

- [ ] **Step 1: Repoint the two scouting forms**

In `frontend/lib/presentation/screens/frc_rebuilt_form.dart`, replace the `hybrid_repository.dart` import with `../../data/repositories/providers.dart`, then change line 797:

```dart
await ref.read(firestoreRepositoryProvider).createMatch(widget.eventId, report);
```

Apply the identical change in `frontend/lib/presentation/screens/ftc_decode_form.dart` at line 739.

- [ ] **Step 2: Repoint the trash screen**

In `frontend/lib/presentation/screens/trash_screen.dart`, replace the `hybrid_repository.dart` import with `../../data/repositories/providers.dart`, then change all three `ref.read(hybridRepositoryProvider)` occurrences (lines 25, 56, 106) to `ref.read(firestoreRepositoryProvider)`.

- [ ] **Step 3: Repoint the dashboard**

In `frontend/lib/presentation/screens/dashboard.dart`, replace the `hybrid_repository.dart` import with `../../data/repositories/providers.dart`, then change every `ref.read(hybridRepositoryProvider)` to `ref.read(firestoreRepositoryProvider)` at lines 39, 51, 58, 107, 194, 235, 535, and 829.

Line 314 is handled separately in the next step — do not repoint it.

- [ ] **Step 4: Remove the clear-local-data action**

In `frontend/lib/presentation/screens/dashboard.dart`, delete the entire settings action containing the `clearAllLocalData()` call at line 314 — the confirmation `AlertDialog`, the `try`/`catch`, and the list tile that triggers it. There is no local data to clear once Firestore owns persistence, and a button that silently does nothing is worse than no button.

Search for any now-unused imports or helper methods left behind and remove them; `flutter analyze` in the next step will flag them.

- [ ] **Step 5: Verify nothing references the hybrid repository**

Run: `cd frontend && grep -rn "hybridRepositoryProvider" lib/`
Expected: **no output.** Any remaining hit is a call site missed above.

- [ ] **Step 6: Verify it compiles and the suite passes**

Run: `cd frontend && flutter analyze && flutter test`
Expected: `No issues found!` and 335 tests passing.

- [ ] **Step 7: Commit**

```bash
cd frontend && git add lib/presentation/screens/
git commit -m "refactor(frontend): point ui at firestore repository"
```

---

### Task 5: Honest connection status

Replaces 525 lines of sync-queue UI with a small widget driven by Firestore's own metadata. This is the hardening item that answers the captive-portal case: `connectivity_plus` reports *associated with an access point*, which is true on a portal that blocks all traffic. Snapshot metadata reports whether the server stream is actually alive.

The status logic lives in a **pure function** because `fake_cloud_firestore` always reports `hasPendingWrites: false` / `isFromCache: false` and can never exercise the offline path (verified 2026-07-22).

**Files:**
- Modify: `frontend/lib/data/repositories/firestore_repository.dart` (add `MatchesView` + `watchMatchesView`)
- Create: `frontend/lib/presentation/widgets/connection_status.dart`
- Delete: `frontend/lib/presentation/widgets/sync_status_indicator.dart`
- Delete: `frontend/test/widgets/sync_status_indicator_test.dart`
- Modify: `frontend/lib/presentation/screens/dashboard.dart:210, 227`
- Create: `frontend/test/presentation/widgets/connection_status_test.dart`

**Order note:** this task comes *before* the cut (Task 6), deliberately. It removes the last import of `sync_manager.dart`, so Task 6's deletion leaves a tree that still compiles. **Do not touch `pubspec.yaml` here** — `sync_manager.dart` still imports `connectivity_plus` until Task 6 removes both together.

**Interfaces:**
- Consumes: `firestoreRepositoryProvider` (Task 3); `MatchReport.isSynced`, which is already `!doc.metadata.hasPendingWrites`.
- Produces:
  - `class MatchesView { final List<MatchReport> matches; final bool isFromCache; const MatchesView({required this.matches, required this.isFromCache}); }` in `firestore_repository.dart`
  - `Stream<MatchesView> FirestoreRepository.watchMatchesView(String eventId)`
  - `class ConnectionStatus { final bool isOffline; final int pendingCount; ... String get message; }` in `connection_status.dart`
  - `ConnectionStatus connectionStatusFrom({required bool isFromCache, required int pendingCount})`
  - `matchesViewProvider` (`StreamProvider<MatchesView>`) — Task 7 consumes this
  - Note: `connection_status.dart` imports `providers.dart` (Task 3) and `event_providers.dart`; it must NOT import `sync_manager.dart`, which Task 6 deletes
  - Widgets `ConnectionStatusBar` and `ConnectionStatusChip({bool compact})`

- [ ] **Step 1: Write the failing test for the pure status function**

Create `frontend/test/presentation/widgets/connection_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/connection_status.dart';

void main() {
  group('connectionStatusFrom', () {
    test('reports everything uploaded when online with no pending writes', () {
      final status = connectionStatusFrom(isFromCache: false, pendingCount: 0);

      expect(status.isOffline, isFalse);
      expect(status.pendingCount, 0);
      expect(status.isFullySynced, isTrue);
      expect(status.message, 'All reports uploaded');
    });

    test('reports uploading when online with pending writes', () {
      final status = connectionStatusFrom(isFromCache: false, pendingCount: 3);

      expect(status.isOffline, isFalse);
      expect(status.isFullySynced, isFalse);
      expect(status.message, 'Uploading 3 reports…');
    });

    test('singularises the count for a single pending report', () {
      final status = connectionStatusFrom(isFromCache: false, pendingCount: 1);

      expect(status.message, 'Uploading 1 report…');
    });

    test('reports offline with a saved count when unreachable', () {
      final status = connectionStatusFrom(isFromCache: true, pendingCount: 2);

      expect(status.isOffline, isTrue);
      expect(status.isFullySynced, isFalse);
      expect(status.message, 'Offline — 2 reports saved on this device');
    });

    test('reports offline without a count when nothing is pending', () {
      final status = connectionStatusFrom(isFromCache: true, pendingCount: 0);

      expect(status.isOffline, isTrue);
      expect(status.message, 'Offline — showing saved data');
    });

    test('a cache-served snapshot is offline even with nothing pending', () {
      // The captive-portal case: the device is associated with wifi, so
      // connectivity_plus would say "online", but no snapshot is reaching us.
      expect(connectionStatusFrom(isFromCache: true, pendingCount: 0).isOffline, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd frontend && flutter test test/presentation/widgets/connection_status_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:frontend/presentation/widgets/connection_status.dart'`.

- [ ] **Step 3: Add `MatchesView` and `watchMatchesView` to the repository**

In `frontend/lib/data/repositories/firestore_repository.dart`, add this class above `class FirestoreRepository`:

```dart
/// A snapshot of an event's matches plus whether it came from the local cache.
///
/// `isFromCache` is Firestore's own answer to "am I reaching the server?" — it
/// is true when the stream is not live, including on a captive-portal network
/// where the device is associated with wifi but nothing gets through.
class MatchesView {
  final List<MatchReport> matches;
  final bool isFromCache;

  const MatchesView({required this.matches, required this.isFromCache});
}
```

Then add this method to `FirestoreRepository`, and rewrite `watchMatches` to derive from it so a screen showing both the list and the status opens only one listener:

```dart
  /// Watches matches along with the snapshot metadata needed for connection
  /// status. Uses `includeMetadataChanges` so an online/offline transition
  /// emits even when no document changed.
  Stream<MatchesView> watchMatchesView(String eventId) {
    return _matchesQuery(eventId, isDeleted: false)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => MatchesView(
            matches: snapshot.docs
                .map((doc) => MatchReport.fromFirestore(doc))
                .toList(),
            isFromCache: snapshot.metadata.isFromCache,
          ),
        );
  }

  @override
  Stream<List<MatchReport>> watchMatches(String eventId) {
    return watchMatchesView(eventId).map((view) => view.matches);
  }
```

Delete the previous `watchMatches` body (lines 27-36) — it is replaced by the version above.

- [ ] **Step 4: Create the connection status file**

Create `frontend/lib/presentation/widgets/connection_status.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/firestore_repository.dart';
import '../../data/repositories/providers.dart';
import '../providers/event_providers.dart';

/// What the app can honestly say about its connection.
///
/// Derived from Firestore snapshot metadata rather than link-layer state:
/// `connectivity_plus` reports "wifi" whenever the device is associated with an
/// access point, which is true on a captive portal that blocks every request.
class ConnectionStatus {
  final bool isOffline;
  final int pendingCount;

  const ConnectionStatus({required this.isOffline, required this.pendingCount});

  bool get isFullySynced => !isOffline && pendingCount == 0;

  String get message {
    final noun = pendingCount == 1 ? 'report' : 'reports';
    if (isOffline) {
      if (pendingCount == 0) return 'Offline — showing saved data';
      return 'Offline — $pendingCount $noun saved on this device';
    }
    if (pendingCount == 0) return 'All reports uploaded';
    return 'Uploading $pendingCount $noun…';
  }
}

ConnectionStatus connectionStatusFrom({
  required bool isFromCache,
  required int pendingCount,
}) {
  return ConnectionStatus(isOffline: isFromCache, pendingCount: pendingCount);
}

/// The single matches subscription for the active event. Both the match list
/// and the connection status read from this, so only one listener is open.
final matchesViewProvider = StreamProvider<MatchesView>((ref) {
  final eventId = ref.watch(currentEventIdProvider);
  return ref.watch(firestoreRepositoryProvider).watchMatchesView(eventId);
});

/// Connection status for the active event.
///
/// Known bound: pending writes are counted only across the current event's
/// matches, because that is the query we already subscribe to. A report saved
/// against a different event is not counted. Scouts work one event at a time.
final connectionStatusProvider = Provider<ConnectionStatus>((ref) {
  final view = ref.watch(matchesViewProvider);
  return view.maybeWhen(
    data: (v) => connectionStatusFrom(
      isFromCache: v.isFromCache,
      pendingCount: v.matches.where((m) => !m.isSynced).length,
    ),
    orElse: () => const ConnectionStatus(isOffline: false, pendingCount: 0),
  );
});

/// A full-width bar shown above the dashboard content. Hidden entirely when
/// everything is uploaded — no chrome for the happy path.
class ConnectionStatusBar extends ConsumerWidget {
  const ConnectionStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    if (status.isFullySynced) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final background = status.isOffline
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foreground = status.isOffline
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                status.isOffline ? Icons.cloud_off : Icons.cloud_upload,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact indicator for the app bar. Shows nothing when fully synced.
class ConnectionStatusChip extends ConsumerWidget {
  final bool compact;

  const ConnectionStatusChip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    if (status.isFullySynced) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final color = status.isOffline ? colorScheme.error : colorScheme.primary;
    final icon = status.isOffline ? Icons.cloud_off : Icons.cloud_upload;

    if (compact) {
      return Tooltip(
        message: status.message,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (status.pendingCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '${status.pendingCount}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color),
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          status.message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
```

There is deliberately no force-sync button: Firestore flushes its queue when the stream recovers, and a button implying the user can hurry that along is exactly how the old UI misled.

- [ ] **Step 5: Run the status tests**

Run: `cd frontend && flutter test test/presentation/widgets/connection_status_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Swap the widgets in the dashboard**

In `frontend/lib/presentation/screens/dashboard.dart`, replace the `sync_status_indicator.dart` import with `../widgets/connection_status.dart`, then:

- line 210: `const SyncStatusBar(),` → `const ConnectionStatusBar(),`
- line 227: `child: Center(child: SyncStatusIndicator(compact: true)),` → `child: Center(child: ConnectionStatusChip(compact: true)),`

- [ ] **Step 7: Delete the old sync UI and its test**

```bash
cd frontend
git rm lib/presentation/widgets/sync_status_indicator.dart
git rm test/widgets/sync_status_indicator_test.dart
```

The test file is deleted rather than ported: both of its cases assert on pending counts sourced from the `SyncManager` queue, which no longer exists. Its replacement coverage is the pure-function suite from Step 1.

- [ ] **Step 8: Verify the app compiles and the suite passes**

Run: `cd frontend && flutter analyze && flutter test`
Expected: `No issues found!` and 339 tests passing (335 + 6 new − 2 deleted; the deleted file has exactly 2 tests).

`sync_manager.dart` and `HybridRepository` still exist at this point and are still expected to analyze cleanly — they are simply unreferenced by the UI now. Task 6 deletes them.

- [ ] **Step 9: Commit**

```bash
cd frontend && git add -A lib/ test/
git commit -m "feat(ui): derive connection status from firestore"
```

---

### Task 6: The cut — delete Drift and the sync queue

Nothing references these files any more. This is the subtraction the whole step exists for: roughly 6,100 lines including the 4,117-line generated Drift file.

**Files:**
- Delete: `frontend/lib/data/repositories/hybrid_repository.dart`
- Delete: `frontend/lib/data/local/sync/sync_manager.dart`
- Delete: `frontend/lib/data/local/database/` (entire directory: `app_database.dart`, `app_database.g.dart`, `tables.dart`, `connection/native.dart`, `connection/web.dart`, `connection/unsupported.dart`)
- Modify: `frontend/pubspec.yaml` (drop the Drift deps **and** `connectivity_plus`)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing. This task only removes.

**Note:** Task 5 already removed the last import of `sync_manager.dart`, so this deletion should leave a fully compiling tree. `flutter analyze` must come back completely clean — any error here means a live reference to the deleted code was missed, not an expected transient break.

- [ ] **Step 1: Delete the files**

```bash
cd frontend
git rm lib/data/repositories/hybrid_repository.dart
git rm lib/data/local/sync/sync_manager.dart
git rm -r lib/data/local/database/
```

- [ ] **Step 2: Remove the Drift dependencies**

In `frontend/pubspec.yaml`, delete these three lines from `dependencies` (lines 51-53):

```yaml
  drift: ^2.21.0
  drift_flutter: ^0.2.0
  sqlite3_flutter_libs: ^0.5.24
```

and this line from `dev_dependencies` (line 74):

```yaml
  drift_dev: ^2.21.0
```

Also delete `connectivity_plus` from `dependencies` (line 54) — `sync_manager.dart:5` was its only import site, and that file is now gone:

```yaml
  connectivity_plus: ^6.0.3
```

- [ ] **Step 3: Resolve dependencies**

Run: `cd frontend && flutter pub get`
Expected: succeeds, removing the drift/sqlite/connectivity packages.

- [ ] **Step 4: Verify the tree is clean and the suite still passes**

Run: `cd frontend && flutter analyze && flutter test`
Expected: `No issues found!` and 339 tests passing — unchanged from Task 5, because this task deletes only unreferenced code and no tests.

Any analyze error means a live reference to the deleted code was missed. Investigate rather than patching around it.

- [ ] **Step 5: Confirm the deleted symbols are gone**

Run: `cd frontend && grep -rn "drift\|Drift\|SyncManager\|hybridRepository\|connectivity_plus" lib/`
Expected: **no output.**

- [ ] **Step 6: Commit**

```bash
cd frontend && git add -A pubspec.yaml pubspec.lock lib/
git commit -m "refactor(db): delete drift and the sync queue"
```

---

### Task 7: Consolidate the dashboard onto one stream

The dashboard currently holds a manually-managed `Stream` field that it tears down and rebuilds in three places, and separately re-fetches with `getMatches()` at three more. Under a throttled network that is repeated full re-reads competing with a live listener. `matchesViewProvider` from Task 5 already subscribes once — everything reads from it.

**Files:**
- Modify: `frontend/lib/presentation/screens/dashboard.dart` (lines 33, 36-40, 47-53, 58, 107, 190-197, 235)

**Interfaces:**
- Consumes: `matchesViewProvider` (`StreamProvider<MatchesView>`) from Task 5.
- Produces: nothing.

- [ ] **Step 1: Delete the manual stream field and its lifecycle**

In `frontend/lib/presentation/screens/dashboard.dart`:

- Delete the field at line 33: `late Stream<List<MatchReport>> _matchesStream;`
- Delete the entire `initState` override (lines 35-40) — the provider handles subscription.
- In `_openSettings` (lines 47-53), delete the `.then((_) { ... setState ... })` callback that rebuilt the stream. The provider re-watches `currentEventIdProvider` automatically, so an event change already re-subscribes.

- [ ] **Step 2: Replace the stream consumer in `build`**

The `StreamBuilder<List<MatchReport>>` is at line 405, fed by `stream: _matchesStream` at line 406. Replace it with a watch on the provider. The provider yields `MatchesView`, so read `.matches` from it:

```dart
    final matchesAsync = ref.watch(matchesViewProvider);

    return matchesAsync.when(
      data: (view) => _buildMatchList(context, view.matches),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load matches: $error')),
    );
```

Move the existing `StreamBuilder`'s `builder` body verbatim into a new `_buildMatchList(BuildContext context, List<MatchReport> matches)` method, substituting its `snapshot.data` references with the `matches` parameter. Do not rewrite the list rendering — it is out of scope, and `dashboard.dart` is slated for a proper split in Step 4. Only the data source changes here.

Note the existing `StreamBuilder` also handles its own loading and error branches; those are now handled by `.when` above, so drop the duplicates from the moved body.

- [ ] **Step 3: Make pull-to-refresh invalidate the provider**

Replace the body of `_onRefresh` (lines 190-197):

```dart
  Future<void> _onRefresh() async {
    AppHaptics.medium();
    ref.invalidate(matchesViewProvider);
  }
```

The artificial `Future.delayed(500ms)` goes away — it existed to give the manually-rebuilt stream time to emit.

- [ ] **Step 4: Serve export and search from the existing subscription**

Three call sites fetch a fresh copy purely to hand a list to a sheet or a search delegate: `_showExportOptions` (line 58), `_exportCsv` (line 107), and the search button (line 235). Each currently does:

```dart
    final matches = await ref.read(firestoreRepositoryProvider).getMatches(eventId);
```

Replace each with a read of the already-subscribed data:

```dart
    final matches = ref.read(matchesViewProvider).value?.matches ?? const <MatchReport>[];
```

The surrounding `if (matches.isEmpty)` guards already handle the empty case, so a not-yet-loaded provider degrades to the existing "No matches to export." path. The enclosing methods may no longer need `async`/`eventId` — let `flutter analyze` flag unused locals and remove them.

- [ ] **Step 5: Confirm the redundant reads are gone**

Run: `cd frontend && grep -n "getMatches\|_matchesStream" lib/presentation/screens/dashboard.dart`
Expected: **no output.**

- [ ] **Step 6: Verify**

Run: `cd frontend && flutter analyze && flutter test`
Expected: `No issues found!` and 339 tests passing.

- [ ] **Step 7: Commit**

```bash
cd frontend && git add lib/presentation/screens/dashboard.dart
git commit -m "perf(ui): read dashboard matches from one stream"
```

---

### Task 8: Update the documentation

`CLAUDE.md` currently describes an offline-first Drift architecture that no longer exists, and instructs future sessions to run Drift codegen. Leaving it stale would send the next session down a deleted path.

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-07-21-simplification-roadmap.md`
- Delete: `.claude/agents/drift-migration-reviewer.md`
- Modify: `.claude/agents/sync-logic-reviewer.md`

**Interfaces:** none.

- [ ] **Step 1: Update `CLAUDE.md`**

Make these edits:

- Under **Frontend Architecture**, replace the "offline-first pattern" bullet with: `**Single store**: Firestore is the only data store, with its own on-disk persistence (`persistenceEnabled`, unlimited cache) providing offline support. There is no local SQLite database and no sync queue — writes go straight to Firestore, which queues them durably on disk when the network is unreachable.`
- Delete the **Key Technical Details** bullet beginning "Drift database requires code generation".
- Delete the bullet "Drift SQLite has 4 tables: LocalMatchReports, LocalEvents, SyncQueue, SyncConflicts".
- Delete the bullet "SyncManager runs periodic sync every 5 minutes with exponential backoff retry (max 5 attempts)".
- In **Testing**, change "currently 292 tests" to the count Task 7 finished with (expected **339**; use the real number from `flutter test`, since 292 was already stale by 16 before this branch started). Note that repository tests use `fake_cloud_firestore`.
- Add a bullet under **Key Technical Details**: `**Connection status comes from Firestore snapshot metadata** (`isFromCache`, `hasPendingWrites`), never from `connectivity_plus`. Link-layer state reports "wifi" on a captive portal that blocks all traffic — which is the venue failure mode we actually face.`

- [ ] **Step 2: Retire and retarget the reviewer agents**

`.claude/agents/` contains `drift-migration-reviewer.md`, `security-reviewer.md`, and `sync-logic-reviewer.md`. Two need attention:

```bash
cd /home/varun/Documents/SushiScout26 && git rm .claude/agents/drift-migration-reviewer.md
```

It reviews Drift schema changes and migrations for tables that no longer exist.

Then edit `.claude/agents/sync-logic-reviewer.md`: its description still names "SyncManager, hybrid_repository" and "the Firestore offline sync queue" as review targets. Narrow it to what remains — the Firestore → Google Sheets one-way export (`on_match_written`, `sheets_service`) — and drop the frontend sync-queue references.

Finally, `grep -rn "drift-migration-reviewer" /home/varun/Documents/SushiScout26 --include=*.md` and remove any lingering references.

- [ ] **Step 3: Mark Step 3 shipped in the roadmap**

In `docs/superpowers/specs/2026-07-21-simplification-roadmap.md`, update §6 to record the outcome, following the format §5 uses for Step 2:

- Change the heading to `## 6. Step 3 — Collapse to a single offline store — **DONE (implemented 2026-07-22)**`, linking the design and this plan.
- Record that shape 1 (Firestore-only) was chosen, and why the read-cache hedge was rejected: Drift is equally empty on a cold start, and a QR escape hatch can enumerate unsynced docs via `Source.cache` + `hasPendingWrites` without it.
- Correct the code-reduction figure: ~42% of total lines, but ~22% of hand-written lines — the 40–50% estimate counted the 4,117-line generated Drift file.
- Note the two defects found in code being deleted: `connectivity_plus` treating access-point association as internet reachability, and the batch-abort/nested-backoff interaction at `sync_manager.dart:424`.

- [ ] **Step 4: Record the QR trip-wire**

In the same file, update §8's closing paragraph to record the resolution rather than leaving it as an open question:

> **Resolved 2026-07-22.** Venue wifi is almost always technically present but unreliable in three ways: captive-portal login we lack, competition-day throttling, and random outages. All three are "the socket does not work," which Firestore's persistence handles by design. Step 3 committed to cloud-live-sync. **Trip-wire:** if a competition produces reports that never land, or scouts cannot authenticate past a portal, QR aggregation gets its own brainstorm — with real data on which failure mode actually bit. Operational precondition: scouts must install and sign in before leaving for the venue, because a portal that blocks login defeats any storage architecture.

- [ ] **Step 5: Commit**

```bash
cd /home/varun/Documents/SushiScout26
git add CLAUDE.md docs/superpowers/specs/2026-07-21-simplification-roadmap.md .claude/
git commit -m "docs: record step 3 single offline store"
```

---

## Final verification (before the whole-branch review)

- [ ] `cd frontend && flutter analyze` → `No issues found!`
- [ ] `cd frontend && flutter test` → all passing, count matches what `CLAUDE.md` now claims
- [ ] `cd functions && ./venv/bin/python -m pytest tests/` → 56 passing (untouched by this branch; confirms no accidental backend change)
- [ ] `grep -rn "drift\|Drift\|SyncManager\|hybridRepository\|connectivity_plus" frontend/lib/` → no output
- [ ] `git diff master --stat` → net deletion of roughly 6,100 lines

## Manual end-to-end verification (required before merge — user present)

Roadmap §5 lesson 2: mocked tests cannot validate an external system. A green suite does **not** prove Firestore's offline queue behaves. Do this on a real device or desktop build, not `-d web-server`.

- [ ] Build and launch: `cd frontend && flutter run -d <device>` (or `flutter build web --release` + a static server)
- [ ] Sign in and select an event while online. Confirm the status bar is hidden (fully synced).
- [ ] Enable airplane mode. Submit two match reports.
- [ ] Confirm the status bar reads **"Offline — 2 reports saved on this device"** and the app-bar chip shows `2`.
- [ ] Confirm both reports appear in the match list while still offline.
- [ ] Force-quit and relaunch the app, still offline. Confirm both reports survive — this is the durability claim the whole step rests on.
- [ ] Disable airplane mode. Confirm the status bar clears within a few seconds.
- [ ] Confirm both reports are in Firestore, and that `on_match_written` exported both rows to the team's Google Sheet.
- [ ] Trash a report offline, then reconnect, and confirm the trash state propagates.

**Known coverage gap, stated rather than papered over:** airplane mode tests "no socket." It does not test a captive portal — "a socket that lies," the failure mode the user named as most likely. The closest cheap proxy is joining a network with no internet egress; if one is available, repeat the offline steps on it. We do not have honest coverage of that case short of a real venue.

**Do not deploy.** Nothing ships without the user present.
