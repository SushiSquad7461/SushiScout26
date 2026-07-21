# One-Way Per-Team Sheets Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Google Sheets a strictly one-way, per-team export — delete the Sheets→Firestore reverse path and the row-number tracker, and give each team its own spreadsheet.

**Architecture:** `on_match_written` and `backfill_event_to_sheets` resolve a target spreadsheet from `teamSettings/{teamId}.googleSheetId` (silently no-oping when unset) and find a report's row by searching the sheet itself rather than consulting a tracker collection. A new admin-only `set_team_sheet` callable validates and stores the sheet id. Everything supporting the reverse direction — two endpoints, the echo guard, the `lastSyncSource` stamp, `sync_tracker.py`, the `sync_tracking` collection, `SYNC_API_KEY`, `MASTER_SPREADSHEET_ID` — is deleted.

**Tech Stack:** Python 3.11 Firebase Cloud Functions (`firebase_functions`, `firebase_admin`, `googleapiclient`), Flutter/Dart with Riverpod, Firestore security rules, `unittest`/`pytest`, `flutter_test`, `@firebase/rules-unit-testing` + Jest.

**Spec:** [`docs/superpowers/specs/2026-07-21-sheets-one-way-export-design.md`](../specs/2026-07-21-sheets-one-way-export-design.md)

## Global Constraints

- **Python venv MUST be 3.11.** Run Python tests as `./venv/bin/python -m pytest tests/` from `functions/`. If the venv is missing: `uv python install 3.11 && uv venv functions/venv --python 3.11`.
- **Never hand-edit generated files** (`*.g.dart`, `*.mocks.dart`, `*.freezed.dart`). Run codegen instead. A hook blocks these edits.
- **Do not deploy anything** during Tasks 1–8. Deployment is Task 9 only, and only with the user present.
- **Commit after every task** using Conventional Commits: `<type>(<scope>): <subject>`, imperative mood, no capitalization, no trailing period, max 50 chars. Scopes used here: `backend`, `frontend`, `sync`, `test`, `config`.
- **Baseline test counts before starting:** 292 Dart tests, 56 Python tests, 16 rules tests. Tests are deleted in this plan (they cover deleted code), so counts will drop — that is expected. Never let a *failure* stand.
- **Firestore rules gotcha:** `resource` is null when a document does not exist. Any rule reading `resource.data.x` must guard with `resource == null ? <fallback> : <check>` or it throws and denies.
- Field name is exactly `googleSheetId`, on `teamSettings/{teamId}` — **not** on `teams/{teamId}`.

---

### Task 1: Resolve a team's spreadsheet id

Adds the lookup every other backend task depends on. Pure addition — nothing is wired up yet, so the suite stays green throughout.

**Files:**
- Modify: `functions/main.py` (add helpers near `_resolve_event_program_type`, ~line 44)
- Test: `functions/tests/test_main.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `_resolve_team_id(event_id: str, report_data: dict | None) -> str` — returns `''` when unknown.
  - `_get_team_sheet_id(team_id: str) -> str` — returns `''` when unset/missing.
  - `_event_tab_name(event_id: str, team_id: str) -> str` — strips the `{teamId}_` prefix.

- [ ] **Step 1: Write the failing tests**

Append to `functions/tests/test_main.py`:

```python
class TestResolveTeamId(unittest.TestCase):
    """teamId comes from the match doc, falling back to the event doc the
    same way programType does — legacy and externally-written match docs
    may not carry it."""

    @patch.object(main, 'get_db')
    def test_prefers_report_team_id(self, mock_get_db):
        self.assertEqual(
            main._resolve_team_id('t1_evt', {'teamId': 't1'}), 't1'
        )
        mock_get_db.assert_not_called()

    @patch.object(main, 'get_db')
    def test_falls_back_to_event_doc(self, mock_get_db):
        doc = Mock()
        doc.exists = True
        doc.to_dict.return_value = {'teamId': 't1'}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc

        self.assertEqual(main._resolve_team_id('t1_evt', {}), 't1')

    @patch.object(main, 'get_db')
    def test_returns_empty_when_unknown(self, mock_get_db):
        doc = Mock()
        doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc

        self.assertEqual(main._resolve_team_id('evt', {}), '')


class TestGetTeamSheetId(unittest.TestCase):

    @patch.object(main, 'get_db')
    def test_returns_configured_id(self, mock_get_db):
        doc = Mock()
        doc.exists = True
        doc.to_dict.return_value = {'googleSheetId': 'sheet-abc'}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc

        self.assertEqual(main._get_team_sheet_id('t1'), 'sheet-abc')

    @patch.object(main, 'get_db')
    def test_returns_empty_when_settings_doc_missing(self, mock_get_db):
        doc = Mock()
        doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc

        self.assertEqual(main._get_team_sheet_id('t1'), '')

    @patch.object(main, 'get_db')
    def test_returns_empty_when_field_absent(self, mock_get_db):
        doc = Mock()
        doc.exists = True
        doc.to_dict.return_value = {'defaultEventCode': 'waore'}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc

        self.assertEqual(main._get_team_sheet_id('t1'), '')

    def test_returns_empty_for_empty_team_id(self):
        self.assertEqual(main._get_team_sheet_id(''), '')


class TestEventTabName(unittest.TestCase):
    """The workbook is already team-scoped, so tabs use the bare event code."""

    def test_strips_team_prefix(self):
        self.assertEqual(main._event_tab_name('t1_2026waore', 't1'), '2026waore')

    def test_leaves_uncomposite_id_alone(self):
        self.assertEqual(main._event_tab_name('2026waore', 't1'), '2026waore')

    def test_leaves_id_alone_when_team_unknown(self):
        self.assertEqual(main._event_tab_name('t1_2026waore', ''), 't1_2026waore')

    def test_only_strips_first_occurrence(self):
        self.assertEqual(main._event_tab_name('t1_t1_evt', 't1'), 't1_evt')
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd functions && ./venv/bin/python -m pytest tests/test_main.py -k "ResolveTeamId or GetTeamSheetId or EventTabName" -v
```

Expected: FAIL — `AttributeError: module 'main' has no attribute '_resolve_team_id'`.

- [ ] **Step 3: Write the implementation**

In `functions/main.py`, insert after `_resolve_event_program_type` (which ends ~line 60):

```python
def _resolve_team_id(event_id: str, report_data: dict | None = None) -> str:
    """Resolve the owning teamId for a match. The match doc normally
    carries it, but legacy and externally-written docs may not — fall back
    to the event doc, which Step 1 (team isolation) made authoritative."""
    if report_data and report_data.get('teamId'):
        return report_data['teamId']

    try:
        event_doc = get_db().collection('events').document(event_id).get()
        if event_doc.exists:
            return (event_doc.to_dict() or {}).get('teamId') or ''
    except Exception as e:
        logger.warn(f"Failed to read event {event_id} for teamId: {e}")

    return ''


def _get_team_sheet_id(team_id: str) -> str:
    """The team's own spreadsheet id, or '' when export isn't configured.

    Sheets export is opt-in: an unset id is a normal state, not an error."""
    if not team_id:
        return ''

    try:
        doc = get_db().collection('teamSettings').document(team_id).get()
        if doc.exists:
            return (doc.to_dict() or {}).get('googleSheetId') or ''
    except Exception as e:
        logger.warn(f"Failed to read teamSettings/{team_id}: {e}")

    return ''


def _event_tab_name(event_id: str, team_id: str) -> str:
    """Tab name for an event inside a team's workbook.

    Event ids are composite `{teamId}_{eventCode}`. The workbook already
    belongs to one team, so the prefix is redundant noise in the tab name."""
    prefix = f"{team_id}_"
    if team_id and event_id.startswith(prefix):
        return event_id[len(prefix):]
    return event_id
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd functions && ./venv/bin/python -m pytest tests/test_main.py -k "ResolveTeamId or GetTeamSheetId or EventTabName" -v
```

Expected: PASS, 11 tests.

- [ ] **Step 5: Run the full Python suite**

```bash
cd functions && ./venv/bin/python -m pytest tests/ -q
```

Expected: all pass (56 baseline + 11 new = 67).

- [ ] **Step 6: Commit**

```bash
git add functions/main.py functions/tests/test_main.py
git commit -m "feat(backend): resolve per-team sheet id and tab name"
```

---

### Task 2: Rewrite the Sheets write path without the tracker

Replaces `sync_report_to_sheets` and `_delete_sheet_row_for_report` so both find rows by searching the sheet. This is where `sync_tracking` stops being consulted.

**Files:**
- Modify: `functions/main.py:63-95` (`_delete_sheet_row_for_report`), `functions/main.py:97-160` (`sync_report_to_sheets`)
- Test: `functions/tests/test_main.py`

**Interfaces:**
- Consumes: `_resolve_team_id`, `_get_team_sheet_id`, `_event_tab_name` from Task 1.
- Produces:
  - `sync_report_to_sheets(event_id: str, report_id: str, report_data: dict) -> None` — note the `is_update` parameter is **removed**; the sheet decides append vs update.
  - `_delete_sheet_row_for_report(event_id: str, report_id: str, report_data: dict | None = None) -> None`

- [ ] **Step 1: Delete the obsolete tests**

In `functions/tests/test_main.py`, delete the entire `class TestDeleteSheetRowForReport` (starts ~line 32, ends just before `class` at ~line 95). Every test in it asserts tracker behavior that no longer exists.

- [ ] **Step 2: Write the failing tests**

Append to `functions/tests/test_main.py`:

```python
class TestSyncReportToSheets(unittest.TestCase):
    """Row identity now comes from the sheet itself: found -> update,
    absent -> append. No tracker, so no stale row numbers."""

    def _report(self):
        return {'teamId': 't1', 'eventId': 't1_evt', 'scouterName': 'sam'}

    @patch('services.sheets_service.get_sheets_service')
    @patch.object(main, '_get_team_sheet_id', return_value='')
    def test_unconfigured_team_is_a_noop(self, mock_sheet_id, mock_get_svc):
        main.sync_report_to_sheets('t1_evt', 'rep1', self._report())

        mock_get_svc.assert_not_called()

    @patch('services.sheets_service.get_sheets_service')
    @patch.object(main, '_resolve_event_program_type', return_value='FRC')
    @patch.object(main, '_get_team_sheet_id', return_value='sheet-abc')
    def test_appends_when_report_not_in_sheet(self, _sid, _pt, mock_get_svc):
        svc = mock_get_svc.return_value
        svc.find_row_by_report_id.return_value = None
        svc.transform_match_report.return_value = ['a', 'b']

        main.sync_report_to_sheets('t1_evt', 'rep1', self._report())

        svc.get_or_create_sheet.assert_called_once_with('sheet-abc', 'evt', 'FRC')
        svc.append_row.assert_called_once_with('sheet-abc', 'evt', ['a', 'b'])
        svc.update_row.assert_not_called()

    @patch('services.sheets_service.get_sheets_service')
    @patch.object(main, '_resolve_event_program_type', return_value='FRC')
    @patch.object(main, '_get_team_sheet_id', return_value='sheet-abc')
    def test_updates_in_place_when_report_already_in_sheet(self, _sid, _pt, mock_get_svc):
        svc = mock_get_svc.return_value
        svc.find_row_by_report_id.return_value = 7
        svc.transform_match_report.return_value = ['a', 'b']

        main.sync_report_to_sheets('t1_evt', 'rep1', self._report())

        svc.update_row.assert_called_once_with('sheet-abc', 'evt', 7, ['a', 'b'])
        svc.append_row.assert_not_called()

    @patch('services.sheets_service.get_sheets_service')
    @patch.object(main, '_resolve_event_program_type', return_value='FTC')
    @patch.object(main, '_get_team_sheet_id', return_value='sheet-abc')
    def test_uses_bare_event_code_as_tab(self, _sid, _pt, mock_get_svc):
        svc = mock_get_svc.return_value
        svc.find_row_by_report_id.return_value = None

        main.sync_report_to_sheets('t1_2026waore', 'rep1', self._report())

        svc.get_or_create_sheet.assert_called_once_with('sheet-abc', '2026waore', 'FTC')


class TestDeleteSheetRowForReport(unittest.TestCase):
    """Deletes find their row the same way writes do."""

    @patch('services.sheets_service.get_sheets_service')
    @patch.object(main, '_get_team_sheet_id', return_value='')
    def test_unconfigured_team_is_a_noop(self, _sid, mock_get_svc):
        main._delete_sheet_row_for_report('t1_evt', 'rep1', {'teamId': 't1'})

        mock_get_svc.assert_not_called()

    @patch('services.sheets_service.get_sheets_service')
    @patch.object(main, '_get_team_sheet_id', return_value='sheet-abc')
    def test_deletes_found_row(self, _sid, mock_get_svc):
        svc = mock_get_svc.return_value
        svc.find_row_by_report_id.return_value = 4

        main._delete_sheet_row_for_report('t1_evt', 'rep1', {'teamId': 't1'})

        svc.find_row_by_report_id.assert_called_once_with('sheet-abc', 'evt', 'rep1')
        svc.delete_row.assert_called_once_with('sheet-abc', 'evt', 4)

    @patch('services.sheets_service.get_sheets_service')
    @patch.object(main, '_get_team_sheet_id', return_value='sheet-abc')
    def test_missing_row_is_not_an_error(self, _sid, mock_get_svc):
        svc = mock_get_svc.return_value
        svc.find_row_by_report_id.return_value = None

        main._delete_sheet_row_for_report('t1_evt', 'rep1', {'teamId': 't1'})

        svc.delete_row.assert_not_called()
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd functions && ./venv/bin/python -m pytest tests/test_main.py -k "SyncReportToSheets or DeleteSheetRowForReport" -v
```

Expected: FAIL — the current implementations call `SyncTracker` and read `MASTER_SPREADSHEET_ID`, so `get_or_create_sheet` is called with the composite id and `append_row` assertions do not match.

- [ ] **Step 4: Replace both functions**

In `functions/main.py`, replace everything from `def _delete_sheet_row_for_report(` through the end of `sync_report_to_sheets` (currently lines 63–160) with:

```python
def _delete_sheet_row_for_report(
    event_id: str, report_id: str, report_data: dict | None = None
) -> None:
    """Remove a report's row from its team's sheet.
    Used for hard deletes and for soft-delete transitions."""
    from services.sheets_service import get_sheets_service

    team_id = _resolve_team_id(event_id, report_data)
    spreadsheet_id = _get_team_sheet_id(team_id)

    if not spreadsheet_id:
        logger.debug(
            f"No sheet configured for team {team_id!r}; skipping delete of {report_id}"
        )
        return

    tab = _event_tab_name(event_id, team_id)
    sheets_service = get_sheets_service()

    row_number = sheets_service.find_row_by_report_id(spreadsheet_id, tab, report_id)

    if row_number is None:
        logger.info(f"Report {report_id} not present in sheet tab {tab}; nothing to delete")
        return

    if sheets_service.delete_row(spreadsheet_id, tab, row_number):
        logger.info(f"Deleted row {row_number} for report {report_id}")
    else:
        logger.warn(f"Failed to delete row {row_number} for report {report_id}")


def sync_report_to_sheets(event_id: str, report_id: str, report_data: dict) -> None:
    """Push a single match report to its team's spreadsheet.

    Row identity is resolved against the sheet itself rather than a tracker
    collection: the sheet is the only record of what is in the sheet, so
    there is no second store that can drift out of agreement with it."""
    from services.sheets_service import get_sheets_service

    team_id = _resolve_team_id(event_id, report_data)
    spreadsheet_id = _get_team_sheet_id(team_id)

    if not spreadsheet_id:
        logger.debug(
            f"No sheet configured for team {team_id!r}; skipping sync of {report_id}"
        )
        return

    tab = _event_tab_name(event_id, team_id)

    # The event doc is authoritative for programType — the match doc's field
    # may be missing (legacy writes, external admin writes) which used to
    # silently force the sheet to FRC columns on first sync of an FTC event.
    program_type = _resolve_event_program_type(event_id, report_data)

    try:
        sheets_service = get_sheets_service()
        sheets_service.get_or_create_sheet(spreadsheet_id, tab, program_type)

        row_data = sheets_service.transform_match_report(report_data)
        row_number = sheets_service.find_row_by_report_id(spreadsheet_id, tab, report_id)

        if row_number is not None:
            sheets_service.update_row(spreadsheet_id, tab, row_number, row_data)
            logger.info(f"Updated report {report_id} in row {row_number}")
        else:
            row_number = sheets_service.append_row(spreadsheet_id, tab, row_data)
            logger.info(f"Appended report {report_id} to row {row_number}")

    except Exception as e:
        logger.error(f"Failed to sync report {report_id}: {str(e)}")
        raise
```

Also delete `get_master_spreadsheet_id()` (lines 28–30) — the next tasks remove its last callers, and leaving it invites reuse.

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd functions && ./venv/bin/python -m pytest tests/test_main.py -k "SyncReportToSheets or DeleteSheetRowForReport" -v
```

Expected: PASS, 7 tests.

- [ ] **Step 6: Commit**

```bash
git add functions/main.py functions/tests/test_main.py
git commit -m "refactor(sync): find sheet rows by report id"
```

---

### Task 3: Strip the echo guard and tracker from `on_match_written`

**Files:**
- Modify: `functions/main.py:163-256` (`on_match_written`)
- Test: `functions/tests/test_main.py`

**Interfaces:**
- Consumes: `sync_report_to_sheets` and `_delete_sheet_row_for_report` from Task 2 (note the changed signatures).
- Produces: no new symbols.

- [ ] **Step 1: Delete the obsolete tests**

In `functions/tests/test_main.py`, inside `class TestOnMatchWrittenSoftDelete`, delete these four tests — every one asserts echo-guard or tracker behavior that no longer exists:
- `test_sheets_origin_update_is_skipped`
- `test_app_edit_after_sheets_edit_still_syncs`
- `test_repeated_sheets_edit_does_not_echo`
- `test_new_already_deleted_doc_is_skipped` (asserts `SyncTracker` short-circuiting)

Keep `test_sheets_origin_soft_delete_still_propagates` but rename it to `test_soft_delete_with_legacy_sync_source_still_propagates`, since the field is now meaningless residue rather than a signal.

- [ ] **Step 2: Write the failing tests**

Add to `class TestOnMatchWrittenSoftDelete` in `functions/tests/test_main.py`:

```python
    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_legacy_sheets_source_no_longer_blocks_sync(self, mock_sync, mock_delete):
        """lastSyncSource is dead residue on old docs — it must not suppress
        an export the way the removed echo guard did."""
        evt = self._build_event(
            before={'eventId': 'e1', 'lastSyncSource': 'sheets'},
            after={'eventId': 'e1', 'lastSyncSource': 'sheets', 'scouterName': 'sam'},
        )

        main.on_match_written(evt)

        mock_sync.assert_called_once_with('e1', 'rep1', evt.data.after.to_dict.return_value)
        mock_delete.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_new_already_deleted_doc_is_skipped(self, mock_sync, mock_delete):
        evt = self._build_event(
            before=None,
            after={'eventId': 'e1', 'isDeleted': True, 'scouterName': 'sam'},
        )

        main.on_match_written(evt)

        mock_sync.assert_not_called()
        mock_delete.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_delete_helper_receives_report_data(self, mock_sync, mock_delete):
        """The delete path needs the doc to resolve teamId -> spreadsheet."""
        before = {'eventId': 'e1', 'teamId': 't1', 'isDeleted': False}
        after = {'eventId': 'e1', 'teamId': 't1', 'isDeleted': True}
        evt = self._build_event(before=before, after=after)

        main.on_match_written(evt)

        mock_delete.assert_called_once_with('e1', 'rep1', after)
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd functions && ./venv/bin/python -m pytest tests/test_main.py -k OnMatchWritten -v
```

Expected: FAIL — `test_legacy_sheets_source_no_longer_blocks_sync` fails because the echo guard returns early; `test_delete_helper_receives_report_data` fails because the helper is still called with two arguments.

- [ ] **Step 4: Edit `on_match_written`**

In `functions/main.py`, make exactly these four changes inside `on_match_written`:

1. Change the decorator (line 163) to drop the removed secret:

```python
@firestore_fn.on_document_written(document="matches/{reportId}", secrets=["GOOGLE_SHEETS_CREDENTIALS"])
```

2. In the hard-delete branch, pass the doc through:

```python
    if data_before and not data_after:
        logger.info(f"Processing hard-deleted match report: {report_id} for event {event_id}")
        try:
            _delete_sheet_row_for_report(event_id, report_id, data_before)
        except Exception as e:
            logger.error(f"Failed to sync delete for report {report_id}: {str(e)}")
```

3. In the create branch, delete the `SyncTracker` import and short-circuit, and drop `is_update`:

```python
        logger.info(f"Processing new match report: {report_id} for event {event_id}")
        sync_report_to_sheets(event_id, report_id, data_after)
```

4. In the update branch, delete the whole echo-guard block (the `if data_after.get('lastSyncSource') == 'sheets' ...` statement and its long comment), pass the doc to the delete helper, and drop `is_update`:

```python
    elif data_before and data_after:
        was_deleted = bool(data_before.get('isDeleted'))
        is_deleted = bool(data_after.get('isDeleted'))

        if is_deleted and not was_deleted:
            # Soft delete (trash): remove the row from Sheets so trashed
            # matches don't keep showing up in analysis views.
            logger.info(f"Processing soft-deleted match report: {report_id} for event {event_id}")
            try:
                _delete_sheet_row_for_report(event_id, report_id, data_after)
            except Exception as e:
                logger.error(f"Failed to sync soft delete for report {report_id}: {str(e)}")
            return

        if is_deleted:
            # Already soft-deleted; ignore further updates (e.g. metadata
            # edits on a trashed match) instead of re-appending the row.
            logger.info(f"Ignoring update to soft-deleted match {report_id}")
            return

        # Restore (was_deleted -> not is_deleted) lands here too: the row was
        # removed on trash, so find_row_by_report_id misses and re-appends.
        logger.info(f"Processing updated match report: {report_id} for event {event_id}")
        sync_report_to_sheets(event_id, report_id, data_after)
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd functions && ./venv/bin/python -m pytest tests/test_main.py -k OnMatchWritten -v
```

Expected: PASS.

- [ ] **Step 6: Verify no echo-guard residue remains in the trigger**

```bash
cd functions && grep -n "lastSyncSource\|SyncTracker\|is_update" main.py
```

Expected: hits only inside `update_match_from_sheets`, `sync_from_sheets_http`, and `backfill_event_to_sheets` — all removed in Task 4. No hits inside `on_match_written`.

- [ ] **Step 7: Commit**

```bash
git add functions/main.py functions/tests/test_main.py
git commit -m "refactor(sync): drop sheets echo guard from trigger"
```

---

### Task 4: Delete the reverse-sync endpoints and the tracker

The bulk deletion. After this the Sheets→Firestore direction does not exist.

**Files:**
- Modify: `functions/main.py` (remove `update_match_from_sheets`, `sync_from_sheets_http`; rework `backfill_event_to_sheets`)
- Delete: `functions/services/sync_tracker.py`, `functions/tests/test_sync_tracker.py`
- Modify: `firebase.json` (drop `SYNC_API_KEY`)
- Test: `functions/tests/test_main.py`

**Interfaces:**
- Consumes: `_get_team_sheet_id`, `_event_tab_name` (Task 1); `sync_report_to_sheets` (Task 2).
- Produces: `backfill_event_to_sheets` returning `{'success': bool, 'eventId': str, 'syncedCount': int, 'failedCount': int}` — shape unchanged, so the frontend call in Task 8 is unaffected.

- [ ] **Step 1: Delete the files and dead code**

```bash
git rm functions/services/sync_tracker.py functions/tests/test_sync_tracker.py
```

In `functions/main.py`, delete these two functions entirely, decorators included:
- `update_match_from_sheets` (currently ~532–616)
- `sync_from_sheets_http` (currently ~618–683)

Then remove the now-unused imports at the top: `from flask import jsonify, Request, Response` (line 8) and `from firebase_functions.options import CorsOptions` (line 6) — confirm with grep in Step 4 before deleting, since `options` on line 5 is a separate import that may still be used.

- [ ] **Step 2: Write the failing test for backfill**

Append to `functions/tests/test_main.py`:

```python
class TestBackfillEventToSheets(unittest.TestCase):
    """Backfill resolves the same per-team target as the trigger, and is
    idempotent because sync_report_to_sheets updates rows in place."""

    def _req(self):
        req = Mock()
        req.auth = Mock()
        req.auth.token = {'teams': {'t1': 'admin'}}
        req.data = {'eventId': 't1_evt'}
        return req

    @patch.object(main, 'sync_report_to_sheets')
    @patch.object(main, '_get_team_sheet_id', return_value='sheet-abc')
    @patch.object(main, 'get_db')
    def test_syncs_each_live_report(self, mock_get_db, _sid, mock_sync):
        event_doc = Mock()
        event_doc.exists = True
        event_doc.to_dict.return_value = {'programType': 'FRC', 'teamId': 't1'}

        live = Mock()
        live.id = 'rep1'
        live.to_dict.return_value = {'scouterName': 'sam', 'teamId': 't1'}
        trashed = Mock()
        trashed.id = 'rep2'
        trashed.to_dict.return_value = {'scouterName': 'sam', 'isDeleted': True}

        db = mock_get_db.return_value
        db.collection.return_value.document.return_value.get.return_value = event_doc
        query = db.collection.return_value.where.return_value
        query.where.return_value.stream.return_value = [live, trashed]
        query.stream.return_value = [live, trashed]

        result = main.backfill_event_to_sheets(self._req())

        self.assertEqual(result['syncedCount'], 1)
        mock_sync.assert_called_once_with('t1_evt', 'rep1', live.to_dict.return_value)

    @patch.object(main, '_get_team_sheet_id', return_value='')
    @patch.object(main, 'get_db')
    def test_unconfigured_team_raises_failed_precondition(self, mock_get_db, _sid):
        event_doc = Mock()
        event_doc.exists = True
        event_doc.to_dict.return_value = {'programType': 'FRC', 'teamId': 't1'}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = event_doc

        with self.assertRaises(main.https_fn.HttpsError) as ctx:
            main.backfill_event_to_sheets(self._req())

        self.assertEqual(
            ctx.exception.code, main.https_fn.FunctionsErrorCode.FAILED_PRECONDITION
        )

    @patch.object(main, 'get_db')
    def test_non_member_is_denied(self, mock_get_db):
        event_doc = Mock()
        event_doc.exists = True
        event_doc.to_dict.return_value = {'programType': 'FRC', 'teamId': 't1'}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = event_doc

        req = self._req()
        req.auth.token = {'teams': {'other': 'admin'}}

        with self.assertRaises(main.https_fn.HttpsError) as ctx:
            main.backfill_event_to_sheets(req)

        self.assertEqual(
            ctx.exception.code, main.https_fn.FunctionsErrorCode.PERMISSION_DENIED
        )
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd functions && ./venv/bin/python -m pytest tests/test_main.py -k Backfill -v
```

Expected: FAIL — backfill still calls `SyncTracker` and `get_master_spreadsheet_id`.

- [ ] **Step 4: Rewrite `backfill_event_to_sheets`**

Replace the whole function with:

```python
@https_fn.on_call(secrets=["GOOGLE_SHEETS_CREDENTIALS"])
def backfill_event_to_sheets(req: https_fn.CallableRequest) -> dict:
    """Backfill all live match reports for an event into the team's sheet.

    Idempotent: sync_report_to_sheets updates a row in place when the report
    is already present, so re-running never duplicates rows."""
    try:
        if not req.auth:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="Must be authenticated"
            )

        event_id = req.data.get('eventId')
        if not event_id:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message="Missing eventId parameter"
            )

        logger.info(f"Starting backfill for event: {event_id}")

        # Cloud Functions use the Admin SDK and bypass Firestore rules, so
        # we must enforce team isolation here.
        db = get_db()
        event_doc = db.collection('events').document(event_id).get()
        event_team_id = ''
        if event_doc.exists:
            event_team_id = (event_doc.to_dict() or {}).get('teamId', '') or ''

        if event_team_id and not _is_team_member(req.auth.token, event_team_id):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="Caller is not a member of the team that owns this event"
            )

        if not _get_team_sheet_id(event_team_id):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                message="This team has no Google Sheet configured"
            )

        reports_ref = db.collection('matches').where('eventId', '==', event_id)
        if event_team_id:
            reports_ref = reports_ref.where('teamId', '==', event_team_id)

        synced_count = 0
        failed_count = 0

        for report_doc in reports_ref.stream():
            report_id = report_doc.id
            report_data = report_doc.to_dict()

            if report_data.get('isDeleted'):
                continue

            # Skip legacy schedule-shaped docs the same way on_match_written
            # does. TBA/FTC sync used to write schedule entries into /matches
            # (now /schedules); old data would otherwise appear as garbage rows.
            if report_data.get('compLevel') and not report_data.get('scouterName'):
                logger.info(f"Skipping schedule-shaped doc {report_id} during backfill")
                continue

            try:
                sync_report_to_sheets(event_id, report_id, report_data)
                synced_count += 1
            except Exception as e:
                failed_count += 1
                logger.error(f"Failed to sync report {report_id}: {str(e)}")

        logger.info(f"Backfill complete. Synced: {synced_count}, Failed: {failed_count}")

        return {
            'success': True,
            'eventId': event_id,
            'syncedCount': synced_count,
            'failedCount': failed_count
        }

    except https_fn.HttpsError:
        raise
    except Exception as e:
        logger.error(f"Backfill failed: {str(e)}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Backfill failed: {str(e)}"
        )
```

- [ ] **Step 5: Remove `SYNC_API_KEY` from config**

```bash
grep -n "SYNC_API_KEY" firebase.json functions/*.py
```

Remove every hit outside of documentation. If `firebase.json` has no hit, the secret was declared only in the deleted decorator and nothing else is needed here.

- [ ] **Step 6: Verify unused imports are actually unused, then confirm the suite**

```bash
cd functions && grep -n "jsonify\|Request\|Response\|CorsOptions" main.py
```

Expected: no hits. If any remain, keep the corresponding import.

```bash
cd functions && ./venv/bin/python -m pytest tests/ -q
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add -A functions firebase.json
git commit -m "refactor(sync): delete sheets-to-firestore reverse path"
```

---

### Task 5: The `set_team_sheet` callable

**Files:**
- Modify: `functions/main.py` (add callable after the membership callables, ~line 400)
- Modify: `functions/services/sheets_service.py` (add `verify_write_access`, `service_account_email`)
- Test: `functions/tests/test_main.py`, `functions/tests/test_sheets_service.py`

**Interfaces:**
- Consumes: `_is_team_member` (existing), `get_db` (existing).
- Produces:
  - `main._extract_sheet_id(value: str) -> str`
  - `main.set_team_sheet(req) -> dict` returning `{'success': True, 'googleSheetId': str}`
  - `SheetsService.verify_write_access(spreadsheet_id: str) -> bool`
  - `SheetsService.service_account_email` (property, `str`)

- [ ] **Step 1: Write the failing tests for id extraction and the callable**

Append to `functions/tests/test_main.py`:

```python
class TestExtractSheetId(unittest.TestCase):
    """People paste the URL, not the id."""

    def test_extracts_from_full_url(self):
        url = 'https://docs.google.com/spreadsheets/d/1AbC-dEf_123/edit#gid=0'
        self.assertEqual(main._extract_sheet_id(url), '1AbC-dEf_123')

    def test_extracts_from_url_without_fragment(self):
        url = 'https://docs.google.com/spreadsheets/d/1AbC-dEf_123'
        self.assertEqual(main._extract_sheet_id(url), '1AbC-dEf_123')

    def test_passes_through_bare_id(self):
        self.assertEqual(main._extract_sheet_id('1AbC-dEf_123'), '1AbC-dEf_123')

    def test_strips_surrounding_whitespace(self):
        self.assertEqual(main._extract_sheet_id('  1AbC-dEf_123  '), '1AbC-dEf_123')

    def test_returns_empty_for_garbage(self):
        self.assertEqual(main._extract_sheet_id('not a sheet!'), '')

    def test_returns_empty_for_empty_input(self):
        self.assertEqual(main._extract_sheet_id(''), '')


class TestSetTeamSheet(unittest.TestCase):

    def _req(self, role='admin', sheet='1AbC-dEf_123'):
        req = Mock()
        req.auth = Mock()
        req.auth.uid = 'u1'
        req.auth.token = {'teams': {'t1': role}}
        req.data = {'teamId': 't1', 'sheetId': sheet}
        return req

    def test_unauthenticated_is_rejected(self):
        req = self._req()
        req.auth = None

        with self.assertRaises(main.https_fn.HttpsError) as ctx:
            main.set_team_sheet(req)

        self.assertEqual(
            ctx.exception.code, main.https_fn.FunctionsErrorCode.UNAUTHENTICATED
        )

    def test_non_admin_member_is_rejected(self):
        with self.assertRaises(main.https_fn.HttpsError) as ctx:
            main.set_team_sheet(self._req(role='member'))

        self.assertEqual(
            ctx.exception.code, main.https_fn.FunctionsErrorCode.PERMISSION_DENIED
        )

    def test_non_member_is_rejected(self):
        req = self._req()
        req.auth.token = {'teams': {'other': 'admin'}}

        with self.assertRaises(main.https_fn.HttpsError) as ctx:
            main.set_team_sheet(req)

        self.assertEqual(
            ctx.exception.code, main.https_fn.FunctionsErrorCode.PERMISSION_DENIED
        )

    def test_unparseable_sheet_is_rejected(self):
        with self.assertRaises(main.https_fn.HttpsError) as ctx:
            main.set_team_sheet(self._req(sheet='not a sheet!'))

        self.assertEqual(
            ctx.exception.code, main.https_fn.FunctionsErrorCode.INVALID_ARGUMENT
        )

    @patch('services.sheets_service.get_sheets_service')
    @patch.object(main, 'get_db')
    def test_unshared_sheet_reports_service_account_email(self, mock_get_db, mock_get_svc):
        svc = mock_get_svc.return_value
        svc.verify_write_access.return_value = False
        svc.service_account_email = 'scout@proj.iam.gserviceaccount.com'

        with self.assertRaises(main.https_fn.HttpsError) as ctx:
            main.set_team_sheet(self._req())

        self.assertEqual(
            ctx.exception.code, main.https_fn.FunctionsErrorCode.FAILED_PRECONDITION
        )
        self.assertIn('scout@proj.iam.gserviceaccount.com', ctx.exception.message)
        mock_get_db.return_value.collection.return_value.document.return_value.set.assert_not_called()

    @patch('services.sheets_service.get_sheets_service')
    @patch.object(main, 'get_db')
    def test_valid_sheet_is_persisted(self, mock_get_db, mock_get_svc):
        svc = mock_get_svc.return_value
        svc.verify_write_access.return_value = True

        url = 'https://docs.google.com/spreadsheets/d/1AbC-dEf_123/edit'
        result = main.set_team_sheet(self._req(sheet=url))

        self.assertEqual(result, {'success': True, 'googleSheetId': '1AbC-dEf_123'})
        svc.verify_write_access.assert_called_once_with('1AbC-dEf_123')

        doc_ref = mock_get_db.return_value.collection.return_value.document.return_value
        written = doc_ref.set.call_args[0][0]
        self.assertEqual(written['googleSheetId'], '1AbC-dEf_123')
```

Append to `functions/tests/test_sheets_service.py`:

```python
class TestVerifyWriteAccess(unittest.TestCase):
    """The write probe is what turns a competition-day mystery into an
    actionable 'share the sheet' message at configure time."""

    def _service(self):
        from services.sheets_service import SheetsService
        svc = SheetsService.__new__(SheetsService)
        svc.service = MagicMock()
        return svc

    def test_true_when_metadata_readable_and_not_protected(self):
        svc = self._service()
        svc.service.spreadsheets.return_value.get.return_value.execute.return_value = {
            'properties': {'title': 'Scouting'},
            'sheets': [{'properties': {'title': 'Sheet1', 'sheetId': 0}}],
        }

        self.assertTrue(svc.verify_write_access('sheet-abc'))

    def test_false_on_http_error(self):
        from googleapiclient.errors import HttpError
        svc = self._service()
        resp = MagicMock()
        resp.status = 403
        svc.service.spreadsheets.return_value.get.return_value.execute.side_effect = (
            HttpError(resp, b'forbidden')
        )

        self.assertFalse(svc.verify_write_access('sheet-abc'))
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd functions && ./venv/bin/python -m pytest tests/test_main.py -k "ExtractSheetId or SetTeamSheet" tests/test_sheets_service.py -k VerifyWriteAccess -v
```

Expected: FAIL — `module 'main' has no attribute '_extract_sheet_id'`.

- [ ] **Step 3: Add the SheetsService probe**

In `functions/services/sheets_service.py`, add to `__init__` (after the existing credential setup, ~line 68) a stored email, then add the two members. First inspect the existing `__init__`:

```bash
cd functions && sed -n '66,80p' services/sheets_service.py
```

Then set the property from the parsed credentials JSON already available there:

```python
    @property
    def service_account_email(self) -> str:
        """The address a team must share their sheet with, as Editor."""
        return self._service_account_email

    def verify_write_access(self, spreadsheet_id: str) -> bool:
        """True if this service account can open the spreadsheet.

        The credentials carry the spreadsheets scope, so a successful
        metadata read with that scope means the account has been granted
        access to the file; a 403/404 means it has not."""
        try:
            self.service.spreadsheets().get(
                spreadsheetId=spreadsheet_id,
                fields='properties.title,sheets.properties'
            ).execute()
            return True
        except HttpError as e:
            import logging
            logging.warning(f"No access to spreadsheet {spreadsheet_id}: {e}")
            return False
```

In `__init__`, store the email alongside the existing credential parse:

```python
        creds_dict = json.loads(credentials_json)
        self._service_account_email = creds_dict.get('client_email', '')
```

If `__init__` already parses the JSON into a variable, reuse that variable rather than parsing twice.

- [ ] **Step 4: Add the callable to `main.py`**

Add `import re` to the imports at the top of `functions/main.py`, then insert after `leave_team` (~line 400):

```python
_SHEET_URL_RE = re.compile(r'/spreadsheets/d/([a-zA-Z0-9-_]+)')
_SHEET_ID_RE = re.compile(r'^[a-zA-Z0-9-_]+$')


def _extract_sheet_id(value: str) -> str:
    """Accept a full Sheets URL or a bare id; return '' if neither."""
    value = (value or '').strip()
    if not value:
        return ''

    url_match = _SHEET_URL_RE.search(value)
    if url_match:
        return url_match.group(1)

    if _SHEET_ID_RE.match(value):
        return value

    return ''


def _is_team_admin(auth_token: dict | None, team_id: str) -> bool:
    """True if the caller's `teams` claim marks them admin of `team_id`."""
    if not auth_token or not team_id:
        return False
    return (auth_token.get('teams') or {}).get(team_id) == 'admin'


@https_fn.on_call(secrets=["GOOGLE_SHEETS_CREDENTIALS"])
def set_team_sheet(req: https_fn.CallableRequest) -> dict:
    """Point a team's Sheets export at a spreadsheet the team owns.

    Validated server-side and stored with the Admin SDK: rules deny client
    writes to googleSheetId, the same server-authoritative pattern used for
    team membership."""
    if not req.auth:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Must be authenticated"
        )

    team_id = (req.data or {}).get('teamId') or ''
    raw_sheet = (req.data or {}).get('sheetId') or ''

    if not _is_team_admin(req.auth.token, team_id):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="Only a team admin can configure the team's Google Sheet"
        )

    sheet_id = _extract_sheet_id(raw_sheet)
    if not sheet_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="That doesn't look like a Google Sheets link or id"
        )

    from services.sheets_service import get_sheets_service
    sheets_service = get_sheets_service()

    if not sheets_service.verify_write_access(sheet_id):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message=(
                "Can't open that sheet. Share it as Editor with "
                f"{sheets_service.service_account_email}, then try again."
            )
        )

    get_db().collection('teamSettings').document(team_id).set(
        {
            'googleSheetId': sheet_id,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    logger.info(f"Team {team_id} sheet set to {sheet_id} by {req.auth.uid}")
    return {'success': True, 'googleSheetId': sheet_id}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd functions && ./venv/bin/python -m pytest tests/ -q
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add functions/main.py functions/services/sheets_service.py functions/tests/
git commit -m "feat(backend): add admin-only set_team_sheet callable"
```

---

### Task 6: Lock `googleSheetId` in Firestore rules

**Files:**
- Modify: `firestore.rules:73-77`
- Test: `test/firestore-rules/rules.test.js`

**Interfaces:**
- Consumes: nothing.
- Produces: `teamSettings/{teamId}` rule denying client writes to `googleSheetId`.

- [ ] **Step 1: Read the existing test file conventions**

```bash
sed -n '1,60p' test/firestore-rules/rules.test.js
```

Match the existing helper names and auth-context setup exactly — do not invent new ones.

- [ ] **Step 2: Write the failing tests**

Append to `test/firestore-rules/rules.test.js`, adapting the context helpers to the names found in Step 1:

```javascript
describe('teamSettings googleSheetId is server-authoritative', () => {
  test('member cannot set googleSheetId', async () => {
    const db = authedDb({ uid: 'u1', teams: { t1: 'member' } });
    await assertFails(
      db.doc('teamSettings/t1').set({ googleSheetId: 'evil' }, { merge: true })
    );
  });

  test('admin cannot set googleSheetId either', async () => {
    const db = authedDb({ uid: 'u1', teams: { t1: 'admin' } });
    await assertFails(
      db.doc('teamSettings/t1').set({ googleSheetId: 'evil' }, { merge: true })
    );
  });

  test('member can still write defaultEventCode', async () => {
    const db = authedDb({ uid: 'u1', teams: { t1: 'member' } });
    await assertSucceeds(
      db.doc('teamSettings/t1').set({ defaultEventCode: 'waore' }, { merge: true })
    );
  });

  test('non-member cannot read teamSettings', async () => {
    const db = authedDb({ uid: 'u2', teams: { other: 'admin' } });
    await assertFails(db.doc('teamSettings/t1').get());
  });
});
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
firebase emulators:exec --only firestore "cd test/firestore-rules && ./node_modules/.bin/jest --runInBand"
```

Expected: the two `googleSheetId` denial tests FAIL (currently any member may write it). Run from the repo root; call the jest binary directly — `npm test` inside `emulators:exec` hits a shell-quoting bug on Linux.

- [ ] **Step 4: Update the rules**

In `firestore.rules`, replace the `teamSettings` block and delete the `sync_tracking` block:

```
    match /teamSettings/{teamId} {
      allow read: if isTeamMember(teamId);

      // googleSheetId is server-authoritative: only the set_team_sheet
      // callable (Admin SDK, which bypasses rules) may write it, because
      // it validates the sheet is actually reachable first. A client write
      // would let any member silently redirect the team's export.
      // `resource` is null on create, so guard before reading resource.data.
      allow write: if isTeamMember(teamId)
                   && (
                        !request.resource.data.keys().hasAny(['googleSheetId'])
                        || (resource != null
                            && request.resource.data.googleSheetId == resource.data.googleSheetId)
                      );
    }
```

Delete this line entirely:

```
    match /sync_tracking/{doc} { allow read, write: if false; }
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
firebase emulators:exec --only firestore "cd test/firestore-rules && ./node_modules/.bin/jest --runInBand"
```

Expected: all pass, including the 16 pre-existing isolation tests.

- [ ] **Step 6: Commit**

```bash
git add firestore.rules test/firestore-rules/rules.test.js
git commit -m "feat(db): deny client writes to googleSheetId"
```

---

### Task 7: Drop `lastSyncSource` from the Flutter write path

**Files:**
- Modify: `frontend/lib/data/repositories/firestore_repository.dart:71,85-92,150,163,171`
- Test: `frontend/test/data/repositories/` (match the existing filename convention found in Step 1)

**Interfaces:**
- Consumes: nothing.
- Produces: `_withTeamId(Map<String, dynamic> data) -> Map<String, dynamic>` replacing `_stampSource`.

**Critical:** `_stampSource` does two jobs. Deleting it wholesale reintroduces a fixed bug. Keep the `teamId` backfill; delete only the `lastSyncSource` line.

- [ ] **Step 1: Find the existing repository test conventions**

```bash
ls frontend/test/data/repositories/ && grep -rn "FakeFirebaseFirestore\|MockFirebaseFirestore" frontend/test --include=*.dart | head -5
```

Use whichever fake/mock the existing tests use. If no repository test file exists, create `frontend/test/data/repositories/firestore_repository_stamp_test.dart` using the same fake as the nearest equivalent test.

- [ ] **Step 2: Write the failing tests**

In that test file:

```dart
group('write payloads', () {
  test('createMatch does not write lastSyncSource', () async {
    await repo.createMatch(eventId, match);

    final doc = await firestore.collection('matches').doc(match.id).get();
    expect(doc.data()!.containsKey('lastSyncSource'), isFalse);
  });

  test('trashMatch does not write lastSyncSource', () async {
    await repo.trashMatch(eventId, match.id);

    final doc = await firestore.collection('matches').doc(match.id).get();
    expect(doc.data()!.containsKey('lastSyncSource'), isFalse);
  });

  test('trashMatch still backfills teamId so the create rule passes', () async {
    // set+merge degrades to a CREATE when the doc was hard-deleted by
    // another client; the matches/{id} create rule requires teamId.
    await repo.trashMatch(eventId, 'never-created');

    final doc = await firestore.collection('matches').doc('never-created').get();
    expect(doc.data()!['teamId'], equals(teamId));
  });

  test('restoreMatch still backfills teamId', () async {
    await repo.restoreMatch(eventId, 'never-created');

    final doc = await firestore.collection('matches').doc('never-created').get();
    expect(doc.data()!['teamId'], equals(teamId));
  });
});
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd frontend && flutter test test/data/repositories/firestore_repository_stamp_test.dart
```

Expected: the two `lastSyncSource` tests FAIL — the field is currently written.

- [ ] **Step 4: Rename the helper and drop the stamp**

In `frontend/lib/data/repositories/firestore_repository.dart`, replace the helper (lines 74–92):

```dart
  /// Backfill teamId when it isn't already in the payload, so trash/restore
  /// writes that race a hard-delete (the doc no longer exists, so set+merge
  /// becomes a CREATE carrying only {isDeleted: ...}) still satisfy the
  /// matches/{id} create rule's isValidTeamId() check. createMatch and
  /// updateMatch already include teamId via _prepareForFirestore.
  Map<String, dynamic> _withTeamId(Map<String, dynamic> data) {
    final stamped = <String, dynamic>{...data};
    if (!stamped.containsKey('teamId') &&
        teamId != null &&
        teamId!.isNotEmpty) {
      stamped['teamId'] = teamId;
    }
    return stamped;
  }
```

Then rename all four call sites (lines 71, 150, 163, 171):

```bash
cd frontend && sed -i 's/_stampSource(/_withTeamId(/g' lib/data/repositories/firestore_repository.dart
grep -n "_stampSource\|lastSyncSource" lib/data/repositories/firestore_repository.dart
```

Expected from the grep: no output.

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd frontend && flutter test test/data/repositories/ && flutter analyze
```

Expected: tests PASS, analyze reports no issues.

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/data/repositories/firestore_repository.dart frontend/test/data/repositories/
git commit -m "refactor(frontend): drop lastSyncSource stamp"
```

---

### Task 8: Extract the settings sheet and add the export section

**Files:**
- Create: `frontend/lib/presentation/widgets/settings_sheet.dart`
- Modify: `frontend/lib/presentation/screens/dashboard.dart:42-47,862-1137`
- Modify: `frontend/lib/data/repositories/team_repository.dart:126-144`
- Modify: `frontend/lib/presentation/providers/auth_provider.dart` (add provider near line 364)
- Test: `frontend/test/widgets/settings_sheet_test.dart`

**Interfaces:**
- Consumes: `set_team_sheet` and `backfill_event_to_sheets` callables (Tasks 4–5); `AuthState.teamMemberships` (`Map<String, String>`, teamId → role).
- Produces:
  - `SettingsSheet` — public widget replacing the private `_SettingsSheet`.
  - `isTeamAdminProvider` — `Provider<bool>`.
  - `TeamRepository.setTeamSheet({required String teamId, required String sheetId}) -> Future<String>` returning the stored id.

- [ ] **Step 1: Extract the widget verbatim, then commit**

Move `_SettingsSheet`, `_SettingsSheetState`, and the private helpers they own (`_buildThemeSelector`, the color-seed builder) out of `dashboard.dart` (lines 862 to end of those classes) into `frontend/lib/presentation/widgets/settings_sheet.dart`. Rename `_SettingsSheet` → `SettingsSheet` and `_SettingsSheetState` → `_SettingsSheetState` (state class stays private). Carry over only the imports it actually uses.

In `dashboard.dart`, update the launcher at line 42–47:

```dart
      builder: (context) => const SettingsSheet(),
```

and add `import '../widgets/settings_sheet.dart';`.

```bash
cd frontend && flutter analyze && flutter test
```

Expected: no analyzer issues; the full suite passes unchanged. This step must be behavior-neutral — verify before moving on.

```bash
git add frontend/lib/presentation/
git commit -m "refactor(ui): extract settings sheet from dashboard"
```

- [ ] **Step 2: Add the admin provider and repository method**

In `frontend/lib/presentation/providers/auth_provider.dart`, after `currentTeamIdProvider` (line 364):

```dart
/// Admin-ness comes from the `teams` custom claim already mirrored into
/// AuthState.teamMemberships (teamId -> role), so this needs no fetch.
final isTeamAdminProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  final teamId = auth.currentTeamId;
  if (teamId == null) return false;
  return auth.teamMemberships[teamId] == 'admin';
});
```

In `frontend/lib/data/repositories/team_repository.dart`, add alongside the other callable wrappers:

```dart
  /// Point the team's Sheets export at [sheetId] (a full Sheets URL or a
  /// bare id). Server-side only: rules deny client writes to googleSheetId.
  Future<String> setTeamSheet({
    required String teamId,
    required String sheetId,
  }) async {
    try {
      final callable = _functions.httpsCallable('set_team_sheet');
      final result = await callable.call<Map<String, dynamic>>({
        'teamId': teamId,
        'sheetId': sheetId,
      });
      return result.data['googleSheetId'] as String;
    } on FirebaseFunctionsException catch (e) {
      _mapFunctionsError(e);
    }
  }
```

Then remove the `googleSheetId` parameter from `updateTeamSettings` (lines 126–144) and its `if (googleSheetId != null)` line, since clients can no longer write that field.

```bash
cd frontend && grep -rn "updateTeamSettings" lib test
```

Fix every caller that passed `googleSheetId`.

- [ ] **Step 3: Write the failing widget tests**

Create `frontend/test/widgets/settings_sheet_test.dart`, following the provider-override conventions in `frontend/test/helpers/`:

```dart
void main() {
  Widget wrap(List<Override> overrides) => ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      );

  testWidgets('shows the Sheets export section for a team admin',
      (tester) async {
    await tester.pumpWidget(wrap([
      isTeamAdminProvider.overrideWith((ref) => true),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Sheets export'), findsOneWidget);
  });

  testWidgets('hides the Sheets export section for a non-admin member',
      (tester) async {
    await tester.pumpWidget(wrap([
      isTeamAdminProvider.overrideWith((ref) => false),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Sheets export'), findsNothing);
  });
}
```

Note: use `overrideWith((ref) => ...)`, never `overrideWithValue` — this codebase requires the former for providers that must react to state changes.

- [ ] **Step 4: Run tests to verify they fail**

```bash
cd frontend && flutter test test/widgets/settings_sheet_test.dart
```

Expected: FAIL — `Sheets export` is not found for the admin case.

- [ ] **Step 5: Add the export section**

In `frontend/lib/presentation/widgets/settings_sheet.dart`, add to the column inside `build`, above the Done button:

```dart
            if (ref.watch(isTeamAdminProvider)) ...[
              const SizedBox(height: AppTheme.spacingXl),
              Text(
                "Sheets export",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                _sheetId == null || _sheetId!.isEmpty
                    ? "Not configured — matches aren't being exported."
                    : "Connected",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              TextField(
                controller: _sheetCtrl,
                decoration: InputDecoration(
                  labelText: "Google Sheet link or id",
                  errorText: _sheetError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _saveSheet,
                    child: Text(_saving ? "Saving…" : "Save"),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  OutlinedButton(
                    onPressed: (_sheetId == null || _sheetId!.isEmpty || _backfilling)
                        ? null
                        : _backfillEvent,
                    child: Text(_backfilling ? "Backfilling…" : "Backfill this event"),
                  ),
                ],
              ),
            ],
```

And to `_SettingsSheetState`:

```dart
  final _sheetCtrl = TextEditingController();
  String? _sheetId;
  String? _sheetError;
  bool _saving = false;
  bool _backfilling = false;

  Future<void> _saveSheet() async {
    final teamId = ref.read(currentTeamIdProvider);
    if (teamId == null) return;

    setState(() {
      _saving = true;
      _sheetError = null;
    });

    try {
      final stored = await ref.read(teamRepositoryProvider).setTeamSheet(
            teamId: teamId,
            sheetId: _sheetCtrl.text,
          );
      if (!mounted) return;
      setState(() => _sheetId = stored);
    } catch (e) {
      // The callable's failed-precondition message names the service
      // account to share the sheet with — surface it verbatim.
      if (!mounted) return;
      setState(() => _sheetError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _backfillEvent() async {
    final eventId = ref.read(currentEventIdProvider);
    if (eventId == null) return;

    setState(() => _backfilling = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('backfill_event_to_sheets')
          .call<Map<String, dynamic>>({'eventId': eventId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Backfill complete")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Backfill failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _backfilling = false);
    }
  }
```

Load the current value in `initState` via `getTeamSettings(teamId)`, setting `_sheetId` and `_sheetCtrl.text`. Dispose `_sheetCtrl` alongside the existing controllers. If `teamRepositoryProvider` does not already exist, add it next to the other repository providers rather than constructing `TeamRepository()` inline — the widget tests need to override it.

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd frontend && flutter test && flutter analyze
```

Expected: all tests pass, no analyzer issues.

- [ ] **Step 7: Commit**

```bash
git add frontend/
git commit -m "feat(ui): add per-team sheets export settings"
```

---

### Task 9: Full verification, docs, and deploy

Deployment is irreversible and outward-facing. **Do not run Step 4 onward without the user present and agreeing.**

**Files:**
- Modify: `CLAUDE.md` (architecture and secrets sections)

- [ ] **Step 1: Run every suite and record real numbers**

```bash
cd frontend && flutter test 2>&1 | tail -5
cd ../functions && ./venv/bin/python -m pytest tests/ -q 2>&1 | tail -5
cd .. && firebase emulators:exec --only firestore "cd test/firestore-rules && ./node_modules/.bin/jest --runInBand" 2>&1 | tail -10
```

Record the actual counts. Do not claim success without pasting the output.

- [ ] **Step 2: Verify the reverse path is genuinely gone**

```bash
grep -rn "update_match_from_sheets\|sync_from_sheets_http\|SYNC_API_KEY\|sync_tracking\|SyncTracker\|lastSyncSource\|MASTER_SPREADSHEET_ID" \
  functions frontend/lib firestore.rules firebase.json 2>/dev/null | grep -v node_modules
```

Expected: no hits. Hits in `docs/` are fine — they are history.

- [ ] **Step 3: Update `CLAUDE.md`**

In the **Firestore Collections** section, delete the `sync_tracking` bullet.

In the **Cloud Functions** section, delete the `update_match_from_sheets` / `sync_from_sheets_http` bullet and the `sync_tracker.py` bullet, and add:

```markdown
- `set_team_sheet` — admin-only callable that validates a team's spreadsheet (write probe against the service account) and stores it at `teamSettings/{teamId}.googleSheetId`. Clients cannot write that field; rules deny it.
```

Amend the `on_match_written` bullet to note it is **one-way** (Firestore → Sheets only), resolves the target from the team's `googleSheetId`, no-ops when unset, and finds rows by searching the sheet rather than a tracker.

In **Key Technical Details**, change the Firebase secrets line to: `GOOGLE_SHEETS_CREDENTIALS`, `TBA_API_KEY`.

In the **Active roadmap** section, mark Step 2 shipped.

```bash
git add CLAUDE.md
git commit -m "docs: record one-way sheets export"
```

- [ ] **Step 4: Deploy rules first — CONFIRM WITH USER**

Rules before functions, so no window exists where a client can still write `googleSheetId`.

```bash
firebase deploy --only firestore:rules
```

- [ ] **Step 5: Deploy functions — CONFIRM WITH USER**

Deploying all functions validates all secrets, and `SYNC_API_KEY` is gone — so name them:

```bash
firebase deploy --only functions:on_match_written,functions:backfill_event_to_sheets,functions:set_team_sheet
```

Then delete the removed functions explicitly (the CLI will not remove them under `--only`):

```bash
firebase functions:delete update_match_from_sheets sync_from_sheets_http
```

- [ ] **Step 6: Remove dead secrets and data — CONFIRM WITH USER**

```bash
firebase functions:secrets:destroy SYNC_API_KEY
firebase functions:secrets:destroy MASTER_SPREADSHEET_ID
```

Delete the `sync_tracking` collection via the Firebase console. The user has confirmed all current data is test data.

- [ ] **Step 7: Verify end-to-end against the empty-DB first-run path**

Step 1 shipped two production bugs that were both first-run-only, because the rules were validated only against seeded data. Explicitly exercise the cold path:

1. As a team admin with **no sheet configured**, record a match. Confirm it saves, and that `on_match_written` logs the skip without erroring (`firebase functions:log --only on_match_written`).
2. Paste a sheet URL that has **not** been shared with the service account. Confirm the inline error names the service-account address.
3. Share the sheet as Editor, save again. Confirm success.
4. Hit **Backfill this event**. Confirm the earlier match appears, in a tab named with the bare event code.
5. Record a second match. Confirm it appends as a new row.
6. Edit that match. Confirm the existing row updates in place — no duplicate.
7. Trash it. Confirm the row disappears and the remaining row is still correct.
8. Re-run backfill. Confirm no duplicate rows appear.

- [ ] **Step 8: Final commit**

```bash
git add -A
git commit -m "chore(config): complete one-way sheets export rollout"
```
