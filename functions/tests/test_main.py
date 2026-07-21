"""Tests for main.py — team isolation helpers and soft-delete propagation."""

import os
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


class TestDeleteSheetRowForReport(unittest.TestCase):
    """Verify the shared delete helper used by hard+soft delete paths."""

    @patch('services.sheets_service.get_sheets_service')
    @patch('services.sync_tracker.SyncTracker')
    @patch.dict(os.environ, {'MASTER_SPREADSHEET_ID': 'sheet1'})
    def test_deletes_row_and_record_when_tracked(self, mock_tracker, mock_get_svc):
        mock_tracker.get_sync_record.return_value = {
            'rowNumber': 5,
            'sheetName': 'event1',
        }
        svc = mock_get_svc.return_value
        svc.delete_row.return_value = True

        main._delete_sheet_row_for_report('event1', 'rep1')

        svc.delete_row.assert_called_once_with('sheet1', 'event1', 5)
        mock_tracker.delete_sync_record.assert_called_once_with('event1', 'rep1')

    @patch('services.sheets_service.get_sheets_service')
    @patch('services.sync_tracker.SyncTracker')
    @patch.dict(os.environ, {'MASTER_SPREADSHEET_ID': 'sheet1'})
    def test_falls_back_to_find_by_id_when_row_delete_fails(self, mock_tracker, mock_get_svc):
        mock_tracker.get_sync_record.return_value = {
            'rowNumber': 5,
            'sheetName': 'event1',
        }
        svc = mock_get_svc.return_value
        svc.delete_row.side_effect = [False, True]
        svc.find_row_by_report_id.return_value = 7

        main._delete_sheet_row_for_report('event1', 'rep1')

        svc.find_row_by_report_id.assert_called_once_with('sheet1', 'event1', 'rep1')
        self.assertEqual(svc.delete_row.call_count, 2)
        svc.delete_row.assert_called_with('sheet1', 'event1', 7)

    @patch('services.sheets_service.get_sheets_service')
    @patch('services.sync_tracker.SyncTracker')
    @patch.dict(os.environ, {'MASTER_SPREADSHEET_ID': 'sheet1'})
    def test_no_sync_record_still_clears_tracker(self, mock_tracker, mock_get_svc):
        mock_tracker.get_sync_record.return_value = None
        svc = mock_get_svc.return_value

        main._delete_sheet_row_for_report('event1', 'rep1')

        svc.delete_row.assert_not_called()
        mock_tracker.delete_sync_record.assert_called_once_with('event1', 'rep1')

    @patch('services.sheets_service.get_sheets_service')
    @patch.dict(os.environ, {'MASTER_SPREADSHEET_ID': ''})
    def test_no_spreadsheet_id_is_a_noop(self, mock_get_svc):
        main._delete_sheet_row_for_report('event1', 'rep1')
        mock_get_svc.return_value.delete_row.assert_not_called()


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
        evt = self._build_event(
            before={'eventId': 'e1', 'isDeleted': False},
            after={'eventId': 'e1', 'isDeleted': True},
        )
        main.on_match_written.__wrapped__(evt)
        mock_delete.assert_called_once_with('e1', 'rep1')
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
        evt = self._build_event(
            before={'eventId': 'e1', 'isDeleted': False},
            after=None,
        )
        main.on_match_written.__wrapped__(evt)
        mock_delete.assert_called_once_with('e1', 'rep1')
        mock_sync.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    @patch('services.sync_tracker.SyncTracker')
    def test_new_already_deleted_doc_is_skipped(self, mock_tracker, mock_sync, mock_delete):
        evt = self._build_event(
            before=None,
            after={'eventId': 'e1', 'isDeleted': True},
        )
        main.on_match_written.__wrapped__(evt)
        mock_sync.assert_not_called()
        mock_delete.assert_not_called()

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
    def test_sheets_origin_update_is_skipped(self, mock_sync, mock_delete):
        # Sheets→Firestore writes stamp lastSyncSource='sheets'. The
        # trigger must not echo that data back to Sheets.
        evt = self._build_event(
            before={'eventId': 'e1', 'isDeleted': False, 'autoFuel': 1},
            after={
                'eventId': 'e1',
                'isDeleted': False,
                'autoFuel': 2,
                'lastSyncSource': 'sheets',
            },
        )
        main.on_match_written.__wrapped__(evt)
        mock_sync.assert_not_called()
        mock_delete.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_app_edit_after_sheets_edit_still_syncs(self, mock_sync, mock_delete):
        # Once the doc has been touched by Sheets, the very next app-side
        # update must still flow back to Sheets. App writes now stamp
        # lastSyncSource='app' explicitly so the guard distinguishes the
        # origin from the after-value alone.
        evt = self._build_event(
            before={
                'eventId': 'e1',
                'isDeleted': False,
                'autoFuel': 2,
                'lastSyncSource': 'sheets',
            },
            after={
                'eventId': 'e1',
                'isDeleted': False,
                'autoFuel': 3,
                'lastSyncSource': 'app',
            },
        )
        main.on_match_written.__wrapped__(evt)
        mock_sync.assert_called_once()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_repeated_sheets_edit_does_not_echo(self, mock_sync, mock_delete):
        # The previous guard required `before != 'sheets'`, so a SECOND
        # consecutive Sheets edit (before='sheets', after='sheets')
        # slipped through and got echoed back. The simplified guard
        # treats any after=='sheets' as a Sheets-origin write.
        evt = self._build_event(
            before={
                'eventId': 'e1',
                'isDeleted': False,
                'autoFuel': 2,
                'lastSyncSource': 'sheets',
            },
            after={
                'eventId': 'e1',
                'isDeleted': False,
                'autoFuel': 3,
                'lastSyncSource': 'sheets',
            },
        )
        main.on_match_written.__wrapped__(evt)
        mock_sync.assert_not_called()
        mock_delete.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    def test_sheets_origin_soft_delete_still_propagates(self, mock_sync, mock_delete):
        # A Sheets edit that flips isDeleted must NOT be silently swallowed
        # by the echo guard — the trigger still needs to remove the row.
        evt = self._build_event(
            before={'eventId': 'e1', 'isDeleted': False},
            after={
                'eventId': 'e1',
                'isDeleted': True,
                'lastSyncSource': 'sheets',
            },
        )
        main.on_match_written.__wrapped__(evt)
        mock_delete.assert_called_once_with('e1', 'rep1')
        mock_sync.assert_not_called()

    @patch.object(main, '_delete_sheet_row_for_report')
    @patch.object(main, 'sync_report_to_sheets')
    @patch('services.sync_tracker.SyncTracker')
    def test_real_report_with_complevel_still_syncs(self, mock_tracker, mock_sync, mock_delete):
        # A genuine scouting report has scouterName set; compLevel alone
        # shouldn't disqualify it.
        mock_tracker.get_sync_record.return_value = None
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


if __name__ == '__main__':
    unittest.main()
