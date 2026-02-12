from pydantic import BaseModel, ConfigDict, Field, field_validator
from datetime import datetime
from typing import Optional

class MatchBase(BaseModel):
    event_code: str = Field(..., min_length=1)
    match_number: int = Field(..., gt=0)
    team_number: int = Field(..., gt=0)
    alliance: str
    scouter_name: str = Field(..., min_length=1)
    
    auto_fuel: int = Field(0, ge=0)
    auto_tower_l1: bool = False
    
    teleop_fuel: int = Field(0, ge=0)
    teleop_tower_level: int = Field(0, ge=0, le=3)
    
    defense_rating: int = Field(0, ge=0, le=5)
    driver_skill: int = Field(0, ge=0, le=5)
    robot_died: bool = False
    comments: str = ""

    @field_validator('alliance')
    @classmethod
    def validate_alliance(cls, v: str) -> str:
        if v not in ('Red', 'Blue'):
            raise ValueError("Alliance must be 'Red' or 'Blue'")
        return v

class MatchCreate(MatchBase):
    pass

class MatchResponse(MatchBase):
    id: str
    created_at: datetime
    is_exported_to_sheets: bool

    model_config = ConfigDict(from_attributes=True)
