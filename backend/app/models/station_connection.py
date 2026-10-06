from sqlalchemy import Column, String, Integer, Float, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class StationConnection(BaseModel):
    __tablename__ = "station_connections"

    from_station_id = Column(
        String(36),
        ForeignKey("stations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    to_station_id = Column(
        String(36),
        ForeignKey("stations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    line_id = Column(
        String(36),
        ForeignKey("railway_lines.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    sequence = Column(Integer, default=1, nullable=False)
    distance_km = Column(Float, nullable=False)
    scheduled_travel_seconds = Column(Integer, nullable=False)
    is_transfer = Column(Boolean, default=False, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    from_station = relationship("Station", foreign_keys=[from_station_id], back_populates="outgoing_connections")
    to_station = relationship("Station", foreign_keys=[to_station_id], back_populates="incoming_connections")
    line = relationship("RailwayLine", back_populates="connections")
