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
    "Teleop Fuel",
    "Climb Level",
    "Robot Died",
    "Comments"
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
    
    def _write_headers(self, spreadsheet_id: str, sheet_name: str):
        """Write header row to sheet."""
        range_name = f"{sheet_name}!A1:K1"
        body = {
            'values': [FRC_HEADERS]
        }
        
        self.service.spreadsheets().values().update(
            spreadsheetId=spreadsheet_id,
            range=range_name,
            valueInputOption='RAW',
            body=body
        ).execute()
        
        # Format headers as bold
        self._format_headers(spreadsheet_id, sheet_name)
    
    def _format_headers(self, spreadsheet_id: str, sheet_name: str):
        """Apply bold formatting to header row."""
        requests = [{
            'repeatCell': {
                'range': {
                    'sheetId': self._get_sheet_id(spreadsheet_id, sheet_name),
                    'startRowIndex': 0,
                    'endRowIndex': 1,
                    'startColumnIndex': 0,
                    'endColumnIndex': len(FRC_HEADERS)
                },
                'cell': {
                    'userEnteredFormat': {
                        'textFormat': {'bold': True},
                        'backgroundColor': {
                            'red': 0.9,
                            'green': 0.9,
                            'blue': 0.9
                        }
                    }
                },
                'fields': 'userEnteredFormat(textFormat,backgroundColor)'
            }
        }]
        
        self.service.spreadsheets().batchUpdate(
            spreadsheetId=spreadsheet_id,
            body={'requests': requests}
        ).execute()
    
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
        range_name = f"{sheet_name}!A:K"
        
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
        
        # Extract row number from updated range
        updated_range = result['updates']['updatedRange']
        row_number = int(updated_range.split('!')[1].split(':')[0][1:])
        return row_number
    
    def update_row(self, spreadsheet_id: str, sheet_name: str, row_number: int, row_data: List[Any]):
        """Update an existing row."""
        range_name = f"{sheet_name}!A{row_number}:K{row_number}"
        
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
        """Find row number by report ID (stored in Match ID column). Returns row number or None."""
        # Get all data from sheet
        range_name = f"{sheet_name}!A:K"
        
        result = self.service.spreadsheets().values().get(
            spreadsheetId=spreadsheet_id,
            range=range_name
        ).execute()
        
        values = result.get('values', [])
        
        # Search for report_id in Match ID column (column B, index 1)
        for i, row in enumerate(values):
            if len(row) > 1 and row[1] == report_id:
                return i + 1  # Convert to 1-indexed row number
        
        return None
    
    def transform_match_report(self, report_data: Dict[str, Any]) -> List[Any]:
        """Transform Firestore match report to row format."""
        game_data = report_data.get('gameData', {})
        
        # Handle timestamp formatting
        created_at = report_data.get('createdAt', '')
        if isinstance(created_at, datetime):
            timestamp_str = created_at.isoformat()
        elif hasattr(created_at, 'isoformat'):
            timestamp_str = created_at.isoformat()
        else:
            timestamp_str = str(created_at)
        
        return [
            timestamp_str,
            report_data.get('matchId', ''),
            report_data.get('matchNumber', 0),
            report_data.get('teamNumber', 0),
            report_data.get('alliance', ''),
            report_data.get('scouterName', ''),
            game_data.get('auto_fuel', 0),
            game_data.get('teleop_fuel', 0),
            game_data.get('teleop_tower_level', 0),
            'Yes' if report_data.get('robotDied') else 'No',
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
