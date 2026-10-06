from enum import Enum
from sqlalchemy import Column, String, Float, DateTime, Text
from app.models.base import BaseModel


class FraudSeverity(str, Enum):
    INFO = "INFO"
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class FraudEventType(str, Enum):
    LOW_ACCURACY = "LOW_ACCURACY"
    MOCK_LOCATION = "MOCK_LOCATION"
    IMPOSSIBLE_SPEED = "IMPOSSIBLE_SPEED"
    TELEPORTATION = "TELEPORTATION"
    CLOCK_ANOMALY = "CLOCK_ANOMALY"
    SENSOR_INCONSISTENCY = "SENSOR_INCONSISTENCY"
    ROUTE_DEVIATION = "ROUTE_DEVIATION"
    LOCATION_REPLAY = "LOCATION_REPLAY"
    GEOFENCE_VIOLATION = "GEOFENCE_VIOLATION"


class FraudEvent(BaseModel):
    __tablename__ = "fraud_events"

    user_id = Column(String(36), nullable=False, index=True)
    ticket_id = Column(String(36), nullable=True, index=True)
    journey_id = Column(String(36), nullable=True, index=True)
    device_id = Column(String(100), nullable=True, index=True)
    event_type = Column(String(50), nullable=False, index=True)
    severity = Column(String(20), default=FraudSeverity.MEDIUM.value, nullable=False)
    confidence = Column(Float, default=1.0, nullable=False)
    metadata_json = Column(Text, nullable=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
