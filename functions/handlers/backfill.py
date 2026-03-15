"""Callable function to backfill historical match reports to Google Sheets."""

import os
from firebase_functions import https_fn, logger
from firebase_admin import firestore

from ..services.sheets_service import get_sheets_service
from ..services.sync_tracker import SyncTracker

# Lazy initialization
_db = None

def get_db():
    """Get Firestore client with lazy initialization."""
    global _db
    if _db is None:
        _db = firestore.client()
    return _db

BATCH_SIZE = 400  # Firestore batch limit is 500


def get_master_spreadsheet_id() -> str:
    """Get master spreadsheet ID from environment."""
    return os.environ.get('MASTER_SPREADSHEET_ID')


@https_fn.on_call()
def backfill_event_to_sheets(req: https_fn.CallableRequest) -> dict:
    """
    Backfill all match reports for an event to Google Sheets.
    Uses batched operations for efficiency.
    
    Input: { "eventId": "2026casj" }
    Output: { "success": true, "syncedCount": 42, "failedCount": 0 }
    """
    try:
        event_id = req.data.get('eventId')
        if not event_id:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message="Missing eventId parameter"
            )
        
        logger.info(f"Starting backfill for event: {event_id}")
        
        sheets_service = get_sheets_service()
        spreadsheet_id = get_master_spreadsheet_id()
        
        if not spreadsheet_id:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                message="MASTER_SPREADSHEET_ID not configured"
            )
        
        sheet_name = event_id
        
        sheets_service.get_or_create_sheet(spreadsheet_id, sheet_name)
        
        db = get_db()
        reports_ref = db.collection('matches').where('eventId', '==', event_id)
        reports = list(reports_ref.stream())
        
        reports_to_append = []  # (row_data, report_id)
        reports_to_update = []  # (row_number, row_data, report_id)
        failed_records = []     # error records
        
        for report_doc in reports:
            report_id = report_doc.id
            report_data = report_doc.to_dict()
            
            if report_data.get('isDeleted'):
                continue
            
            try:
                row_data = sheets_service.transform_match_report(report_data)
                existing = SyncTracker.get_sync_record(event_id, report_id)
                
                if existing and existing.get('rowNumber'):
                    reports_to_update.append((existing['rowNumber'], row_data, report_id))
                else:
                    reports_to_append.append((row_data, report_id))
                    
            except Exception as e:
                failed_count = len(failed_records) + 1
                failed_records.append({
                    'eventId': event_id,
                    'reportId': report_id,
                    'spreadsheetId': spreadsheet_id,
                    'sheetName': sheet_name,
                    'rowNumber': 0,
                    'status': 'failed',
                    'error_message': str(e)
                })
                logger.error(f"Failed to prepare report {report_id}: {str(e)}")
        
        synced_count = 0
        failed_count = len(failed_records)
        
        # Batch append new rows
        if reports_to_append:
            logger.info(f"Appending {len(reports_to_append)} new rows")
            rows = [r[0] for r in reports_to_append]
            start_row = sheets_service.append_rows(spreadsheet_id, sheet_name, rows)
            
            sync_records = []
            for i, (_, report_id) in enumerate(reports_to_append):
                sync_records.append({
                    'eventId': event_id,
                    'reportId': report_id,
                    'spreadsheetId': spreadsheet_id,
                    'sheetName': sheet_name,
                    'rowNumber': start_row + i,
                    'status': 'success'
                })
            
            for i in range(0, len(sync_records), BATCH_SIZE):
                SyncTracker.record_sync_batch(sync_records[i:i + BATCH_SIZE])
            
            synced_count += len(reports_to_append)
            logger.info(f"Appended {len(reports_to_append)} rows starting at row {start_row}")
        
        # Batch update existing rows
        if reports_to_update:
            logger.info(f"Updating {len(reports_to_update)} existing rows")
            updates = [(row_num, row_data) for row_num, row_data, _ in reports_to_update]
            sheets_service.update_rows(spreadsheet_id, sheet_name, updates)
            
            sync_records = [{
                'eventId': event_id,
                'reportId': report_id,
                'spreadsheetId': spreadsheet_id,
                'sheetName': sheet_name,
                'rowNumber': row_num,
                'status': 'updated'
            } for row_num, _, report_id in reports_to_update]
            
            for i in range(0, len(sync_records), BATCH_SIZE):
                SyncTracker.record_sync_batch(sync_records[i:i + BATCH_SIZE])
            
            synced_count += len(reports_to_update)
            logger.info(f"Updated {len(reports_to_update)} rows")
        
        # Record failed syncs
        if failed_records:
            for i in range(0, len(failed_records), BATCH_SIZE):
                SyncTracker.record_sync_batch(failed_records[i:i + BATCH_SIZE])
        
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
