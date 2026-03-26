/**
 * Google Apps Script to sync Google Sheets ↔ Firestore
 *
 * SETUP (required for UrlFetchApp permissions):
 * 1. Open your Google Sheet → Extensions → Apps Script
 * 2. Paste this code into Code.gs
 * 3. Copy appsscript.json into Project Settings → Show "appsscript.json" manifest
 * 4. Set script properties (Project Settings → Script Properties):
 *    - SYNC_API_KEY: your API key
 * 5. Run onOpen() once to grant permissions and create the menu
 * 6. Create an INSTALLABLE edit trigger:
 *    a. In Apps Script editor, click Triggers (clock icon)
 *    b. + Add Trigger
 *    c. Function: onSheetEdit, Event source: From spreadsheet, Event type: On edit
 *    d. Save and authorize when prompted
 *
 * NOTE: The simple onEdit(e) trigger CANNOT call UrlFetchApp.fetch().
 *       You MUST use an installable trigger pointing to onSheetEdit().
 */

const PROJECT_ID = 'sushiscout26-a8f5d';
const SYNC_URL = 'https://us-central1-sushiscout26-a8f5d.cloudfunctions.net/sync_from_sheets_http';

/**
 * Get API key from script properties (not hardcoded).
 */
function getApiKey() {
  return PropertiesService.getScriptProperties().getProperty('SYNC_API_KEY') || '';
}

/**
 * Installable edit trigger handler — call this from Triggers, NOT onEdit.
 */
function onSheetEdit(e) {
  const sheet = e.source.getActiveSheet();
  const range = e.range;

  if (range.getRow() <= 1 || range.getNumRows() === 0) return;

  const sheetName = sheet.getName();
  if (!sheetName || sheetName === 'Master' || sheetName.includes('Template')) return;

  const matchId = sheet.getRange(range.getRow(), 2, 1, 1).getValue();
  if (!matchId) return;

  Logger.log(`Sheet edited: Event=${sheetName}, Match=${matchId}, Row=${range.getRow()}`);
  syncRowToFirestore(sheet, range.getRow(), sheetName, matchId);
}

/**
 * Detect program type from sheet headers.
 * FTC sheets have "Leave" in column G; FRC sheets have "Auto Fuel".
 */
function detectProgramType(headers) {
  if (headers.includes('Leave') || headers.includes('Auto Artifacts')) return 'FTC';
  return 'FRC';
}

/**
 * Sync a single row to Firestore via the HTTP Cloud Function.
 */
function syncRowToFirestore(sheet, rowNum, eventName, matchId) {
  try {
    const lastCol = sheet.getLastColumn();
    const headers = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
    const values = sheet.getRange(rowNum, 1, 1, lastCol).getValues()[0];
    const programType = detectProgramType(headers);

    const matchData = { gameData: {} };

    for (let i = 0; i < headers.length; i++) {
      const header = headers[i];
      const value = values[i];

      // Common fields
      switch (header) {
        case 'Match ID':    matchData.matchId = String(value); break;
        case 'Match #':     matchData.matchNumber = parseInt(value) || 0; break;
        case 'Team #':      matchData.teamNumber = parseInt(value) || 0; break;
        case 'Alliance':    matchData.alliance = String(value); break;
        case 'Scouter':     matchData.scouterName = String(value); break;
        case 'Robot Died':  matchData.gameData.robot_died = _toBool(value); break;
        case 'Comments':    matchData.comments = String(value || ''); break;

        // FRC fields
        case 'Auto Fuel':       matchData.gameData.auto_fuel = parseInt(value) || 0; break;
        case 'Auto L1 Hang':    matchData.gameData.auto_tower_l1 = _toBool(value); break;
        case 'Teleop Fuel':     matchData.gameData.teleop_fuel = parseInt(value) || 0; break;
        case 'Climb Level':     matchData.gameData.teleop_tower_level = _parseClimb(value); break;
        case 'Defense Rating':  matchData.gameData.defense_rating = _parseRating(value); break;
        case 'Driver Skill':    matchData.gameData.driver_skill = _parseRating(value); break;
        case 'Trench Traverse': matchData.gameData.trench_traverse = _toBool(value); break;
        case 'Bump Traverse':   matchData.gameData.bump_traverse = _toBool(value); break;
        case 'Shooting Close':  matchData.gameData.shooting_range_close = _toBool(value); break;
        case 'Shooting Mid':    matchData.gameData.shooting_range_mid = _toBool(value); break;
        case 'Shooting Far':    matchData.gameData.shooting_range_far = _toBool(value); break;

        // FTC fields
        case 'Leave':            matchData.gameData.leave = _toBool(value); break;
        case 'Auto Artifacts':   matchData.gameData.artifacts_auto = parseInt(value) || 0; break;
        case 'Auto Indexing':    matchData.gameData.indexing_auto = _toBool(value); break;
        case 'Teleop Artifacts': matchData.gameData.artifacts_teleop = parseInt(value) || 0; break;
        case 'Teleop Indexing':  matchData.gameData.indexing_teleop = _toBool(value); break;
        case 'Base Expansion':   matchData.gameData.base_expansion = String(value || 'None'); break;
        case 'Driver Quality':   matchData.gameData.driver_quality = _parseRating(value); break;
      }
    }

    matchData.programType = programType;

    const payload = {
      eventId: eventName,
      reportId: matchId,
      data: matchData
    };

    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': getApiKey()
      },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    };

    const response = UrlFetchApp.fetch(SYNC_URL, options);
    const code = response.getResponseCode();

    if (code === 200) {
      Logger.log(`Synced row ${rowNum}: ${eventName}/${matchId}`);
    } else {
      Logger.log(`Sync error ${code}: ${response.getContentText()}`);
    }
  } catch (error) {
    Logger.log(`Error syncing to Firestore: ${error.message}`);
  }
}

// --- Helpers ---

function _toBool(value) {
  if (typeof value === 'boolean') return value;
  return String(value).toLowerCase() === 'yes' || String(value).toLowerCase() === 'true';
}

function _parseClimb(value) {
  const s = String(value);
  if (s === 'No Climb' || s === '0') return 0;
  const match = s.match(/(\d+)/);
  return match ? parseInt(match[1]) : 0;
}

function _parseRating(value) {
  return parseInt(String(value).replace('/5', '')) || 0;
}

// --- Menu & Bulk Operations ---

/**
 * Sync all data rows from every event sheet to Firestore.
 */
function syncAllRows() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = spreadsheet.getSheets();
  let syncedCount = 0;

  for (const sheet of sheets) {
    const name = sheet.getName();
    if (name === 'Master' || name.includes('Template')) continue;

    const lastRow = sheet.getLastRow();
    if (lastRow <= 1) continue;

    for (let r = 2; r <= lastRow; r++) {
      const id = sheet.getRange(r, 2, 1, 1).getValue();
      if (id) {
        syncRowToFirestore(sheet, r, name, id);
        syncedCount++;
      }
    }
  }

  SpreadsheetApp.getUi().alert(`Sync complete! Synced ${syncedCount} rows to Firestore.`);
}

/**
 * Create menu when spreadsheet opens.
 */
function onOpen() {
  SpreadsheetApp.getUi().createMenu('Firestore Sync')
    .addItem('Sync Sheets → Firestore', 'syncAllRows')
    .addToUi();
}
