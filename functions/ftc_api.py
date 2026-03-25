"""FTC event schedule sync via FIRST Tech Challenge Events API."""

from firebase_functions import https_fn, logger
from firebase_admin import firestore
import requests
import os
from datetime import datetime, timedelta

_db = None

CACHE_TTL_HOURS = 24


def _get_db():
    """Get Firestore client with lazy initialization."""
    global _db
    if _db is None:
        _db = firestore.client()
    return _db


def _get_ftc_season():
    """Derive the FTC season year from the current date.

    FTC seasons start in September. Events from Jan-Aug belong to
    the season that started the previous September.
    """
    now = datetime.now()
    return now.year if now.month >= 9 else now.year - 1


@https_fn.on_call(secrets=["FTC_API_USERNAME", "FTC_API_KEY"])
def fetch_ftc_schedule(req: https_fn.CallableRequest) -> dict:
    """Fetch FTC match schedule from the FIRST Tech Challenge Events API.

    Input: { "eventCode": "USNYEXCL" }
    Returns: { "success": True, "count": N, "cached": bool }
    Schedule data is written to Firestore, not returned inline.
    """
    event_code = req.data.get("eventCode")
    if not event_code:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Missing eventCode",
        )

    db = _get_db()
    cache_ref = db.collection("ftc_cache").document(event_code)
    cached = cache_ref.get()

    if cached.exists:
        cached_data = cached.to_dict()
        cached_at = cached_data.get("cachedAt")
        matches = cached_data.get("matches", [])

        if cached_at and matches:
            cache_age = (
                datetime.now(cached_at.tzinfo) - cached_at
                if cached_at.tzinfo
                else datetime.utcnow() - cached_at.replace(tzinfo=None)
            )
            if cache_age < timedelta(hours=CACHE_TTL_HOURS):
                logger.info(
                    f"Using cached FTC data for {event_code} (age: {cache_age})"
                )
                return {"success": True, "count": len(matches), "cached": True}

    username = os.environ.get("FTC_API_USERNAME")
    api_key = os.environ.get("FTC_API_KEY")

    if not username or not api_key:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="FTC_API_USERNAME or FTC_API_KEY secret not configured",
        )

    season = _get_ftc_season()
    url = f"https://ftc-api.firstinspires.org/v2.0/{season}/schedule/{event_code}"
    resp = requests.get(url, auth=(username, api_key), params={"tournamentLevel": "qual"})

    if resp.status_code != 200:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAVAILABLE,
            message=f"FTC API Error: {resp.status_code}",
        )

    data = resp.json()
    matches = data.get("schedule", [])

    batch = db.batch()
    count = 0

    for m in matches:
        match_number = m.get("matchNumber", 0)
        match_id = f"{event_code}_qm{match_number}"
        teams = m.get("teams", [])

        match_doc = {
            "matchId": match_id,
            "matchNumber": match_number,
            "compLevel": "qm",
            "teams": teams,
            "startTime": m.get("startTime"),
            "programType": "FTC",
            "eventId": event_code,
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

    cache_ref.set(
        {
            "matches": matches,
            "cachedAt": firestore.SERVER_TIMESTAMP,
            "eventCode": event_code,
            "matchCount": len(matches),
        }
    )

    logger.info(f"Cached FTC data for {event_code}: {len(matches)} matches")

    return {"success": True, "count": len(matches), "cached": False}
