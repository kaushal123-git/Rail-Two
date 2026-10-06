from sqlalchemy import Column, String, Boolean
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class RailwayLine(BaseModel):
    __tablename__ = "railway_lines"

    code = Column(String(20), unique=True, index=True, nullable=False)  # WR, CR, HR
    name = Column(String(100), nullable=False)
    display_name = Column(String(150), nullable=False)
    operator = Column(String(100), default="Indian Railways / Mumbai Suburban", nullable=False)
    color_code = Column(String(20), default="#FF5722", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    connections = relationship("StationConnection", back_populates="line", cascade="all, delete-orphan")
    services = relationship("RailwayService", back_populates="line", cascade="all, delete-orphan")
    updates = relationship("ServiceUpdate", back_populates="line")
