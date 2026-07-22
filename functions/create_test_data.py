"""Script to clear existing test matches and create fresh test data.

Writes to the top-level `matches` collection (with eventId field), which is
what the app reads from after the subcollection→top-level refactor.

Credentials path is read from the GOOGLE_APPLICATION_CREDENTIALS env var
when set; otherwise falls back to the default ADC location.
"""

import datetime
import os

import firebase_admin
from firebase_admin import credentials, firestore

EVENT_ID = "2026TEST"

cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
if cred_path:
    firebase_admin.initialize_app(credentials.Certificate(cred_path))
else:
    # Application Default Credentials (e.g., from `gcloud auth
    # application-default login`).
    firebase_admin.initialize_app()

db = firestore.client()

# Delete existing top-level matches for this event
print(f"\nDeleting existing matches for event {EVENT_ID}...")
existing = db.collection("matches").where("eventId", "==", EVENT_ID).stream()
deleted = 0
for doc in existing:
    doc.reference.delete()
    deleted += 1
    print(f"Deleted: {doc.id}")
print(f"Deleted {deleted} match documents")

# Test match data with all scouting wizard fields
matches = [
    {
        "id": "2026TEST_qm1_254",
        "matchId": "2026TEST_qm1",
        "matchNumber": 1,
        "teamNumber": 254,
        "alliance": "Red",
        "scouterName": "Alex",
        "gameData": {
            "auto_fuel": 5,
            "auto_tower_l1": True,
            "teleop_fuel": 12,
            "teleop_tower_level": 3,
            "defense_rating": 3,
            "driver_skill": 5
        },
        "robotDied": False,
        "comments": "Excellent autonomous, consistent scoring all match. Great climb.",
        "images": [],
        "createdAt": datetime.datetime.now()
    },
    {
        "id": "2026TEST_qm2_4198",
        "matchId": "2026TEST_qm2",
        "matchNumber": 2,
        "teamNumber": 4198,
        "alliance": "Blue",
        "scouterName": "Jordan",
        "gameData": {
            "auto_fuel": 8,
            "auto_tower_l1": True,
            "teleop_fuel": 20,
            "teleop_tower_level": 3,
            "defense_rating": 4,
            "driver_skill": 5
        },
        "robotDied": False,
        "comments": "Fast intake, excellent defense. Dominated the field.",
        "images": [],
        "createdAt": datetime.datetime.now()
    },
    {
        "id": "2026TEST_qm3_1678",
        "matchId": "2026TEST_qm3",
        "matchNumber": 3,
        "teamNumber": 1678,
        "alliance": "Red",
        "scouterName": "Sam",
        "gameData": {
            "auto_fuel": 3,
            "auto_tower_l1": False,
            "teleop_fuel": 15,
            "teleop_tower_level": 2,
            "defense_rating": 2,
            "driver_skill": 4
        },
        "robotDied": True,
        "comments": "Motor issues in teleop, died mid-match. Potential for more.",
        "images": [],
        "createdAt": datetime.datetime.now()
    },
    {
        "id": "2026TEST_qm4_1323",
        "matchId": "2026TEST_qm4",
        "matchNumber": 4,
        "teamNumber": 1323,
        "alliance": "Blue",
        "scouterName": "Taylor",
        "gameData": {
            "auto_fuel": 6,
            "auto_tower_l1": True,
            "teleop_fuel": 18,
            "teleop_tower_level": 3,
            "defense_rating": 3,
            "driver_skill": 4
        },
        "robotDied": False,
        "comments": "Very reliable, good climb. Solid performer.",
        "images": [],
        "createdAt": datetime.datetime.now()
    },
    {
        "id": "2026TEST_qm5_254",
        "matchId": "2026TEST_qm5",
        "matchNumber": 5,
        "teamNumber": 254,
        "alliance": "Blue",
        "scouterName": "Alex",
        "gameData": {
            "auto_fuel": 7,
            "auto_tower_l1": True,
            "teleop_fuel": 14,
            "teleop_tower_level": 3,
            "defense_rating": 4,
            "driver_skill": 5
        },
        "robotDied": False,
        "comments": "Another solid performance. Consistent as always.",
        "images": [],
        "createdAt": datetime.datetime.now()
    }
]

# Create new documents in the top-level matches collection with eventId field
print("\nCreating new match reports...")
for match in matches:
    doc_ref = db.collection("matches").document(match["id"])
    match_data = {k: v for k, v in match.items() if k != "id"}
    # Required fields for the app's _matchesQuery and Firestore rules.
    match_data["eventId"] = EVENT_ID
    match_data["isDeleted"] = False
    match_data["isSynced"] = True
    match_data.setdefault("teamId", "")
    match_data.setdefault("programType", "FRC")
    doc_ref.set(match_data)
    print(f"Created: {match['id']} - Team {match['teamNumber']} - {match['alliance']}")

print(f"\nDone! Created {len(matches)} match reports in event {EVENT_ID}")
