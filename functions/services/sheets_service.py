"""Google Sheets service for syncing match reports."""

import json
import os
from datetime import datetime
from typing import List, Optional, Dict, Any
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = ['https://www.googleapis.com/auth/spreadsheets']

# Column headers for FRC match reports - matches scouting wizard schema
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
    "Comments",
    "Images"
]


class SheetsService:
    """Service for interacting with Google Sheets API."""
    
    def __init__(self, credentials_json: str):
        """Initialize with service account credentials JSON string."""
        creds_dict = json.loads(credentials_json)
        credentials = service_account.Credentials.from_service_account_info(
            creds_dict, scopes=SCOPES
        )
        self.service = build('sheets', 'v4', credentials=credentials)
    
    def get_or_create_sheet(self, spreadsheet_id: str, sheet_name: str) -> int:
        """Get sheet ID by name, create if doesn't exist. Returns sheet ID."""
        try:
            spreadsheet = self.service.spreadsheets().get(
                spreadsheetId=spreadsheet_id
            ).execute()
            
            # Check if sheet exists
            for sheet in spreadsheet.get('sheets', []):
                if sheet['properties']['title'] == sheet_name:
                    # Sheet exists, ensure it has enough columns
                    self._ensure_column_count(spreadsheet_id, sheet['properties']['sheetId'], len(FRC_HEADERS))
                    return sheet['properties']['sheetId']
            
            # Create new sheet
            body = {
                'requests': [{
                    'addSheet': {
                        'properties': {
                            'title': sheet_name,
                            'gridProperties': {
                                'rowCount': 1000,
                                'columnCount': len(FRC_HEADERS)
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
            self._write_headers(spreadsheet_id, sheet_name)
            
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
    
    def _write_headers(self, spreadsheet_id: str, sheet_name: str):
        """Write header row to sheet."""
        range_name = f"{sheet_name}!1:1"
        body = {
            'values': [FRC_HEADERS]
        }
        
        self.service.spreadsheets().values().update(
            spreadsheetId=spreadsheet_id,
            range=range_name,
            valueInputOption='RAW',
            body=body
        ).execute()
        
        # Format headers as bold with color
        self._format_headers(spreadsheet_id, sheet_name)
        
        # Set column widths
        self._set_column_widths(spreadsheet_id, sheet_name)
    
    def _format_headers(self, spreadsheet_id: str, sheet_name: str):
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
                        'endColumnIndex': len(FRC_HEADERS)
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
            # Wrap text for comments
            {
                'repeatCell': {
                    'range': {
                        'sheetId': sheet_id,
                        'startRowIndex': 1,
                        'endRowIndex': 1000,
                        'startColumnIndex': len(FRC_HEADERS) - 2,  # Comments column
                        'endColumnIndex': len(FRC_HEADERS) - 1
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
    
    def _set_column_widths(self, spreadsheet_id: str, sheet_name: str):
        """Set appropriate column widths."""
        try:
            sheet_id = self._get_sheet_id(spreadsheet_id, sheet_name)
            
            requests = []
            for col_idx, width in enumerate([
                160, 140, 60, 70, 70, 100, 80, 90, 90, 90, 100, 100, 85, 250, 80
            ]):
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
        range_name = f"{sheet_name}!A:O"
        
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
        row_number = int(updated_range.split('!')[1].split(':')[0][1:])
        return row_number
    
    def append_rows(self, spreadsheet_id: str, sheet_name: str, rows: List[List[Any]]) -> int:
        """Append multiple rows at once. Returns starting row number (1-indexed)."""
        if not rows:
            return 0
        
        range_name = f"{sheet_name}!A:O"
        body = {'values': rows}
        
        result = self.service.spreadsheets().values().append(
            spreadsheetId=spreadsheet_id,
            range=range_name,
            valueInputOption='RAW',
            insertDataOption='INSERT_ROWS',
            body=body
        ).execute()
        
        updated_range = result['updates']['updatedRange']
        row_number = int(updated_range.split('!')[1].split(':')[0][1:])
        return row_number

    def update_rows(self, spreadsheet_id: str, sheet_name: str, 
                    updates: List[tuple]) -> None:
        """Update multiple rows at specific row numbers."""
        if not updates:
            return
        
        data = []
        for row_number, row_data in updates:
            data.append({
                'range': f"{sheet_name}!A{row_number}:O{row_number}",
                'values': [row_data]
            })
        
        body = {'valueInputOption': 'RAW', 'data': data}
        self.service.spreadsheets().values().batchUpdate(
            spreadsheetId=spreadsheet_id,
            body=body
        ).execute()
    
    def update_row(self, spreadsheet_id: str, sheet_name: str, row_number: int, row_data: List[Any]):
        """Update an existing row."""
        range_name = f"{sheet_name}!A{row_number}:O{row_number}"
        
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
        """Find row number by report ID (stored in Match ID column)."""
        range_name = f"{sheet_name}!A:O"
        
        result = self.service.spreadsheets().values().get(
            spreadsheetId=spreadsheet_id,
            range=range_name
        ).execute()
        
        values = result.get('values', [])
        
        # Search for report_id in Match ID column (column B, index 1)
        for i, row in enumerate(values):
            if len(row) > 1 and row[1] == report_id:
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
        """Transform Firestore match report to row format - matches scouting wizard schema."""
        game_data = report_data.get('gameData', {})
        
        # Handle timestamp formatting
        created_at = report_data.get('createdAt', '')
        if isinstance(created_at, datetime):
            timestamp_str = created_at.strftime('%Y-%m-%d %H:%M:%S')
        elif hasattr(created_at, 'isoformat'):
            timestamp_str = created_at.isoformat()
        else:
            timestamp_str = str(created_at)
        
        # Format images as comma-separated list
        images = report_data.get('images', [])
        images_str = ', '.join(images) if images else ''
        
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
            'Yes' if report_data.get('robotDied') else 'No',
            report_data.get('comments', ''),
            images_str
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
