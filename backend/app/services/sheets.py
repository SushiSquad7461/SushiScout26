import gspread
from oauth2client.service_account import ServiceAccountCredentials
import json
from ..config import get_settings
import logging

logger = logging.getLogger(__name__)
settings = get_settings()

class SheetsService:
    def __init__(self):
        self.client = None
        self.sheet = None
        self._authenticate()

    def _authenticate(self):
        try:
            if not settings.google_service_account_json or settings.google_service_account_json == "{}":
                logger.warning("Google Service Account JSON not set. Sheets sync disabled.")
                return

            creds_dict = json.loads(settings.google_service_account_json)
            scope = [
                'https://spreadsheets.google.com/feeds',
                'https://www.googleapis.com/auth/drive'
            ]
            creds = ServiceAccountCredentials.from_json_keyfile_dict(creds_dict, scope)
            self.client = gspread.authorize(creds)
            
            if settings.google_sheet_id:
                try:
                    self.sheet = self.client.open_by_key(settings.google_sheet_id).sheet1
                except Exception as e:
                    logger.error(f"Could not open sheet by ID: {e}")
            
        except Exception as e:
            logger.error(f"Failed to authenticate with Google Sheets: {e}")

    def append_match(self, row_data: list) -> bool:
        if not self.sheet:
             # Try re-auth once if session expired or not init
             self._authenticate()
             if not self.sheet:
                 return False
        
        try:
            self.sheet.append_row(row_data)
            return True
        except Exception as e:
            logger.error(f"Failed to append row to Sheets: {e}")
            return False

# Global instance
sheets_service = SheetsService()
