"""Main entry point for Firebase Cloud Functions."""

import os
import random
from firebase_functions import https_fn, firestore_fn, logger, options
from firebase_functions.options import CorsOptions
from firebase_admin import initialize_app, firestore, auth as fb_auth
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


def _is_team_member(uid: str, team_id: str) -> bool:
    """True if uid is a member of team_id. Cloud Functions use the Admin SDK
    which bypasses Firestore rules, so callable functions must check team
    membership themselves before mutating team-scoped data."""
    if not uid or not team_id:
        return False
    db = get_db()
    member_ref = (
        db.collection('teams')
        .document(team_id)
        .collection('members')
        .document(uid)
    )
    return member_ref.get().exists


def _resolve_event_program_type(event_id: str, report_data: dict | None = None) -> str:
    """Resolve programType for an event. The event doc is authoritative
    so the sheet schema doesn't get locked to FRC just because a match
    was written without programType."""
    try:
        event_doc = get_db().collection('events').document(event_id).get()
        if event_doc.exists:
            event_data = event_doc.to_dict() or {}
            program_type = event_data.get('programType')
            if program_type:
                return program_type
    except Exception as e:
        logger.warn(f"Failed to read event {event_id} for programType: {e}")

    if report_data:
        return report_data.get('programType') or 'FRC'
    return 'FRC'


def _delete_sheet_row_for_report(event_id: str, report_id: str) -> None:
    """Remove a report's row from Sheets and clear its sync record.
    Used for hard deletes and for soft-delete transitions."""
    from services.sheets_service import get_sheets_service
    from services.sync_tracker import SyncTracker

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
            logger.warn(f"Failed to delete row for report {report_id}, trying to find and delete")
            found_row = sheets_service.find_row_by_report_id(spreadsheet_id, sheet_name, report_id)
            if found_row:
                sheets_service.delete_row(spreadsheet_id, sheet_name, found_row)
                logger.info(f"Found and deleted row {found_row} for report {report_id}")

    SyncTracker.delete_sync_record(event_id, report_id)
    logger.info(f"Deleted sync record for report {report_id}")


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

        # The event doc is authoritative for programType — the match doc's
        # field may be missing (legacy writes, reverse-sync from Sheets,
        # external admin writes) which used to silently force the sheet to
        # FRC columns on first sync of an FTC event.
        program_type = _resolve_event_program_type(event_id, report_data)

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
        logger.warn(f"Match {report_id} has no eventId, skipping sync")
        return

    # Schedule docs from TBA/FTC sync now live in /schedules, but legacy
    # deploys may have left schedule entries (identified by compLevel and
    # no scouterName) in /matches. Don't push them to Sheets.
    payload = data_after or data_before or {}
    if payload.get('compLevel') and not payload.get('scouterName'):
        logger.info(
            f"Skipping schedule-shaped doc {report_id} in matches collection"
        )
        return

    if data_before and not data_after:
        logger.info(f"Processing hard-deleted match report: {report_id} for event {event_id}")
        try:
            _delete_sheet_row_for_report(event_id, report_id)
        except Exception as e:
            logger.error(f"Failed to sync delete for report {report_id}: {str(e)}")
    elif not data_before and data_after:
        # Newly created document. If it's created already-deleted (rare,
        # e.g. import of a soft-deleted record), skip pushing it to Sheets.
        if data_after.get('isDeleted'):
            logger.info(f"New match {report_id} is soft-deleted, skipping Sheets sync")
            return

        logger.info(f"Processing new match report: {report_id} for event {event_id}")

        from services.sync_tracker import SyncTracker
        existing = SyncTracker.get_sync_record(event_id, report_id)
        if existing and existing.get('status') == 'success':
            logger.info(f"Report {report_id} already synced, skipping")
            return

        sync_report_to_sheets(event_id, report_id, data_after, is_update=False)
    elif data_before and data_after:
        was_deleted = bool(data_before.get('isDeleted'))
        is_deleted = bool(data_after.get('isDeleted'))

        # Echo guard: if this update came from the Sheets → Firestore path
        # (update_match_from_sheets / sync_from_sheets_http stamp
        # lastSyncSource='sheets'), don't push the same data back to Sheets.
        # App-originated writes stamp lastSyncSource='app' explicitly, so
        # the after-value alone tells us the origin — we don't need to
        # compare against before. (The earlier "transition-only" guard
        # echoed on the SECOND consecutive sheets edit because before was
        # also 'sheets'.) was_deleted == is_deleted ensures soft deletes
        # initiated from Sheets still propagate to the trash path below.
        if (
            data_after.get('lastSyncSource') == 'sheets'
            and was_deleted == is_deleted
        ):
            logger.info(
                f"Skipping echo sync for {report_id}: write originated in Sheets"
            )
            return

        if is_deleted and not was_deleted:
            # Soft delete (trash): remove the row from Sheets so trashed
            # matches don't keep showing up in analysis views.
            logger.info(f"Processing soft-deleted match report: {report_id} for event {event_id}")
            try:
                _delete_sheet_row_for_report(event_id, report_id)
            except Exception as e:
                logger.error(f"Failed to sync soft delete for report {report_id}: {str(e)}")
            return

        if is_deleted:
            # Already soft-deleted; ignore further updates (e.g. metadata
            # edits on a trashed match) instead of re-appending the row.
            logger.info(f"Ignoring update to soft-deleted match {report_id}")
            return

        # Restore (was_deleted -> not is_deleted) is handled here too: the
        # sync record was cleared on trash, so this re-appends a new row.
        logger.info(f"Processing updated match report: {report_id} for event {event_id}")
        sync_report_to_sheets(event_id, report_id, data_after, is_update=True)


def _generate_invite_code() -> str:
    chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    return ''.join(random.choice(chars) for _ in range(6))


def _set_team_claims(uid: str, memberships: dict) -> None:
    """Mirror a user's team memberships into their auth token. The claim is
    the ONLY membership signal Firestore rules trust, and it is written only
    here (server-side) — clients cannot forge it."""
    fb_auth.set_custom_user_claims(uid, {'teams': memberships})


def _user_memberships(db, uid: str) -> dict:
    snap = db.collection('users').document(uid).get()
    if not snap.exists:
        return {}
    return dict((snap.to_dict() or {}).get('teamMemberships') or {})


@https_fn.on_call()
def create_team(req: https_fn.CallableRequest) -> dict:
    """Create a team, make the caller its admin, and set their claim."""
    if not req.auth:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Must be authenticated")
    data = req.data or {}
    name = data.get('name')
    if not name:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "Missing team name")
    is_master = bool(data.get('isMasterTeam'))
    uid = req.auth.uid
    db = get_db()

    invite_code = _generate_invite_code()
    while list(db.collection('teams').where('inviteCode', '==', invite_code).limit(1).get()):
        invite_code = _generate_invite_code()

    team_ref = db.collection('teams').document()
    team_id = team_ref.id
    now = firestore.SERVER_TIMESTAMP
    memberships = _user_memberships(db, uid)
    memberships[team_id] = 'admin'

    batch = db.batch()
    batch.set(team_ref, {
        'name': name, 'inviteCode': invite_code, 'createdBy': uid,
        'createdAt': now, 'isMasterTeam': is_master, 'memberCount': 1,
    })
    batch.set(team_ref.collection('members').document(uid),
              {'role': 'admin', 'userId': uid, 'joinedAt': now})
    batch.set(db.collection('users').document(uid),
              {'currentTeamId': team_id, 'teamMemberships': memberships}, merge=True)
    batch.commit()

    _set_team_claims(uid, memberships)
    return {'teamId': team_id, 'name': name, 'inviteCode': invite_code,
            'createdBy': uid, 'isMasterTeam': is_master, 'memberCount': 1}


@https_fn.on_call()
def join_team(req: https_fn.CallableRequest) -> dict:
    """Join a team by invite code. The code is verified server-side — it is
    the only proof of authorization, so this must never be a client write."""
    if not req.auth:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Must be authenticated")
    code = ((req.data or {}).get('inviteCode') or '').upper()
    if not code:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "Missing invite code")
    uid = req.auth.uid
    db = get_db()

    teams = list(db.collection('teams').where('inviteCode', '==', code).limit(1).get())
    if not teams:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.NOT_FOUND, "Invalid invite code")
    team_doc = teams[0]
    team_id = team_doc.id
    team = team_doc.to_dict() or {}

    team_ref = db.collection('teams').document(team_id)
    member_ref = team_ref.collection('members').document(uid)
    if member_ref.get().exists:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.ALREADY_EXISTS, "Already a member of this team")

    memberships = _user_memberships(db, uid)
    memberships[team_id] = 'member'

    batch = db.batch()
    batch.set(member_ref, {'role': 'member', 'userId': uid, 'joinedAt': firestore.SERVER_TIMESTAMP})
    batch.update(team_ref, {'memberCount': firestore.Increment(1)})
    batch.set(db.collection('users').document(uid),
              {'currentTeamId': team_id, 'teamMemberships': memberships}, merge=True)
    batch.commit()

    _set_team_claims(uid, memberships)
    return {'teamId': team_id, 'name': team.get('name'), 'inviteCode': code,
            'createdBy': team.get('createdBy'),
            'isMasterTeam': team.get('isMasterTeam', False),
            'memberCount': team.get('memberCount', 0) + 1}


@https_fn.on_call()
def leave_team(req: https_fn.CallableRequest) -> dict:
    """Leave a team. Blocks the last admin from orphaning the team."""
    if not req.auth:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Must be authenticated")
    team_id = (req.data or {}).get('teamId')
    if not team_id:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "Missing teamId")
    uid = req.auth.uid
    db = get_db()

    team_ref = db.collection('teams').document(team_id)
    team_snap = team_ref.get()
    if not team_snap.exists:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.NOT_FOUND, "Team not found")
    team = team_snap.to_dict() or {}

    member_ref = team_ref.collection('members').document(uid)
    member_snap = member_ref.get()
    if not member_snap.exists:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.PERMISSION_DENIED, "Not a member of this team")
    if (member_snap.to_dict() or {}).get('role') == 'admin' and team.get('memberCount', 0) <= 1:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                                  "The last admin cannot leave the team")

    user_snap = db.collection('users').document(uid).get()
    user_data = user_snap.to_dict() or {} if user_snap.exists else {}
    memberships = dict(user_data.get('teamMemberships') or {})
    memberships.pop(team_id, None)
    current = user_data.get('currentTeamId')
    new_current = current if current != team_id else next(iter(memberships), None)

    batch = db.batch()
    batch.delete(member_ref)
    batch.update(team_ref, {'memberCount': firestore.Increment(-1)})
    batch.set(db.collection('users').document(uid),
              {'currentTeamId': new_current, 'teamMemberships': memberships}, merge=True)
    batch.commit()

    _set_team_claims(uid, memberships)
    return {'success': True, 'currentTeamId': new_current}


@https_fn.on_call(secrets=["GOOGLE_SHEETS_CREDENTIALS", "MASTER_SPREADSHEET_ID"])
def backfill_event_to_sheets(req: https_fn.CallableRequest) -> dict:
    """Backfill all match reports for an event to Google Sheets."""
    try:
        if not req.auth:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="Must be authenticated"
            )

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

        # Get program type from event and verify the caller owns the team
        # this event belongs to. Cloud Functions use the Admin SDK and
        # bypass Firestore rules, so we must enforce isolation here.
        db = get_db()
        event_doc = db.collection('events').document(event_id).get()
        program_type = 'FRC'
        event_team_id = ''
        if event_doc.exists:
            event_data = event_doc.to_dict()
            program_type = event_data.get('programType', 'FRC')
            event_team_id = event_data.get('teamId', '') or ''

        if event_team_id and not _is_team_member(req.auth.uid, event_team_id):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="Caller is not a member of the team that owns this event"
            )

        sheet_name = event_id
        sheets_service.get_or_create_sheet(spreadsheet_id, sheet_name, program_type)
        
        db = get_db()
        reports_ref = db.collection('matches').where('eventId', '==', event_id)
        if event_team_id:
            reports_ref = reports_ref.where('teamId', '==', event_team_id)
        reports = list(reports_ref.stream())
        
        synced_count = 0
        failed_count = 0
        
        for report_doc in reports:
            report_id = report_doc.id
            report_data = report_doc.to_dict()

            if report_data.get('isDeleted'):
                continue

            # Skip legacy schedule-shaped docs the same way on_match_written
            # does. TBA/FTC sync used to write schedule entries into /matches
            # (now moved to /schedules); old data may still be there and
            # would otherwise show up as garbage rows in the sheet.
            if report_data.get('compLevel') and not report_data.get('scouterName'):
                logger.info(f"Skipping schedule-shaped doc {report_id} during backfill")
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

        # Verify event match AND team membership. Admin SDK bypasses Firestore
        # rules, so without this any signed-in user could mutate any team's
        # match if they learned a (reportId, eventId) pair.
        existing = doc_ref.get()
        if not existing.exists:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.NOT_FOUND,
                message="Match does not exist"
            )

        existing_data = existing.to_dict() or {}
        if existing_data.get('eventId') and existing_data['eventId'] != event_id:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="Match does not belong to the specified event"
            )

        existing_team_id = existing_data.get('teamId', '') or ''
        if existing_team_id and not _is_team_member(req.auth.uid, existing_team_id):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="Caller is not a member of the team that owns this match"
            )

        # Force eventId and teamId — never let the client overwrite these
        # from the Sheets payload, which would let a caller move a match
        # between teams or events.
        match_data['eventId'] = event_id
        if existing_team_id:
            match_data['teamId'] = existing_team_id

        # Tag the source so on_match_written can skip the echo write back
        # to Sheets. Without this, every Sheets-side edit fires a redundant
        # Sheets API update and risks silently rewriting the user's cell
        # with transform_match_report's reformatted values.
        match_data['lastSyncSource'] = 'sheets'

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

        existing = doc_ref.get()
        if not existing.exists:
            return jsonify({'error': 'Match does not exist'}), 404

        existing_data = existing.to_dict() or {}
        if existing_data.get('eventId') and existing_data['eventId'] != event_id:
            return jsonify({'error': 'Match does not belong to the specified event'}), 403

        # Force eventId and teamId — never trust the client payload for
        # these, otherwise a compromised Apps Script could move matches
        # between teams or events.
        match_data['eventId'] = event_id
        if existing_data.get('teamId'):
            match_data['teamId'] = existing_data['teamId']

        # Tag the source so on_match_written can skip the echo write back
        # to Sheets — see update_match_from_sheets for the rationale.
        match_data['lastSyncSource'] = 'sheets'

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
