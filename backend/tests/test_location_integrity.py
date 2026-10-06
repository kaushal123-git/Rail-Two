import pytest
from httpx import AsyncClient
from datetime import datetime, timezone, timedelta
from app.schemas.journey import LocationEvidenceInput
from app.models.location_event import LocationEvent
from app.models.fraud_event import FraudEventType
from app.services.location_integrity_service import LocationIntegrityService
from app.repositories.fraud_event_repository import FraudEventRepository
from tests.conftest import TestingSessionLocal, test_redis_store


@pytest.mark.asyncio
async def test_mock_location_signal(client: AsyncClient):
    async with TestingSessionLocal() as session:
        fraud_repo = FraudEventRepository(session)
        service = LocationIntegrityService(fraud_repo, redis=test_redis_store)

        loc = LocationEvidenceInput(
            latitude=19.2290,
            longitude=72.8573,
            accuracy_meters=10.0,
            is_mock=True,
            mock_confidence=0.95,
        )

        result = await service.evaluate_location(
            user_id="test-user-1",
            device_id="test-dev-1",
            current_location=loc,
        )

        signal_types = [s["type"] for s in result.signals]
        assert FraudEventType.MOCK_LOCATION.value in signal_types
        assert result.risk_score >= 0.40
        assert result.location_confidence < 0.50


@pytest.mark.asyncio
async def test_impossible_speed_and_teleportation(client: AsyncClient):
    async with TestingSessionLocal() as session:
        fraud_repo = FraudEventRepository(session)
        service = LocationIntegrityService(fraud_repo, redis=test_redis_store)

        server_t0 = datetime.now(timezone.utc) - timedelta(seconds=10)
        server_t1 = datetime.now(timezone.utc)

        # Observation 1: Borivali (19.2290, 72.8573)
        last_event = LocationEvent(
            user_id="test-user-2",
            device_id="test-dev-2",
            latitude=19.2290,
            longitude=72.8573,
            accuracy_meters=10.0,
            timestamp_device=server_t0,
            timestamp_server=server_t0,
        )

        # Observation 2: 10 seconds later, 23km away at Dadar (19.0192, 72.8438) -> 8280 km/h!
        teleport_loc = LocationEvidenceInput(
            latitude=19.0192,
            longitude=72.8438,
            accuracy_meters=10.0,
            timestamp_device=server_t1,
        )

        result = await service.evaluate_location(
            user_id="test-user-2",
            device_id="test-dev-2",
            current_location=teleport_loc,
            last_event=last_event,
            server_now=server_t1,
        )

        signal_types = [s["type"] for s in result.signals]
        assert FraudEventType.TELEPORTATION.value in signal_types
        assert result.risk_score >= 0.60
        assert result.security_state in ("SECURITY_WARNING", "SUSPICIOUS")


@pytest.mark.asyncio
async def test_device_clock_anomaly(client: AsyncClient):
    async with TestingSessionLocal() as session:
        fraud_repo = FraudEventRepository(session)
        service = LocationIntegrityService(fraud_repo, redis=test_redis_store)

        server_now = datetime.now(timezone.utc)
        # Device clock manipulated: 10 minutes (600s) behind server time
        manipulated_device_ts = server_now - timedelta(seconds=600)

        loc = LocationEvidenceInput(
            latitude=19.2290,
            longitude=72.8573,
            accuracy_meters=10.0,
            timestamp_device=manipulated_device_ts,
        )

        result = await service.evaluate_location(
            user_id="test-user-3",
            device_id="test-dev-3",
            current_location=loc,
            server_now=server_now,
        )

        signal_types = [s["type"] for s in result.signals]
        assert FraudEventType.CLOCK_ANOMALY.value in signal_types


@pytest.mark.asyncio
async def test_sensor_inconsistency_and_replay_detection(client: AsyncClient):
    async with TestingSessionLocal() as session:
        fraud_repo = FraudEventRepository(session)
        service = LocationIntegrityService(fraud_repo, redis=test_redis_store)

        server_now = datetime.now(timezone.utc)

        # GPS says 80 km/h (22.2 m/s) but accelerometer motion sensor says stationary
        inconsistent_loc = LocationEvidenceInput(
            latitude=19.2290,
            longitude=72.8573,
            accuracy_meters=10.0,
            speed_mps=22.2,
            device_moving_sensor=False,
            client_event_id="nonce-xyz-100",
        )

        result = await service.evaluate_location(
            user_id="test-user-4",
            device_id="test-dev-4",
            current_location=inconsistent_loc,
            server_now=server_now,
        )

        signal_types = [s["type"] for s in result.signals]
        assert FraudEventType.SENSOR_INCONSISTENCY.value in signal_types

        # Submit identical client_event_id to trigger anti-replay
        replay_result = await service.evaluate_location(
            user_id="test-user-4",
            device_id="test-dev-4",
            current_location=inconsistent_loc,
            server_now=server_now,
        )
        replay_signals = [s["type"] for s in replay_result.signals]
        assert FraudEventType.LOCATION_REPLAY.value in replay_signals
