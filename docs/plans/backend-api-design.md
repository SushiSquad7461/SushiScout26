# Backend API Design

**Date:** 2026-02-22
**Status:** Superseded — the Sheets integration described here was bidirectional; it is now a one-way per-team export. See `docs/superpowers/specs/2026-07-21-sheets-one-way-export-design.md`. Kept as a historical record.

## Overview

This document outlines the design for the backend API of SushiScout 26. The API will be responsible for handling data synchronization, user authentication, and team management.

## Components

*   **Authentication:**
    *   Endpoints for user registration, login, and token refreshing.
    *   Integration with Firebase Authentication.
*   **Data Synchronization:**
    *   Endpoints for uploading and downloading match and event data.
    *   Conflict resolution strategies.
*   **Team Management:**
    *   Endpoints for creating, joining, and managing teams.
    *   Role-based access control.

## Database Schema

*   **Users:** Stores user profile information.
*   **Teams:** Stores team information and memberships.
*   **Events:** Stores event data.
*   **Matches:** Stores match scouting data.
# Backend API Design - Firebase Cloud Functions

**Author**: AI Assistant
**Date**: 2026-02-22
**Status**: Approved

## 1. Overview

The backend for SushiScout26 is a serverless architecture built on Google Cloud, using Firebase Cloud Functions written in Python. It is designed to be scalable, maintainable, and cost-effective.

The primary responsibilities of the backend are:
- Ingesting official match schedules from The Blue Alliance (TBA).
- Providing a mechanism for the frontend application to store scouting data in Firestore.
- Syncing scouting data in real-time from Firestore to a master Google Sheet for analysis.
- Providing a bulk-sync mechanism for historical data.

## 2. Architecture Diagram

```
+----------+      (HTTPS Call)      +------------------------+      (API Req)       +-------------------+
|  Admin   | ---------------------> | fetch_event_schedule() | -------------------> | The Blue Alliance |
| (Client) |                        +------------------------+                      +-------------------+
+----------+                                   |                                            |
                                               | (Write to Firestore)                        |
                                               v                                            |
+----------+      (Write)           +----------------------------+ <------------------------+
| Scouter  | ---------------------> | Firestore                  |
|  (App)   |                        | /events/{eid}/matches/{rid}|
+----------+                        +----------------------------+
                                               |
         (Firestore Trigger)                   |
                                               v
+------------------------+      (Sheets API)      +-----------------+
| on_match_created()     | ---------------------> |   Google Sheet  |
| on_match_updated()     |                        | (Master Report) |
+------------------------+ <--------------------+ +-----------------+
             |                                  |
             | (Write to Firestore)             |
             v                                  |
+----------------------------+                  |
| Firestore                  |                  |
| /sync_tracking/{eid}_{rid} | ------------------+
+----------------------------+    (Read for idempotency)

```

## 3. Core Components

### 3.1. Firestore Database
- **Primary Data Store**: All scouting data, TBA match schedules, and sync tracking information is stored in Firestore.
- **Collections**:
    - `events/{eventId}/matches/{reportId}`: Stores both the TBA match schedule data and the detailed scouting reports submitted from the app.
    - `sync_tracking/{eventId_reportId}`: Stores metadata about the Google Sheets sync status for each report, ensuring idempotency and providing a monitoring trail.
    - `tba_cache/{eventId}`: Caches responses from The Blue Alliance API for 24 hours to reduce redundant API calls.

### 3.2. Firebase Cloud Functions (Python)
- **Business Logic Layer**: All backend logic is contained within Python functions.
- **Functions**:
    - **`fetch_event_schedule` (HTTPS Callable)**: Pulls match schedules from TBA and populates Firestore.
    - **`on_match_created` / `on_match_updated` (Firestore Triggers)**: Sync data to Google Sheets in real-time when a scouting report is saved.
    - **`backfill_event_to_sheets` (HTTPS Callable)**: Provides a manual way to sync an entire event's data to Google Sheets.

### 3.3. Google Sheets
- **Data Destination**: The final destination for the processed scouting data, used for analysis, dashboards, and review by the strategy team.
- **Structure**: A single master spreadsheet contains individual sheets (tabs) for each event, named with the event ID (e.g., `2026casj`).

## 4. Services

- **`sheets_service.py`**: A dedicated service class that encapsulates all interactions with the Google Sheets API (e.g., creating sheets, appending/updating rows, formatting).
- **`sync_tracker.py`**: A service class that manages reading from and writing to the `sync_tracking` collection in Firestore.

## 5. Security and Authentication
- **API Keys & Credentials**: The functions authenticate with Google Sheets and The Blue Alliance API using credentials and keys stored securely as environment variables and secrets in the Google Cloud project.
- **Function Access**: Callable functions can be restricted to authenticated users (e.g., admins) via Firebase Authentication rules, though this is not explicitly implemented in the current code.
