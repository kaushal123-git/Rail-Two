from sqlalchemy import Column, String, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import BaseModel


class FraudRuleEvent(BaseModel):
    """
    Fine-grained rule violation event triggered during security evaluation.
    """
    __tablename__ = "fraud_rule_events"

    decision_id = Column(
        String(36),
        ForeignKey("fraud_decisions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    rule_code = Column(String(50), nullable=False, index=True)
    rule_severity = Column(String(20), nullable=False)  # INFO, WARNING, CRITICAL
    description = Column(Text, nullable=False)
    metadata_json = Column(Text, nullable=True)

    # Relationship
    decision_record = relationship("FraudDecision", back_populates="rule_events")
