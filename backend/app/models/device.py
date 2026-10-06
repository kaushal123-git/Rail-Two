from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class Device(BaseModel):
    __tablename__ = "devices"

    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    device_identifier = Column(String(255), index=True, nullable=False)
    platform = Column(String(50), default="android", nullable=False)  # android, ios, web
    app_version = Column(String(50), nullable=True)
    os_version = Column(String(50), nullable=True)
    public_key = Column(Text, nullable=True)
    integrity_status = Column(String(50), default="UNVERIFIED", nullable=False)
    last_seen_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    revoked_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    user = relationship("User", back_populates="devices")
    sessions = relationship("Session", back_populates="device")
