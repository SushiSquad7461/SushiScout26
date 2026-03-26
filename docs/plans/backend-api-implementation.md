# Backend API Implementation Plan

**Date:** 2026-02-22
**Status:** Pending

## Overview

This document outlines the implementation plan for the backend API.

## Task Breakdown

*   **Phase 1: Project Setup**
    *   Initialize a new Python project with FastAPI.
    *   Set up the database with Alembic for migrations.
*   **Phase 2: Authentication**
    *   Implement user registration and login endpoints.
    *   Integrate with Firebase Authentication for Google Sign-In.
*   **Phase 3: Team Management**
    *   Implement endpoints for creating, joining, and managing teams.
*   **Phase 4: Data Synchronization**
    *   Implement endpoints for handling data sync.
*   **Phase 5: Deployment**
    *   Containerize the application with Docker.
    *   Deploy to a cloud provider.
# Backend API Implementation - Firebase Cloud Functions

**Author**: AI Assistant
**Date**: 2026-02-22
**Status**: Approved

## 1. Overview

This document details the implementation of the Python-based Firebase Cloud Functions that constitute the backend for SushiScout26. The code is organized into a modular structure to separate concerns and improve maintainability.

## 2. File Structure

```
functions/
├── main.py
├── requirements.txt
├── tba_sync.py
├── handlers/
│   └── backfill.py
├── services/
│   ├── sheets_service.py
│   └── sync_tracker.py
└── triggers/
    └── match_sync.py
```

## 3. Core Modules and Functions

### 3.1. `main.py`
- **Purpose**: Acts as the main entry point for deploying the cloud functions. It initializes the Firebase Admin SDK and aggregates all the individual functions from other modules for export.

### 3.2. `tba_sync.py`
- **Function**: `fetch_event_schedule(req: https_fn.CallableRequest)`
- **Trigger**: HTTPS Callable
- **Description**:
    1. Called by an admin from the client with an `eventKey`.
    2. Checks a Firestore collection (`tba_cache`) for a recent, non-expired copy of the event data. If found, returns the cached data.
    3. If no valid cache exists, it fetches the match schedule from the TBA API (`/api/v3/event/{event_key}/matches`).
    4. It authenticates using the `TBA_API_KEY` secret.
    5. The fetched match data is transformed and saved in a batch write to the `/events/{eventKey}/matches` collection in Firestore.
    6. The new data is then cached in `tba_cache` with a 24-hour TTL.

### 3.3. `triggers/match_sync.py`
- **Function**: `on_match_created(event: firestore_fn.Event)`
- **Trigger**: Firestore (on document create in `events/{eventId}/matches/{reportId}`)
- **Description**:
    1. Fires when a new match scouting report is created.
    2. Checks the `sync_tracking` collection to ensure the report hasn't already been synced.
    3. Calls `sync_report_to_sheets` to process the data.

- **Function**: `on_match_updated(event: firestore_fn.Event)`
- **Trigger**: Firestore (on document update in `events/{eventId}/matches/{reportId}`)
- **Description**:
    1. Fires when a match scouting report is updated.
    2. Calls `sync_report_to_sheets` to process the data, flagging it as an update.

- **Helper**: `sync_report_to_sheets(...)`
    1. Initializes the `SheetsService`.
    2. Retrieves the master spreadsheet ID from the `MASTER_SPREADSHEET_ID` environment variable.
    3. Ensures a sheet (tab) for the `eventId` exists, creating it if necessary.
    4. Transforms the Firestore report data into the flat row format required by the sheet.
    5. Checks the `SyncTracker` to see if a row already exists for this report.
    6. Calls the appropriate `SheetsService` method (`update_row` or `append_row`).
    7. Records the result (success or failure) of the operation using the `SyncTracker`.

### 3.4. `handlers/backfill.py`
- **Function**: `backfill_event_to_sheets(req: https_fn.CallableRequest)`
- **Trigger**: HTTPS Callable
- **Description**:
    1. Called by an admin from the client with an `eventId`.
    2. Fetches all match report documents for that event from Firestore.
    3. Sorts reports into two lists: new reports to be appended and existing reports to be updated (based on `SyncTracker` data).
    4. Uses the batch methods of `SheetsService` (`append_rows`, `update_rows`) and `SyncTracker` (`record_sync_batch`) to perform the sync efficiently.
    5. Returns a summary of the operation (synced count, failed count) to the client.

### 3.5. `services/sheets_service.py`
- **Purpose**: A class that abstracts all communication with the Google Sheets API.
- **Authentication**: Uses a service account credential stored in the `GOOGLE_SHEETS_CREDENTIALS` environment variable.
- **Key Methods**:
    - `get_or_create_sheet`: Ensures a sheet exists and has the correct headers.
    - `append_rows`: Appends multiple rows in a single API call.
    - `update_rows`: Updates multiple rows in a single batch API call.
    - `transform_match_report`: Maps the nested Firestore document structure to a flat list of values for a sheet row.

### 3.6. `services/sync_tracker.py`
- **Purpose**: A class that manages the state of sync operations in the `sync_tracking` Firestore collection.
- **Key Methods**:
    - `get_sync_record`: Retrieves the sync status for a specific report.
    - `record_sync`: Creates or updates a sync status document.
    - `record_sync_batch`: Writes multiple sync status documents in a single batch.
