from sqlalchemy import Column, String, Float, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class FraudFeatureSnapshot(BaseModel):
    """
    Persisted snapshot of the 52-dimensional fraud feature vector
    for auditability and training data accumulation.
    """
    __tablename__ = "fraud_feature_snapshots"

    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    ticket_id = Column(String(36), ForeignKey("tickets.id", ondelete="SET NULL"), nullable=True, index=True)
    journey_id = Column(String(36), ForeignKey("journeys.id", ondelete="SET NULL"), nullable=True, index=True)
    feature_schema_version = Column(String(50), default="LOCO-FRAUD-FEATURE-v1.0", nullable=False)
    features_json = Column(Text, nullable=False)

    # Relationships
    user = relationship("User")
    ticket = relationship("Ticket")
    journey = relationship("Journey")
