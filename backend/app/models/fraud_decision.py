from enum import Enum
from sqlalchemy import Column, String, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class FraudDecisionOutcome(str, Enum):
    ALLOW = "ALLOW"
    MONITOR = "MONITOR"
    CHALLENGE = "CHALLENGE"
    RESTRICT = "RESTRICT"
    BLOCK = "BLOCK"


class FraudRiskState(str, Enum):
    LOW_RISK = "LOW_RISK"
    MONITORED = "MONITORED"
    CHALLENGE_REQUIRED = "CHALLENGE_REQUIRED"
    HIGH_RISK = "HIGH_RISK"
    BLOCKED = "BLOCKED"


class FraudReviewStatus(str, Enum):
    AUTOMATED = "AUTOMATED"
    PENDING_REVIEW = "PENDING_REVIEW"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"


class FraudDecision(BaseModel):
    """
    Authoritative decision synthesized from ML risk predictions,
    deterministic security rules, and real-time transit state.
    """
    __tablename__ = "fraud_decisions"

    prediction_id = Column(
        String(36),
        ForeignKey("fraud_predictions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    ticket_id = Column(String(36), ForeignKey("tickets.id", ondelete="SET NULL"), nullable=True, index=True)
    journey_id = Column(String(36), ForeignKey("journeys.id", ondelete="SET NULL"), nullable=True, index=True)
    decision = Column(String(30), nullable=False)  # ALLOW, MONITOR, CHALLENGE, RESTRICT, BLOCK
    risk_state = Column(String(30), nullable=False)  # LOW_RISK, MONITORED, CHALLENGE_REQUIRED, HIGH_RISK, BLOCKED
    reason = Column(Text, nullable=False)
    triggered_rules_json = Column(Text, nullable=True)
    rule_version = Column(String(50), default="LOCO-RULES-v1.0", nullable=False)
    review_status = Column(String(30), default=FraudReviewStatus.AUTOMATED.value, nullable=False)

    # Relationships
    prediction = relationship("FraudPrediction", back_populates="decisions")
    user = relationship("User")
    ticket = relationship("Ticket")
    journey = relationship("Journey")
    rule_events = relationship("FraudRuleEvent", back_populates="decision_record", cascade="all, delete-orphan")
