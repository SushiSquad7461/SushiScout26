"""Tests for main.py — team isolation helpers and soft-delete propagation."""

import unittest
from unittest.mock import Mock, patch, MagicMock

# Patch initialize_app before importing main, since it runs at import time
# and would otherwise try to contact real Firebase services.
with patch('firebase_admin.initialize_app'):
    import main  # noqa: E402


class TestIsTeamMember(unittest.TestCase):
    """Membership is now read from the token's `teams` custom claim."""

    def test_none_token_returns_false(self):
        self.assertFalse(main._is_team_member(None, 'team1'))

    def test_empty_team_returns_false(self):
        self.assertFalse(main._is_team_member({'teams': {'team1': 'admin'}}, ''))

    def test_true_when_team_in_claim(self):
        self.assertTrue(main._is_team_member({'teams': {'team1': 'admin'}}, 'team1'))

    def test_false_when_team_not_in_claim(self):
        self.assertFalse(main._is_team_member({'teams': {'team2': 'member'}}, 'team1'))

    def test_false_when_no_teams_claim(self):
        self.assertFalse(main._is_team_member({'email': 'a@b.c'}, 'team1'))


class TestResolveEventProgramType(unittest.TestCase):
    """The event doc is authoritative for programType — match-doc field is
    only used as a fallback so legacy / external writes can't lock an FTC
    event's sheet to FRC columns."""

    def setUp(self):
        main._db = None

    @patch('main.get_db')
    def test_uses_event_doc_when_present(self, mock_get_db):
        event_doc = Mock(exists=True)
        event_doc.to_dict.return_value = {'programType': 'FTC'}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = event_doc

        self.assertEqual(
            main._resolve_event_program_type('e1', {'programType': 'FRC'}),
            'FTC',
        )

    @patch('main.get_db')
    def test_falls_back_to_report_when_event_missing(self, mock_get_db):
        event_doc = Mock(exists=False)
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = event_doc

        self.assertEqual(
            main._resolve_event_program_type('e1', {'programType': 'FTC'}),
            'FTC',
        )

    @patch('main.get_db')
    def test_defaults_to_frc_when_nothing_known(self, mock_get_db):
        event_doc = Mock(exists=False)
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = event_doc

        self.assertEqual(main._resolve_event_program_type('e1', None), 'FRC')


class TestOnMatchWrittenSoftDelete(unittest.TestCase):
    """The trigger must route soft-delete transitions to the delete path
    instead of pushing the row to Sheets again."""

    def _build_event(self, before, after):
        evt = Mock()
        evt.params = {'reportId': 'rep1'}
        evt.data = Mock()
        evt.data.before = Mock()
        evt.data.before.to_dict.return_value = before
        evt.data.before.__bool__ = lambda self: before is not None
        evt.data.after = Mock()
        evt.data.after.to_dict.return_value = after
        evt.data.after.__bool__ = lambda self: after is not None
        if before is None:
            evt.data.before = None
        if after is None:
            evt.data.after = None
        return evt

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_soft_delete_transition_calls_delete_helper(self, mock_sync, mock_delete):
        after = {'eventId': 'e1', 'isDeleted': True}
        evt = self._build_event(
            before={'eventId': 'e1', 'isDeleted': False},
            after=after,
        )
        main.on_match_written.__wrapped__(evt)
        mock_delete.assert_called_once_with('e1', 'rep1', after)
        mock_sync.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_update_to_already_trashed_match_is_ignored(self, mock_sync, mock_delete):
        evt = self._build_event(
            before={'eventId': 'e1', 'isDeleted': True},
            after={'eventId': 'e1', 'isDeleted': True, 'comments': 'edited'},
        )
        main.on_match_written.__wrapped__(evt)
        mock_delete.assert_not_called()
        mock_sync.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_restore_transition_appends_via_sync_report(self, mock_sync, mock_delete):
        evt = self._build_event(
            before={'eventId': 'e1', 'isDeleted': True},
            after={'eventId': 'e1', 'isDeleted': False},
        )
        main.on_match_written.__wrapped__(evt)
        mock_delete.assert_not_called()
        mock_sync.assert_called_once()
        args, kwargs = mock_sync.call_args
        self.assertEqual(args[0], 'e1')
        self.assertEqual(args[1], 'rep1')

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_hard_delete_calls_delete_helper(self, mock_sync, mock_delete):
        before = {'eventId': 'e1', 'isDeleted': False}
        evt = self._build_event(
            before=before,
            after=None,
        )
        main.on_match_written.__wrapped__(evt)
        mock_delete.assert_called_once_with('e1', 'rep1', before)
        mock_sync.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_schedule_shaped_doc_in_matches_is_skipped(self, mock_sync, mock_delete):
        # Legacy schedule rows (TBA/FTC sync used to write to /matches) have
        # compLevel set and no scouterName. They must not flow to Sheets.
        evt = self._build_event(
            before=None,
            after={
                'eventId': 'e1',
                'compLevel': 'qm',
                'matchNumber': 1,
                'programType': 'FRC',
            },
        )
        main.on_match_written.__wrapped__(evt)
        mock_sync.assert_not_called()
        mock_delete.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_soft_delete_with_legacy_sync_source_still_propagates(self, mock_sync, mock_delete):
        # A Sheets edit that flips isDeleted must NOT be silently swallowed
        # by the echo guard — the trigger still needs to remove the row.
        after = {
            'eventId': 'e1',
            'isDeleted': True,
            'lastSyncSource': 'sheets',
        }
        evt = self._build_event(
            before={'eventId': 'e1', 'isDeleted': False},
            after=after,
        )
        main.on_match_written.__wrapped__(evt)
        mock_delete.assert_called_once_with('e1', 'rep1', after)
        mock_sync.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_legacy_sheets_source_no_longer_blocks_sync(self, mock_sync, mock_delete):
        """lastSyncSource is dead residue on old docs — it must not suppress
        an export the way the removed echo guard did."""
        evt = self._build_event(
            before={'eventId': 'e1', 'lastSyncSource': 'sheets'},
            after={'eventId': 'e1', 'lastSyncSource': 'sheets', 'scouterName': 'sam'},
        )

        main.on_match_written.__wrapped__(evt)

        mock_sync.assert_called_once_with('e1', 'rep1', evt.data.after.to_dict.return_value)
        mock_delete.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_new_already_deleted_doc_is_skipped(self, mock_sync, mock_delete):
        evt = self._build_event(
            before=None,
            after={'eventId': 'e1', 'isDeleted': True, 'scouterName': 'sam'},
        )

        main.on_match_written.__wrapped__(evt)

        mock_sync.assert_not_called()
        mock_delete.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_delete_helper_receives_report_data(self, mock_sync, mock_delete):
        """The delete path needs the doc to resolve teamId -> spreadsheet."""
        before = {'eventId': 'e1', 'teamId': 't1', 'isDeleted': False}
        after = {'eventId': 'e1', 'teamId': 't1', 'isDeleted': True}
        evt = self._build_event(before=before, after=after)

        main.on_match_written.__wrapped__(evt)

        mock_delete.assert_called_once_with('e1', 'rep1', after)

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_real_report_with_complevel_still_syncs(self, mock_sync, mock_delete):
        # A genuine scouting report has scouterName set; compLevel alone
        # shouldn't disqualify it.
        evt = self._build_event(
            before=None,
            after={
                'eventId': 'e1',
                'compLevel': 'qm',
                'scouterName': 'Alice',
                'matchNumber': 1,
            },
        )
        main.on_match_written.__wrapped__(evt)
        mock_sync.assert_called_once()


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

        result = main.backfill_event_to_sheets.__wrapped__.__wrapped__(self._req())

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
            main.backfill_event_to_sheets.__wrapped__.__wrapped__(self._req())

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
            main.backfill_event_to_sheets.__wrapped__.__wrapped__(req)

        self.assertEqual(
            ctx.exception.code, main.https_fn.FunctionsErrorCode.PERMISSION_DENIED
        )


if __name__ == '__main__':
    unittest.main()
