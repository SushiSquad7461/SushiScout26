/**
 * Google Apps Script to sync Google Sheets to Firestore
 * 
 * Install Instructions:
 * 1. Open your Google Sheet
 * 2. Extensions → Apps Script
 * 3. Paste this code
 * 4. Save and run onOpen() once to create menu
 * 5. In Project Settings → Script Properties, add:
 *    - FIREBASE_PROJECT_ID: sushiscout26-a8f5d
 *    - CALLABLE_FUNCTION_URL: https://us-central1-sushiscout26-a8f5d.cloudfunctions.net/updateMatchFromSheets
 * 
 * Note: For production, add API key protection or use Firebase Auth
 */

// Configuration
const PROJECT_ID = 'sushiscout26-a8f5d';

/**
 * Get the callable function URL from script properties
 */
function getCallableUrl() {
  const scriptProps = PropertiesService.getScriptProperties();
  return scriptProps.getProperty('CALLABLE_FUNCTION_URL') || 
         `https://us-central1-${PROJECT_ID}.cloudfunctions.net/updateMatchFromSheets`;
}

/**
 * Called when sheet is edited
 */
function onEdit(e) {
  const sheet = e.source.getActiveSheet();
  const range = e.range;
  
  // Skip if header row or empty
  if (range.getRow() <= 1 || range.getNumRows() === 0) {
    return;
  }
  
  // Get event name from sheet name
  const eventName = sheet.getName();
  if (!eventName || eventName === 'Master' || eventName.includes('Template')) {
    return;
  }
  
  // Get the match ID from column B (Match ID)
  const matchIdCell = sheet.getRange(range.getRow(), 2, 1, 1);
  const matchId = matchIdCell.getValue();
  
  if (!matchId) {
    return;
  }
  
  Logger.log(`Sheet edited: Event=${eventName}, Match=${matchId}, Row=${range.getRow()}`);
  
  // Trigger sync to Firestore
  syncRowToFirestore(sheet, range.getRow(), eventName, matchId);
}

/**
 * Sync a single row to Firestore via Callable Function
 */
function syncRowToFirestore(sheet, rowNum, eventName, matchId) {
  try {
    // Get all column values
    const lastCol = sheet.getLastColumn();
    const headers = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
    const values = sheet.getRange(rowNum, 1, 1, lastCol).getValues()[0];
    
    // Build match data object
    const matchData = {};
    for (let i = 0; i < headers.length; i++) {
      const header = headers[i];
      const value = values[i];
      
      // Map sheet columns to Firestore fields
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
          if (climbVal.includes('Level')) {
            matchData.gameData.teleop_tower_level = parseInt(climbVal.replace('Level ', '')) || 0;
          } else {
            matchData.gameData.teleop_tower_level = parseInt(value) || 0;
          }
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
    
    // Call Firebase Callable Function
    const url = getCallableUrl();
    
    const payload = {
      eventId: eventName,
      reportId: matchId,
      data: matchData
    };
    
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    };
    
    const response = UrlFetchApp.fetch(url, options);
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
 * Manual sync - trigger full sync from Sheets to Firestore
 * Available from the menu
 */
function manualSyncAll() {
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
    
    // Get all match IDs in column B (skip header)
    for (let rowNum = 2; rowNum <= lastRow; rowNum++) {
      const matchId = sheet.getRange(rowNum, 2, 1, 1).getValue();
      if (matchId) {
        syncRowToFirestore(sheet, rowNum, sheetName, matchId);
        syncedCount++;
      }
    }
  }
  
  Logger.log(`Manual sync complete. Synced ${syncedCount} rows.`);
  SpreadsheetApp.getUi().alert(`Sync complete! Synced ${syncedCount} rows to Firestore.`);
}

/**
 * Create menu when spreadsheet opens
 */
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('🔥 Firestore Sync')
    .addItem('Sync All Rows to Firestore', 'manualSyncAll')
    .addItem('Setup Configuration', 'setupConfig')
    .addToUi();
}

/**
 * Setup dialog for configuration
 */
function setupConfig() {
  const html = HtmlService.createHtmlOutput(`
    <h2>Setup Firestore Sync</h2>
    <p>1. Go to Project Settings → Script Properties</p>
    <p>2. Add these properties:</p>
    <ul>
      <li>FIREBASE_PROJECT_ID: sushiscout26-a8f5d</li>
      <li>CALLABLE_FUNCTION_URL: https://us-central1-sushiscout26-a8f5d.cloudfunctions.net/updateMatchFromSheets</li>
    </ul>
    <p>Or click below to auto-configure:</p>
    <button onclick="autoSetup()">Auto Setup</button>
    <script>
      function autoSetup() {
        const props = PropertiesService.getScriptProperties();
        props.setProperty('FIREBASE_PROJECT_ID', 'sushiscout26-a8f5d');
        props.setProperty('CALLABLE_FUNCTION_URL', 'https://us-central1-sushiscout26-a8f5d.cloudfunctions.net/updateMatchFromSheets');
        alert('Configuration saved!');
      }
    </script>
  `);
  
  SpreadsheetApp.getUi().showModalDialog(html, 'Setup Firestore Sync');
}
