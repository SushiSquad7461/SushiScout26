"""Main entry point for Firebase Cloud Functions."""

from firebase_functions import https_fn, firestore_fn
from firebase_admin import initialize_app, firestore

# Initialize Firebase Admin
initialize_app()
db = firestore.client()

# Import existing TBA/FTC functions
from .tba_sync import fetch_event_schedule, fetch_ftc_schedule

# Import Firestore triggers
from .triggers.match_sync import on_match_created, on_match_updated

# Import callable handlers
from .handlers.backfill import backfill_event_to_sheets

# Re-export all functions
__all__ = [
    'fetch_event_schedule',
    'fetch_ftc_schedule', 
    'on_match_created',
    'on_match_updated',
    'backfill_event_to_sheets'
]
