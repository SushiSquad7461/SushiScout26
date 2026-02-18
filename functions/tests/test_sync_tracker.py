"""Tests for sync tracker."""

import unittest
from unittest.mock import Mock, patch, MagicMock

from services.sync_tracker import SyncTracker


class TestSyncTracker(unittest.TestCase):
    """Test cases for SyncTracker."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.event_id = "2026test"
        self.report_id = "report123"
    
    @patch('services.sync_tracker.db')
    def test_get_sync_record_exists(self, mock_db):
        """Test getting existing sync record."""
        mock_doc = Mock()
        mock_doc.exists = True
        mock_doc.to_dict.return_value = {
            'eventId': self.event_id,
            'reportId': self.report_id,
            'rowNumber': 5,
            'status': 'success'
        }
        
        mock_collection = Mock()
        mock_collection.document.return_value.get.return_value = mock_doc
        mock_db.collection.return_value = mock_collection
        
        result = SyncTracker.get_sync_record(self.event_id, self.report_id)
        
        self.assertIsNotNone(result)
        self.assertEqual(result['rowNumber'], 5)
        self.assertEqual(result['status'], 'success')
    
    @patch('services.sync_tracker.db')
    def test_get_sync_record_not_exists(self, mock_db):
        """Test getting non-existent sync record."""
        mock_doc = Mock()
        mock_doc.exists = False
        
        mock_collection = Mock()
        mock_collection.document.return_value.get.return_value = mock_doc
        mock_db.collection.return_value = mock_collection
        
        result = SyncTracker.get_sync_record(self.event_id, self.report_id)
        
        self.assertIsNone(result)
    
    @patch('services.sync_tracker.db')
    def test_record_sync_success(self, mock_db):
        """Test recording successful sync."""
        mock_doc = Mock()
        mock_doc.exists = False
        
        mock_collection = Mock()
        mock_doc_ref = Mock()
        mock_doc_ref.get.return_value = mock_doc
        mock_collection.document.return_value = mock_doc_ref
        mock_db.collection.return_value = mock_collection
        
        SyncTracker.record_sync(
            event_id=self.event_id,
            report_id=self.report_id,
            spreadsheet_id="test_spreadsheet",
            sheet_name="2026test",
            row_number=10,
            status='success'
        )
        
        mock_doc_ref.set.assert_called_once()
        call_args = mock_doc_ref.set.call_args
        self.assertEqual(call_args[0][0]['status'], 'success')
        self.assertEqual(call_args[0][0]['rowNumber'], 10)
        self.assertEqual(call_args[0][0]['attemptCount'], 1)
    
    @patch('services.sync_tracker.db')
    def test_record_sync_with_error(self, mock_db):
        """Test recording failed sync."""
        mock_doc = Mock()
        mock_doc.exists = False
        
        mock_collection = Mock()
        mock_doc_ref = Mock()
        mock_doc_ref.get.return_value = mock_doc
        mock_collection.document.return_value = mock_doc_ref
        mock_db.collection.return_value = mock_collection
        
        SyncTracker.record_sync(
            event_id=self.event_id,
            report_id=self.report_id,
            spreadsheet_id="test_spreadsheet",
            sheet_name="2026test",
            row_number=0,
            status='failed',
            error_message="API Error"
        )
        
        mock_doc_ref.set.assert_called_once()
        call_args = mock_doc_ref.set.call_args
        self.assertEqual(call_args[0][0]['status'], 'failed')
        self.assertEqual(call_args[0][0]['errorMessage'], "API Error")
    
    @patch('services.sync_tracker.db')
    def test_update_row_number(self, mock_db):
        """Test updating row number."""
        mock_doc_ref = Mock()
        mock_collection = Mock()
        mock_collection.document.return_value = mock_doc_ref
        mock_db.collection.return_value = mock_collection
        
        SyncTracker.update_row_number(self.event_id, self.report_id, 15)
        
        mock_doc_ref.update.assert_called_once()
        call_args = mock_doc_ref.update.call_args
        self.assertEqual(call_args[0][0]['rowNumber'], 15)


if __name__ == '__main__':
    unittest.main()
