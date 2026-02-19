"""Track sync status in Firestore for idempotency and monitoring."""

from datetime import datetime
from typing import Optional, List
from firebase_admin import firestore


def _get_db():
    """Lazy-load Firestore client to allow mocking in tests."""
    return firestore.client()


class SyncTracker:
    """Tracks which reports have been synced to Google Sheets."""
    
    @staticmethod
    def get_sync_record(event_id: str, report_id: str) -> Optional[dict]:
        """Get existing sync record for a report."""
        db = _get_db()
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
        db = _get_db()
        doc_ref = db.collection('sync_tracking').document(f"{event_id}_{report_id}")
        
        data = {
            'eventId': event_id,
            'reportId': report_id,
            'spreadsheetId': spreadsheet_id,
            'sheetName': sheet_name,
            'rowNumber': row_number,
            'status': status,
            'syncedAt': firestore.SERVER_TIMESTAMP,
            'attemptCount': firestore.Increment(1),
        }
        
        if error_message:
            data['errorMessage'] = error_message
        
        doc_ref.set(data, merge=True)
    
    @staticmethod
    def record_sync_batch(records: List[dict]) -> None:
        """Batch write multiple sync records. Max 500 per batch.
        
        Args:
            records: List of dicts with keys:
                - eventId, reportId, spreadsheetId, sheetName, rowNumber, status
                - Optional: error_message
        """
        if not records:
            return
        
        db = _get_db()
        batch = db.batch()
        for rec in records:
            doc_ref = db.collection('sync_tracking').document(
                f"{rec['eventId']}_{rec['reportId']}"
            )
            data = {
                'eventId': rec['eventId'],
                'reportId': rec['reportId'],
                'spreadsheetId': rec['spreadsheetId'],
                'sheetName': rec['sheetName'],
                'rowNumber': rec['rowNumber'],
                'status': rec.get('status', 'success'),
                'syncedAt': firestore.SERVER_TIMESTAMP,
                'attemptCount': firestore.Increment(1),
            }
            if rec.get('error_message'):
                data['errorMessage'] = rec['error_message']
            batch.set(doc_ref, data, merge=True)
        batch.commit()
    
    @staticmethod
    def update_row_number(event_id: str, report_id: str, row_number: int):
        """Update the row number for an existing sync record."""
        db = _get_db()
        doc_ref = db.collection('sync_tracking').document(f"{event_id}_{report_id}")
        doc_ref.update({
            'rowNumber': row_number,
            'lastUpdated': firestore.SERVER_TIMESTAMP
        })
