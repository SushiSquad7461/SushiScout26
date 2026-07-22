"""Main entry point for Firebase Cloud Functions."""

import os
import re
import secrets
from firebase_functions import https_fn, firestore_fn, logger, options
from firebase_admin import initialize_app, firestore, auth as fb_auth

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


def _is_team_member(auth_token: dict | None, team_id: str) -> bool:
    """True if the caller's token carries `team_id` in its `teams` custom
    claim. Cloud Functions use the Admin SDK which bypasses Firestore
    rules, so callables must check membership themselves — but the claim
    (set by the membership callables: create_team/join_team/leave_team)
    makes it a free token read instead of a Firestore lookup."""
    if not auth_token or not team_id:
        return False
    return team_id in (auth_token.get('teams') or {})


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


def _resolve_team_id(event_id: str, report_data: dict | None = None) -> str:
    """Resolve the owning teamId for a match. The match doc normally
    carries it, but legacy and externally-written docs may not — fall back
    to the event doc, which Step 1 (team isolation) made authoritative."""
    if report_data and report_data.get('teamId'):
        return report_data['teamId']

    try:
        event_doc = get_db().collection('events').document(event_id).get()
        if event_doc.exists:
            return (event_doc.to_dict() or {}).get('teamId') or ''
    except Exception as e:
        logger.warn(f"Failed to read event {event_id} for teamId: {e}")

    return ''


def _get_team_sheet_id(team_id: str) -> str:
    """The team's own spreadsheet id, or '' when export isn't configured.

    Sheets export is opt-in: an unset id is a normal state, not an error."""
    if not team_id:
        return ''

    try:
        doc = get_db().collection('teamSettings').document(team_id).get()
        if doc.exists:
            return (doc.to_dict() or {}).get('googleSheetId') or ''
    except Exception as e:
        logger.warn(f"Failed to read teamSettings/{team_id}: {e}")

    return ''


def _event_tab_name(event_id: str, team_id: str) -> str:
    """Tab name for an event inside a team's workbook.

    Event ids are composite `{teamId}_{eventCode}`. The workbook already
    belongs to one team, so the prefix is redundant noise in the tab name."""
    prefix = f"{team_id}_"
    if team_id and event_id.startswith(prefix):
        return event_id[len(prefix):]
    return event_id


def _delete_sheet_row_for_report(
    event_id: str, report_id: str, report_data: dict | None = None
) -> None:
    """Remove a report's row from its team's sheet.
    Used for hard deletes and for soft-delete transitions."""
    from services.sheets_service import get_sheets_service

    team_id = _resolve_team_id(event_id, report_data)
    spreadsheet_id = _get_team_sheet_id(team_id)

    if not spreadsheet_id:
        logger.debug(
            f"No sheet configured for team {team_id!r}; skipping delete of {report_id}"
        )
        return

    tab = _event_tab_name(event_id, team_id)
    sheets_service = get_sheets_service()

    row_number = sheets_service.find_row_by_report_id(spreadsheet_id, tab, report_id)

    if row_number is None:
        logger.info(f"Report {report_id} not present in sheet tab {tab}; nothing to delete")
        return

    if sheets_service.delete_row(spreadsheet_id, tab, row_number):
        logger.info(f"Deleted row {row_number} for report {report_id}")
    else:
        logger.warn(f"Failed to delete row {row_number} for report {report_id}")


def sync_report_to_sheets(event_id: str, report_id: str, report_data: dict) -> None:
    """Push a single match report to its team's spreadsheet.

    Row identity is resolved against the sheet itself rather than a tracker
    collection: the sheet is the only record of what is in the sheet, so
    there is no second store that can drift out of agreement with it."""
    from services.sheets_service import get_sheets_service

    team_id = _resolve_team_id(event_id, report_data)
    spreadsheet_id = _get_team_sheet_id(team_id)

    if not spreadsheet_id:
        logger.debug(
            f"No sheet configured for team {team_id!r}; skipping sync of {report_id}"
        )
        return

    tab = _event_tab_name(event_id, team_id)

    # The event doc is authoritative for programType — the match doc's field
    # may be missing (legacy writes, external admin writes) which used to
    # silently force the sheet to FRC columns on first sync of an FTC event.
    program_type = _resolve_event_program_type(event_id, report_data)

    try:
        sheets_service = get_sheets_service()
        sheets_service.get_or_create_sheet(spreadsheet_id, tab, program_type)

        row_data = sheets_service.transform_match_report(report_data)
        row_number = sheets_service.find_row_by_report_id(spreadsheet_id, tab, report_id)

        if row_number is not None:
            sheets_service.update_row(spreadsheet_id, tab, row_number, row_data)
            logger.info(f"Updated report {report_id} in row {row_number}")
        else:
            row_number = sheets_service.append_row(spreadsheet_id, tab, row_data)
            logger.info(f"Appended report {report_id} to row {row_number}")

    except Exception as e:
        logger.error(f"Failed to sync report {report_id}: {str(e)}")
        raise


@firestore_fn.on_document_written(document="matches/{reportId}", secrets=["GOOGLE_SHEETS_CREDENTIALS"])
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
            _delete_sheet_row_for_report(event_id, report_id, data_before)
        except Exception as e:
            logger.error(f"Failed to sync delete for report {report_id}: {str(e)}")
    elif not data_before and data_after:
        # Newly created document. If it's created already-deleted (rare,
        # e.g. import of a soft-deleted record), skip pushing it to Sheets.
        if data_after.get('isDeleted'):
            logger.info(f"New match {report_id} is soft-deleted, skipping Sheets sync")
            return

        logger.info(f"Processing new match report: {report_id} for event {event_id}")
        sync_report_to_sheets(event_id, report_id, data_after)
    elif data_before and data_after:
        was_deleted = bool(data_before.get('isDeleted'))
        is_deleted = bool(data_after.get('isDeleted'))

        if is_deleted and not was_deleted:
            # Soft delete (trash): remove the row from Sheets so trashed
            # matches don't keep showing up in analysis views.
            logger.info(f"Processing soft-deleted match report: {report_id} for event {event_id}")
            try:
                _delete_sheet_row_for_report(event_id, report_id, data_after)
            except Exception as e:
                logger.error(f"Failed to sync soft delete for report {report_id}: {str(e)}")
            return

        if is_deleted:
            # Already soft-deleted; ignore further updates (e.g. metadata
            # edits on a trashed match) instead of re-appending the row.
            logger.info(f"Ignoring update to soft-deleted match {report_id}")
            return

        # Restore (was_deleted -> not is_deleted) lands here too: the row was
        # removed on trash, so find_row_by_report_id misses and re-appends.
        logger.info(f"Processing updated match report: {report_id} for event {event_id}")
        sync_report_to_sheets(event_id, report_id, data_after)


def _generate_invite_code() -> str:
    chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    return ''.join(secrets.choice(chars) for _ in range(8))


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
    if (member_snap.to_dict() or {}).get('role') == 'admin':
        admins = list(team_ref.collection('members').where('role', '==', 'admin').get())
        if len(admins) <= 1:
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


_SHEET_URL_RE = re.compile(r'/spreadsheets/d/([a-zA-Z0-9-_]+)')
_SHEET_ID_RE = re.compile(r'^[a-zA-Z0-9-_]+$')


def _extract_sheet_id(value: str) -> str:
    """Accept a full Sheets URL or a bare id; return '' if neither."""
    value = (value or '').strip()
    if not value:
        return ''

    url_match = _SHEET_URL_RE.search(value)
    if url_match:
        return url_match.group(1)

    if _SHEET_ID_RE.match(value):
        return value

    return ''


def _is_team_admin(auth_token: dict | None, team_id: str) -> bool:
    """True if the caller's `teams` claim marks them admin of `team_id`."""
    if not auth_token or not team_id:
        return False
    teams = auth_token.get('teams')
    if not isinstance(teams, dict):
        return False
    return teams.get(team_id) == 'admin'


@https_fn.on_call(secrets=["GOOGLE_SHEETS_CREDENTIALS"])
def set_team_sheet(req: https_fn.CallableRequest) -> dict:
    """Point a team's Sheets export at a spreadsheet the team owns.

    Validated server-side and stored with the Admin SDK: rules deny client
    writes to googleSheetId, the same server-authoritative pattern used for
    team membership."""
    if not req.auth:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Must be authenticated"
        )

    team_id = (req.data or {}).get('teamId') or ''
    raw_sheet = (req.data or {}).get('sheetId') or ''

    if not _is_team_admin(req.auth.token, team_id):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="Only a team admin can configure the team's Google Sheet"
        )

    sheet_id = _extract_sheet_id(raw_sheet)
    if not sheet_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="That doesn't look like a Google Sheets link or id"
        )

    from services.sheets_service import get_sheets_service
    sheets_service = get_sheets_service()

    if not sheets_service.verify_write_access(sheet_id):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message=(
                "Can't open that sheet. Share it as Editor with "
                f"{sheets_service.service_account_email}, then try again."
            )
        )

    get_db().collection('teamSettings').document(team_id).set(
        {
            'googleSheetId': sheet_id,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    logger.info(f"Team {team_id} sheet set to {sheet_id} by {req.auth.uid}")
    return {'success': True, 'googleSheetId': sheet_id}


@https_fn.on_call(secrets=["GOOGLE_SHEETS_CREDENTIALS"])
def backfill_event_to_sheets(req: https_fn.CallableRequest) -> dict:
    """Backfill all live match reports for an event into the team's sheet.

    Idempotent: sync_report_to_sheets updates a row in place when the report
    is already present, so re-running never duplicates rows."""
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

        # Cloud Functions use the Admin SDK and bypass Firestore rules, so
        # we must enforce team isolation here.
        db = get_db()
        event_doc = db.collection('events').document(event_id).get()
        event_team_id = ''
        if event_doc.exists:
            event_team_id = (event_doc.to_dict() or {}).get('teamId', '') or ''

        if event_team_id and not _is_team_member(req.auth.token, event_team_id):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="Caller is not a member of the team that owns this event"
            )

        if not _get_team_sheet_id(event_team_id):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                message="This team has no Google Sheet configured"
            )

        reports_ref = db.collection('matches').where('eventId', '==', event_id)
        if event_team_id:
            reports_ref = reports_ref.where('teamId', '==', event_team_id)

        synced_count = 0
        failed_count = 0

        for report_doc in reports_ref.stream():
            report_id = report_doc.id
            report_data = report_doc.to_dict()

            if report_data.get('isDeleted'):
                continue

            # Skip legacy schedule-shaped docs the same way on_match_written
            # does. TBA/FTC sync used to write schedule entries into /matches
            # (now /schedules); old data would otherwise appear as garbage rows.
            if report_data.get('compLevel') and not report_data.get('scouterName'):
                logger.info(f"Skipping schedule-shaped doc {report_id} during backfill")
                continue

            try:
                sync_report_to_sheets(event_id, report_id, report_data)
                synced_count += 1
            except Exception as e:
                failed_count += 1
                logger.error(f"Failed to sync report {report_id}: {str(e)}")

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
