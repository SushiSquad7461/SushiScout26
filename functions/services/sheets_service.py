"""Google Sheets service for syncing match reports."""

import json
import os
from datetime import datetime
from typing import List, Optional, Dict, Any
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = ['https://www.googleapis.com/auth/spreadsheets']

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
    "Defense Rating",
    "Driver Skill",
    "Robot Died",
    "Trench Traverse",
    "Bump Traverse",
    "Shooting Close",
    "Shooting Mid",
    "Shooting Far",
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
    "Driver Quality",
    "Robot Died",
    "Comments"
]


def _col_letter(n: int) -> str:
    """Convert 1-based column number to letter (1='A', 26='Z', 27='AA')."""
    result = ''
    while n > 0:
        n, remainder = divmod(n - 1, 26)
        result = chr(65 + remainder) + result
    return result


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
        """True if this service account can open the spreadsheet.

        The credentials carry the spreadsheets scope, so a successful
        metadata read with that scope means the account has been granted
        access to the file; a 403/404 means it has not."""
        try:
            self.service.spreadsheets().get(
                spreadsheetId=spreadsheet_id,
                fields='properties.title,sheets.properties'
            ).execute()
            return True
        except HttpError as e:
            import logging
            logging.warning(f"No access to spreadsheet {spreadsheet_id}: {e}")
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
                    self._ensure_column_count(spreadsheet_id, sheet['properties']['sheetId'], len(headers))
                    return sheet['properties']['sheetId']
            
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
        
        # Format headers as bold with color
        self._format_headers(spreadsheet_id, sheet_name, len(headers))
        
        # Set column widths
        self._set_column_widths(spreadsheet_id, sheet_name, program_type)
    
    def _format_headers(self, spreadsheet_id: str, sheet_name: str, column_count: int):
        """Apply bold formatting and background color to header row."""
        sheet_id = self._get_sheet_id(spreadsheet_id, sheet_name)
        
        requests = [
            # Bold and background
            {
                'repeatCell': {
                    'range': {
                        'sheetId': sheet_id,
                        'startRowIndex': 0,
                        'endRowIndex': 1,
                        'startColumnIndex': 0,
                        'endColumnIndex': column_count
                    },
                    'cell': {
                        'userEnteredFormat': {
                            'textFormat': {'bold': True},
                            'backgroundColor': {
                                'red': 0.2,
                                'green': 0.4,
                                'blue': 0.6
                            },
                            'horizontalAlignment': 'CENTER'
                        }
                    },
                    'fields': 'userEnteredFormat(textFormat,backgroundColor,horizontalAlignment)'
                }
            },
            # Wrap text for comments (last column)
            {
                'repeatCell': {
                    'range': {
                        'sheetId': sheet_id,
                        'startRowIndex': 1,
                        'endRowIndex': 1000,
                        'startColumnIndex': column_count - 1,
                        'endColumnIndex': column_count
                    },
                    'cell': {
                        'userEnteredFormat': {
                            'wrapStrategy': 'WRAP'
                        }
                    },
                    'fields': 'userEnteredFormat(wrapStrategy)'
                }
            }
        ]
        
        self.service.spreadsheets().batchUpdate(
            spreadsheetId=spreadsheet_id,
            body={'requests': requests}
        ).execute()
    
    def _set_column_widths(self, spreadsheet_id: str, sheet_name: str, program_type: str = 'FRC'):
        """Set appropriate column widths."""
        try:
            sheet_id = self._get_sheet_id(spreadsheet_id, sheet_name)
            
            # FRC has 19 columns, FTC has 13 columns
            frc_widths = [160, 140, 60, 70, 70, 100, 80, 90, 90, 90, 100, 100, 85, 90, 90, 90, 90, 90, 250]
            ftc_widths = [160, 140, 60, 70, 70, 100, 70, 100, 90, 110, 100, 110, 100, 85, 250]
            widths = ftc_widths if program_type == 'FTC' else frc_widths
            
            requests = []
            for col_idx, width in enumerate(widths):
                requests.append({
                    'updateDimensionProperties': {
                        'range': {
                            'sheetId': sheet_id,
                            'dimension': 'COLUMNS',
                            'startIndex': col_idx,
                            'endIndex': col_idx + 1
                        },
                        'properties': {'pixelSize': width},
                        'fields': 'pixelSize'
                    }
                })
            
            self.service.spreadsheets().batchUpdate(
                spreadsheetId=spreadsheet_id,
                body={'requests': requests}
            ).execute()
        except Exception as e:
            import logging
            logging.warning(f"Could not set column widths: {e}")
    
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

    def append_rows(self, spreadsheet_id: str, sheet_name: str, rows: List[List[Any]]) -> int:
        """Append multiple rows at once. Returns starting row number (1-indexed)."""
        if not rows:
            return 0

        last_col = _col_letter(len(rows[0]))
        range_name = f"'{sheet_name}'!A:{last_col}"
        body = {'values': rows}
        
        result = self.service.spreadsheets().values().append(
            spreadsheetId=spreadsheet_id,
            range=range_name,
            valueInputOption='RAW',
            insertDataOption='INSERT_ROWS',
            body=body
        ).execute()
        
        updated_range = result['updates']['updatedRange']
        after_bang = updated_range.split('!')[-1]
        row_number = int(''.join(c for c in after_bang.split(':')[0] if c.isdigit()))
        return row_number

    def update_rows(self, spreadsheet_id: str, sheet_name: str, 
                    updates: List[tuple]) -> None:
        """Update multiple rows at specific row numbers."""
        if not updates:
            return
        
        data = []
        for row_number, row_data in updates:
            last_col = _col_letter(len(row_data))
            data.append({
                'range': f"'{sheet_name}'!A{row_number}:{last_col}{row_number}",
                'values': [row_data]
            })
        
        body = {'valueInputOption': 'RAW', 'data': data}
        self.service.spreadsheets().values().batchUpdate(
            spreadsheetId=spreadsheet_id,
            body=body
        ).execute()
    
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
            f"{game_data.get('defense_rating', 0)}/5",
            f"{game_data.get('driver_skill', 0)}/5",
            'Yes' if game_data.get('robot_died', False) else 'No',
            'Yes' if game_data.get('trench_traverse', False) else 'No',
            'Yes' if game_data.get('bump_traverse', False) else 'No',
            'Yes' if game_data.get('shooting_range_close', False) else 'No',
            'Yes' if game_data.get('shooting_range_mid', False) else 'No',
            'Yes' if game_data.get('shooting_range_far', False) else 'No',
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
            f"{int(game_data.get('driver_quality', 0))}/5",
            'Yes' if game_data.get('robot_died', False) else 'No',
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
