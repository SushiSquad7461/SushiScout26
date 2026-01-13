from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional

class MatchBase(BaseModel):
    event_code: str
    match_number: int
    team_number: int
    alliance: str
    scouter_name: str
    
    auto_fuel: int = 0
    auto_tower_l1: bool = False
    
    teleop_fuel: int = 0
    teleop_tower_level: int = 0
    
    defense_rating: int = 0
    driver_skill: int = 0
    robot_died: bool = False
    comments: str = ""

class MatchCreate(MatchBase):
    pass

class MatchResponse(MatchBase):
    id: str
    created_at: datetime
    is_exported_to_sheets: bool

    model_config = ConfigDict(from_attributes=True)
