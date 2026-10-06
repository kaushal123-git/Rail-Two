from enum import Enum
from sqlalchemy import Column, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class JourneyStatus(str, Enum):
    PLANNED = "PLANNED"
    STARTING = "STARTING"
    ACTIVE = "ACTIVE"
    TRANSFER = "TRANSFER"
    ARRIVING = "ARRIVING"
    COMPLETED = "COMPLETED"
    ABANDONED = "ABANDONED"
    SUSPICIOUS = "SUSPICIOUS"


class JourneySecurityState(str, Enum):
    NORMAL = "NORMAL"
    LOCATION_UNCERTAIN = "LOCATION_UNCERTAIN"
    ROUTE_DEVIATION = "ROUTE_DEVIATION"
    SECURITY_WARNING = "SECURITY_WARNING"
    SUSPICIOUS = "SUSPICIOUS"


class Journey(BaseModel):
    __tablename__ = "journeys"

    ticket_id = Column(
        String(36),
        ForeignKey("tickets.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    user_id = Column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    device_id = Column(String(100), nullable=False, index=True)
    origin_station_id = Column(
        String(36),
        ForeignKey("stations.id"),
        nullable=False,
        index=True,
    )
    destination_station_id = Column(
        String(36),
        ForeignKey("stations.id"),
        nullable=False,
        index=True,
    )
    route_id = Column(String(100), nullable=True)
    status = Column(
        String(30),
        default=JourneyStatus.ACTIVE.value,
        nullable=False,
        index=True,
    )
    started_at = Column(DateTime(timezone=True), nullable=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    current_station_id = Column(
        String(36),
        ForeignKey("stations.id"),
        nullable=True,
    )
    last_validated_station_id = Column(
        String(36),
        ForeignKey("stations.id"),
        nullable=True,
    )
    security_state = Column(
        String(30),
        default=JourneySecurityState.NORMAL.value,
        nullable=False,
    )
    location_confidence = Column(Float, default=1.0, nullable=False)
    risk_score = Column(Float, default=0.0, nullable=False)

    # Relationships
    ticket = relationship("Ticket", backref="journey", lazy="joined")
    user = relationship("User", backref="journeys")
    origin_station = relationship("Station", foreign_keys=[origin_station_id], lazy="joined")
    destination_station = relationship("Station", foreign_keys=[destination_station_id], lazy="joined")
    current_station = relationship("Station", foreign_keys=[current_station_id], lazy="joined")
    last_validated_station = relationship("Station", foreign_keys=[last_validated_station_id], lazy="joined")
    location_events = relationship(
        "LocationEvent",
        back_populates="journey",
        cascade="all, delete-orphan",
        order_by="LocationEvent.timestamp_server",
        lazy="selectin",
    )
