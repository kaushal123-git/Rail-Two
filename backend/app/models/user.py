from datetime import datetime, timezone
from sqlalchemy import Column, String, Boolean, Float, DateTime
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class User(BaseModel):
    __tablename__ = "users"

    phone_number = Column(String(20), unique=True, index=True, nullable=False)
    phone_verified = Column(Boolean, default=False, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=True)
    full_name = Column(String(100), default="Commuter", nullable=False)
    profile_image_url = Column(String(500), nullable=True)
    hashed_mpin = Column(String(255), nullable=True)
    status = Column(String(20), default="ACTIVE", nullable=False)  # ACTIVE, SUSPENDED, BLOCKED
    rwallet_balance = Column(Float, default=100.0, nullable=False)
    last_login_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    devices = relationship("Device", back_populates="user", cascade="all, delete-orphan")
    sessions = relationship("Session", back_populates="user", cascade="all, delete-orphan")
    tickets = relationship("Ticket", back_populates="user", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="user", cascade="all, delete-orphan")
