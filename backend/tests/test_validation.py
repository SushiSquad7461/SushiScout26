import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_create_match_invalid_match_number(client: AsyncClient):
    payload = {
        "event_code": "2026TEST",
        "match_number": -1, # Invalid
        "team_number": 254,
        "alliance": "Blue",
        "scouter_name": "Test Bot"
    }
    response = await client.post("/api/v1/matches/", json=payload)
    assert response.status_code == 422

@pytest.mark.asyncio
async def test_create_match_invalid_team_number(client: AsyncClient):
    payload = {
        "event_code": "2026TEST",
        "match_number": 1,
        "team_number": 0, # Invalid (usually start at 1)
        "alliance": "Blue",
        "scouter_name": "Test Bot"
    }
    response = await client.post("/api/v1/matches/", json=payload)
    assert response.status_code == 422

@pytest.mark.asyncio
async def test_create_match_invalid_alliance(client: AsyncClient):
    payload = {
        "event_code": "2026TEST",
        "match_number": 1,
        "team_number": 254,
        "alliance": "Green", # Invalid
        "scouter_name": "Test Bot"
    }
    response = await client.post("/api/v1/matches/", json=payload)
    assert response.status_code == 422

@pytest.mark.asyncio
async def test_create_match_negative_fuel(client: AsyncClient):
    payload = {
        "event_code": "2026TEST",
        "match_number": 1,
        "team_number": 254,
        "alliance": "Blue",
        "scouter_name": "Test Bot",
        "auto_fuel": -5
    }
    response = await client.post("/api/v1/matches/", json=payload)
    assert response.status_code == 422

@pytest.mark.asyncio
async def test_create_match_invalid_rating(client: AsyncClient):
    payload = {
        "event_code": "2026TEST",
        "match_number": 1,
        "team_number": 254,
        "alliance": "Blue",
        "scouter_name": "Test Bot",
        "defense_rating": 6 # Invalid (0-5)
    }
    response = await client.post("/api/v1/matches/", json=payload)
    assert response.status_code == 422
