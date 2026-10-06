from sqlalchemy import Column, String, Text, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class ServiceUpdate(BaseModel):
    __tablename__ = "service_updates"

    line_id = Column(
        String(36),
        ForeignKey("railway_lines.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    station_id = Column(
        String(36),
        ForeignKey("stations.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)
    severity = Column(String(20), default="INFO", nullable=False)  # INFO, WARNING, CRITICAL
    source = Column(String(50), default="OPERATIONAL_BULLETIN", nullable=False)
    effective_from = Column(DateTime(timezone=True), nullable=False)
    effective_until = Column(DateTime(timezone=True), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    line = relationship("RailwayLine", back_populates="updates")
    station = relationship("Station")
