import json
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import (
    get_current_user,
    get_fraud_decision_engine,
    get_fraud_feature_extractor,
    get_fraud_decision_repo,
    get_fraud_prediction_repo,
    get_fraud_model_repo,
    get_fraud_model_service,
    get_ticket_repo,
    get_journey_repo,
)
from app.models.user import User
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.fraud import (
    FraudEvaluateRequest,
    FraudDecisionResponse,
    FraudPredictionRead,
    CommuterRiskSummaryResponse,
    FraudModelVersionRead,
)
from app.services.fraud_decision_engine import FraudDecisionEngine
from app.services.fraud_feature_extractor import FraudFeatureExtractor
from app.services.fraud_model_service import FraudModelService
from app.repositories.fraud_repository import (
    FraudDecisionRepository,
    FraudPredictionRepository,
    FraudModelVersionRepository,
)
from app.repositories.ticket_repository import TicketRepository
from app.repositories.journey_repository import JourneyRepository


router = APIRouter(prefix="/fraud", tags=["Custom ML Fraud Detection Engine"])


@router.post("/evaluate", response_model=ApiResponse[FraudDecisionResponse])
async def evaluate_fraud_risk(
    payload: FraudEvaluateRequest,
    current_user: User = Depends(get_current_user),
    extractor: FraudFeatureExtractor = Depends(get_fraud_feature_extractor),
    engine: FraudDecisionEngine = Depends(get_fraud_decision_engine),
    ticket_repo: TicketRepository = Depends(get_ticket_repo),
    journey_repo: JourneyRepository = Depends(get_journey_repo),
):
    """
    Evaluate multi-signal fraud risk and render an authoritative security decision.
    Combines trained ML model inference (Gradient Boosting) with deterministic rules.
    """
    ticket = await ticket_repo.get_by_id(payload.ticket_id) if payload.ticket_id else None
    journey = await journey_repo.get_by_id(payload.journey_id) if payload.journey_id else None

    # Extract 52-dimensional tabular feature vector
    vector, conf = await extractor.extract_features(
        user_id=current_user.id,
        ticket_id=payload.ticket_id,
        journey_id=payload.journey_id,
        device_id=payload.device_id,
        current_location=payload.location,
        network_signals=payload.network_signals,
    )

    # Execute Decision Engine pipeline
    decision, prediction = await engine.evaluate_decision(
        user_id=current_user.id,
        feature_vector=vector,
        ticket=ticket,
        journey=journey,
        context_action=payload.context_action,
    )

    top_features = json.loads(prediction.top_features_json) if prediction.top_features_json else []
    triggered_rules = json.loads(decision.triggered_rules_json) if decision.triggered_rules_json else []

    pred_read = FraudPredictionRead(
        prediction_id=prediction.id,
        model_version=prediction.model_version,
        risk_score=prediction.risk_score,
        probability=prediction.probability,
        risk_level=prediction.risk_level,
        top_features=top_features,
        latency_ms=prediction.inference_latency_ms,
        created_at=prediction.created_at,
    )

    resp_data = FraudDecisionResponse(
        decision_id=decision.id,
        decision=decision.decision,
        risk_state=decision.risk_state,
        risk_score=prediction.risk_score,
        reason=decision.reason,
        triggered_rules=triggered_rules,
        prediction=pred_read,
        created_at=decision.created_at,
    )

    return ApiResponse(
        success=True,
        message=f"Fraud evaluation complete: {decision.decision} ({decision.risk_state})",
        data=resp_data,
    )


@router.get("/risk/{user_id}", response_model=ApiResponse[CommuterRiskSummaryResponse])
async def get_commuter_risk_summary(
    user_id: str,
    current_user: User = Depends(get_current_user),
    decision_repo: FraudDecisionRepository = Depends(get_fraud_decision_repo),
    prediction_repo: FraudPredictionRepository = Depends(get_fraud_prediction_repo),
):
    """
    Retrieve historical risk profile and temporal anomaly counts for a commuter.
    Users can inspect their own profile; administrators can inspect any user.
    """
    if current_user.id != user_id:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="UNAUTHORIZED", message="Unauthorized to view foreign risk telemetry."),
        )

    decisions = await decision_repo.get_for_user(user_id, limit=20)
    predictions = await prediction_repo.get_for_user(user_id, limit=20)

    avg_score = 0.0
    if predictions:
        avg_score = sum(p.risk_score for p in predictions) / len(predictions)

    current_state = "LOW_RISK"
    if decisions:
        current_state = decisions[0].risk_state

    is_monitored = current_state in ["MONITORED", "CHALLENGE_REQUIRED", "HIGH_RISK", "BLOCKED"]
    recent_anomalies = sum(1 for p in predictions if p.risk_level in ["MEDIUM", "HIGH", "CRITICAL"])

    return ApiResponse(
        success=True,
        data=CommuterRiskSummaryResponse(
            user_id=user_id,
            current_risk_state=current_state,
            average_risk_score_24h=round(avg_score, 3),
            recent_anomalies_count=recent_anomalies,
            is_monitored=is_monitored,
            recent_decisions_count=len(decisions),
            last_evaluated_at=decisions[0].created_at if decisions else None,
        ),
    )


@router.get("/ticket/{ticket_id}", response_model=ApiResponse[List[FraudDecisionResponse]])
async def get_ticket_fraud_decisions(
    ticket_id: str,
    current_user: User = Depends(get_current_user),
    decision_repo: FraudDecisionRepository = Depends(get_fraud_decision_repo),
    prediction_repo: FraudPredictionRepository = Depends(get_fraud_prediction_repo),
    ticket_repo: TicketRepository = Depends(get_ticket_repo),
):
    """
    Fetch all fraud decisions and audit records linked to a specific ticket.
    """
    ticket = await ticket_repo.get_by_id(ticket_id)
    if not ticket or ticket.user_id != current_user.id:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="TICKET_NOT_FOUND", message="Ticket not found or unauthorized."),
        )

    decisions = await decision_repo.get_for_ticket(ticket_id)
    response_list = []

    for d in decisions:
        pred_read = None
        if d.prediction:
            top_feats = json.loads(d.prediction.top_features_json) if d.prediction.top_features_json else []
            pred_read = FraudPredictionRead(
                prediction_id=d.prediction.id,
                model_version=d.prediction.model_version,
                risk_score=d.prediction.risk_score,
                probability=d.prediction.probability,
                risk_level=d.prediction.risk_level,
                top_features=top_feats,
                latency_ms=d.prediction.inference_latency_ms,
                created_at=d.prediction.created_at,
            )

        triggered_rules = json.loads(d.triggered_rules_json) if d.triggered_rules_json else []
        response_list.append(
            FraudDecisionResponse(
                decision_id=d.id,
                decision=d.decision,
                risk_state=d.risk_state,
                risk_score=d.prediction.risk_score if d.prediction else 0.0,
                reason=d.reason,
                triggered_rules=triggered_rules,
                prediction=pred_read,
                created_at=d.created_at,
            )
        )

    return ApiResponse(
        success=True,
        data=response_list,
    )


@router.get("/events/{decision_id}", response_model=ApiResponse[FraudDecisionResponse])
async def get_fraud_decision_by_id(
    decision_id: str,
    current_user: User = Depends(get_current_user),
    decision_repo: FraudDecisionRepository = Depends(get_fraud_decision_repo),
):
    """
    Auditable lookup of a specific fraud decision and associated rule triggers.
    """
    d = await decision_repo.get_by_id(decision_id)
    if not d or d.user_id != current_user.id:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="DECISION_NOT_FOUND", message="Fraud decision record not found."),
        )

    pred_read = None
    if d.prediction:
        top_feats = json.loads(d.prediction.top_features_json) if d.prediction.top_features_json else []
        pred_read = FraudPredictionRead(
            prediction_id=d.prediction.id,
            model_version=d.prediction.model_version,
            risk_score=d.prediction.risk_score,
            probability=d.prediction.probability,
            risk_level=d.prediction.risk_level,
            top_features=top_feats,
            latency_ms=d.prediction.inference_latency_ms,
            created_at=d.prediction.created_at,
        )

    triggered_rules = json.loads(d.triggered_rules_json) if d.triggered_rules_json else []
    return ApiResponse(
        success=True,
        data=FraudDecisionResponse(
            decision_id=d.id,
            decision=d.decision,
            risk_state=d.risk_state,
            risk_score=d.prediction.risk_score if d.prediction else 0.0,
            reason=d.reason,
            triggered_rules=triggered_rules,
            prediction=pred_read,
            created_at=d.created_at,
        ),
    )


@router.get("/model/active", response_model=ApiResponse[FraudModelVersionRead])
async def get_active_model_version(
    model_service: FraudModelService = Depends(get_fraud_model_service),
    model_repo: FraudModelVersionRepository = Depends(get_fraud_model_repo),
):
    """
    Retrieve active ML fraud detection model version, algorithm, training dataset,
    and validation performance metrics.
    """
    active_db = await model_repo.get_active()
    meta = model_service.metadata

    version_str = meta.get("model_version", model_service.model_version)
    model_name = meta.get("model_name", "LOCO Custom ML Fraud Detector")
    algo = meta.get("algorithm", "GradientBoosting")
    data_ver = meta.get("training_dataset_version", "LOCO-FRAUD-DATASET-v1.0-CONTROLLED")
    schema_ver = meta.get("feature_schema_version", "LOCO-FRAUD-FEATURE-v1.0")
    metrics = meta.get("metrics", {})
    thresholds = meta.get("thresholds", model_service.thresholds)

    return ApiResponse(
        success=True,
        data=FraudModelVersionRead(
            id=active_db.id if active_db else "active-singleton",
            model_name=model_name,
            version=version_str,
            algorithm=algo,
            training_dataset_version=data_ver,
            feature_schema_version=schema_ver,
            metrics=metrics,
            thresholds=thresholds,
            is_active=True,
            created_at=active_db.created_at if active_db else datetime.now(timezone.utc),
        ),
    )
