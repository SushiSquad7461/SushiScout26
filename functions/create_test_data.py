"""Script to clear sync tracking and create fresh test data."""

import firebase_admin
from firebase_admin import credentials, firestore
import datetime

# Use service account credentials
cred = credentials.Certificate("C:/Users/Originalhawk/Downloads/sushiscout26-a8f5d-4b3d92bb5946.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

# Clear sync tracking for 2026TEST
print("Clearing sync tracking for 2026TEST...")
sync_ref = db.collection("sync_tracking")
docs = sync_ref.stream()
count = 0
for doc in docs:
    if "2026TEST" in doc.id:
        doc.reference.delete()
        count += 1
print(f"Deleted {count} sync records")

# Delete old matches
print("\nDeleting old matches from 2026TEST...")
old_matches = db.collection("events").document("2026TEST").collection("matches").stream()
for doc in old_matches:
    doc.reference.delete()
    print(f"Deleted: {doc.id}")

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

# Create new documents
print("\nCreating new match reports...")
for match in matches:
    doc_ref = db.collection("events").document("2026TEST").collection("matches").document(match["id"])
    match_data = {k: v for k, v in match.items() if k != "id"}
    doc_ref.set(match_data)
    print(f"Created: {match['id']} - Team {match['teamNumber']} - {match['alliance']}")

print(f"\nDone! Created {len(matches)} match reports in event 2026TEST")
