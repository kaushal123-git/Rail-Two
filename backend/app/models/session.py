from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class Session(BaseModel):
    __tablename__ = "sessions"

    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    device_id = Column(String(36), ForeignKey("devices.id", ondelete="SET NULL"), nullable=True, index=True)
    refresh_token_hash = Column(String(64), unique=True, index=True, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
    last_used_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    ip_hash = Column(String(64), nullable=True)
    user_agent = Column(String(255), nullable=True)

    # Relationships
    user = relationship("User", back_populates="sessions")
    device = relationship("Device", back_populates="sessions")
