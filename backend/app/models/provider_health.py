from sqlalchemy import Column, String, Integer, Text, DateTime
from app.models.base import BaseModel


class ProviderHealth(BaseModel):
    __tablename__ = "provider_health"

    provider_name = Column(String(100), unique=True, index=True, nullable=False)
    status = Column(String(30), default="NOT_CONFIGURED", nullable=False)  # HEALTHY, DEGRADED, UNAVAILABLE, NOT_CONFIGURED
    last_successful_sync = Column(DateTime(timezone=True), nullable=True)
    last_error = Column(Text, nullable=True)
    latency_ms = Column(Integer, nullable=True)
    metadata_json = Column(Text, nullable=True)
