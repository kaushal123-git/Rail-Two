from enum import Enum
from datetime import datetime
from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class TicketStatus(str, Enum):
    CREATED = "CREATED"
    PAYMENT_PENDING = "PAYMENT_PENDING"
    PAYMENT_CONFIRMED = "PAYMENT_CONFIRMED"
    ISSUING = "ISSUING"
    ISSUED = "ISSUED"
    ACTIVE = "ACTIVE"
    IN_JOURNEY = "IN_JOURNEY"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"
    FRAUD_BLOCKED = "FRAUD_BLOCKED"
    ISSUANCE_FAILED = "ISSUANCE_FAILED"


class Ticket(BaseModel):
    __tablename__ = "tickets"

    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    provider = Column(String(50), default="LOCO_RAIL", nullable=False)
    provider_ticket_id = Column(String(100), nullable=True, index=True)
    origin_station_id = Column(String(36), ForeignKey("stations.id"), nullable=False, index=True)
    destination_station_id = Column(String(36), ForeignKey("stations.id"), nullable=False, index=True)
    journey_type = Column(String(20), default="SINGLE", nullable=False)  # SINGLE, RETURN, SEASON
    ticket_class = Column(String(20), default="SECOND", nullable=False)   # FIRST, SECOND, AC
    passenger_count = Column(Integer, default=1, nullable=False)
    fare = Column(Float, nullable=False)
    currency = Column(String(10), default="INR", nullable=False)
    booking_status = Column(String(30), default="CREATED", nullable=False)
    payment_status = Column(String(30), default="PENDING", nullable=False)
    ticket_status = Column(String(30), default=TicketStatus.CREATED.value, nullable=False, index=True)
    issued_at = Column(DateTime(timezone=True), nullable=True)
    valid_from = Column(DateTime(timezone=True), nullable=True)
    valid_until = Column(DateTime(timezone=True), nullable=True)
    qr_token_id = Column(String(255), nullable=True)

    # Relationships
    user = relationship("User", back_populates="tickets")
    origin_station = relationship("Station", foreign_keys=[origin_station_id], back_populates="origin_tickets", lazy="joined")
    destination_station = relationship("Station", foreign_keys=[destination_station_id], back_populates="destination_tickets", lazy="joined")
    events = relationship("TicketEvent", back_populates="ticket", cascade="all, delete-orphan", order_by="TicketEvent.created_at", lazy="selectin")
    payments = relationship("Payment", back_populates="ticket", cascade="all, delete-orphan", order_by="Payment.created_at", lazy="selectin")
