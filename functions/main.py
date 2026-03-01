"""Main entry point for Firebase Cloud Functions."""

from firebase_functions import https_fn, firestore_fn
from firebase_admin import initialize_app, firestore

# Initialize Firebase Admin
initialize_app()
db = firestore.client()

# TBA function - commented out for now (TBA integration not ready)
# from .tba_sync import fetch_event_schedule

# Import Firestore triggers
from .triggers.match_sync import on_match_created, on_match_updated

# Import callable handlers
from .handlers.backfill import backfill_event_to_sheets

# Re-export all functions
__all__ = [
    # 'fetch_event_schedule',  # Disabled - TBA integration paused
    'on_match_created',
    'on_match_updated',
    'backfill_event_to_sheets'
]
