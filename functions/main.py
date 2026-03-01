"""Main entry point for Firebase Cloud Functions."""

import os
from firebase_functions import https_fn, firestore_fn, logger
from firebase_admin import firestore

# Lazy initialization
_db = None

def get_db():
    """Get Firestore client with lazy initialization."""
    global _db
    if _db is None:
        _db = firestore.client()
    return _db


def get_master_spreadsheet_id() -> str:
    """Get master spreadsheet ID from environment."""
    return os.environ.get('MASTER_SPREADSHEET_ID') or ''


def sync_report_to_sheets(event_id: str, report_id: str, report_data: dict, is_update: bool = False):
    """Sync a single match report to Google Sheets."""
    from services.sheets_service import get_sheets_service
    from services.sync_tracker import SyncTracker
    
    try:
        sheets_service = get_sheets_service()
        spreadsheet_id = get_master_spreadsheet_id()
        
        if not spreadsheet_id:
            logger.error("MASTER_SPREADSHEET_ID not configured")
            return
        
        sheet_name = event_id
        sheets_service.get_or_create_sheet(spreadsheet_id, sheet_name)
        
        row_data = sheets_service.transform_match_report(report_data)
        
        sync_record = SyncTracker.get_sync_record(event_id, report_id)
        
        if sync_record and sync_record.get('rowNumber'):
            row_number = sync_record['rowNumber']
            sheets_service.update_row(spreadsheet_id, sheet_name, row_number, row_data)
            logger.info(f"Updated report {report_id} in row {row_number}")
            
            SyncTracker.record_sync(
                event_id=event_id,
                report_id=report_id,
                spreadsheet_id=spreadsheet_id,
                sheet_name=sheet_name,
                row_number=row_number,
                status='updated'
            )
        else:
            row_number = sheets_service.append_row(spreadsheet_id, sheet_name, row_data)
            logger.info(f"Appended report {report_id} to row {row_number}")
            
            SyncTracker.record_sync(
                event_id=event_id,
                report_id=report_id,
                spreadsheet_id=spreadsheet_id,
                sheet_name=sheet_name,
                row_number=row_number,
                status='success'
            )
            
    except Exception as e:
        logger.error(f"Failed to sync report {report_id}: {str(e)}")
        SyncTracker.record_sync(
            event_id=event_id,
            report_id=report_id,
            spreadsheet_id=get_master_spreadsheet_id() or 'unknown',
            sheet_name=event_id,
            row_number=0,
            status='failed',
            error_message=str(e)
        )
        raise


@firestore_fn.on_document_created(document="events/{eventId}/matches/{reportId}")
def on_match_created(event: firestore_fn.Event):
    """Trigger when a new match report is created."""
    event_id = event.params['eventId']
    report_id = event.params['reportId']
    
    report_data = event.data.to_dict() if event.data else None
    
    if not report_data:
        logger.warning(f"No data found for report {report_id}")
        return
    
    logger.info(f"Processing new match report: {report_id} for event {event_id}")
    
    from services.sync_tracker import SyncTracker
    existing = SyncTracker.get_sync_record(event_id, report_id)
    if existing and existing.get('status') == 'success':
        logger.info(f"Report {report_id} already synced, skipping")
        return
    
    sync_report_to_sheets(event_id, report_id, report_data, is_update=False)


@firestore_fn.on_document_updated(document="events/{eventId}/matches/{reportId}")
def on_match_updated(event: firestore_fn.Event):
    """Trigger when a match report is updated."""
    event_id = event.params['eventId']
    report_id = event.params['reportId']
    
    report_data = event.data.after.to_dict() if event.data.after else None
    
    if not report_data:
        logger.warning(f"No data found for updated report {report_id}")
        return
    
    logger.info(f"Processing updated match report: {report_id} for event {event_id}")
    
    sync_report_to_sheets(event_id, report_id, report_data, is_update=True)


@https_fn.on_call()
def backfill_event_to_sheets(req: https_fn.CallableRequest) -> dict:
    """Backfill all match reports for an event to Google Sheets."""
    try:
        event_id = req.data.get('eventId')
        if not event_id:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message="Missing eventId parameter"
            )
        
        logger.info(f"Starting backfill for event: {event_id}")
        
        from services.sheets_service import get_sheets_service
        from services.sync_tracker import SyncTracker
        
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
        reports_ref = db.collection(f'events/{event_id}/matches')
        reports = list(reports_ref.stream())
        
        synced_count = 0
        failed_count = 0
        
        for report_doc in reports:
            report_id = report_doc.id
            report_data = report_doc.to_dict()
            
            if report_data.get('isDeleted'):
                continue
            
            try:
                existing = SyncTracker.get_sync_record(event_id, report_id)
                if existing and existing.get('status') == 'success':
                    logger.info(f"Skipping already synced report: {report_id}")
                    continue
                
                row_data = sheets_service.transform_match_report(report_data)
                row_number = sheets_service.append_row(spreadsheet_id, sheet_name, row_data)
                
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



