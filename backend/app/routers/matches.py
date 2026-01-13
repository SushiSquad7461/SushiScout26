from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
from ..database import get_db
from ..models.match import Match
from ..schemas.match import MatchCreate, MatchResponse
from ..services.sheets import sheets_service
import logging

router = APIRouter(prefix="/matches", tags=["matches"])
logger = logging.getLogger(__name__)

@router.post("/", response_model=MatchResponse, status_code=201)
async def create_match(
    match_data: MatchCreate, 
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    new_match = Match(**match_data.model_dump())
    db.add(new_match)
    await db.commit()
    await db.refresh(new_match)
    
    # Schedule Sheets Sync in Background
    background_tasks.add_task(sync_to_sheets, new_match, db)
    
    return new_match

@router.get("/", response_model=List[MatchResponse])
async def get_matches(skip: int = 0, limit: int = 100, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Match).offset(skip).limit(limit))
    return result.scalars().all()

async def sync_to_sheets(match: Match, db: AsyncSession):
    """Background task to sync a single match to Google Sheets"""
    try:
        success = sheets_service.append_match(match.to_sheets_row())
        if success:
            # We need a new session for background tasks usually, but here strict session management 
            # might get complex. For simple use cases, re-using might work or ideally create new.
            # For now, let's just log. Updating DB state in background requires careful session handling.
            logger.info(f"Match {match.id} synced to Sheets.")
            # In a real robust app, we'd update 'is_exported_to_sheets' here.
    except Exception as e:
        logger.error(f"Error in background sync: {e}")
