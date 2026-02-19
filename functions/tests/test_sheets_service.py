"""Tests for Google Sheets service."""

import unittest
from unittest.mock import Mock, patch, MagicMock
import json
from datetime import datetime

from services.sheets_service import SheetsService, get_sheets_service, FRC_HEADERS


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
    
    def test_transform_match_report(self):
        """Test transforming match report to row format."""
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
                'teleop_fuel': 15,
                'teleop_tower_level': 3
            },
            'robotDied': False,
            'comments': 'Great performance',
            'createdAt': datetime(2026, 2, 17, 10, 30, 0)
        }
        
        result = service.transform_match_report(report_data)
        
        self.assertEqual(len(result), 11)  # Should match FRC_HEADERS length
        self.assertEqual(result[0], '2026-02-17T10:30:00')  # Timestamp
        self.assertEqual(result[1], 'qm1_254')  # Match ID
        self.assertEqual(result[2], 1)  # Match number
        self.assertEqual(result[3], 254)  # Team number
        self.assertEqual(result[4], 'Red')  # Alliance
        self.assertEqual(result[5], 'Test Scouter')  # Scouter
        self.assertEqual(result[6], 5)  # Auto fuel
        self.assertEqual(result[7], 15)  # Teleop fuel
        self.assertEqual(result[8], 3)  # Climb level
        self.assertEqual(result[9], 'No')  # Robot died
        self.assertEqual(result[10], 'Great performance')  # Comments
    
    def test_transform_match_report_robot_died_true(self):
        """Test robot died field when true."""
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
                'teleop_fuel': 0,
                'teleop_tower_level': 0
            },
            'robotDied': True,
            'comments': 'Mechanical failure',
            'createdAt': datetime(2026, 2, 17, 11, 0, 0)
        }
        
        result = service.transform_match_report(report_data)
        
        self.assertEqual(result[9], 'Yes')  # Robot died should be 'Yes'
    
    def test_frc_headers(self):
        """Test that FRC headers are correct."""
        expected_headers = [
            "Timestamp",
            "Match ID",
            "Match #",
            "Team #",
            "Alliance",
            "Scouter",
            "Auto Fuel",
            "Teleop Fuel",
            "Climb Level",
            "Robot Died",
            "Comments"
        ]
        
        self.assertEqual(FRC_HEADERS, expected_headers)
    
    def test_append_rows(self):
        """Test appending multiple rows at once."""
        with patch('services.sheets_service.build') as mock_build, \
             patch('services.sheets_service.service_account.Credentials'):
            mock_service = Mock()
            mock_build.return_value = mock_service
            
            mock_append_result = Mock()
            mock_append_result.execute.return_value = {
                'updates': {'updatedRange': '2026test!A5:K7'}
            }
            mock_service.spreadsheets().values().append.return_value = mock_append_result
            
            service = SheetsService(self.mock_credentials)
            rows = [
                ['2026-02-17T10:00:00', 'qm1_254', 1, 254, 'Red', 'Scouter', 5, 10, 3, 'No', ''],
                ['2026-02-17T10:15:00', 'qm2_118', 2, 118, 'Blue', 'Scouter', 3, 8, 2, 'No', ''],
            ]
            
            result = service.append_rows('spreadsheet_id', '2026test', rows)
            
            self.assertEqual(result, 5)
            mock_service.spreadsheets().values().append.assert_called_once()
    
    def test_append_rows_empty(self):
        """Test appending empty list returns 0."""
        with patch('services.sheets_service.build'), \
             patch('services.sheets_service.service_account.Credentials'):
            service = SheetsService(self.mock_credentials)
            result = service.append_rows('spreadsheet_id', '2026test', [])
            self.assertEqual(result, 0)
    
    def test_update_rows(self):
        """Test updating multiple rows in a single batch."""
        with patch('services.sheets_service.build') as mock_build, \
             patch('services.sheets_service.service_account.Credentials'):
            mock_service = Mock()
            mock_build.return_value = mock_service
            
            mock_batch_update = Mock()
            mock_batch_update.execute.return_value = {}
            mock_service.spreadsheets().values().batchUpdate.return_value = mock_batch_update
            
            service = SheetsService(self.mock_credentials)
            updates = [
                (5, ['2026-02-17T10:00:00', 'qm1_254', 1, 254, 'Red', 'Scouter', 5, 10, 3, 'No', 'updated']),
                (10, ['2026-02-17T10:15:00', 'qm2_118', 2, 118, 'Blue', 'Scouter', 3, 8, 2, 'No', 'updated']),
            ]
            
            service.update_rows('spreadsheet_id', '2026test', updates)
            
            mock_service.spreadsheets().values().batchUpdate.assert_called_once()
            call_args = mock_service.spreadsheets().values().batchUpdate.call_args
            self.assertEqual(len(call_args[1]['body']['data']), 2)
    
    def test_update_rows_empty(self):
        """Test updating with empty list does nothing."""
        with patch('services.sheets_service.build'), \
             patch('services.sheets_service.service_account.Credentials'):
            mock_service = Mock()
            service = SheetsService(self.mock_credentials)
            service.service = mock_service
            
            service.update_rows('spreadsheet_id', '2026test', [])
            
            mock_service.spreadsheets().values().batchUpdate.assert_not_called()


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
        
        # First call should create instance
        service1 = get_sheets_service()
        mock_service_class.assert_called_once()
        
        # Second call should return same instance
        service2 = get_sheets_service()
        mock_service_class.assert_called_once()  # Should not create new instance
        
        self.assertEqual(service1, service2)
    
    @patch.dict('os.environ', {}, clear=True)
    def test_missing_credentials(self):
        """Test error when credentials not set."""
        # Reset singleton
        import services.sheets_service as ss
        ss._sheets_service = None
        
        with self.assertRaises(ValueError) as context:
            get_sheets_service()
        
        self.assertIn("GOOGLE_SHEETS_CREDENTIALS not set", str(context.exception))


if __name__ == '__main__':
    unittest.main()
