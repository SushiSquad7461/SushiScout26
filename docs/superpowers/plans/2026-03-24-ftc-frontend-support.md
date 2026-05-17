# FTC Frontend Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a program type selector (FRC/FTC) to the settings UI and FTC match schedule fetching via the FIRST Tech Challenge Events API.

**Architecture:** SharedPreferences stores the user's program type choice (default FRC). Firestore is authoritative — if an event exists with a different programType, the local preference silently syncs to match. A new Cloud Function (`fetch_ftc_schedule`) mirrors the existing `fetch_event_schedule` pattern for FTC schedule fetching. A Flutter `ScheduleService` wraps both callable functions.

**Tech Stack:** Flutter/Dart (Riverpod, SharedPreferences, cloud_functions), Python 3.11 (Firebase Cloud Functions, FIRST Events API)

**Spec:** `docs/superpowers/specs/2026-03-24-ftc-frontend-support-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `frontend/lib/data/local/preferences.dart` | Add `programType` key + getter/setter |
| Modify | `frontend/lib/presentation/screens/dashboard.dart` | Settings toggle, FAB fallback, Firestore sync |
| Modify | `frontend/lib/data/repositories/firestore_repository.dart` | `_getOrCreateEvent` accepts programType param; callers pass `match.programType` |
| Modify | `frontend/lib/presentation/screens/frc_rebuilt_form.dart` | Optional schedule fetch button on match info page |
| Modify | `frontend/lib/presentation/screens/ftc_decode_form.dart` | Optional schedule fetch button on match info page |
| Modify | `frontend/pubspec.yaml` | Add `cloud_functions` dependency |
| Create | `frontend/lib/data/services/schedule_service.dart` | Cloud Functions wrapper for FRC/FTC schedule fetching |
| Create | `functions/ftc_api.py` | FIRST Events API client + `fetch_ftc_schedule` callable |
| Modify | `functions/main.py` | Register `fetch_ftc_schedule` |

---

### Task 1: Add `programType` to preferences

**Files:**
- Modify: `frontend/lib/data/local/preferences.dart`

- [ ] **Step 1: Add programType key and setter**

Add to `PrefKeys` class (after line 12):

```dart
static const String programType = 'program_type';
```

Add to `SettingsNotifier.build()` return map (after `fuelIncrement` entry at line 34):

```dart
PrefKeys.programType: _prefs.getString(PrefKeys.programType) ?? 'FRC',
```

Add setter method (after `setFuelIncrement` at line 66):

```dart
Future<void> setProgramType(String value) async {
  await _prefs.setString(PrefKeys.programType, value);
  state = {...state, PrefKeys.programType: value};
}
```

- [ ] **Step 2: Verify no compile errors**

Run: `cd frontend && flutter analyze lib/data/local/preferences.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/data/local/preferences.dart
git commit -m "feat(frontend): add programType to SharedPreferences"
```

---

### Task 2: Add FRC/FTC toggle to settings dialog

**Files:**
- Modify: `frontend/lib/presentation/screens/dashboard.dart:855-899` (inside `_SettingsSheetState.build()`)

- [ ] **Step 1: Add SegmentedButton between event code and appearance section**

Note: `_SettingsSheet` is a `ConsumerStatefulWidget` (line 812) and `_SettingsSheetState extends ConsumerState` (line 819), so `ref` is available.

In `_SettingsSheetState.build()`, replace the `SizedBox(height: AppTheme.spacingLg)` at line 899 (between the event code field closing `)` at line 897 and the Appearance section at line 901) with the program type toggle plus the original spacer:

```dart
const SizedBox(height: AppTheme.spacingMd),

Text(
  "Program Type",
  style: theme.textTheme.labelLarge?.copyWith(
    color: colorScheme.onSurfaceVariant,
  ),
),
const SizedBox(height: AppTheme.spacingSm),
SegmentedButton<String>(
  segments: const [
    ButtonSegment(
      value: 'FRC',
      label: Text('FRC'),
    ),
    ButtonSegment(
      value: 'FTC',
      label: Text('FTC'),
    ),
  ],
  selected: {ref.watch(settingsProvider)[PrefKeys.programType] ?? 'FRC'},
  onSelectionChanged: (selection) {
    ref.read(settingsProvider.notifier).setProgramType(selection.first);
  },
),
```

- [ ] **Step 2: Verify no compile errors**

Run: `cd frontend && flutter analyze lib/presentation/screens/dashboard.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/presentation/screens/dashboard.dart
git commit -m "feat(ui): add FRC/FTC program type toggle to settings"
```

---

### Task 3: Wire programType into dashboard FAB + Firestore sync

**Files:**
- Modify: `frontend/lib/presentation/screens/dashboard.dart:496-533` (FAB onPressed handler)

- [ ] **Step 1: Update FAB to use programType preference as fallback**

Replace the FAB `onPressed` handler (lines 496-533). The dummy event should use the preference instead of hardcoding `"FRC"`. When an event IS found from Firestore/local, sync the local preference to match:

```dart
onPressed: () async {
  AppHaptics.medium();
  final eventCode =
      ref.read(settingsProvider)[PrefKeys.eventCode] ?? "Unknown";
  final programType =
      ref.read(settingsProvider)[PrefKeys.programType] ?? "FRC";
  final event = await ref.read(hybridRepositoryProvider).getEvent(eventCode);

  if (!mounted) return;

  if (event == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Event '$eventCode' not found. Defaulting to $programType.",
        ),
      ),
    );
    final dummyEvent = Event(
      id: eventCode,
      name: "Dummy/Offline Event",
      programType: programType,
      tbaKey: eventCode,
      startDate: DateTime.now(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScoutingFormFactory.create(dummyEvent),
      ),
    );
    return;
  }

  // Firestore-wins: sync local preference to match event
  if (event.programType != programType) {
    ref.read(settingsProvider.notifier).setProgramType(event.programType);
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ScoutingFormFactory.create(event),
    ),
  );
},
```

- [ ] **Step 2: Verify no compile errors**

Run: `cd frontend && flutter analyze lib/presentation/screens/dashboard.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/presentation/screens/dashboard.dart
git commit -m "feat(frontend): use programType preference in FAB with Firestore-wins sync"
```

---

### Task 4: Update `_getOrCreateEvent` to accept programType parameter

**Files:**
- Modify: `frontend/lib/data/repositories/firestore_repository.dart:81-104`

- [ ] **Step 1: Add programType parameter to `_getOrCreateEvent`**

Change the method signature and the hardcoded `'FRC'` in auto-creation:

```dart
/// Gets the event's programType, creating the event document if needed.
/// Combines getEvent + ensureEventExists into a single read to avoid double-reads.
/// [fallbackProgramType] is used when auto-creating a new event.
Future<String> _getOrCreateEvent(String eventId, {String fallbackProgramType = 'FRC'}) async {
  try {
    final eventDoc = _firestore.collection('events').doc(eventId);
    final docSnapshot = await eventDoc.get();

    if (docSnapshot.exists) {
      return Event.fromFirestore(docSnapshot).programType;
    }

    _logger.i('Auto-creating event $eventId in Firestore');
    await eventDoc.set({
      'name': eventId,
      'programType': fallbackProgramType,
      'tbaKey': eventId,
      'startDate': Timestamp.fromDate(DateTime.now()),
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'autoCreated': true,
    }, SetOptions(merge: true));
    return fallbackProgramType;
  } catch (e, stackTrace) {
    _logger.e('Failed to get or create event', error: e, stackTrace: stackTrace);
    rethrow;
  }
}
```

- [ ] **Step 2: Update callers to pass `match.programType`**

In `createMatch` (line 58), change:
```dart
final programType = await _getOrCreateEvent(eventId);
```
to:
```dart
final programType = await _getOrCreateEvent(eventId, fallbackProgramType: match.programType);
```

In `updateMatch` (line 110), change:
```dart
final programType = await _getOrCreateEvent(eventId);
```
to:
```dart
final programType = await _getOrCreateEvent(eventId, fallbackProgramType: match.programType);
```

This ensures that when `SyncManager` queues a match created under FTC, the auto-created event document gets `programType: 'FTC'` instead of always defaulting to `'FRC'`. The `match.programType` is already set correctly by `HybridRepository._toMatchReport()` based on the gameData heuristic.

- [ ] **Step 3: Verify no compile errors**

Run: `cd frontend && flutter analyze lib/data/repositories/firestore_repository.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/data/repositories/firestore_repository.dart
git commit -m "feat(db): wire programType through _getOrCreateEvent callers"
```

---

### Task 5: Create FTC schedule Cloud Function

**Files:**
- Create: `functions/ftc_api.py`

- [ ] **Step 1: Create `functions/ftc_api.py`**

```python
"""FTC event schedule sync via FIRST Tech Challenge Events API."""

from firebase_functions import https_fn, logger
from firebase_admin import firestore
import requests
import os
from datetime import datetime, timedelta

_db = None

CACHE_TTL_HOURS = 24


def _get_db():
    """Get Firestore client with lazy initialization."""
    global _db
    if _db is None:
        _db = firestore.client()
    return _db


def _get_ftc_season():
    """Derive the FTC season year from the current date.

    FTC seasons start in September. Events from Jan-Aug belong to
    the season that started the previous September.
    """
    now = datetime.now()
    return now.year if now.month >= 9 else now.year - 1


@https_fn.on_call(secrets=["FTC_API_USERNAME", "FTC_API_KEY"])
def fetch_ftc_schedule(req: https_fn.CallableRequest) -> dict:
    """Fetch FTC match schedule from the FIRST Tech Challenge Events API.

    Input: { "eventCode": "USNYEXCL" }
    Returns: { "success": True, "count": N, "cached": bool }
    Schedule data is written to Firestore, not returned inline.
    """
    event_code = req.data.get("eventCode")
    if not event_code:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Missing eventCode",
        )

    db = _get_db()
    cache_ref = db.collection("ftc_cache").document(event_code)
    cached = cache_ref.get()

    if cached.exists:
        cached_data = cached.to_dict()
        cached_at = cached_data.get("cachedAt")
        matches = cached_data.get("matches", [])

        if cached_at and matches:
            cache_age = (
                datetime.now(cached_at.tzinfo) - cached_at
                if cached_at.tzinfo
                else datetime.utcnow() - cached_at.replace(tzinfo=None)
            )
            if cache_age < timedelta(hours=CACHE_TTL_HOURS):
                logger.info(
                    f"Using cached FTC data for {event_code} (age: {cache_age})"
                )
                return {"success": True, "count": len(matches), "cached": True}

    username = os.environ.get("FTC_API_USERNAME")
    api_key = os.environ.get("FTC_API_KEY")

    if not username or not api_key:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="FTC_API_USERNAME or FTC_API_KEY secret not configured",
        )

    season = _get_ftc_season()
    url = f"https://ftc-api.firstinspires.org/v2.0/{season}/schedule/{event_code}"
    resp = requests.get(url, auth=(username, api_key), params={"tournamentLevel": "qual"})

    if resp.status_code != 200:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAVAILABLE,
            message=f"FTC API Error: {resp.status_code}",
        )

    data = resp.json()
    matches = data.get("schedule", [])

    batch = db.batch()
    count = 0

    for m in matches:
        match_number = m.get("matchNumber", 0)
        match_id = f"{event_code}_qm{match_number}"
        teams = m.get("teams", [])

        match_doc = {
            "matchId": match_id,
            "matchNumber": match_number,
            "compLevel": "qm",
            "teams": teams,
            "startTime": m.get("startTime"),
            "programType": "FTC",
            "eventId": event_code,
        }

        doc_ref = db.collection("matches").document(match_id)
        batch.set(doc_ref, match_doc, merge=True)
        count += 1

        if count >= 400:
            batch.commit()
            batch = db.batch()
            count = 0

    if count > 0:
        batch.commit()

    cache_ref.set(
        {
            "matches": matches,
            "cachedAt": firestore.SERVER_TIMESTAMP,
            "eventCode": event_code,
            "matchCount": len(matches),
        }
    )

    logger.info(f"Cached FTC data for {event_code}: {len(matches)} matches")

    return {"success": True, "count": len(matches), "cached": False}
```

- [ ] **Step 2: Verify syntax**

Run: `cd functions && python -c "import ast; ast.parse(open('ftc_api.py').read()); print('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add functions/ftc_api.py
git commit -m "feat(backend): add FTC schedule fetching via FIRST Events API"
```

---

### Task 6: Register `fetch_ftc_schedule` in main.py

**Files:**
- Modify: `functions/main.py:13`

- [ ] **Step 1: Add import**

After line 13 (`from tba_sync import fetch_event_schedule`), add:

```python
from ftc_api import fetch_ftc_schedule  # noqa: E402, F401
```

- [ ] **Step 2: Verify syntax**

Run: `cd functions && python -c "import ast; ast.parse(open('main.py').read()); print('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add functions/main.py
git commit -m "feat(backend): register fetch_ftc_schedule in main"
```

---

### Task 7: Add `cloud_functions` dependency + create `ScheduleService`

**Files:**
- Modify: `frontend/pubspec.yaml`
- Create: `frontend/lib/data/services/schedule_service.dart`

- [ ] **Step 1: Add cloud_functions to pubspec.yaml**

Add after `cloud_firestore: ^6.1.1` (line 46):

```yaml
  cloud_functions: ^5.3.3
```

- [ ] **Step 2: Install dependency**

Run: `cd frontend && flutter pub get`
Expected: Resolves dependencies successfully

- [ ] **Step 3: Create schedule_service.dart**

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService();
});

/// Wraps callable Cloud Functions for FRC and FTC schedule fetching.
class ScheduleService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Logger _logger = const Logger('SCHEDULE');

  /// Fetch match schedule for the given event.
  /// Returns `{success, count, cached}` on success, or throws.
  Future<Map<String, dynamic>> fetchSchedule({
    required String eventCode,
    required String programType,
  }) async {
    final functionName =
        programType == 'FTC' ? 'fetch_ftc_schedule' : 'fetch_event_schedule';
    final paramKey = programType == 'FTC' ? 'eventCode' : 'eventKey';

    _logger.i('Fetching $programType schedule for $eventCode');

    try {
      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call<Map<String, dynamic>>({paramKey: eventCode});
      final data = Map<String, dynamic>.from(result.data);
      _logger.i('Schedule fetch result: $data');
      return data;
    } on FirebaseFunctionsException catch (e) {
      _logger.e('Schedule fetch failed', error: e);
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Verify no compile errors**

Run: `cd frontend && flutter analyze lib/data/services/schedule_service.dart`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add frontend/pubspec.yaml frontend/lib/data/services/schedule_service.dart
git commit -m "feat(frontend): add cloud_functions dep and ScheduleService"
```

---

### Task 8: Add schedule fetch + match picker to scouting forms

**Files:**
- Modify: `frontend/lib/presentation/screens/frc_rebuilt_form.dart:40-44` (match info fields)
- Modify: `frontend/lib/presentation/screens/ftc_decode_form.dart:40-44` (match info fields)

Both forms have the same match info page structure: `_matchNumberCtrl`, `_teamNumberCtrl`, `_alliance`, `_scouterNameCtrl`. We add a "Load Schedule" button that fetches the schedule (if not cached) then shows a bottom sheet of matches to pick from. Tapping a match auto-fills the match number and team number fields. Manual entry remains the primary input and fallback.

- [ ] **Step 1: Add schedule fetch + picker to FRC form**

In `_FrcRebuiltFormState`, add imports at the top of the file:

```dart
import '../../data/services/schedule_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
```

Add a helper method to `_FrcRebuiltFormState`:

```dart
Future<void> _loadSchedule() async {
  final settings = ref.read(settingsProvider);
  final eventCode = settings[PrefKeys.eventCode] ?? '';
  final programType = settings[PrefKeys.programType] ?? 'FRC';
  if (eventCode.isEmpty) return;

  // Fetch schedule (writes to Firestore, uses cache if fresh)
  try {
    await ref.read(scheduleServiceProvider).fetchSchedule(
      eventCode: eventCode,
      programType: programType,
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch schedule. Enter match details manually.')),
      );
    }
    return;
  }

  if (!mounted) return;

  // Read schedule entries from Firestore for this event
  final snapshot = await FirebaseFirestore.instance
      .collection('matches')
      .where('eventId', isEqualTo: eventCode)
      .where('programType', isEqualTo: programType)
      .orderBy('matchNumber')
      .get();

  final scheduleMatches = snapshot.docs
      .map((doc) => doc.data())
      .where((d) => d['compLevel'] != null) // schedule entries have compLevel
      .toList();

  if (!mounted) return;

  if (scheduleMatches.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No schedule found. Enter match details manually.')),
    );
    return;
  }

  // Show bottom sheet picker
  showModalBottomSheet(
    context: context,
    builder: (ctx) => ListView.builder(
      itemCount: scheduleMatches.length,
      itemBuilder: (ctx, i) {
        final m = scheduleMatches[i];
        final matchNum = m['matchNumber'] ?? 0;
        final alliances = m['alliances'] as Map<String, dynamic>?;
        final teams = m['teams'] as List<dynamic>?;
        // Build a display string based on available data
        String subtitle = '';
        if (alliances != null) {
          final red = (alliances['red']?['team_keys'] as List?)?.join(', ') ?? '';
          final blue = (alliances['blue']?['team_keys'] as List?)?.join(', ') ?? '';
          subtitle = 'Red: $red | Blue: $blue';
        } else if (teams != null) {
          subtitle = teams.map((t) => '${t['teamNumber']}').join(', ');
        }
        return ListTile(
          title: Text('Match $matchNum'),
          subtitle: subtitle.isNotEmpty ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
          onTap: () {
            _matchNumberCtrl.text = '$matchNum';
            Navigator.pop(ctx);
          },
        );
      },
    ),
  );
}
```

In the match info page build method (the first page of the PageView), add a "Load Schedule" `OutlinedButton` below the scouter name field:

```dart
const SizedBox(height: AppTheme.spacingMd),
OutlinedButton.icon(
  icon: const Icon(Icons.calendar_month_rounded),
  label: const Text('Load Schedule'),
  onPressed: _loadSchedule,
),
```

- [ ] **Step 2: Add identical schedule picker to FTC form**

Apply the same pattern to `_FtcDecodeFormState` — add the imports, the `_loadSchedule()` method, and the `OutlinedButton.icon` widget. The method body is identical since `ScheduleService` handles the FRC/FTC routing internally based on programType.

- [ ] **Step 3: Verify no compile errors**

Run: `cd frontend && flutter analyze lib/presentation/screens/frc_rebuilt_form.dart lib/presentation/screens/ftc_decode_form.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/presentation/screens/frc_rebuilt_form.dart frontend/lib/presentation/screens/ftc_decode_form.dart
git commit -m "feat(ui): add schedule fetch and match picker to scouting forms"
```

---

### Task 9: Integration smoke test

- [ ] **Step 1: Run full frontend analysis**

Run: `cd frontend && flutter analyze`
Expected: No new issues introduced (pre-existing warnings may appear)

- [ ] **Step 2: Run existing tests**

Run: `cd frontend && flutter test`
Expected: Pre-existing test failures only (scripts_test.dart, web_removal_test.dart). No new failures.

- [ ] **Step 3: Verify Python backend syntax**

Run: `cd functions && python -c "import ast; ast.parse(open('main.py').read()); ast.parse(open('ftc_api.py').read()); print('All OK')"`
Expected: `All OK`

- [ ] **Step 4: Final commit with all changes verified**

If any uncommitted fixes were needed during smoke testing, commit them:

```bash
git add -A
git commit -m "chore: fix smoke test issues from FTC frontend support"
```
