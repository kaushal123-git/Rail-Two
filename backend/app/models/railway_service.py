from sqlalchemy import Column, String, Integer, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class RailwayService(BaseModel):
    __tablename__ = "railway_services"

    line_id = Column(
        String(36),
        ForeignKey("railway_lines.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    service_code = Column(String(50), nullable=False)  # FAST, SLOW, AC_FAST, SEMI_FAST
    service_name = Column(String(150), nullable=False)
    direction = Column(String(20), default="UP", nullable=False)  # UP, DOWN, BOTH
    status = Column(String(30), default="ACTIVE", nullable=False)  # ACTIVE, DELAYED, SUSPENDED, CLOSED, UNKNOWN
    delay_seconds = Column(Integer, default=0, nullable=False)
    source = Column(String(50), default="TIMETABLE", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    line = relationship("RailwayLine", back_populates="services")
