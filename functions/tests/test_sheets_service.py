"""Tests for Google Sheets service."""

import unittest
from unittest.mock import Mock, patch, MagicMock
import json
from datetime import datetime

from services.sheets_service import SheetsService, get_sheets_service, FRC_HEADERS, FTC_HEADERS, _col_letter, _rating


class TestColLetter(unittest.TestCase):
    """Test column letter helper."""

    def test_single_letters(self):
        self.assertEqual(_col_letter(1), 'A')
        self.assertEqual(_col_letter(19), 'S')
        self.assertEqual(_col_letter(26), 'Z')

    def test_double_letters(self):
        self.assertEqual(_col_letter(27), 'AA')
        self.assertEqual(_col_letter(28), 'AB')


class TestSheetsService(unittest.TestCase):
    """Test cases for SheetsService."""

    def setUp(self):
        """Set up test fixtures."""
        self.mock_credentials = json.dumps({
            "type": "service_account",
            "project_id": "test-project",
            "private_key_id": "test-key-id",
            "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC5Z5Z5Z5Z5Z5Z5\n-----END PRIVATE KEY-----\n",
            "client_email": "test@test-project.iam.gserviceaccount.com",
            "client_id": "123456789",
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token"
        })

    @patch('services.sheets_service.build')
    @patch('services.sheets_service.service_account.Credentials')
    def test_init(self, mock_creds_class, mock_build):
        """Test SheetsService initialization."""
        mock_creds = Mock()
        mock_creds_class.from_service_account_info.return_value = mock_creds
        mock_service = Mock()
        mock_build.return_value = mock_service

        service = SheetsService(self.mock_credentials)

        mock_creds_class.from_service_account_info.assert_called_once()
        mock_build.assert_called_once_with('sheets', 'v4', credentials=mock_creds)

    def test_frc_headers(self):
        """Test that FRC headers match the 25-column schema."""
        self.assertEqual(len(FRC_HEADERS), 25)
        self.assertEqual(FRC_HEADERS[0], "Timestamp")
        self.assertEqual(FRC_HEADERS[1], "Match ID")
        self.assertEqual(FRC_HEADERS[6], "Auto Fuel")
        self.assertEqual(FRC_HEADERS[13], "Trench Traverse")
        self.assertEqual(FRC_HEADERS[18], "Drivetrain Speed (/5)")
        self.assertEqual(FRC_HEADERS[19], "Intake Speed (/5)")
        self.assertEqual(FRC_HEADERS[20], "Shooter Speed (/5)")
        self.assertEqual(FRC_HEADERS[21], "Defense Cause")
        self.assertEqual(FRC_HEADERS[22], "Died At")
        self.assertEqual(FRC_HEADERS[23], "Died Reason")
        self.assertEqual(FRC_HEADERS[24], "Comments")

    def test_ftc_headers(self):
        """Test that FTC headers match the 22-column schema."""
        self.assertEqual(len(FTC_HEADERS), 22)
        self.assertEqual(FTC_HEADERS[0], "Timestamp")
        self.assertEqual(FTC_HEADERS[6], "Leave")
        self.assertEqual(FTC_HEADERS[7], "Auto Artifacts")
        self.assertEqual(FTC_HEADERS[11], "Base Expansion")
        self.assertEqual(FTC_HEADERS[14], "Defense Rating (/5)")
        self.assertEqual(FTC_HEADERS[15], "Drivetrain Speed (/5)")
        self.assertEqual(FTC_HEADERS[16], "Intake Speed (/5)")
        self.assertEqual(FTC_HEADERS[17], "Shooter Speed (/5)")
        self.assertEqual(FTC_HEADERS[18], "Defense Cause")
        self.assertEqual(FTC_HEADERS[19], "Died At")
        self.assertEqual(FTC_HEADERS[20], "Died Reason")
        self.assertEqual(FTC_HEADERS[21], "Comments")

    def test_transform_frc_report(self):
        """Test transforming FRC match report to row format."""
        with patch('services.sheets_service.build'), \
             patch('services.sheets_service.service_account.Credentials'):
            service = SheetsService(self.mock_credentials)

        report_data = {
            'matchId': 'qm1_254',
            'matchNumber': 1,
            'teamNumber': 254,
            'alliance': 'Red',
            'scouterName': 'Test Scouter',
            'gameData': {
                'auto_fuel': 5,
                'auto_tower_l1': True,
                'teleop_fuel': 15,
                'teleop_tower_level': 3,
                'defense_rating': 3,
                'driver_skill': 4,
                'robot_died': True,
                'trench_traverse': True,
                'bump_traverse': False,
                'shooting_range_close': True,
                'shooting_range_mid': False,
                'shooting_range_far': False,
                'drivetrain_speed': 4,
                'intake_speed': 2,
                'shooter_speed': 5,
                'defense_cause': 'broke',
                'died_at_seconds': 65,
                'died_reason': 'tipped on the ramp',
            },
            'comments': 'Great performance',
            'createdAt': datetime(2026, 2, 17, 10, 30, 0)
        }

        result = service.transform_match_report(report_data)

        self.assertEqual(len(result), len(FRC_HEADERS))  # 25 columns
        self.assertEqual(result[1], 'qm1_254')       # Match ID
        self.assertEqual(result[2], 1)                 # Match #
        self.assertEqual(result[3], 254)               # Team #
        self.assertEqual(result[4], 'Red')             # Alliance
        self.assertEqual(result[5], 'Test Scouter')    # Scouter
        self.assertEqual(result[6], 5)                 # Auto Fuel
        self.assertEqual(result[7], 'Yes')             # Auto L1 Hang
        self.assertEqual(result[8], 15)                # Teleop Fuel
        self.assertEqual(result[9], 'Level 3')         # Climb Level
        self.assertEqual(result[10], 3)            # Defense Rating
        self.assertEqual(result[11], 4)            # Driver Skill
        self.assertEqual(result[12], 'Yes')            # Robot Died
        self.assertEqual(result[13], 'Yes')            # Trench Traverse
        self.assertEqual(result[14], 'No')             # Bump Traverse
        self.assertEqual(result[15], 'Yes')            # Shooting Close
        self.assertEqual(result[16], 'No')             # Shooting Mid
        self.assertEqual(result[17], 'No')             # Shooting Far
        self.assertEqual(result[18], 4)            # Drivetrain Speed
        self.assertEqual(result[19], 2)            # Intake Speed
        self.assertEqual(result[20], 5)            # Shooter Speed
        self.assertEqual(result[21], 'Robot Broke')    # Defense Cause
        self.assertEqual(result[22], '1:05')           # Died At
        self.assertEqual(result[23], 'tipped on the ramp')  # Died Reason
        self.assertEqual(result[24], 'Great performance')  # Comments

    def test_transform_frc_report_without_a_defense_cause_or_death(self):
        """Cause/died columns stay blank when the robot never died and no
        cause was recorded — the common case, most matches have neither."""
        with patch('services.sheets_service.build'), \
             patch('services.sheets_service.service_account.Credentials'):
            service = SheetsService(self.mock_credentials)

        report_data = {
            'matchId': 'qm2_254',
            'matchNumber': 2,
            'teamNumber': 254,
            'alliance': 'Red',
            'scouterName': 'Test Scouter',
            'gameData': {
                'defense_rating': 0,
                'robot_died': False,
            },
            'comments': '',
            'createdAt': datetime(2026, 2, 17, 10, 30, 0)
        }

        result = service.transform_match_report(report_data)

        self.assertEqual(result[21], '')  # Defense Cause
        self.assertEqual(result[22], '')  # Died At
        self.assertEqual(result[23], '')  # Died Reason

    def test_transform_ftc_report(self):
        """Test transforming FTC match report to row format."""
        with patch('services.sheets_service.build'), \
             patch('services.sheets_service.service_account.Credentials'):
            service = SheetsService(self.mock_credentials)

        report_data = {
            'matchId': 'ftc_qm1_12345',
            'matchNumber': 1,
            'teamNumber': 12345,
            'alliance': 'Blue',
            'scouterName': 'FTC Scouter',
            'programType': 'FTC',
            'gameData': {
                'leave': True,
                'artifacts_auto': 3,
                'indexing_auto': True,
                'artifacts_teleop': 8,
                'indexing_teleop': False,
                'base_expansion': 'Full',
                'driver_quality': 4.0,
                'robot_died': False,
                'defense_rating': 2,
                'drivetrain_speed': 3,
                'intake_speed': 3,
                'shooter_speed': 3,
                'defense_cause': 'strategic',
            },
            'comments': 'Solid match',
            'createdAt': datetime(2026, 3, 1, 14, 0, 0)
        }

        result = service.transform_match_report(report_data)

        self.assertEqual(len(result), len(FTC_HEADERS))  # 22 columns
        self.assertEqual(result[1], 'ftc_qm1_12345')  # Match ID
        self.assertEqual(result[4], 'Blue')             # Alliance
        self.assertEqual(result[6], 'Yes')              # Leave
        self.assertEqual(result[7], 3)                  # Auto Artifacts
        self.assertEqual(result[8], 'Yes')              # Auto Indexing
        self.assertEqual(result[9], 8)                  # Teleop Artifacts
        self.assertEqual(result[10], 'No')              # Teleop Indexing
        self.assertEqual(result[11], 'Full')            # Base Expansion
        self.assertEqual(result[12], 4)             # Driver Quality
        self.assertEqual(result[13], 'No')              # Robot Died
        self.assertEqual(result[14], 2)             # Defense Rating
        self.assertEqual(result[15], 3)             # Drivetrain Speed
        self.assertEqual(result[16], 3)             # Intake Speed
        self.assertEqual(result[17], 3)             # Shooter Speed
        self.assertEqual(result[18], 'Strategic')       # Defense Cause
        self.assertEqual(result[19], '')                # Died At (not set)
        self.assertEqual(result[20], '')                # Died Reason (not set)

    def test_transform_frc_robot_died_true(self):
        """Test robot died field reads from gameData.robot_died."""
        with patch('services.sheets_service.build'), \
             patch('services.sheets_service.service_account.Credentials'):
            service = SheetsService(self.mock_credentials)

        report_data = {
            'matchId': 'qm2_254',
            'matchNumber': 2,
            'teamNumber': 254,
            'alliance': 'Blue',
            'scouterName': 'Test',
            'gameData': {
                'auto_fuel': 0,
                'auto_tower_l1': False,
                'teleop_fuel': 0,
                'teleop_tower_level': 0,
                'defense_rating': 0,
                'driver_skill': 0,
                'robot_died': True,
                'trench_traverse': False,
                'bump_traverse': False,
                'shooting_range_close': False,
                'shooting_range_mid': False,
                'shooting_range_far': False,
            },
            'comments': 'Mechanical failure',
            'createdAt': datetime(2026, 2, 17, 11, 0, 0)
        }

        result = service.transform_match_report(report_data)
        self.assertEqual(result[12], 'Yes')  # Robot Died

    def test_delete_row(self):
        """Test deleting a row from the sheet."""
        with patch('services.sheets_service.build') as mock_build, \
             patch('services.sheets_service.service_account.Credentials'):
            mock_service = Mock()
            mock_build.return_value = mock_service

            mock_get = Mock()
            mock_get.execute.return_value = {
                'sheets': [{'properties': {'title': '2026test', 'sheetId': 0}}]
            }
            mock_service.spreadsheets().get.return_value = mock_get

            mock_batch = Mock()
            mock_batch.execute.return_value = {}
            mock_service.spreadsheets().batchUpdate.return_value = mock_batch

            service = SheetsService(self.mock_credentials)
            result = service.delete_row('spreadsheet_id', '2026test', 5)

            self.assertTrue(result)
            mock_service.spreadsheets().batchUpdate.assert_called_once()

    def test_find_row_by_report_id(self):
        """Reconstructs report_id from (matchId, teamNumber) columns.

        Real sheet rows store matchId in column B and teamNumber in
        column D — the Firestore report_id is the concatenation of the
        two, never written as-is into any single column.
        """
        with patch('services.sheets_service.build') as mock_build, \
             patch('services.sheets_service.service_account.Credentials'):
            mock_service = Mock()
            mock_build.return_value = mock_service

            mock_values = Mock()
            mock_values.execute.return_value = {
                'values': [
                    ['Timestamp', 'Match ID', 'Match #', 'Team #'],
                    ['2026-02-17 10:00:00', '2026waore_qm1', '1', '254'],
                    ['2026-02-17 10:15:00', '2026waore_qm2', '2', '118'],
                    ['2026-02-17 10:30:00', '2026waore_qm3', '3', '254'],
                ]
            }
            mock_service.spreadsheets().values().get.return_value = mock_values

            service = SheetsService(self.mock_credentials)
            result = service.find_row_by_report_id(
                'spreadsheet_id', '2026waore', '2026waore_qm2_118'
            )

            self.assertEqual(result, 3)  # Row 3 (1-indexed, header is row 1)

    def test_find_row_by_report_id_legacy_matchid_column(self):
        """Falls back to a direct column-B match for any legacy rows
        that stored the report_id verbatim in the Match ID column."""
        with patch('services.sheets_service.build') as mock_build, \
             patch('services.sheets_service.service_account.Credentials'):
            mock_service = Mock()
            mock_build.return_value = mock_service

            mock_values = Mock()
            mock_values.execute.return_value = {
                'values': [
                    ['Timestamp', 'Match ID', 'Match #', 'Team #'],
                    ['2026-02-17 10:00:00', 'legacy_qm1_254', '1', '254'],
                ]
            }
            mock_service.spreadsheets().values().get.return_value = mock_values

            service = SheetsService(self.mock_credentials)
            result = service.find_row_by_report_id(
                'spreadsheet_id', '2026waore', 'legacy_qm1_254'
            )

            self.assertEqual(result, 2)

    def test_find_row_by_report_id_not_found(self):
        """Test finding a row that doesn't exist."""
        with patch('services.sheets_service.build') as mock_build, \
             patch('services.sheets_service.service_account.Credentials'):
            mock_service = Mock()
            mock_build.return_value = mock_service

            mock_values = Mock()
            mock_values.execute.return_value = {
                'values': [
                    ['Timestamp', 'Match ID', 'Match #', 'Team #'],
                    ['2026-02-17 10:00:00', '2026waore_qm1', '1', '254'],
                ]
            }
            mock_service.spreadsheets().values().get.return_value = mock_values

            service = SheetsService(self.mock_credentials)
            result = service.find_row_by_report_id(
                'spreadsheet_id', '2026waore', 'nonexistent'
            )

            self.assertIsNone(result)


class TestGetSheetsService(unittest.TestCase):
    """Test cases for get_sheets_service singleton."""

    @patch.dict('os.environ', {'GOOGLE_SHEETS_CREDENTIALS': '{"test": "credentials"}'})
    @patch('services.sheets_service.SheetsService')
    def test_singleton_pattern(self, mock_service_class):
        """Test that get_sheets_service returns singleton."""
        mock_instance = Mock()
        mock_service_class.return_value = mock_instance

        # Reset singleton for test
        import services.sheets_service as ss
        ss._sheets_service = None

        service1 = get_sheets_service()
        mock_service_class.assert_called_once()

        service2 = get_sheets_service()
        mock_service_class.assert_called_once()

        self.assertEqual(service1, service2)

    @patch.dict('os.environ', {}, clear=True)
    def test_missing_credentials(self):
        """Test error when credentials not set."""
        import services.sheets_service as ss
        ss._sheets_service = None

        with self.assertRaises(ValueError) as context:
            get_sheets_service()

        self.assertIn("GOOGLE_SHEETS_CREDENTIALS not set", str(context.exception))


class TestVerifyWriteAccess(unittest.TestCase):
    """The write probe is what turns a competition-day mystery into an
    actionable 'share the sheet' message at configure time."""

    def _service(self):
        from services.sheets_service import SheetsService
        svc = SheetsService.__new__(SheetsService)
        svc.service = MagicMock()
        return svc

    def test_true_when_title_read_and_rewritten_successfully(self):
        svc = self._service()
        svc.service.spreadsheets.return_value.get.return_value.execute.return_value = {
            'properties': {'title': 'Scouting'},
        }
        batch_update = svc.service.spreadsheets.return_value.batchUpdate

        self.assertTrue(svc.verify_write_access('sheet-abc'))

        batch_update.assert_called_once()
        _, kwargs = batch_update.call_args
        self.assertEqual(kwargs['spreadsheetId'], 'sheet-abc')
        sent_title = kwargs['body']['requests'][0][
            'updateSpreadsheetProperties'
        ]['properties']['title']
        self.assertEqual(sent_title, 'Scouting')

    def test_false_on_http_error_from_initial_read(self):
        from googleapiclient.errors import HttpError
        svc = self._service()
        resp = MagicMock()
        resp.status = 403
        svc.service.spreadsheets.return_value.get.return_value.execute.side_effect = (
            HttpError(resp, b'forbidden')
        )

        self.assertFalse(svc.verify_write_access('sheet-abc'))
        svc.service.spreadsheets.return_value.batchUpdate.assert_not_called()

    def test_false_on_http_error_from_write_viewer_share(self):
        """Regression test: a Viewer-level share can read metadata but is
        denied the write. This must fail against a read-only probe."""
        from googleapiclient.errors import HttpError
        svc = self._service()
        svc.service.spreadsheets.return_value.get.return_value.execute.return_value = {
            'properties': {'title': 'Scouting'},
        }
        resp = MagicMock()
        resp.status = 403
        svc.service.spreadsheets.return_value.batchUpdate.return_value.execute.side_effect = (
            HttpError(resp, b'forbidden')
        )

        self.assertFalse(svc.verify_write_access('sheet-abc'))


if __name__ == '__main__':
    unittest.main()


class TestVerifyWriteAccessCredentialFailures(unittest.TestCase):
    """A bad/rotated service-account credential is an OPERATOR problem, not a
    sharing problem. It must not be reported as 'share your sheet' — that
    sends the admin chasing a setting they already got right."""

    def _service(self):
        from services.sheets_service import SheetsService
        svc = SheetsService.__new__(SheetsService)
        svc.service = MagicMock()
        return svc

    def test_raises_credentials_error_when_read_auth_fails(self):
        from google.auth.exceptions import RefreshError
        from services.sheets_service import SheetsCredentialsError

        svc = self._service()
        svc.service.spreadsheets.return_value.get.return_value.execute.side_effect = (
            RefreshError('invalid_grant')
        )

        with self.assertRaises(SheetsCredentialsError):
            svc.verify_write_access('sheet-abc')

    def test_raises_credentials_error_when_write_auth_fails(self):
        from google.auth.exceptions import RefreshError
        from services.sheets_service import SheetsCredentialsError

        svc = self._service()
        svc.service.spreadsheets.return_value.get.return_value.execute.return_value = {
            'properties': {'title': 'Scouting'},
        }
        svc.service.spreadsheets.return_value.batchUpdate.return_value.execute.side_effect = (
            RefreshError('invalid_grant')
        )

        with self.assertRaises(SheetsCredentialsError):
            svc.verify_write_access('sheet-abc')

    def test_http_error_still_returns_false_not_raises(self):
        """The sharing path must be unaffected by the credentials handling."""
        from googleapiclient.errors import HttpError
        svc = self._service()
        resp = MagicMock()
        resp.status = 403
        svc.service.spreadsheets.return_value.get.return_value.execute.side_effect = (
            HttpError(resp, b'forbidden')
        )

        self.assertFalse(svc.verify_write_access('sheet-abc'))


class TestRating(unittest.TestCase):
    def test_numbers_not_strings(self):
        self.assertEqual(_rating(4), 4)
        self.assertIsInstance(_rating(4.0), int)
        self.assertEqual(_rating(3.5), 3.5)

    def test_missing_or_bad_is_blank_but_zero_is_zero(self):
        for v in (None, '', 'x', float('nan'), float('inf')):
            self.assertEqual(_rating(v), '')
        self.assertEqual(_rating(0), 0)


class TestSheetStyling(unittest.TestCase):
    """_style_sheet is formatting only and must never break a sync."""

    def _service(self):
        svc = SheetsService.__new__(SheetsService)
        svc.service = MagicMock()
        return svc

    def _requests(self, svc):
        return svc.service.spreadsheets().batchUpdate.call_args.kwargs['body']['requests']

    def test_freezes_header_filters_and_bands_in_one_batch(self):
        svc = self._service()
        svc._style_sheet('sid', 7, 'FRC')
        self.assertEqual(svc.service.spreadsheets().batchUpdate.call_count, 1)
        kinds = [next(iter(r)) for r in self._requests(svc)]
        for kind in ('updateSheetProperties', 'setBasicFilter', 'addBanding'):
            self.assertIn(kind, kinds)

    def test_never_writes_cell_values(self):
        svc = self._service()
        svc._style_sheet('sid', 7, 'FTC')
        self.assertFalse(svc.service.spreadsheets().values.called)
        for r in self._requests(svc):
            self.assertNotIn('updateCells', r)

    def test_sets_a_width_for_every_column(self):
        for program, headers in (('FRC', FRC_HEADERS), ('FTC', FTC_HEADERS)):
            svc = self._service()
            svc._style_sheet('sid', 7, program)
            widths = [r for r in self._requests(svc)
                      if r.get('updateDimensionProperties', {}).get('range', {}).get('dimension') == 'COLUMNS']
            self.assertEqual(len(widths), len(headers))

    def test_highlight_rules_point_at_the_right_columns(self):
        svc = self._service()
        svc._style_sheet('sid', 7, 'FRC')
        rules = [r['addConditionalFormatRule']['rule'] for r in self._requests(svc)
                 if 'addConditionalFormatRule' in r]
        died_col = _col_letter(FRC_HEADERS.index('Robot Died') + 1)
        alliance_col = _col_letter(FRC_HEADERS.index('Alliance') + 1)
        formulas = [r['booleanRule']['condition']['values'][0]['userEnteredValue'] for r in rules]
        self.assertIn(f'=${died_col}2="Yes"', formulas)
        self.assertIn(f'=LOWER(${alliance_col}2)="red"', formulas)

    def test_styling_failure_is_swallowed(self):
        svc = self._service()
        svc.service.spreadsheets().batchUpdate().execute.side_effect = Exception('boom')
        svc._style_sheet('sid', 7, 'FRC')  # must not raise

    def test_existing_unstyled_tab_gets_styled_once(self):
        svc = self._service()
        svc._style_existing_sheet = Mock()
        svc._ensure_column_count = Mock()
        get = svc.service.spreadsheets().get
        get().execute.return_value = {'sheets': [{'properties': {
            'title': 'evt', 'sheetId': 3, 'gridProperties': {'columnCount': 25}}}]}
        svc.get_or_create_sheet('sid', 'evt', 'FRC')
        svc._style_existing_sheet.assert_called_once_with('sid', 'evt', 3, 'FRC', [])

        svc._style_existing_sheet.reset_mock()
        get().execute.return_value = {'sheets': [{'properties': {
            'title': 'evt', 'sheetId': 3,
            'gridProperties': {'columnCount': 25, 'frozenRowCount': 1}}}]}
        svc.get_or_create_sheet('sid', 'evt', 'FRC')
        svc._style_existing_sheet.assert_not_called()

    def _legacy(self, row1):
        svc = self._service()
        svc._style_sheet = Mock()
        svc._write_headers = Mock()
        svc.service.spreadsheets().values().get().execute.return_value = {'values': [row1]}
        svc._style_existing_sheet('sid', 'evt', 3, 'FRC', [11])
        return svc

    def test_legacy_tab_same_layout_gets_new_headers_and_highlights(self):
        svc = self._legacy([h.replace(' (/5)', '') for h in FRC_HEADERS])
        svc._write_headers.assert_called_once()
        svc._style_sheet.assert_called_once_with('sid', 3, 'FRC', [11], highlight=True)

    def test_legacy_tab_other_layout_keeps_headers_and_skips_highlights(self):
        svc = self._legacy(['Timestamp', 'Match ID', 'Match #'])
        svc._write_headers.assert_not_called()
        svc._style_sheet.assert_called_once_with('sid', 3, 'FRC', [11], highlight=False)

    def test_existing_banding_is_deleted_before_adding(self):
        svc = self._service()
        svc._style_sheet('sid', 3, 'FRC', existing_banding_ids=[11])
        kinds = [next(iter(r)) for r in self._requests(svc)]
        self.assertLess(kinds.index('deleteBanding'), kinds.index('addBanding'))

    def test_match_id_is_hidden_not_removed(self):
        for program, headers in (('FRC', FRC_HEADERS), ('FTC', FTC_HEADERS)):
            svc = self._service()
            svc._style_sheet('sid', 7, program)
            col = headers.index('Match ID')
            self.assertEqual(col, 1)  # find_row_by_report_id reads column B
            hidden = [r['updateDimensionProperties'] for r in self._requests(svc)
                      if r.get('updateDimensionProperties', {}).get('properties', {}).get('hiddenByUser')]
            self.assertEqual([h['range']['startIndex'] for h in hidden], [col])

    def test_unfrozen_tab_with_our_color_is_not_restyled(self):
        svc = self._service()
        svc._style_existing_sheet = Mock()
        svc._ensure_column_count = Mock()
        svc.service.spreadsheets().get().execute.return_value = {'sheets': [{'properties': {
            'title': 'evt', 'sheetId': 3,
            'gridProperties': {'columnCount': 25},  # user unfroze the header
            'tabColorStyle': {'rgbColor': {'red': 0.122, 'green': 0.161, 'blue': 0.216}},
        }}]}
        svc.get_or_create_sheet('sid', 'evt', 'FRC')
        svc._style_existing_sheet.assert_not_called()

    def test_a_foreign_tab_color_does_not_count_as_styled(self):
        svc = self._service()
        svc._style_existing_sheet = Mock()
        svc._ensure_column_count = Mock()
        svc.service.spreadsheets().get().execute.return_value = {'sheets': [{'properties': {
            'title': 'evt', 'sheetId': 3,
            'gridProperties': {'columnCount': 25},
            'tabColorStyle': {'rgbColor': {'red': 1.0}},
        }}]}
        svc.get_or_create_sheet('sid', 'evt', 'FRC')
        svc._style_existing_sheet.assert_called_once()

    def test_styling_sets_the_tab_color_marker(self):
        svc = self._service()
        svc._style_sheet('sid', 7, 'FRC')
        props = [r['updateSheetProperties'] for r in self._requests(svc)
                 if 'updateSheetProperties' in r][0]
        self.assertIn('tabColorStyle', props['properties'])
        self.assertIn('tabColorStyle', props['fields'])

