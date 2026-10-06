from datetime import datetime, timezone
from enum import Enum
from sqlalchemy import Column, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class LocationIntegrityStatus(str, Enum):
    VALID = "VALID"
    SUSPICIOUS = "SUSPICIOUS"
    REJECTED = "REJECTED"


class LocationEvent(BaseModel):
    __tablename__ = "location_events"

    user_id = Column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    device_id = Column(String(100), nullable=False, index=True)
    journey_id = Column(
        String(36),
        ForeignKey("journeys.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    ticket_id = Column(
        String(36),
        ForeignKey("tickets.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    accuracy_meters = Column(Float, nullable=False)
    altitude = Column(Float, nullable=True)
    speed_mps = Column(Float, nullable=True)
    bearing = Column(Float, nullable=True)
    timestamp_device = Column(DateTime(timezone=True), nullable=False)
    timestamp_server = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )
    provider = Column(String(50), default="gps", nullable=False)
    is_mock = Column(Boolean, default=False, nullable=False)
    mock_confidence = Column(Float, default=0.0, nullable=False)
    location_source = Column(String(50), default="device_stream", nullable=False)
    integrity_status = Column(
        String(30),
        default=LocationIntegrityStatus.VALID.value,
        nullable=False,
    )
    s2_cell_token = Column(String(20), nullable=True, index=True)

    # Relationship
    journey = relationship("Journey", back_populates="location_events")
