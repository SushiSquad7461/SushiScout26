"""Firestore triggers for syncing match reports to Google Sheets."""

import os
from firebase_functions import firestore_fn, logger
from firebase_admin import firestore
from datetime import datetime

from ..services.sheets_service import get_sheets_service
from ..services.sync_tracker import SyncTracker

db = firestore.client()


def get_master_spreadsheet_id() -> str:
    """Get master spreadsheet ID from environment."""
    return os.environ.get('MASTER_SPREADSHEET_ID')


def sync_report_to_sheets(event_id: str, report_id: str, report_data: dict, is_update: bool = False):
    """Sync a single match report to Google Sheets."""
    try:
        # Initialize services
        sheets_service = get_sheets_service()
        spreadsheet_id = get_master_spreadsheet_id()
        
        if not spreadsheet_id:
            logger.error("MASTER_SPREADSHEET_ID not configured")
            return
        
        # Sheet name based on event ID
        sheet_name = event_id
        
        # Ensure sheet exists (creates if not)
        sheets_service.get_or_create_sheet(spreadsheet_id, sheet_name)
        
        # Transform data
        row_data = sheets_service.transform_match_report(report_data)
        
        # Check if this report already exists (for updates or duplicate prevention)
        sync_record = SyncTracker.get_sync_record(event_id, report_id)
        
        if sync_record and sync_record.get('rowNumber'):
            # Update existing row
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
            # Append new row
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
        # Record failure for retry
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
def on_match_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]):
    """Trigger when a new match report is created."""
    event_id = event.params['eventId']
    report_id = event.params['reportId']
    
    # Get the document data
    report_data = event.data.to_dict() if event.data else None
    
    if not report_data:
        logger.warning(f"No data found for report {report_id}")
        return
    
    logger.info(f"Processing new match report: {report_id} for event {event_id}")
    
    # Check if already synced (idempotency)
    existing = SyncTracker.get_sync_record(event_id, report_id)
    if existing and existing.get('status') == 'success':
        logger.info(f"Report {report_id} already synced, skipping")
        return
    
    sync_report_to_sheets(event_id, report_id, report_data, is_update=False)


@firestore_fn.on_document_updated(document="events/{eventId}/matches/{reportId}")
def on_match_updated(event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]]):
    """Trigger when a match report is updated."""
    event_id = event.params['eventId']
    report_id = event.params['reportId']
    
    # Get the new document data
    report_data = event.data.after.to_dict() if event.data.after else None
    
    if not report_data:
        logger.warning(f"No data found for updated report {report_id}")
        return
    
    logger.info(f"Processing updated match report: {report_id} for event {event_id}")
    
    sync_report_to_sheets(event_id, report_id, report_data, is_update=True)
