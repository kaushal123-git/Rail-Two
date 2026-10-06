from enum import Enum
from sqlalchemy import Column, String, Float, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class GeofenceType(str, Enum):
    STATION = "STATION"
    BOARDING = "BOARDING"
    DESTINATION = "DESTINATION"
    TRANSFER = "TRANSFER"


class StationGeofence(BaseModel):
    __tablename__ = "geofences"

    station_id = Column(
        String(36),
        ForeignKey("stations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    center_latitude = Column(Float, nullable=False)
    center_longitude = Column(Float, nullable=False)
    radius_meters = Column(Float, default=300.0, nullable=False)
    geofence_type = Column(String(30), default=GeofenceType.STATION.value, nullable=False)
    s2_cell_token = Column(String(20), nullable=True, index=True)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    station = relationship("Station", backref="geofences", lazy="joined")
