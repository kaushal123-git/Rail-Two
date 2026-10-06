from sqlalchemy import Column, String, Float, Boolean
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class Station(BaseModel):
    __tablename__ = "stations"

    code = Column(String(10), unique=True, index=True, nullable=False)
    name = Column(String(100), index=True, nullable=False)
    display_name = Column(String(150), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    city = Column(String(50), default="Mumbai", nullable=False)
    zone = Column(String(50), default="Western", nullable=False)  # Western, Central, Harbour
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    origin_tickets = relationship(
        "Ticket",
        foreign_keys="Ticket.origin_station_id",
        back_populates="origin_station",
    )
    destination_tickets = relationship(
        "Ticket",
        foreign_keys="Ticket.destination_station_id",
        back_populates="destination_station",
    )
    outgoing_connections = relationship(
        "StationConnection",
        foreign_keys="StationConnection.from_station_id",
        back_populates="from_station",
        cascade="all, delete-orphan",
    )
    incoming_connections = relationship(
        "StationConnection",
        foreign_keys="StationConnection.to_station_id",
        back_populates="to_station",
        cascade="all, delete-orphan",
    )
