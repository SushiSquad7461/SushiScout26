"""Track sync status in Firestore for idempotency and monitoring."""

from datetime import datetime
from typing import Optional
from firebase_admin import firestore

db = firestore.client()


class SyncTracker:
    """Tracks which reports have been synced to Google Sheets."""
    
    @staticmethod
    def get_sync_record(event_id: str, report_id: str) -> Optional[dict]:
        """Get existing sync record for a report."""
        doc_ref = db.collection('sync_tracking').document(f"{event_id}_{report_id}")
        doc = doc_ref.get()
        if doc.exists:
            return doc.to_dict()
        return None
    
    @staticmethod
    def record_sync(event_id: str, report_id: str, spreadsheet_id: str, 
                    sheet_name: str, row_number: int, status: str = 'success',
                    error_message: str = None):
        """Record a successful or failed sync."""
        doc_ref = db.collection('sync_tracking').document(f"{event_id}_{report_id}")
        
        data = {
            'eventId': event_id,
            'reportId': report_id,
            'spreadsheetId': spreadsheet_id,
            'sheetName': sheet_name,
            'rowNumber': row_number,
            'status': status,
            'syncedAt': firestore.SERVER_TIMESTAMP,
        }
        
        # Handle attempt count - get current value first
        doc = doc_ref.get()
        if doc.exists:
            current_data = doc.to_dict()
            current_attempts = current_data.get('attemptCount', 0)
            data['attemptCount'] = current_attempts + 1
        else:
            data['attemptCount'] = 1
        
        if error_message:
            data['errorMessage'] = error_message
        
        doc_ref.set(data, merge=True)
    
    @staticmethod
    def update_row_number(event_id: str, report_id: str, row_number: int):
        """Update the row number for an existing sync record."""
        doc_ref = db.collection('sync_tracking').document(f"{event_id}_{report_id}")
        doc_ref.update({
            'rowNumber': row_number,
            'lastUpdated': firestore.SERVER_TIMESTAMP
        })
