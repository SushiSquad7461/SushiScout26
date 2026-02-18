"""TBA and FTC event schedule sync functions."""

from firebase_functions import https_fn
from firebase_admin import firestore
import requests
import os
from datetime import datetime

db = firestore.client()


@https_fn.on_call(secrets=["TBA_API_KEY"])
def fetch_event_schedule(req: https_fn.CallableRequest) -> any:
    """
    Syncs FRC event data from The Blue Alliance (TBA).
    Input: { "eventKey": "2026casj" }
    """
    event_key = req.data.get("eventKey")
    if not event_key:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="Missing eventKey")

    tba_api_key = os.environ.get("TBA_API_KEY")
    if not tba_api_key:
         raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION, message="TBA_API_KEY secret not set")

    headers = {"X-TBA-Auth-Key": tba_api_key}
    
    # 1. Fetch Matches
    matches_url = f"https://www.thebluealliance.com/api/v3/event/{event_key}/matches"
    resp = requests.get(matches_url, headers=headers)
    
    if resp.status_code != 200:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAVAILABLE, message=f"TBA API Error: {resp.status_code}")
        
    matches = resp.json()
    batch = db.batch()
    count = 0
    
    for m in matches:
        match_id = m['key']
        # Simplified Match Object for scheduling
        match_doc = {
            "matchId": match_id,
            "matchNumber": m['match_number'],
            "compLevel": m['comp_level'],
            "alliances": m['alliances'], # Red/Blue teams
            "startTime": datetime.fromtimestamp(m['time']) if m['time'] else None,
            "programType": "FRC"
        }
        
        doc_ref = db.collection(f"events/{event_key}/matches").document(match_id)
        batch.set(doc_ref, match_doc, merge=True)
        count += 1
        
        if count >= 400: # Batch limit is 500
            batch.commit()
            batch = db.batch()
            count = 0
            
    if count > 0:
        batch.commit()

    return {"success": True, "count": len(matches)}



