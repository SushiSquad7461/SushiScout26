"""Callable function to backfill historical match reports to Google Sheets."""

import os
from firebase_functions import https_fn, logger
from firebase_admin import firestore

from ..services.sheets_service import get_sheets_service
from ..services.sync_tracker import SyncTracker

db = firestore.client()


def get_master_spreadsheet_id() -> str:
    """Get master spreadsheet ID from environment."""
    return os.environ.get('MASTER_SPREADSHEET_ID')


@https_fn.on_call()
def backfill_event_to_sheets(req: https_fn.CallableRequest) -> dict:
    """
    Backfill all match reports for an event to Google Sheets.
    
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
        
        # Initialize services
        sheets_service = get_sheets_service()
        spreadsheet_id = get_master_spreadsheet_id()
        
        if not spreadsheet_id:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                message="MASTER_SPREADSHEET_ID not configured"
            )
        
        sheet_name = event_id
        
        # Ensure sheet exists
        sheets_service.get_or_create_sheet(spreadsheet_id, sheet_name)
        
        # Fetch all match reports for this event
        reports_ref = db.collection(f'events/{event_id}/matches')
        reports = reports_ref.stream()
        
        synced_count = 0
        failed_count = 0
        
        for report_doc in reports:
            report_id = report_doc.id
            report_data = report_doc.to_dict()
            
            # Skip deleted reports
            if report_data.get('isDeleted'):
                continue
            
            try:
                # Check if already synced
                existing = SyncTracker.get_sync_record(event_id, report_id)
                if existing and existing.get('status') == 'success':
                    logger.info(f"Skipping already synced report: {report_id}")
                    continue
                
                # Transform and append
                row_data = sheets_service.transform_match_report(report_data)
                row_number = sheets_service.append_row(spreadsheet_id, sheet_name, row_data)
                
                # Record sync
                SyncTracker.record_sync(
                    event_id=event_id,
                    report_id=report_id,
                    spreadsheet_id=spreadsheet_id,
                    sheet_name=sheet_name,
                    row_number=row_number,
                    status='success'
                )
                
                synced_count += 1
                logger.info(f"Synced report {report_id} to row {row_number}")
                
            except Exception as e:
                failed_count += 1
                logger.error(f"Failed to sync report {report_id}: {str(e)}")
                
                SyncTracker.record_sync(
                    event_id=event_id,
                    report_id=report_id,
                    spreadsheet_id=spreadsheet_id,
                    sheet_name=sheet_name,
                    row_number=0,
                    status='failed',
                    error_message=str(e)
                )
        
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
