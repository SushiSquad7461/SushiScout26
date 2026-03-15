"""TBA and FTC event schedule sync functions."""

from firebase_functions import https_fn, logger
from firebase_admin import firestore
import requests
import os
from datetime import datetime, timedelta

db = firestore.client()

CACHE_TTL_HOURS = 24


@https_fn.on_call(secrets=["TBA_API_KEY"])
def fetch_event_schedule(req: https_fn.CallableRequest) -> any:
    """
    Syncs FRC event data from The Blue Alliance (TBA).
    Caches responses for 24 hours to reduce API calls.
    Input: { "eventKey": "2026casj" }
    """
    event_key = req.data.get("eventKey")
    if not event_key:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="Missing eventKey")

    cache_ref = db.collection('tba_cache').document(event_key)
    cached = cache_ref.get()
    
    if cached.exists:
        cached_data = cached.to_dict()
        cached_at = cached_data.get('cachedAt')
        matches = cached_data.get('matches', [])
        
        if cached_at and matches:
            cache_age = datetime.now(cached_at.tzinfo) - cached_at if cached_at.tzinfo else datetime.utcnow() - cached_at.replace(tzinfo=None)
            if cache_age < timedelta(hours=CACHE_TTL_HOURS):
                logger.info(f"Using cached TBA data for {event_key} (age: {cache_age})")
                return {"success": True, "count": len(matches), "cached": True}

    tba_api_key = os.environ.get("TBA_API_KEY")
    if not tba_api_key:
         raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION, message="TBA_API_KEY secret not set")

    headers = {"X-TBA-Auth-Key": tba_api_key}
    
    matches_url = f"https://www.thebluealliance.com/api/v3/event/{event_key}/matches"
    resp = requests.get(matches_url, headers=headers)
    
    if resp.status_code != 200:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAVAILABLE, message=f"TBA API Error: {resp.status_code}")
        
    matches = resp.json()
    batch = db.batch()
    count = 0
    
    for m in matches:
        match_id = m['key']
        match_doc = {
            "matchId": match_id,
            "matchNumber": m['match_number'],
            "compLevel": m['comp_level'],
            "alliances": m['alliances'],
            "startTime": datetime.fromtimestamp(m['time']) if m['time'] else None,
            "programType": "FRC",
            "eventId": event_key
        }
        
        doc_ref = db.collection("matches").document(match_id)
        batch.set(doc_ref, match_doc, merge=True)
        count += 1
        
        if count >= 400:
            batch.commit()
            batch = db.batch()
            count = 0
            
    if count > 0:
        batch.commit()

    cache_ref.set({
        'matches': matches,
        'cachedAt': firestore.SERVER_TIMESTAMP,
        'eventKey': event_key,
        'matchCount': len(matches)
    })

    logger.info(f"Cached TBA data for {event_key}: {len(matches)} matches")

    return {"success": True, "count": len(matches), "cached": False}
