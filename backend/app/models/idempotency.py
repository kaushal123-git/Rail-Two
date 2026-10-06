from datetime import datetime, timezone
import uuid
from sqlalchemy import Column, String, Integer, Text, DateTime
from app.core.database import Base


class IdempotencyKey(Base):
    __tablename__ = "idempotency_keys"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    key = Column(String(128), unique=True, nullable=False, index=True)
    user_id = Column(String(36), nullable=True, index=True)
    request_path = Column(String(255), nullable=False)
    request_hash = Column(String(64), nullable=False)
    response_status_code = Column(Integer, nullable=True)
    response_body = Column(Text, nullable=True)
    status = Column(String(30), default="PROCESSING", nullable=False, index=True)  # PROCESSING, COMPLETED, FAILED
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    expires_at = Column(DateTime(timezone=True), nullable=False, index=True)
