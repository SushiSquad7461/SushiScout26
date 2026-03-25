# Full FTC Frontend Support

## Problem

The app has complete FTC backend support (scouting form, match details, exports, Sheets sync) but no UI to select FRC vs FTC. Users must pre-create events in Firestore with the correct `programType`. FTC schedule fetching is also missing.

## Scope

Two changes:
1. Program type selector (FRC/FTC) in the settings UI
2. FTC match schedule fetching via the FIRST Tech Challenge Events API

### Out of Scope

- FTC scouting form changes (DECODE fields stay as-is)
- Match details, export service, Sheets sync (already handle FTC)
- FRC form or TBA integration changes

## Design

### 1. Program Type Selector

**Storage**: New `PrefKeys.programType` in SharedPreferences, defaulting to `'FRC'`.

**Settings UI**: `SegmentedButton` with FRC/FTC segments, placed between the event code field and the theme selector in the existing settings dialog.

**Behavior when tapping "Scout Match"**:
1. Dashboard looks up event from hybrid repo (local DB → Firestore fallback).
2. If event found: its `programType` is authoritative. Update the local preference to match (so the toggle reflects reality next time settings is opened).
3. If event not found (offline/new): use the preference value for the dummy event instead of hardcoding `'FRC'`.

**Event auto-creation**: `_getOrCreateEvent` in `firestore_repository.dart` accepts a `programType` parameter instead of hardcoding `'FRC'`. The caller passes the current preference value. This ensures auto-created Firestore events get the correct programType from the start, preventing the scenario where FTC matches are synced under an FRC event.

**Conflict resolution**: Firestore always wins. If user has FTC selected locally but Firestore event says FRC, the local preference silently flips to FRC. No error dialog needed.

### 2. FTC Schedule Fetching

**API**: FIRST Tech Challenge Events API (`https://ftc-api.firstinspires.org/v2.0/{season}/schedule/{eventCode}`). The `{season}` path segment is the competition year (e.g., `2026`). Derived from `datetime.now().year` on the backend, since FTC events don't embed the year in their event codes (unlike FRC's TBA keys).

**Authentication**: HTTP Basic Auth with username + API key. Two Firebase secrets required:
- `FTC_API_USERNAME` — FIRST account username
- `FTC_API_KEY` — API authorization key from firstinspires.org

This differs from TBA's single `X-TBA-Auth-Key` header because the FIRST API uses standard Basic Auth.

**Backend** — new callable Cloud Function `fetch_ftc_schedule`:
- Lives in `functions/ftc_api.py` (new file), registered in `functions/main.py`
- Same pattern as existing `fetch_event_schedule` in `tba_sync.py`
- Fetches match schedule for an FTC event code using the season year
- Caches responses in a dedicated `ftc_cache` Firestore collection with 24h TTL (separate from `tba_cache` to avoid naming confusion and key collisions between FRC/FTC namespaces)
- Returns `{"success": True, "count": N, "cached": bool}` — same response pattern as existing `fetch_event_schedule`. Schedule data is written to Firestore, not returned inline.

**Frontend** — new schedule service + `cloud_functions` dependency:
- Add `cloud_functions` package to `pubspec.yaml` (not currently a dependency)
- New `frontend/lib/data/services/schedule_service.dart` — wraps callable Cloud Functions for both FRC and FTC schedule fetching
- When `programType` is FTC, calls `fetch_ftc_schedule`; when FRC, calls `fetch_event_schedule`
- Both scouting forms gain optional schedule-populated dropdowns for match/team selection
- Manual entry fields (match number, team number) remain as primary input and fallback

Note: The existing `fetch_event_schedule` is also not currently called from the Flutter frontend. This work builds the Flutter → Cloud Functions integration layer for both program types.

### 3. Error Handling

| Scenario | Behavior |
|----------|----------|
| Firestore event programType differs from local toggle | Local preference silently updates to match Firestore |
| Offline, user creates FTC matches, then Firestore event is auto-created | Auto-created event uses the local preference (FTC), so matches and event stay consistent |
| FTC event code not found in FIRST API | Snackbar: "Could not fetch FTC schedule. Enter match details manually." |
| `FTC_API_USERNAME` or `FTC_API_KEY` not configured | `fetch_ftc_schedule` returns clear error. Frontend shows "FTC schedule fetching not configured", falls back to manual entry. |
| Offline, no cached schedule | Manual entry fallback (same as FRC when TBA unreachable) |
| Offline, cached schedule available | Works via Firestore unlimited cache |

### 4. Files Changed

**Frontend**:
- `frontend/pubspec.yaml` — add `cloud_functions` dependency
- `frontend/lib/data/local/preferences.dart` — add `programType` key + setter
- `frontend/lib/presentation/screens/dashboard.dart` — settings dialog toggle; FAB uses preference as fallback; syncs preference when Firestore event fetched
- `frontend/lib/data/repositories/firestore_repository.dart` — `_getOrCreateEvent` accepts programType parameter
- `frontend/lib/data/services/schedule_service.dart` (new) — Cloud Functions wrapper for FRC/FTC schedule fetching
- `frontend/lib/presentation/screens/frc_rebuilt_form.dart` — optional schedule dropdown integration
- `frontend/lib/presentation/screens/ftc_decode_form.dart` — optional schedule dropdown integration

**Backend**:
- `functions/ftc_api.py` (new) — FIRST Events API client + `fetch_ftc_schedule` callable
- `functions/main.py` — register `fetch_ftc_schedule`

**No changes to**:
- `match_details.dart`, `export_service.dart`, `sheets_service.py`, `tba_sync.py`

### 5. Known Limitations

- **programType not stored in LocalMatchReports**: The local SQLite table infers programType from gameData keys (checking for `artifacts_auto`). This heuristic works for DECODE but is fragile if FTC game field names change in the future. Adding a `programType` column to the Drift schema would be more robust but requires a schema migration and `build_runner` re-run. Deferred as a future improvement since the heuristic works correctly for the current DECODE game.
- **Season year derivation**: The backend derives the FTC season year from `datetime.now().year`. This works for the current season but will need adjustment for events that span year boundaries (e.g., kickoff in September, championships in April). A more robust approach would be `year if month >= 9 else year - 1`, which handles the typical FTC season calendar.
