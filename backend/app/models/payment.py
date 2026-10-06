from enum import Enum
from datetime import datetime
from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class PaymentStatus(str, Enum):
    CREATED = "CREATED"
    PENDING = "PENDING"
    AUTHORIZED = "AUTHORIZED"
    CAPTURED = "CAPTURED"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"
    PARTIALLY_REFUNDED = "PARTIALLY_REFUNDED"
    CANCELLED = "CANCELLED"


class Payment(BaseModel):
    __tablename__ = "payments"

    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    ticket_id = Column(String(36), ForeignKey("tickets.id", ondelete="CASCADE"), nullable=False, index=True)
    gateway = Column(String(50), default="TEST", nullable=False)  # RAZORPAY, TEST, UPI
    gateway_order_id = Column(String(100), nullable=True, index=True)
    gateway_payment_id = Column(String(100), nullable=True, index=True)
    gateway_signature = Column(String(255), nullable=True)
    amount = Column(Float, nullable=False)
    currency = Column(String(10), default="INR", nullable=False)
    status = Column(String(30), default=PaymentStatus.CREATED.value, nullable=False, index=True)
    failure_reason = Column(Text, nullable=True)
    verified_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    user = relationship("User", back_populates="payments")
    ticket = relationship("Ticket", back_populates="payments")
