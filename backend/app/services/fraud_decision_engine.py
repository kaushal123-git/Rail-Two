"""
LOCO Machine Learning Fraud Detection - Decision Engine
Version: LOCO-DECISION-ENGINE-v1.0

Synthesizes probabilistic ML risk predictions with deterministic hard security rules,
transit state machine constraints, and temporal Redis anomaly windows to produce
auditable security decisions (ALLOW, MONITOR, CHALLENGE, RESTRICT, BLOCK).
"""

import json
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ticket import Ticket, TicketStatus
from app.models.journey import Journey, JourneyStatus
from app.models.user import User
from app.models.fraud_decision import (
    FraudDecision,
    FraudDecisionOutcome,
    FraudRiskState,
    FraudReviewStatus,
)
from app.models.fraud_prediction import FraudPrediction
from app.models.fraud_feature_snapshot import FraudFeatureSnapshot
from app.models.fraud_rule_event import FraudRuleEvent
from app.repositories.fraud_repository import (
    FraudPredictionRepository,
    FraudDecisionRepository,
    FraudFeatureSnapshotRepository,
)
from app.services.fraud_model_service import FraudModelService, FraudPredictionResult
from ml.features.schema import FraudFeatureVector
from app.core.logging import logger


RULE_VERSION = "LOCO-RULES-v1.0"


class RuleEvaluationResult:
    def __init__(
        self,
        rule_code: str,
        severity: str,  # INFO, WARNING, CRITICAL
        description: str,
        forces_decision: Optional[FraudDecisionOutcome] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ):
        self.rule_code = rule_code
        self.severity = severity
        self.description = description
        self.forces_decision = forces_decision
        self.metadata = metadata or {}


class FraudDecisionEngine:
    """
    Authoritative security decision engine for LOCO.
    Separates the probabilistic ML signal from deterministic transit security controls.
    """

    def __init__(
        self,
        session: AsyncSession,
        model_service: FraudModelService,
        prediction_repo: FraudPredictionRepository,
        decision_repo: FraudDecisionRepository,
        snapshot_repo: FraudFeatureSnapshotRepository,
        redis=None,
    ):
        self.session = session
        self.model_service = model_service
        self.prediction_repo = prediction_repo
        self.decision_repo = decision_repo
        self.snapshot_repo = snapshot_repo
        self.redis = redis

    async def evaluate_decision(
        self,
        user_id: str,
        feature_vector: FraudFeatureVector,
        ticket: Optional[Ticket] = None,
        journey: Optional[Journey] = None,
        context_action: str = "TICKET_VERIFY",
    ) -> Tuple[FraudDecision, FraudPrediction]:
        """
        Full evaluation pipeline:
        1. Evaluate Deterministic Hard Security Rules
        2. Execute ML Inference for Risk Probability
        3. Evaluate Temporal Behavioral Accumulators in Redis
        4. Synthesize Final Authoritative Security Decision
        5. Persist auditable records (Snapshot, Prediction, Decision, Rule Events)
        """
        now = datetime.now(timezone.utc)

        # -------------------------------------------------------------
        # Step 1: Evaluate Deterministic Hard Security Rules
        # -------------------------------------------------------------
        rule_results: List[RuleEvaluationResult] = self._evaluate_hard_rules(
            ticket=ticket,
            journey=journey,
            vector=feature_vector,
            context_action=context_action,
        )

        # -------------------------------------------------------------
        # Step 2: Execute Real ML Inference
        # -------------------------------------------------------------
        ml_prediction: FraudPredictionResult = self.model_service.predict(feature_vector)

        # -------------------------------------------------------------
        # Step 3: Temporal Accumulation in Redis
        # -------------------------------------------------------------
        recent_anomaly_count = await self._update_temporal_state(
            user_id=user_id,
            ticket_id=ticket.id if ticket else None,
            ml_risk_score=ml_prediction.risk_score,
            rule_count=len(rule_results),
        )

        # -------------------------------------------------------------
        # Step 4: Decision Synthesis (ML + Rules + Temporal Context)
        # -------------------------------------------------------------
        critical_rule = next((r for r in rule_results if r.forces_decision == FraudDecisionOutcome.BLOCK), None)
        challenge_rule = next((r for r in rule_results if r.forces_decision == FraudDecisionOutcome.CHALLENGE), None)

        if critical_rule is not None:
            # Deterministic hard block overrides ML score
            final_decision = FraudDecisionOutcome.BLOCK
            final_risk_state = FraudRiskState.BLOCKED
            decision_reason = f"Security Rule Enforcement: {critical_rule.description}"
        elif challenge_rule is not None:
            # Deterministic challenge required
            final_decision = FraudDecisionOutcome.CHALLENGE
            final_risk_state = FraudRiskState.CHALLENGE_REQUIRED
            decision_reason = f"Security Verification Required: {challenge_rule.description}"
        elif ml_prediction.risk_level == "CRITICAL" or ml_prediction.risk_score >= 0.85:
            final_decision = FraudDecisionOutcome.BLOCK
            final_risk_state = FraudRiskState.BLOCKED
            decision_reason = f"High-confidence ML anomaly detected ({ml_prediction.risk_score*100:.1f}% risk score)."
        elif ml_prediction.risk_level == "HIGH" or ml_prediction.risk_score >= 0.55 or recent_anomaly_count >= 3:
            final_decision = FraudDecisionOutcome.CHALLENGE
            final_risk_state = FraudRiskState.CHALLENGE_REQUIRED
            decision_reason = "Suspicious movement telemetry requires additional passenger verification."
        elif ml_prediction.risk_level == "MEDIUM" or ml_prediction.risk_score >= 0.25:
            final_decision = FraudDecisionOutcome.MONITOR
            final_risk_state = FraudRiskState.MONITORED
            decision_reason = "Minor observation uncertainty; continuing journey with active telemetry monitoring."
        else:
            final_decision = FraudDecisionOutcome.ALLOW
            final_risk_state = FraudRiskState.LOW_RISK
            decision_reason = "Telemetry verified. Standard passenger transit approved."

        # -------------------------------------------------------------
        # Step 5: Persist Audit Records
        # -------------------------------------------------------------
        # 5.1 Feature Snapshot
        snapshot = FraudFeatureSnapshot(
            user_id=user_id,
            ticket_id=ticket.id if ticket else None,
            journey_id=journey.id if journey else None,
            feature_schema_version="LOCO-FRAUD-FEATURE-v1.0",
            features_json=json.dumps(feature_vector.to_dict()),
        )
        await self.snapshot_repo.create(snapshot)

        # 5.2 Prediction
        prediction_record = FraudPrediction(
            user_id=user_id,
            ticket_id=ticket.id if ticket else None,
            journey_id=journey.id if journey else None,
            feature_snapshot_id=snapshot.id,
            model_version=ml_prediction.model_version,
            risk_score=ml_prediction.risk_score,
            probability=ml_prediction.probability,
            risk_level=ml_prediction.risk_level,
            top_features_json=json.dumps(ml_prediction.top_features),
            inference_latency_ms=ml_prediction.latency_ms,
        )
        await self.prediction_repo.create(prediction_record)

        # 5.3 Decision
        triggered_rule_codes = [r.rule_code for r in rule_results]
        decision_record = FraudDecision(
            prediction_id=prediction_record.id,
            user_id=user_id,
            ticket_id=ticket.id if ticket else None,
            journey_id=journey.id if journey else None,
            decision=final_decision.value,
            risk_state=final_risk_state.value,
            reason=decision_reason,
            triggered_rules_json=json.dumps(triggered_rule_codes),
            rule_version=RULE_VERSION,
            review_status=FraudReviewStatus.AUTOMATED.value,
        )
        await self.decision_repo.create(decision_record)

        # 5.4 Rule Events
        for r in rule_results:
            rule_evt = FraudRuleEvent(
                decision_id=decision_record.id,
                rule_code=r.rule_code,
                rule_severity=r.severity,
                description=r.description,
                metadata_json=json.dumps(r.metadata),
            )
            await self.decision_repo.create_rule_event(rule_evt)

        logger.info(
            "Fraud Decision: %s [%s] for user=%s, ticket=%s, risk=%.2f, rules=%s",
            final_decision.value,
            final_risk_state.value,
            user_id,
            ticket.id if ticket else None,
            ml_prediction.risk_score,
            triggered_rule_codes,
        )

        return decision_record, prediction_record

    def _evaluate_hard_rules(
        self,
        ticket: Optional[Ticket],
        journey: Optional[Journey],
        vector: FraudFeatureVector,
        context_action: str,
    ) -> List[RuleEvaluationResult]:
        """
        Evaluate deterministic security rules.
        """
        now = datetime.now(timezone.utc)
        results: List[RuleEvaluationResult] = []

        if ticket is not None:
            # Rule: Ticket Expired
            if ticket.valid_until is not None:
                v_until = ticket.valid_until if ticket.valid_until.tzinfo else ticket.valid_until.replace(tzinfo=timezone.utc)
                if v_until < now:
                    results.append(
                        RuleEvaluationResult(
                            rule_code="RULE_TICKET_EXPIRED",
                            severity="CRITICAL",
                            description="Ticket has exceeded its valid transit window and is expired.",
                            forces_decision=FraudDecisionOutcome.BLOCK,
                            metadata={"valid_until": v_until.isoformat(), "now": now.isoformat()},
                        )
                    )

            # Rule: Ticket Already Completed / Consumed
            if ticket.ticket_status == TicketStatus.COMPLETED.value:
                results.append(
                    RuleEvaluationResult(
                        rule_code="RULE_TICKET_ALREADY_COMPLETED",
                        severity="CRITICAL",
                        description="Ticket lifecycle has already terminated (status is COMPLETED).",
                        forces_decision=FraudDecisionOutcome.BLOCK,
                        metadata={"ticket_status": ticket.ticket_status},
                    )
                )

            # Rule: Ticket Fraud Blocked
            if ticket.ticket_status == TicketStatus.FRAUD_BLOCKED.value:
                results.append(
                    RuleEvaluationResult(
                        rule_code="RULE_TICKET_PREVIOUSLY_BLOCKED",
                        severity="CRITICAL",
                        description="Ticket is already permanently revoked due to prior security violation.",
                        forces_decision=FraudDecisionOutcome.BLOCK,
                    )
                )

            # Rule: Payment Not Confirmed
            if ticket.payment_status != "CONFIRMED" and context_action in ["TICKET_VERIFY", "JOURNEY_START"]:
                results.append(
                    RuleEvaluationResult(
                        rule_code="RULE_PAYMENT_NOT_CONFIRMED",
                        severity="CRITICAL",
                        description=f"Ticket payment is unverified (status: {ticket.payment_status}).",
                        forces_decision=FraudDecisionOutcome.BLOCK,
                        metadata={"payment_status": ticket.payment_status},
                    )
                )

        # Rule: Severe Mock Location
        if vector.mock_location_signal >= 1.0:
            results.append(
                RuleEvaluationResult(
                    rule_code="RULE_MOCK_LOCATION_DETECTED",
                    severity="CRITICAL",
                    description="Device mock location provider actively asserted during transit validation.",
                    forces_decision=FraudDecisionOutcome.BLOCK,
                    metadata={"mock_signal": vector.mock_location_signal},
                )
            )

        # Rule: Location Replay Detected
        if vector.location_replay_signal >= 1.0:
            results.append(
                RuleEvaluationResult(
                    rule_code="RULE_LOCATION_REPLAY_DETECTED",
                    severity="CRITICAL",
                    description="Cryptographic client observation event ID has already been submitted.",
                    forces_decision=FraudDecisionOutcome.BLOCK,
                    metadata={"replay_signal": vector.location_replay_signal},
                )
            )

        # Rule: Teleportation / Impossible Speed
        if (vector.location_jump_distance > 5000.0 and vector.location_jump_time < 30.0) or vector.speed_kmh > 300.0:
            results.append(
                RuleEvaluationResult(
                    rule_code="RULE_TELEPORTATION_DETECTED",
                    severity="CRITICAL",
                    description=f"Teleportation jump of {vector.location_jump_distance/1000.0:.1f}km or impossible speed ({vector.speed_kmh:.1f} km/h).",
                    forces_decision=FraudDecisionOutcome.BLOCK,
                    metadata={"jump_distance": vector.location_jump_distance, "jump_time": vector.location_jump_time, "speed_kmh": vector.speed_kmh},
                )
            )


        # Rule: Repeated Pass-Back / Ticket Reuse
        if vector.ticket_reuse_count >= 2.0:
            results.append(
                RuleEvaluationResult(
                    rule_code="RULE_PASS_BACK_TICKET_REUSE",
                    severity="CRITICAL",
                    description=f"Ticket reused {int(vector.ticket_reuse_count)} times across stations in short succession.",
                    forces_decision=FraudDecisionOutcome.BLOCK,
                    metadata={"reuse_count": vector.ticket_reuse_count},
                )
            )

        # Rule: Severe Hardware Attestation Failure
        if vector.emulator_detected >= 1.0 and vector.root_detected >= 1.0:
            results.append(
                RuleEvaluationResult(
                    rule_code="RULE_COMPROMISED_ENVIRONMENT",
                    severity="WARNING",
                    description="Rooted emulator platform detected during transit verification.",
                    forces_decision=FraudDecisionOutcome.CHALLENGE,
                    metadata={"emulator": vector.emulator_detected, "root": vector.root_detected},
                )
            )

        return results

    async def _update_temporal_state(
        self,
        user_id: str,
        ticket_id: Optional[str],
        ml_risk_score: float,
        rule_count: int,
    ) -> int:
        """
        Record rolling anomaly counters in Redis for temporal cross-event analysis.
        Returns the count of recent anomalies in the last 30 minutes.
        """
        if not self.redis:
            return 0

        anomaly_key = f"fraud:user:{user_id}:recent_anomalies"
        recent_count = 0

        try:
            if ml_risk_score >= 0.50 or rule_count > 0:
                # Increment 30-minute rolling window counter
                await self.redis.incr(anomaly_key)
                await self.redis.expire(anomaly_key, 1800)  # 30 mins TTL

            val = await self.redis.get(anomaly_key)
            if val:
                recent_count = int(val)

            # Record ticket scan timestamp and station in Redis
            if ticket_id:
                scan_key = f"fraud:ticket:{ticket_id}:scans"
                await self.redis.incr(scan_key)
                await self.redis.expire(scan_key, 7200)  # 2 hours TTL

        except Exception as e:
            logger.warning("Redis temporal fraud state update failed: %s", str(e))

        return recent_count
