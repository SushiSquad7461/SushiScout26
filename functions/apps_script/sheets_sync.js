/**
 * Google Apps Script to sync Google Sheets to Firestore
 * 
 * Install Instructions:
 * 1. Open your Google Sheet
 * 2. Extensions → Apps Script
 * 3. Paste this code
 * 4. Save and run onOpen() once to create menu
 * 
 * No configuration needed - uses default Firebase project
 */

const PROJECT_ID = 'sushiscout26-a8f5d';
const SYNC_URL = 'https://us-central1-sushiscout26-a8f5d.cloudfunctions.net/sync_from_sheets_http';
const BACKFILL_URL = 'https://us-central1-sushiscout26-a8f5d.cloudfunctions.net/backfill_event_to_sheets';
const API_KEY = 'sushiscout26-sheets-api-key-2026';

/**
 * Called when sheet is edited
 */
function onEdit(e) {
  const sheet = e.source.getActiveSheet();
  const range = e.range;
  
  if (range.getRow() <= 1 || range.getNumRows() === 0) {
    return;
  }
  
  const eventName = sheet.getName();
  if (!eventName || eventName === 'Master' || eventName.includes('Template')) {
    return;
  }
  
  const matchIdCell = sheet.getRange(range.getRow(), 2, 1, 1);
  const matchId = matchIdCell.getValue();
  
  if (!matchId) {
    return;
  }
  
  Logger.log(`Sheet edited: Event=${eventName}, Match=${matchId}, Row=${range.getRow()}`);
  syncRowToFirestore(sheet, range.getRow(), eventName, matchId);
}

/**
 * Sync a single row to Firestore
 */
function syncRowToFirestore(sheet, rowNum, eventName, matchId) {
  try {
    const lastCol = sheet.getLastColumn();
    const headers = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
    const values = sheet.getRange(rowNum, 1, 1, lastCol).getValues()[0];
    
    const matchData = {};
    for (let i = 0; i < headers.length; i++) {
      const header = headers[i];
      const value = values[i];
      
      switch (header) {
        case 'Match ID':
          matchData.matchId = String(value);
          break;
        case 'Match #':
          matchData.matchNumber = parseInt(value) || 0;
          break;
        case 'Team #':
          matchData.teamNumber = parseInt(value) || 0;
          break;
        case 'Alliance':
          matchData.alliance = String(value);
          break;
        case 'Scouter':
          matchData.scouterName = String(value);
          break;
        case 'Auto Fuel':
          matchData.gameData = matchData.gameData || {};
          matchData.gameData.auto_fuel = parseInt(value) || 0;
          break;
        case 'Auto L1 Hang':
          matchData.gameData = matchData.gameData || {};
          matchData.gameData.auto_tower_l1 = (String(value).toLowerCase() === 'yes' || value === true);
          break;
        case 'Teleop Fuel':
          matchData.gameData = matchData.gameData || {};
          matchData.gameData.teleop_fuel = parseInt(value) || 0;
          break;
        case 'Climb Level':
          matchData.gameData = matchData.gameData || {};
          const climbVal = String(value);
          matchData.gameData.teleop_tower_level = parseInt(climbVal.replace('Level ', '')) || 0;
          break;
        case 'Defense Rating':
          matchData.gameData = matchData.gameData || {};
          matchData.gameData.defense_rating = parseInt(String(value).replace('/5', '')) || 0;
          break;
        case 'Driver Skill':
          matchData.gameData = matchData.gameData || {};
          matchData.gameData.driver_skill = parseInt(String(value).replace('/5', '')) || 0;
          break;
        case 'Robot Died':
          matchData.robotDied = (String(value).toLowerCase() === 'yes' || value === true);
          break;
        case 'Comments':
          matchData.comments = String(value || '');
          break;
        case 'Images':
          matchData.images = value ? String(value).split(',').map(s => s.trim()).filter(s => s) : [];
          break;
      }
    }
    
    const payload = {
      eventId: eventName,
      reportId: matchId,
      data: matchData
    };
    
    const options = {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'X-API-Key': API_KEY
      },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    };
    
    const response = UrlFetchApp.fetch(SYNC_URL, options);
    const responseCode = response.getResponseCode();
    
    if (responseCode === 200) {
      Logger.log(`Synced row ${rowNum} to Firestore: ${eventName}/${matchId}`);
    } else {
      Logger.log(`Error syncing: ${responseCode} - ${response.getContentText()}`);
    }
    
  } catch (error) {
    Logger.log(`Error syncing to Firestore: ${error.message}`);
  }
}

/**
 * Sync all rows from Sheets to Firestore
 */
function syncAllRows() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = spreadsheet.getSheets();
  
  let syncedCount = 0;
  
  for (const sheet of sheets) {
    const sheetName = sheet.getName();
    if (sheetName === 'Master' || sheetName.includes('Template')) {
      continue;
    }
    
    Logger.log(`Syncing sheet: ${sheetName}`);
    
    const lastRow = sheet.getLastRow();
    if (lastRow <= 1) continue;
    
    for (let rowNum = 2; rowNum <= lastRow; rowNum++) {
      const matchId = sheet.getRange(rowNum, 2, 1, 1).getValue();
      if (matchId) {
        syncRowToFirestore(sheet, rowNum, sheetName, matchId);
        syncedCount++;
      }
    }
  }
  
  Logger.log(`Sync complete. Synced ${syncedCount} rows.`);
  SpreadsheetApp.getUi().alert(`Sync complete! Synced ${syncedCount} rows to Firestore.`);
}

/**
 * Backfill: Sync from Firestore to Sheets
 */
function backfillFromFirestore() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = spreadsheet.getSheets();
  
  // Let user select which event to backfill
  const sheetNames = sheets
    .map(s => s.getName())
    .filter(n => n !== 'Master' && !n.includes('Template'));
  
  if (sheetNames.length === 0) {
    SpreadsheetApp.getUi().alert('No event sheets found.');
    return;
  }
  
  // Simple prompt for event name
  const eventName = SpreadsheetApp.getUi().prompt(
    'Backfill from Firestore',
    'Enter the event ID to backfill (e.g., 2026TEST):',
    SpreadsheetApp.getUi().ButtonSet.OK_CANCEL
  ).getResponseText();
  
  if (!eventName) return;
  
  SpreadsheetApp.getUi().alert(`Starting backfill for event: ${eventName}\n\nThis will take a moment...`);
  
  try {
    const options = {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'X-API-Key': API_KEY
      },
      payload: JSON.stringify({ eventId: eventName }),
      muteHttpExceptions: true
    };
    
    const response = UrlFetchApp.fetch(BACKFILL_URL, options);
    const responseCode = response.getResponseCode();
    const responseText = response.getContentText();
    
    if (responseCode === 200) {
      const result = JSON.parse(responseText);
      SpreadsheetApp.getUi().alert(
        `Backfill complete!\n\nSynced: ${result.syncedCount}\nFailed: ${result.failedCount}`
      );
    } else {
      SpreadsheetApp.getUi().alert(`Backfill failed: ${responseText}`);
    }
    
  } catch (error) {
    SpreadsheetApp.getUi().alert(`Error: ${error.message}`);
  }
}

/**
 * Create menu when spreadsheet opens
 */
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('🔥 Firestore Sync')
    .addItem('Sync Sheets → Firestore', 'syncAllRows')
    .addItem('Backfill Firestore → Sheets', 'backfillFromFirestore')
    .addToUi();
}
