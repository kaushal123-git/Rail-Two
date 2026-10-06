from datetime import datetime, timezone
import uuid
from sqlalchemy import Column, String, Float, Boolean, DateTime
from app.core.database import Base


class FareRule(Base):
    __tablename__ = "fare_rules"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    origin_zone = Column(String(50), default="*", nullable=False)        # WESTERN, CENTRAL, HARBOUR, *
    destination_zone = Column(String(50), default="*", nullable=False)   # WESTERN, CENTRAL, HARBOUR, *
    journey_type = Column(String(20), default="SINGLE", nullable=False)  # SINGLE, RETURN, SEASON
    ticket_class = Column(String(20), default="SECOND", nullable=False)  # SECOND, FIRST, AC
    min_distance_km = Column(Float, default=0.0, nullable=False)
    max_distance_km = Column(Float, default=9999.0, nullable=False)
    base_fare = Column(Float, nullable=False)
    per_km_rate = Column(Float, default=0.0, nullable=False)
    discount_percentage = Column(Float, default=0.0, nullable=False)
    tax_percentage = Column(Float, default=0.0, nullable=False)
    active = Column(Boolean, default=True, nullable=False, index=True)
    version = Column(String(20), default="v1.0", nullable=False)
    effective_from = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    effective_until = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
