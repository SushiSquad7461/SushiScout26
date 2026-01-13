from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, Boolean, DateTime, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
import uuid
from ..database import Base

class Match(Base):
    __tablename__ = "matches"

    # Primary Key
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))

    # Event Context
    event_code: Mapped[str] = mapped_column(String, index=True)
    match_number: Mapped[int] = mapped_column(Integer, index=True)
    team_number: Mapped[int] = mapped_column(Integer, index=True)
    alliance: Mapped[str] = mapped_column(String) # 'Red' or 'Blue'
    scouter_name: Mapped[str] = mapped_column(String)

    # Autonomous
    auto_fuel: Mapped[int] = mapped_column(Integer, default=0)
    auto_tower_l1: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Teleop
    teleop_fuel: Mapped[int] = mapped_column(Integer, default=0)
    # teleop_tower_level: 0=None, 1=L1, 2=L2, 3=L3
    teleop_tower_level: Mapped[int] = mapped_column(Integer, default=0)
    
    # Qualitative / Meta
    defense_rating: Mapped[int] = mapped_column(Integer, default=0) # 0-5
    driver_skill: Mapped[int] = mapped_column(Integer, default=0)   # 0-5
    robot_died: Mapped[bool] = mapped_column(Boolean, default=False)
    comments: Mapped[str] = mapped_column(String, default="")
    
    # Sync / Sys
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    is_exported_to_sheets: Mapped[bool] = mapped_column(Boolean, default=False)

    def to_sheets_row(self) -> list:
        """Helper to convert match to list for Google Sheets append"""
        return [
            self.id,
            self.event_code,
            self.match_number,
            self.team_number,
            self.alliance,
            self.scouter_name,
            self.auto_fuel,
            "TRUE" if self.auto_tower_l1 else "FALSE",
            self.teleop_fuel,
            self.teleop_tower_level,
            self.defense_rating,
            self.driver_skill,
            "TRUE" if self.robot_died else "FALSE",
            self.comments,
            self.created_at.isoformat()
        ]
