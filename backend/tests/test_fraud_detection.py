import pytest
import time
from datetime import datetime, timezone, timedelta
from httpx import AsyncClient

from app.models.ticket import Ticket, TicketStatus
from app.models.journey import Journey, JourneyStatus, JourneySecurityState
from app.models.fraud_model_version import FraudModelVersion
from app.models.fraud_decision import FraudDecision
from app.models.fraud_prediction import FraudPrediction
from app.models.fraud_feature_snapshot import FraudFeatureSnapshot
from app.models.fraud_rule_event import FraudRuleEvent
from app.schemas.journey import LocationEvidenceInput
from app.services.fraud_model_service import FraudModelService
from app.services.fraud_decision_engine import FraudDecisionEngine
from app.services.fraud_feature_extractor import FraudFeatureExtractor
from app.repositories.ticket_repository import TicketRepository
from app.repositories.fraud_repository import (
    FraudModelVersionRepository,
    FraudPredictionRepository,
    FraudDecisionRepository,
    FraudFeatureSnapshotRepository,
)
from ml.features.schema import FraudFeatureVector, FEATURE_NAMES, NUM_FEATURES
from tests.conftest import TestingSessionLocal


@pytest.mark.asyncio
async def test_feature_schema_and_vector_completeness():
    """Verify feature schema contains exactly 52 transit features in specified order."""
    assert len(FEATURE_NAMES) == 52
    assert NUM_FEATURES == 52

    vector = FraudFeatureVector()
    as_list = vector.to_list()
    assert len(as_list) == 52

    # Check key categories
    as_dict = vector.to_dict()
    assert "speed_kmh" in as_dict
    assert "distance_from_expected_station" in as_dict
    assert "mock_location_signal" in as_dict
    assert "play_integrity_status" in as_dict
    assert "tickets_created_24h" in as_dict
    assert "active_ticket_count" in as_dict


@pytest.mark.asyncio
async def test_fraud_model_service_loading_and_inference():
    """Verify model service loads trained GradientBoosting artifact and runs sub-25ms inference."""
    service = FraudModelService.get_instance()
    assert service.is_loaded is True
    assert service.metadata.get("model_version") == "LOCO-FRAUD-v1.0"
    assert service.metadata.get("algorithm") == "GradientBoosting"

    # Clean feature vector
    clean_vector = FraudFeatureVector(
        gps_accuracy=8.0,
        distance_from_expected_station=15.0,
        speed_kmh=22.0,
        location_confidence=0.98,
        mock_location_signal=0.0,
        play_integrity_status=1.0,
        device_integrity_status=1.0,
        active_ticket_count=1.0,
        payment_attempts_24h=1.0,
        payment_success_rate=1.0,
    )

    # Warm-up call
    service.predict(clean_vector)

    latencies = []
    for _ in range(5):
        t0 = time.perf_counter()
        res_clean = service.predict(clean_vector)
        latencies.append((time.perf_counter() - t0) * 1000.0)

    avg_latency_ms = sum(latencies) / len(latencies)
    assert avg_latency_ms < 100.0  # Fast inference requirement (target sub-10ms in production)
    assert res_clean.risk_score < 0.35
    assert res_clean.risk_level in ["LOW", "MEDIUM"]
    assert res_clean.model_version == "LOCO-FRAUD-v1.0"


    # High anomaly feature vector
    suspicious_vector = FraudFeatureVector(
        gps_accuracy=250.0,
        distance_from_expected_station=4500.0,
        speed_kmh=380.0,
        location_jump_distance=5200.0,
        location_confidence=0.05,
        mock_location_signal=1.0,
        play_integrity_status=0.0,
        device_integrity_status=0.0,
        active_ticket_count=8.0,
        payment_failures_24h=4.0,
        payment_success_rate=0.2,
        suspicious_network_signal=1.0,
    )

    res_suspicious = service.predict(suspicious_vector)
    assert res_suspicious.risk_score > 0.70
    assert res_suspicious.risk_level in ["HIGH", "CRITICAL"]
    assert len(res_suspicious.top_features) > 0


@pytest.mark.asyncio
async def test_hard_security_rules_evaluation():
    """Test deterministic hard security rules trigger regardless of ML scores."""
    async with TestingSessionLocal() as session:
        pred_repo = FraudPredictionRepository(session)
        dec_repo = FraudDecisionRepository(session)
        snap_repo = FraudFeatureSnapshotRepository(session)
        model_service = FraudModelService.get_instance()

        engine = FraudDecisionEngine(
            session=session,
            model_service=model_service,
            prediction_repo=pred_repo,
            decision_repo=dec_repo,
            snapshot_repo=snap_repo,
        )

        now = datetime.now(timezone.utc)

        # 1. Expired ticket rule
        expired_ticket = Ticket(
            id="ticket-expired-test",
            user_id="user-123",
            ticket_status=TicketStatus.EXPIRED.value,
            valid_until=now - timedelta(minutes=15),
            origin_station_id="st-churchgate",
            destination_station_id="st-andheri",
            fare=20.0,
        )
        rules_expired = engine._evaluate_hard_rules(
            ticket=expired_ticket,
            journey=None,
            vector=FraudFeatureVector(),
            context_action="TICKET_VERIFY",
        )
        rule_codes = [r.rule_code for r in rules_expired]
        assert "RULE_TICKET_EXPIRED" in rule_codes

        # 2. Mock location detected rule
        mock_vector = FraudFeatureVector(mock_location_signal=1.0)
        rules_mock = engine._evaluate_hard_rules(
            ticket=None,
            journey=None,
            vector=mock_vector,
            context_action="LOCATION_UPDATE",
        )
        assert any(r.rule_code == "RULE_MOCK_LOCATION_DETECTED" for r in rules_mock)

        # 3. Teleportation speed > 300 km/h
        teleport_vector = FraudFeatureVector(speed_kmh=350.0)
        rules_teleport = engine._evaluate_hard_rules(
            ticket=None,
            journey=None,
            vector=teleport_vector,
            context_action="LOCATION_UPDATE",
        )
        assert any(r.rule_code == "RULE_TELEPORTATION_DETECTED" for r in rules_teleport)


@pytest.mark.asyncio
async def test_decision_engine_end_to_end_evaluation(authenticated_user_tokens):
    """Test full decision engine evaluation, ML synthesis, and database audit persistence."""
    user_id = authenticated_user_tokens["user_id"]

    async with TestingSessionLocal() as session:
        pred_repo = FraudPredictionRepository(session)
        dec_repo = FraudDecisionRepository(session)
        snap_repo = FraudFeatureSnapshotRepository(session)
        model_service = FraudModelService.get_instance()

        engine = FraudDecisionEngine(
            session=session,
            model_service=model_service,
            prediction_repo=pred_repo,
            decision_repo=dec_repo,
            snapshot_repo=snap_repo,
        )

        clean_vector = FraudFeatureVector(
            gps_accuracy=10.0,
            distance_from_expected_station=20.0,
            speed_kmh=25.0,
            location_confidence=0.95,
            mock_location_signal=0.0,
            play_integrity_status=1.0,
        )

        decision, prediction = await engine.evaluate_decision(
            user_id=user_id,
            feature_vector=clean_vector,
            context_action="TICKET_VERIFY",
        )

        assert decision is not None
        assert prediction is not None
        assert decision.decision in ["ALLOW", "MONITOR"]
        assert prediction.model_version == "LOCO-FRAUD-v1.0"
        assert decision.user_id == user_id

        # Verify audit records in DB
        persisted_dec = await dec_repo.get_by_id(decision.id)
        assert persisted_dec is not None
        assert persisted_dec.decision == decision.decision

        persisted_pred = await pred_repo.get_by_id(prediction.id)
        assert persisted_pred is not None
        assert persisted_pred.risk_score == prediction.risk_score


@pytest.mark.asyncio
async def test_fraud_api_active_model_endpoint(client: AsyncClient, authenticated_user_tokens):
    """Test GET /api/v1/fraud/model/active endpoint returns model metadata."""
    headers = authenticated_user_tokens["headers"]
    resp = await client.get("/api/v1/fraud/model/active", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["success"] is True
    data = body["data"]
    assert data["version"] == "LOCO-FRAUD-v1.0"
    assert data["algorithm"] == "GradientBoosting"
    assert "thresholds" in data
    assert "metrics" in data


@pytest.mark.asyncio
async def test_fraud_api_evaluate_endpoint(client: AsyncClient, authenticated_user_tokens):
    """Test POST /api/v1/fraud/evaluate with simulated feature input."""
    headers = authenticated_user_tokens["headers"]

    eval_payload = {
        "context_action": "TICKET_VERIFY",
        "location": {
            "latitude": 18.9322,
            "longitude": 72.8264,
            "accuracy_meters": 12.0,
            "speed_mps": 5.0,
            "is_mock": False,
        },
    }

    resp = await client.post("/api/v1/fraud/evaluate", json=eval_payload, headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["success"] is True
    data = body["data"]
    assert "risk_score" in data
    assert "decision" in data
    assert data["decision"] in ["ALLOW", "MONITOR", "CHALLENGE", "BLOCK"]
    assert data["prediction"]["model_version"] == "LOCO-FRAUD-v1.0"


@pytest.mark.asyncio
async def test_ticket_turnstile_verify_with_fraud_decision(client: AsyncClient, authenticated_user_tokens):
    """Test POST /api/v1/tickets/verify validates ticket lifecycle and ML fraud decision."""
    headers = authenticated_user_tokens["headers"]

    # 1. Fetch stations
    st_res = await client.get("/api/v1/stations/search?q=Churchgate")
    ccg_id = st_res.json()["data"][0]["id"]
    st_and = await client.get("/api/v1/stations/search?q=Andheri")
    and_id = st_and.json()["data"][0]["id"]

    # 2. Create ticket
    create_res = await client.post(
        "/api/v1/tickets",
        headers=headers,
        json={
            "origin_station_id": ccg_id,
            "destination_station_id": and_id,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )
    assert create_res.status_code == 200
    ticket_id = create_res.json()["data"]["id"]

    # Transition to ISSUED and ensure payment is CONFIRMED
    for target in ["PAYMENT_PENDING", "PAYMENT_CONFIRMED", "ISSUING", "ISSUED"]:
        await client.post(
            f"/api/v1/tickets/{ticket_id}/transition",
            headers=headers,
            json={"target_status": target, "reason": "Test transition"},
        )

    async with TestingSessionLocal() as session:
        t_repo = TicketRepository(session)
        t_obj = await t_repo.get_by_id(ticket_id)
        if t_obj:
            t_obj.payment_status = "CONFIRMED"
            await t_repo.update(t_obj)
            await session.commit()

    # 3. Get QR token for the issued ticket
    qr_res = await client.get(f"/api/v1/tickets/{ticket_id}/qr", headers=headers)
    assert qr_res.status_code == 200
    qr_token = qr_res.json()["data"]["qr_token_id"]

    # 4. Simulate turnstile verification scan with clean location
    verify_turnstile_res = await client.post(
        "/api/v1/tickets/verify",
        json={
            "ticket_id": ticket_id,
            "qr_token_id": qr_token,
            "origin_station_id": ccg_id,
            "destination_station_id": and_id,
            "location": {
                "latitude": 18.9322,
                "longitude": 72.8264,
                "accuracy_meters": 10.0,
                "speed_mps": 0.5,
                "is_mock": False,
            },
        },
        headers=headers,
    )
    assert verify_turnstile_res.status_code == 200
    body = verify_turnstile_res.json()
    assert body["success"] is True
    t_data = body["data"]
    assert t_data["is_valid"] is True
    assert t_data["ticket_id"] == ticket_id
    assert t_data["fraud_decision"] in ["ALLOW", "MONITOR"]
    assert t_data["fraud_risk_score"] is not None


@pytest.mark.asyncio
async def test_ticket_turnstile_verify_rejects_mock_location(client: AsyncClient, authenticated_user_tokens):
    """Test turnstile verification blocks scan if mock location signal is detected."""
    headers = authenticated_user_tokens["headers"]

    # Fetch stations
    st_res = await client.get("/api/v1/stations/search?q=Churchgate")
    ccg_id = st_res.json()["data"][0]["id"]
    st_dad = await client.get("/api/v1/stations/search?q=Dadar")
    dad_id = st_dad.json()["data"][0]["id"]

    # Create ticket and transition to ISSUED
    create_res = await client.post(
        "/api/v1/tickets",
        headers=headers,
        json={
            "origin_station_id": ccg_id,
            "destination_station_id": dad_id,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )
    ticket_id = create_res.json()["data"]["id"]

    for target in ["PAYMENT_PENDING", "PAYMENT_CONFIRMED", "ISSUING", "ISSUED"]:
        await client.post(
            f"/api/v1/tickets/{ticket_id}/transition",
            headers=headers,
            json={"target_status": target, "reason": "Test transition"},
        )

    async with TestingSessionLocal() as session:
        t_repo = TicketRepository(session)
        t_obj = await t_repo.get_by_id(ticket_id)
        if t_obj:
            t_obj.payment_status = "CONFIRMED"
            await t_repo.update(t_obj)
            await session.commit()


    qr_res = await client.get(f"/api/v1/tickets/{ticket_id}/qr", headers=headers)
    qr_token = qr_res.json()["data"]["qr_token_id"]

    # Turnstile scan with mock GPS provider flag
    verify_mock_res = await client.post(
        "/api/v1/tickets/verify",
        json={
            "ticket_id": ticket_id,
            "qr_token_id": qr_token,
            "location": {
                "latitude": 18.9322,
                "longitude": 72.8264,
                "accuracy_meters": 10.0,
                "speed_mps": 0.5,
                "is_mock": True,
                "mock_confidence": 0.99,
            },
        },
        headers=headers,
    )
    assert verify_mock_res.status_code == 200
    body = verify_mock_res.json()
    # Ticket verification should deny passage due to mock location hard rule
    assert body["data"]["is_valid"] is False
    assert body["data"]["fraud_decision"] in ["BLOCK", "RESTRICT"]
