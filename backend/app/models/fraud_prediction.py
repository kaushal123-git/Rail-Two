from sqlalchemy import Column, String, Float, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class FraudPrediction(BaseModel):
    """
    ML model inference evaluation record for a commuter ticket or journey observation.
    """
    __tablename__ = "fraud_predictions"

    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    ticket_id = Column(String(36), ForeignKey("tickets.id", ondelete="SET NULL"), nullable=True, index=True)
    journey_id = Column(String(36), ForeignKey("journeys.id", ondelete="SET NULL"), nullable=True, index=True)
    feature_snapshot_id = Column(
        String(36),
        ForeignKey("fraud_feature_snapshots.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    model_version = Column(String(50), nullable=False, index=True)
    risk_score = Column(Float, nullable=False)
    probability = Column(Float, nullable=False)
    risk_level = Column(String(20), nullable=False)  # LOW, MEDIUM, HIGH, CRITICAL
    top_features_json = Column(Text, nullable=True)
    inference_latency_ms = Column(Float, nullable=True)

    # Relationships
    user = relationship("User")
    ticket = relationship("Ticket")
    journey = relationship("Journey")
    feature_snapshot = relationship("FraudFeatureSnapshot")
    decisions = relationship("FraudDecision", back_populates="prediction", cascade="all, delete-orphan")
