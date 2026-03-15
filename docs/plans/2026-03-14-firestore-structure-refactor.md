# Firestore Data Structure Refactor Design

## Date: 2026-03-14

## Overview
Refactor Firestore data structure to use top-level matches collection instead of nested subcollection under events.

## Current Structure
```
events/{eventId}
  - name, programType, tbaKey, startDate
  matches/{matchId}  (subcollection)
    - matchId, matchNumber, teamNumber, alliance, scouterName, gameData, etc.
```

## Proposed Structure
```
events/{eventId}
  - name, programType, tbaKey, startDate, teamId

matches/{matchId}
  - matchId, matchNumber, teamNumber, alliance, scouterName, gameData
  - robotDied, comments, images, createdAt, isDeleted
  - eventId, teamId  (foreign keys)
```

## Changes Required

### Frontend
1. **event.dart** - Add `teamId` field
2. **match_report.dart** - Add `eventId` and `teamId` fields
3. **firestore_repository.dart** - Change from subcollection to top-level collection

### Backend
1. **main.py** - Update Firestore triggers from `events/{eventId}/matches/{reportId}` to `matches/{reportId}`
2. **handlers/backfill.py** - Update collection path
3. **triggers/match_sync.py** - Update trigger paths
4. **tba_sync.py** - Update document paths
5. **sync_tracker.py** - Keep as-is (tracks sync status)

### Sync Logic (Sheets <-> Firestore)
- **Firestore -> Sheets**: When match created/updated in `matches/{matchId}`, trigger syncs to Google Sheets
- **Sheets -> Firestore**: HTTP endpoint receives updates and writes to `matches/{matchId}`
- **Sync tracking**: Continue using `sync_tracking/{eventId_reportId}` to track which rows map to which reports

## Data Migration
- Delete all existing `events/{eventId}/matches` subcollections
- Fresh start - no migration of old data needed
