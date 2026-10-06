from enum import Enum
from datetime import datetime, timezone
import uuid
from sqlalchemy import Column, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


class TicketEventType(str, Enum):
    TICKET_CREATED = "TICKET_CREATED"
    FARE_CALCULATED = "FARE_CALCULATED"
    PAYMENT_ORDER_CREATED = "PAYMENT_ORDER_CREATED"
    PAYMENT_STARTED = "PAYMENT_STARTED"
    PAYMENT_CONFIRMED = "PAYMENT_CONFIRMED"
    PAYMENT_VERIFIED = "PAYMENT_VERIFIED"
    PAYMENT_FAILED = "PAYMENT_FAILED"
    TICKET_ISSUING = "TICKET_ISSUING"
    TICKET_ISSUED = "TICKET_ISSUED"
    TICKET_ACTIVATED = "TICKET_ACTIVATED"
    JOURNEY_STARTED = "JOURNEY_STARTED"
    STATION_VALIDATED = "STATION_VALIDATED"
    JOURNEY_COMPLETED = "JOURNEY_COMPLETED"
    TICKET_CANCELLED = "TICKET_CANCELLED"
    TICKET_EXPIRED = "TICKET_EXPIRED"
    TICKET_REFUND_REQUESTED = "TICKET_REFUND_REQUESTED"
    TICKET_REFUNDED = "TICKET_REFUNDED"
    FRAUD_BLOCKED = "FRAUD_BLOCKED"
    ISSUANCE_FAILED = "ISSUANCE_FAILED"


class TicketEvent(Base):
    __tablename__ = "ticket_events"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    ticket_id = Column(String(36), ForeignKey("tickets.id", ondelete="CASCADE"), nullable=False, index=True)
    event_type = Column(String(50), nullable=False, index=True)
    metadata_json = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    ticket = relationship("Ticket", back_populates="events")
