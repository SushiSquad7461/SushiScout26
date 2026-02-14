import pytest
from httpx import AsyncClient

# Simple test payload
MATCH_DATA = {
    "event_code": "2026TEST",
    "match_number": 1,
    "team_number": 254,
    "alliance": "Blue",
    "scouter_name": "Test Bot",
    "auto_fuel": 3,
    "auto_tower_l1": True,
    "teleop_fuel": 10,
    "teleop_tower_level": 3,
    "defense_rating": 5,
    "driver_skill": 4,
    "robot_died": False,
    "comments": "Great match!"
}

@pytest.mark.asyncio
async def test_create_match(client: AsyncClient):
    response = await client.post("/api/v1/matches/", json=MATCH_DATA)
    assert response.status_code == 201
    data = response.json()
    assert data["team_number"] == 254
    assert data["auto_fuel"] == 3
    assert "id" in data

@pytest.mark.asyncio
async def test_get_matches(client: AsyncClient):
    # Create one first
    await client.post("/api/v1/matches/", json=MATCH_DATA)
    
    response = await client.get("/api/v1/matches/")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["event_code"] == "2026TEST"

@pytest.mark.asyncio
async def test_duplicate_match_conflict(client: AsyncClient):
    # 1. Create a match
    res1 = await client.post("/api/v1/matches/", json=MATCH_DATA)
    assert res1.status_code == 201

    # 2. Try to create the exact same match again
    res2 = await client.post("/api/v1/matches/", json=MATCH_DATA)
    
    # 3. Should fail with 409 Conflict
    assert res2.status_code == 409
    assert "already exists" in res2.json()["detail"]

