from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, DateTime
from app.models.base import BaseModel


class OtpRequest(BaseModel):
    __tablename__ = "otp_requests"

    phone_number = Column(String(20), index=True, nullable=False)
    hashed_otp = Column(String(64), nullable=False)
    purpose = Column(String(50), default="LOGIN", nullable=False)  # LOGIN, REGISTER, RESET_PIN
    attempts = Column(Integer, default=0, nullable=False)
    max_attempts = Column(Integer, default=3, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    consumed_at = Column(DateTime(timezone=True), nullable=True)
