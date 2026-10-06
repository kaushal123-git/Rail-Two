from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, DateTime, Boolean, ForeignKey
from app.models.base import BaseModel


class AssistantRequest(BaseModel):
    """
    Audit log record for every LOCO Assist query, intent resolution,
    and tool execution.
    """
    __tablename__ = "assistant_requests"

    user_id = Column(String(36), ForeignKey("users.id"), nullable=True, index=True)
    session_id = Column(String(36), nullable=True)
    request_id = Column(String(64), nullable=False, index=True)
    query = Column(Text, nullable=False)
    intent = Column(String(64), nullable=False, index=True)
    tool_name = Column(String(64), nullable=True, index=True)
    tool_arguments_hash = Column(String(64), nullable=True)
    result_status = Column(String(32), nullable=False, default="SUCCESS")  # SUCCESS, ERROR, REJECTED, AUTH_REQUIRED, TIMEOUT
    error_code = Column(String(64), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class AssistantAction(BaseModel):
    """
    Represents a staged, sensitive LOCO Assist action requiring explicit user confirmation
    (e.g., ticket cancellation, refund request).
    """
    __tablename__ = "assistant_actions"

    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    action_type = Column(String(64), nullable=False)  # e.g. CANCEL_TICKET, REQUEST_REFUND
    target_id = Column(String(64), nullable=False)  # e.g. ticket_id
    confirmation_token = Column(String(128), nullable=False, unique=True, index=True)
    status = Column(String(32), nullable=False, default="PENDING_CONFIRMATION")  # PENDING_CONFIRMATION, CONFIRMED, EXECUTED, EXPIRED, CANCELLED
    expires_at = Column(DateTime(timezone=True), nullable=False)
    executed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
