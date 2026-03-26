"""Main entry point for Firebase Cloud Functions."""

import os
from firebase_functions import https_fn, firestore_fn, logger, options
from firebase_functions.options import CorsOptions
from firebase_admin import initialize_app, firestore
from flask import jsonify, Request, Response

# Initialize Firebase Admin
initialize_app()

# Import tba_sync so its Cloud Functions are discoverable by the Firebase runtime
from tba_sync import fetch_event_schedule  # noqa: E402, F401
from ftc_api import fetch_ftc_schedule  # noqa: E402, F401

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
        
        # Get program type from report data, default to FRC
        program_type = report_data.get('programType', 'FRC')
        
        sheet_name = event_id
        sheets_service.get_or_create_sheet(spreadsheet_id, sheet_name, program_type)
        
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


@firestore_fn.on_document_written(document="matches/{reportId}", secrets=["GOOGLE_SHEETS_CREDENTIALS", "MASTER_SPREADSHEET_ID"])
def on_match_written(event: firestore_fn.Event):
    """Trigger when a match report is created, updated, or deleted in Firestore."""
    report_id = event.params['reportId']
    
    data_before = event.data.before.to_dict() if event.data and event.data.before else None
    data_after = event.data.after.to_dict() if event.data and event.data.after else None
    
    # Get eventId from the document data
    event_id = None
    if data_after and 'eventId' in data_after:
        event_id = data_after['eventId']
    elif data_before and 'eventId' in data_before:
        event_id = data_before['eventId']
    
    if not event_id:
        logger.warning(f"Match {report_id} has no eventId, skipping sync")
        return
    
    if data_before and not data_after:
        logger.info(f"Processing deleted match report: {report_id} for event {event_id}")
        
        from services.sheets_service import get_sheets_service
        from services.sync_tracker import SyncTracker
        
        try:
            sheets_service = get_sheets_service()
            spreadsheet_id = get_master_spreadsheet_id()
            
            if not spreadsheet_id:
                logger.error("MASTER_SPREADSHEET_ID not configured")
                return
            
            sync_record = SyncTracker.get_sync_record(event_id, report_id)
            
            if sync_record and sync_record.get('rowNumber') and sync_record.get('sheetName'):
                row_number = sync_record['rowNumber']
                sheet_name = sync_record['sheetName']
                
                success = sheets_service.delete_row(spreadsheet_id, sheet_name, row_number)
                
                if success:
                    logger.info(f"Deleted row {row_number} for report {report_id}")
                else:
                    logger.warning(f"Failed to delete row for report {report_id}, trying to find and delete")
                    
                    found_row = sheets_service.find_row_by_report_id(spreadsheet_id, sheet_name, report_id)
                    if found_row:
                        sheets_service.delete_row(spreadsheet_id, sheet_name, found_row)
                        logger.info(f"Found and deleted row {found_row} for report {report_id}")
            
            SyncTracker.delete_sync_record(event_id, report_id)
            logger.info(f"Deleted sync record for report {report_id}")
            
        except Exception as e:
            logger.error(f"Failed to sync delete for report {report_id}: {str(e)}")
    elif not data_before and data_after:
        logger.info(f"Processing new match report: {report_id} for event {event_id}")
        
        from services.sync_tracker import SyncTracker
        existing = SyncTracker.get_sync_record(event_id, report_id)
        if existing and existing.get('status') == 'success':
            logger.info(f"Report {report_id} already synced, skipping")
            return
        
        sync_report_to_sheets(event_id, report_id, data_after, is_update=False)
    elif data_before and data_after:
        logger.info(f"Processing updated match report: {report_id} for event {event_id}")
        sync_report_to_sheets(event_id, report_id, data_after, is_update=True)


@https_fn.on_call(secrets=["GOOGLE_SHEETS_CREDENTIALS", "MASTER_SPREADSHEET_ID"])
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
        
        # Get program type from event
        db = get_db()
        event_doc = db.collection('events').document(event_id).get()
        program_type = 'FRC'
        if event_doc.exists:
            event_data = event_doc.to_dict()
            program_type = event_data.get('programType', 'FRC')
        
        sheet_name = event_id
        sheets_service.get_or_create_sheet(spreadsheet_id, sheet_name, program_type)
        
        db = get_db()
        reports_ref = db.collection('matches').where('eventId', '==', event_id)
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


@https_fn.on_call(secrets=["GOOGLE_SHEETS_CREDENTIALS", "MASTER_SPREADSHEET_ID"])
def update_match_from_sheets(req: https_fn.CallableRequest) -> dict:
    """Receive match updates from Google Sheets via Apps Script.
    
    Called by Apps Script when a row is edited in Sheets.
    """
    try:
        if not req.auth:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="Must be authenticated"
            )

        event_id = req.data.get('eventId')
        report_id = req.data.get('reportId')
        match_data = req.data.get('data', {})

        if not event_id or not report_id:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message="Missing eventId or reportId"
            )

        logger.info(f"Updating match from Sheets: {event_id}/{report_id}")

        db = get_db()
        doc_ref = db.collection('matches').document(report_id)

        # Verify team ownership — existing match must belong to same event
        existing = doc_ref.get()
        if existing.exists:
            existing_data = existing.to_dict()
            if existing_data.get('eventId') and existing_data['eventId'] != event_id:
                raise https_fn.HttpsError(
                    code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                    message="Match does not belong to the specified event"
                )

        # Add eventId to the match data
        match_data['eventId'] = event_id

        # Merge update with existing data
        doc_ref.set(match_data, merge=True)
        
        logger.info(f"Successfully updated {report_id} in Firestore from Sheets")
        
        return {
            'success': True,
            'eventId': event_id,
            'reportId': report_id
        }
        
    except https_fn.HttpsError:
        raise
    except Exception as e:
        logger.error(f"Failed to update match from Sheets: {str(e)}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Failed to update match: {str(e)}"
        )


@https_fn.on_request(
    secrets=["GOOGLE_SHEETS_CREDENTIALS", "MASTER_SPREADSHEET_ID"],
    cors=options.CorsOptions(cors_origins="*", cors_methods=["get", "post"])
)
def sync_from_sheets_http(req: Request) -> Response:
    """HTTP endpoint for Sheets to Firestore sync.
    
    Use: POST with JSON body {eventId, reportId, data}
    Requires X-API-Key header for authentication.
    """
    # Check API key
    api_key = req.headers.get('X-API-Key')
    expected_key = os.environ.get('SYNC_API_KEY')
    if not expected_key:
        return jsonify({'error': 'SYNC_API_KEY not configured'}), 500
    
    if api_key != expected_key:
        return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        req_data = req.get_json(silent=True) or {}
        
        event_id = req_data.get('eventId')
        report_id = req_data.get('reportId')
        match_data = req_data.get('data', {})
        
        if not event_id or not report_id:
            return jsonify({'error': 'Missing eventId or reportId'}), 400
        
        logger.info(f"HTTP: Updating match from Sheets: {event_id}/{report_id}")
        
        db = get_db()
        doc_ref = db.collection('matches').document(report_id)
        
        # Add eventId to the match data
        match_data['eventId'] = event_id
        
        doc_ref.set(match_data, merge=True)
        
        logger.info(f"Successfully updated {report_id} in Firestore from Sheets")
        
        return jsonify({
            'success': True,
            'eventId': event_id,
            'reportId': report_id
        })
        
    except Exception as e:
        logger.error(f"HTTP: Failed to update match from Sheets: {str(e)}")
        return jsonify({'error': str(e)}), 500
