"""Google Sheets service for syncing match reports."""

import json
import math
import os
from datetime import datetime
from typing import List, Optional, Dict, Any
from google.auth.exceptions import GoogleAuthError
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = ['https://www.googleapis.com/auth/spreadsheets']


class SheetsCredentialsError(Exception):
    """The service account's own credentials failed (expired, revoked, or
    malformed key) — as distinct from the team's sheet not being shared.

    These need opposite fixes: a sharing failure is the admin's to solve,
    a credentials failure is the operator's. Conflating them tells the
    admin to re-share a sheet they already shared correctly."""

# Column headers for FRC match reports
FRC_HEADERS = [
    "Timestamp",
    "Match ID",
    "Match #",
    "Team #",
    "Alliance",
    "Scouter",
    "Auto Fuel",
    "Auto L1 Hang",
    "Teleop Fuel",
    "Climb Level",
    "Defense Rating (/5)",
    "Driver Skill (/5)",
    "Robot Died",
    "Trench Traverse",
    "Bump Traverse",
    "Shooting Close",
    "Shooting Mid",
    "Shooting Far",
    "Drivetrain Speed (/5)",
    "Intake Speed (/5)",
    "Shooter Speed (/5)",
    "Defense Cause",
    "Died At",
    "Died Reason",
    "Comments"
]

# Column headers for FTC match reports
FTC_HEADERS = [
    "Timestamp",
    "Match ID",
    "Match #",
    "Team #",
    "Alliance",
    "Scouter",
    "Leave",
    "Auto Artifacts",
    "Auto Indexing",
    "Teleop Artifacts",
    "Teleop Indexing",
    "Base Expansion",
    "Driver Quality (/5)",
    "Robot Died",
    "Defense Rating (/5)",
    "Drivetrain Speed (/5)",
    "Intake Speed (/5)",
    "Shooter Speed (/5)",
    "Defense Cause",
    "Died At",
    "Died Reason",
    "Comments"
]

# Pixel width per column, by header. Anything not listed gets the default.
_COLUMN_WIDTHS = {
    "Timestamp": 150, "Match #": 70, "Team #": 75,
    "Alliance": 80, "Scouter": 110, "Climb Level": 100,
    "Base Expansion": 120, "Defense Cause": 120, "Died At": 80,
    "Died Reason": 200, "Comments": 300,
}
_DEFAULT_COLUMN_WIDTH = 95
# Free-text columns: left-aligned and wrapped. Every other column is a short
# value (number, Yes/No, 1-5 rating), so it is centered and clipped.
_TEXT_COLUMNS = {"Timestamp", "Scouter", "Died Reason", "Comments"}
# Kept for row identity, not for reading.
_HIDDEN_COLUMNS = {"Match ID"}
_WRAP_COLUMNS = {"Died Reason", "Comments"}

_HEADER_BG = {'red': 0.122, 'green': 0.161, 'blue': 0.216}
_HEADER_FG = {'red': 1.0, 'green': 1.0, 'blue': 1.0}
_BAND_ALT = {'red': 0.953, 'green': 0.957, 'blue': 0.965}
_BAND_WHITE = {'red': 1.0, 'green': 1.0, 'blue': 1.0}
_RED_TINT = {'red': 0.957, 'green': 0.780, 'blue': 0.765}
_BLUE_TINT = {'red': 0.788, 'green': 0.855, 'blue': 0.973}

DEFENSE_CAUSE_LABELS = {'broke': 'Robot Broke', 'strategic': 'Strategic'}


def _col_letter(n: int) -> str:
    """Convert 1-based column number to letter (1='A', 26='Z', 27='AA')."""
    result = ''
    while n > 0:
        n, remainder = divmod(n - 1, 26)
        result = chr(65 + remainder) + result
    return result


def _rating(value: Any) -> Any:
    """A 0-5 rating as a plain number, so the sheet can sort and average it.
    The "/5" scale lives in the column header. A missing rating is a blank
    cell, not 0, so it cannot drag an AVERAGE down."""
    if value is None or value == '':
        return ''
    try:
        number = float(value)
    except (TypeError, ValueError):
        return ''
    if not math.isfinite(number):
        return ''
    return int(number) if number.is_integer() else number


def _format_died_at(seconds_remaining: Optional[int]) -> str:
    """Format a stored died_at_seconds value (seconds remaining on the
    match clock, matching MatchTimer's own countdown convention) as mm:ss
    for the sheet — the same format the app itself displays. Returns an
    empty string when the robot never died."""
    if seconds_remaining is None:
        return ''
    minutes, seconds = divmod(int(seconds_remaining), 60)
    return f'{minutes}:{seconds:02d}'


class SheetsService:
    """Service for interacting with Google Sheets API."""

    def __init__(self, credentials_json: str):
        """Initialize with service account credentials JSON string."""
        creds_dict = json.loads(credentials_json)
        credentials = service_account.Credentials.from_service_account_info(
            creds_dict, scopes=SCOPES
        )
        self.service = build('sheets', 'v4', credentials=credentials)
        self._service_account_email = creds_dict.get('client_email', '')

    @property
    def service_account_email(self) -> str:
        """The address a team must share their sheet with, as Editor."""
        return self._service_account_email

    def verify_write_access(self, spreadsheet_id: str) -> bool:
        """True if this service account can actually WRITE to the spreadsheet.

        A metadata read only proves Viewer-level access, which is not
        enough to sync match data. This reads the current title and writes
        it straight back via batchUpdate — a real write that changes
        nothing visible. Viewer shares get a 403 on the write; Editor
        shares pass.

        Raises SheetsCredentialsError if OUR OWN credentials are the
        problem — that is an operator fault the team cannot fix by
        sharing the sheet, so it must not be reported as one."""
        try:
            meta = self.service.spreadsheets().get(
                spreadsheetId=spreadsheet_id, fields='properties.title'
            ).execute()
            title = meta['properties']['title']

            self.service.spreadsheets().batchUpdate(
                spreadsheetId=spreadsheet_id,
                body={'requests': [{
                    'updateSpreadsheetProperties': {
                        'properties': {'title': title},
                        'fields': 'title',
                    }
                }]}
            ).execute()
            return True
        except GoogleAuthError as e:
            import logging
            logging.error(
                f"Sheets service-account credentials failed while probing "
                f"{spreadsheet_id}: {e}"
            )
            raise SheetsCredentialsError(str(e)) from e
        except HttpError as e:
            import logging
            logging.warning(f"No write access to spreadsheet {spreadsheet_id}: {e}")
            return False

    def get_headers(self, program_type: str = 'FRC') -> List[str]:
        """Get column headers based on program type."""
        return FTC_HEADERS if program_type == 'FTC' else FRC_HEADERS
    
    def get_or_create_sheet(self, spreadsheet_id: str, sheet_name: str, program_type: str = 'FRC') -> int:
        """Get sheet ID by name, create if doesn't exist. Returns sheet ID."""
        headers = self.get_headers(program_type)
        
        try:
            spreadsheet = self.service.spreadsheets().get(
                spreadsheetId=spreadsheet_id
            ).execute()
            
            # Check if sheet exists
            for sheet in spreadsheet.get('sheets', []):
                if sheet['properties']['title'] == sheet_name:
                    # Sheet exists, ensure it has enough columns
                    existing_id = sheet['properties']['sheetId']
                    self._ensure_column_count(spreadsheet_id, existing_id, len(headers))
                    # A frozen header row is our marker that the tab is
                    # already styled, so this costs nothing after the first
                    # write and brings pre-existing tabs up to date once.
                    frozen = sheet['properties'].get('gridProperties', {}).get('frozenRowCount', 0)
                    if frozen < 1:
                        banding = [b['bandedRangeId'] for b in sheet.get('bandedRanges', [])]
                        self._style_existing_sheet(
                            spreadsheet_id, sheet_name, existing_id, program_type, banding
                        )
                    return existing_id
            
            # Create new sheet
            body = {
                'requests': [{
                    'addSheet': {
                        'properties': {
                            'title': sheet_name,
                            'gridProperties': {
                                'rowCount': 1000,
                                'columnCount': len(headers)
                            }
                        }
                    }
                }]
            }
            
            result = self.service.spreadsheets().batchUpdate(
                spreadsheetId=spreadsheet_id,
                body=body
            ).execute()
            
            sheet_id = result['replies'][0]['addSheet']['properties']['sheetId']
            
            # Add headers to new sheet
            self._write_headers(spreadsheet_id, sheet_name, program_type)
            self._style_sheet(spreadsheet_id, sheet_id, program_type)
            
            return sheet_id
            
        except HttpError as e:
            raise Exception(f"Failed to get or create sheet: {e}")
    
    def _ensure_column_count(self, spreadsheet_id: str, sheet_id: int, required_columns: int):
        """Ensure sheet has enough columns."""
        spreadsheet = self.service.spreadsheets().get(
            spreadsheetId=spreadsheet_id
        ).execute()
        
        for sheet in spreadsheet.get('sheets', []):
            if sheet['properties']['sheetId'] == sheet_id:
                current_cols = sheet['properties'].get('gridProperties', {}).get('columnCount', 0)
                if current_cols < required_columns:
                    # Need to add columns
                    body = {
                        'requests': [{
                            'updateSheetProperties': {
                                'properties': {
                                    'sheetId': sheet_id,
                                    'gridProperties': {
                                        'columnCount': required_columns
                                    }
                                },
                                'fields': 'gridProperties.columnCount'
                            }
                        }]
                    }
                    self.service.spreadsheets().batchUpdate(
                        spreadsheetId=spreadsheet_id,
                        body=body
                    ).execute()
                break
    
    def _write_headers(self, spreadsheet_id: str, sheet_name: str, program_type: str = 'FRC'):
        """Write header row to sheet."""
        headers = self.get_headers(program_type)
        range_name = f"'{sheet_name}'!1:1"
        body = {
            'values': [headers]
        }
        
        self.service.spreadsheets().values().update(
            spreadsheetId=spreadsheet_id,
            range=range_name,
            valueInputOption='RAW',
            body=body
        ).execute()
        

    def _style_existing_sheet(self, spreadsheet_id: str, sheet_name: str, sheet_id: int,
                              program_type: str, banding_ids: List[int]):
        """Style a tab that predates the styling pass.

        Its header row is rewritten only when it is the same column layout
        as today's, differing at most in the "(/5)" rating labels. A tab
        with a different layout keeps its headers (relabeling would put the
        wrong names over its data) and skips the highlight rules, which
        address columns by the current layout."""
        headers = self.get_headers(program_type)
        same_layout = False
        try:
            result = self.service.spreadsheets().values().get(
                spreadsheetId=spreadsheet_id, range=f"'{sheet_name}'!1:1"
            ).execute()
            current = (result.get('values') or [[]])[0]
            strip = lambda hs: [h.replace(' (/5)', '') for h in hs]
            same_layout = strip(current) == strip(headers)
            if same_layout and current != headers:
                self._write_headers(spreadsheet_id, sheet_name, program_type)
        except Exception as e:
            import logging
            logging.warning(f"Could not check headers of {sheet_name!r}: {e}")
        self._style_sheet(spreadsheet_id, sheet_id, program_type, banding_ids, highlight=same_layout)

    def _style_sheet(self, spreadsheet_id: str, sheet_id: int, program_type: str = 'FRC',
                     existing_banding_ids: Optional[List[int]] = None,
                     highlight: bool = True):
        """Make a tab readable: styled and frozen header, filter, row banding,
        per-column width and alignment, and highlights for dead robots and
        alliance color.

        Formatting only — it never writes cell values. All requests go out in
        one batchUpdate, so the frozen header row (which get_or_create_sheet
        uses as the "already styled" marker) lands atomically with the rest.
        A failure is logged, not raised: a cosmetic problem must never drop
        a scout's match row."""
        headers = self.get_headers(program_type)
        n = len(headers)

        def cols(start=0, end=n):
            return {'sheetId': sheet_id, 'startColumnIndex': start, 'endColumnIndex': end}

        requests = [
            # A banded range cannot overlap another, so clear any first. This
            # keeps the pass re-runnable on a tab someone already banded.
            *({'deleteBanding': {'bandedRangeId': i}} for i in (existing_banding_ids or [])),
            # Header row.
            {'repeatCell': {
                'range': {**cols(), 'startRowIndex': 0, 'endRowIndex': 1},
                'cell': {'userEnteredFormat': {
                    'backgroundColor': _HEADER_BG,
                    'textFormat': {'bold': True, 'foregroundColor': _HEADER_FG},
                    'horizontalAlignment': 'CENTER',
                    'verticalAlignment': 'MIDDLE',
                    'wrapStrategy': 'WRAP',
                }},
                'fields': 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment,verticalAlignment,wrapStrategy)',
            }},
            {'updateDimensionProperties': {
                'range': {'sheetId': sheet_id, 'dimension': 'ROWS', 'startIndex': 0, 'endIndex': 1},
                'properties': {'pixelSize': 44},
                'fields': 'pixelSize',
            }},
            {'updateSheetProperties': {
                'properties': {'sheetId': sheet_id, 'gridProperties': {'frozenRowCount': 1}},
                'fields': 'gridProperties.frozenRowCount',
            }},
            {'setBasicFilter': {'filter': {'range': {**cols(), 'startRowIndex': 0}}}},
            # Alternating row shading, open-ended so appended rows inherit it.
            {'addBanding': {'bandedRange': {
                'range': {**cols(), 'startRowIndex': 1},
                'rowProperties': {
                    'firstBandColor': _BAND_WHITE,
                    'secondBandColor': _BAND_ALT,
                },
            }}},
        ]

        # Column widths, plus alignment/wrapping for the body of each column.
        for idx, name in enumerate(headers):
            requests.append({'updateDimensionProperties': {
                'range': {'sheetId': sheet_id, 'dimension': 'COLUMNS', 'startIndex': idx, 'endIndex': idx + 1},
                'properties': {
                    'pixelSize': _COLUMN_WIDTHS.get(name, _DEFAULT_COLUMN_WIDTH),
                    # Match ID is hidden, not removed: find_row_by_report_id
                    # reads it (column B) to find a report's row, so deleting
                    # it would turn every update into a duplicate append.
                    'hiddenByUser': name in _HIDDEN_COLUMNS,
                },
                'fields': 'pixelSize,hiddenByUser',
            }})
            requests.append({'repeatCell': {
                'range': {**cols(idx, idx + 1), 'startRowIndex': 1},
                'cell': {'userEnteredFormat': {
                    'horizontalAlignment': 'LEFT' if name in _TEXT_COLUMNS else 'CENTER',
                    'verticalAlignment': 'MIDDLE',
                    'wrapStrategy': 'WRAP' if name in _WRAP_COLUMNS else 'CLIP',
                }},
                'fields': 'userEnteredFormat(horizontalAlignment,verticalAlignment,wrapStrategy)',
            }})

        # Highlights. Row 2 is the first data row; the formula is relative.
        died_idx = headers.index("Robot Died")
        alliance_idx = headers.index("Alliance")
        died, alliance = _col_letter(died_idx + 1), _col_letter(alliance_idx + 1)
        for col_idx, formula, color in () if not highlight else (
            (died_idx, f'=${died}2="Yes"', _RED_TINT),
            (alliance_idx, f'=LOWER(${alliance}2)="red"', _RED_TINT),
            (alliance_idx, f'=LOWER(${alliance}2)="blue"', _BLUE_TINT),
        ):
            requests.append({'addConditionalFormatRule': {
                'index': 0,
                'rule': {
                    'ranges': [{**cols(col_idx, col_idx + 1), 'startRowIndex': 1}],
                    'booleanRule': {
                        'condition': {'type': 'CUSTOM_FORMULA', 'values': [{'userEnteredValue': formula}]},
                        'format': {'backgroundColor': color},
                    },
                },
            }})

        try:
            self.service.spreadsheets().batchUpdate(
                spreadsheetId=spreadsheet_id,
                body={'requests': requests},
            ).execute()
        except Exception as e:
            import logging
            logging.warning(f"Could not style sheet {sheet_id}: {e}")

    def sheet_exists(self, spreadsheet_id: str, sheet_name: str) -> bool:
        """True if a tab named `sheet_name` already exists in the workbook.

        Read-only check — unlike get_or_create_sheet, this never creates
        the tab. Callers that only want to look something up (e.g. a
        delete) must not have the side effect of materializing a tab that
        holds nothing."""
        spreadsheet = self.service.spreadsheets().get(
            spreadsheetId=spreadsheet_id, fields='sheets.properties.title'
        ).execute()
        return any(
            sheet['properties']['title'] == sheet_name
            for sheet in spreadsheet.get('sheets', [])
        )

    def _get_sheet_id(self, spreadsheet_id: str, sheet_name: str) -> int:
        """Get numeric sheet ID from name."""
        spreadsheet = self.service.spreadsheets().get(
            spreadsheetId=spreadsheet_id
        ).execute()
        
        for sheet in spreadsheet.get('sheets', []):
            if sheet['properties']['title'] == sheet_name:
                return sheet['properties']['sheetId']
        
        raise ValueError(f"Sheet '{sheet_name}' not found")
    
    def append_row(self, spreadsheet_id: str, sheet_name: str, row_data: List[Any]) -> int:
        """Append a row to the sheet. Returns the row number (1-indexed)."""
        last_col = _col_letter(len(row_data))
        range_name = f"'{sheet_name}'!A:{last_col}"
        
        body = {
            'values': [row_data]
        }
        
        result = self.service.spreadsheets().values().append(
            spreadsheetId=spreadsheet_id,
            range=range_name,
            valueInputOption='RAW',
            insertDataOption='INSERT_ROWS',
            body=body
        ).execute()
        
        updated_range = result['updates']['updatedRange']
        # Parse row number from range like "'Sheet'!A5:S5"
        after_bang = updated_range.split('!')[-1]
        row_number = int(''.join(c for c in after_bang.split(':')[0] if c.isdigit()))
        return row_number

    def update_row(self, spreadsheet_id: str, sheet_name: str, row_number: int, row_data: List[Any]):
        """Update an existing row."""
        last_col = _col_letter(len(row_data))
        range_name = f"'{sheet_name}'!A{row_number}:{last_col}{row_number}"
        
        body = {
            'values': [row_data]
        }
        
        self.service.spreadsheets().values().update(
            spreadsheetId=spreadsheet_id,
            range=range_name,
            valueInputOption='RAW',
            body=body
        ).execute()
    
    def find_row_by_report_id(self, spreadsheet_id: str, sheet_name: str, report_id: str) -> Optional[int]:
        """Find row number by Firestore report_id.

        Sheets stores the matchId (e.g. "2026waore_qm1") in column B and
        the teamNumber in column D, but the Firestore document id is the
        concatenation: f"{matchId}_{teamNumber}" (e.g.
        "2026waore_qm1_254"). The old implementation searched column B
        for the full report_id and therefore always returned None on real
        data — the fallback delete path was effectively dead.

        Reconstruct each row's implicit report_id from (matchId, teamNumber)
        and match against the input. Fall back to direct column-B compare
        for any legacy rows that stored the report_id verbatim.
        """
        range_name = f"'{sheet_name}'!A:D"

        result = self.service.spreadsheets().values().get(
            spreadsheetId=spreadsheet_id,
            range=range_name
        ).execute()

        values = result.get('values', [])

        for i, row in enumerate(values):
            if len(row) < 2:
                continue
            match_id = row[1]
            if match_id == report_id:
                return i + 1
            if len(row) > 3 and f"{match_id}_{row[3]}" == report_id:
                return i + 1

        return None
    
    def delete_row(self, spreadsheet_id: str, sheet_name: str, row_number: int) -> bool:
        """Delete a row from the sheet by row number. Returns True if successful."""
        try:
            sheet_id = self._get_sheet_id(spreadsheet_id, sheet_name)
            
            request = {
                'deleteDimension': {
                    'range': {
                        'sheetId': sheet_id,
                        'dimension': 'ROWS',
                        'startIndex': row_number - 1,
                        'endIndex': row_number
                    }
                }
            }
            
            self.service.spreadsheets().batchUpdate(
                spreadsheetId=spreadsheet_id,
                body={'requests': [request]}
            ).execute()
            return True
        except HttpError as e:
            import logging
            logging.warning(f"Could not delete row {row_number}: {e}")
            return False
    
    def transform_match_report(self, report_data: Dict[str, Any]) -> List[Any]:
        """Transform Firestore match report to row format based on program type."""
        game_data = report_data.get('gameData', {})
        program_type = report_data.get('programType', 'FRC')
        
        # Handle timestamp formatting
        created_at = report_data.get('createdAt', '')
        if isinstance(created_at, datetime):
            timestamp_str = created_at.strftime('%Y-%m-%d %H:%M:%S')
        elif hasattr(created_at, 'isoformat'):
            timestamp_str = created_at.isoformat()
        else:
            timestamp_str = str(created_at)
        
        if program_type == 'FTC':
            return self._transform_ftc_report(report_data, game_data, timestamp_str)
        else:
            return self._transform_frc_report(report_data, game_data, timestamp_str)
    
    def _transform_frc_report(self, report_data: Dict[str, Any], game_data: Dict[str, Any], timestamp_str: str) -> List[Any]:
        """Transform FRC match report to row format."""
        # Climb level mapping
        climb_level = game_data.get('teleop_tower_level', 0)
        climb_map = {0: 'No Climb', 1: 'Level 1', 2: 'Level 2', 3: 'Level 3'}
        climb_str = climb_map.get(climb_level, f'Level {climb_level}')

        return [
            timestamp_str,
            report_data.get('matchId', ''),
            report_data.get('matchNumber', 0),
            report_data.get('teamNumber', 0),
            report_data.get('alliance', ''),
            report_data.get('scouterName', ''),
            game_data.get('auto_fuel', 0),
            'Yes' if game_data.get('auto_tower_l1', False) else 'No',
            game_data.get('teleop_fuel', 0),
            climb_str,
            _rating(game_data.get('defense_rating')),
            _rating(game_data.get('driver_skill')),
            'Yes' if game_data.get('robot_died', False) else 'No',
            'Yes' if game_data.get('trench_traverse', False) else 'No',
            'Yes' if game_data.get('bump_traverse', False) else 'No',
            'Yes' if game_data.get('shooting_range_close', False) else 'No',
            'Yes' if game_data.get('shooting_range_mid', False) else 'No',
            'Yes' if game_data.get('shooting_range_far', False) else 'No',
            _rating(game_data.get('drivetrain_speed')),
            _rating(game_data.get('intake_speed')),
            _rating(game_data.get('shooter_speed')),
            DEFENSE_CAUSE_LABELS.get(game_data.get('defense_cause'), ''),
            _format_died_at(game_data.get('died_at_seconds')),
            game_data.get('died_reason', ''),
            report_data.get('comments', '')
        ]

    def _transform_ftc_report(self, report_data: Dict[str, Any], game_data: Dict[str, Any], timestamp_str: str) -> List[Any]:
        """Transform FTC match report to row format."""

        return [
            timestamp_str,
            report_data.get('matchId', ''),
            report_data.get('matchNumber', 0),
            report_data.get('teamNumber', 0),
            report_data.get('alliance', ''),
            report_data.get('scouterName', ''),
            'Yes' if game_data.get('leave', False) else 'No',
            game_data.get('artifacts_auto', 0),
            'Yes' if game_data.get('indexing_auto', False) else 'No',
            game_data.get('artifacts_teleop', 0),
            'Yes' if game_data.get('indexing_teleop', False) else 'No',
            game_data.get('base_expansion', 'None'),
            _rating(game_data.get('driver_quality')),
            'Yes' if game_data.get('robot_died', False) else 'No',
            _rating(game_data.get('defense_rating')),
            _rating(game_data.get('drivetrain_speed')),
            _rating(game_data.get('intake_speed')),
            _rating(game_data.get('shooter_speed')),
            DEFENSE_CAUSE_LABELS.get(game_data.get('defense_cause'), ''),
            _format_died_at(game_data.get('died_at_seconds')),
            game_data.get('died_reason', ''),
            report_data.get('comments', '')
        ]


# Singleton instance
_sheets_service: Optional[SheetsService] = None

def get_sheets_service() -> SheetsService:
    """Get or create singleton SheetsService instance."""
    global _sheets_service
    if _sheets_service is None:
        creds_json = os.environ.get('GOOGLE_SHEETS_CREDENTIALS')
        if not creds_json:
            raise ValueError("GOOGLE_SHEETS_CREDENTIALS not set")
        _sheets_service = SheetsService(creds_json)
    return _sheets_service
