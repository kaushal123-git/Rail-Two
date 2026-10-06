from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from app.schemas.journey import LocationEvidenceInput


class FraudEvaluateRequest(BaseModel):
    """Payload to evaluate fraud risk across multi-source signals."""
    ticket_id: Optional[str] = Field(default=None, description="Ticket ID if evaluating booking/scan")
    journey_id: Optional[str] = Field(default=None, description="Active Journey ID if evaluating live movement")
    device_id: Optional[str] = Field(default=None, description="Device UUID / identifier")
    location: Optional[LocationEvidenceInput] = Field(default=None, description="Current GPS observation")
    context_action: str = Field(
        default="TICKET_VERIFY",
        description="Action context: TICKET_BOOKING, TICKET_VERIFY, JOURNEY_UPDATE, GEOFENCE_ENTRY",
    )
    network_signals: Optional[Dict[str, Any]] = Field(default=None, description="Optional network signals: vpn, proxy, ip")


class FraudPredictionRead(BaseModel):
    """ML model inference prediction result."""
    prediction_id: str
    model_version: str
    risk_score: float
    probability: float
    risk_level: str
    top_features: List[Dict[str, Any]] = Field(default_factory=list)
    latency_ms: Optional[float] = None
    created_at: datetime


class FraudDecisionResponse(BaseModel):
    """Authoritative decision rendered by LOCO Fraud Decision Engine."""
    decision_id: str
    decision: str  # ALLOW, MONITOR, CHALLENGE, RESTRICT, BLOCK
    risk_state: str  # LOW_RISK, MONITORED, CHALLENGE_REQUIRED, HIGH_RISK, BLOCKED
    risk_score: float
    reason: str
    triggered_rules: List[str] = Field(default_factory=list)
    prediction: Optional[FraudPredictionRead] = None
    created_at: datetime


class CommuterRiskSummaryResponse(BaseModel):
    """Commuter risk profile summary for administrative review and audit."""
    user_id: str
    current_risk_state: str
    average_risk_score_24h: float
    recent_anomalies_count: int
    is_monitored: bool
    recent_decisions_count: int
    last_evaluated_at: Optional[datetime] = None


class FraudModelVersionRead(BaseModel):
    """Metadata regarding an active or registered LOCO fraud ML model."""
    id: str
    model_name: str
    version: str
    algorithm: str
    training_dataset_version: str
    feature_schema_version: str
    metrics: Dict[str, Any] = Field(default_factory=dict)
    thresholds: Dict[str, float] = Field(default_factory=dict)
    is_active: bool
    created_at: datetime
