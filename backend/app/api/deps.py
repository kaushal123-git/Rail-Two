from typing import Optional
from fastapi import Depends, HTTPException, status, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.redis import get_redis
from app.core.security import decode_access_token
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.repositories.device_repository import DeviceRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.otp_repository import OtpRepository
from app.repositories.station_repository import StationRepository
from app.repositories.ticket_repository import TicketRepository
from app.services.otp_service import OtpService
from app.services.auth_service import AuthService
from app.services.device_service import DeviceService
from app.services.station_service import StationService
from app.services.ticket_service import TicketService

security_bearer = HTTPBearer(auto_error=False)


# --- Service Inversion of Control Dependencies ---

def get_user_repo(db: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(db)


def get_device_repo(db: AsyncSession = Depends(get_db)) -> DeviceRepository:
    return DeviceRepository(db)


def get_session_repo(db: AsyncSession = Depends(get_db)) -> SessionRepository:
    return SessionRepository(db)


def get_otp_repo(db: AsyncSession = Depends(get_db)) -> OtpRepository:
    return OtpRepository(db)


def get_station_repo(db: AsyncSession = Depends(get_db)) -> StationRepository:
    return StationRepository(db)


def get_ticket_repo(db: AsyncSession = Depends(get_db)) -> TicketRepository:
    return TicketRepository(db)


def get_otp_service(
    otp_repo: OtpRepository = Depends(get_otp_repo),
    redis=Depends(get_redis),
) -> OtpService:
    return OtpService(otp_repo, redis)


def get_auth_service(
    user_repo: UserRepository = Depends(get_user_repo),
    device_repo: DeviceRepository = Depends(get_device_repo),
    session_repo: SessionRepository = Depends(get_session_repo),
    otp_service: OtpService = Depends(get_otp_service),
) -> AuthService:
    return AuthService(user_repo, device_repo, session_repo, otp_service)


def get_device_service(device_repo: DeviceRepository = Depends(get_device_repo)) -> DeviceService:
    return DeviceService(device_repo)


def get_station_service(station_repo: StationRepository = Depends(get_station_repo)) -> StationService:
    return StationService(station_repo)


from app.repositories.payment_repository import PaymentRepository
from app.repositories.fare_repository import FareRepository
from app.repositories.idempotency_repository import IdempotencyRepository
from app.services.fare_service import FareService
from app.services.payment_gateway import PaymentGateway, get_payment_gateway
from app.services.railway_provider import RailwayProvider, get_railway_provider


def get_payment_repo(db: AsyncSession = Depends(get_db)) -> PaymentRepository:
    return PaymentRepository(db)


def get_fare_repo(db: AsyncSession = Depends(get_db)) -> FareRepository:
    return FareRepository(db)


def get_idempotency_repo(db: AsyncSession = Depends(get_db)) -> IdempotencyRepository:
    return IdempotencyRepository(db)


def get_fare_service(
    fare_repo: FareRepository = Depends(get_fare_repo),
) -> FareService:
    return FareService(fare_repo)


def get_ticket_service(
    ticket_repo: TicketRepository = Depends(get_ticket_repo),
    station_repo: StationRepository = Depends(get_station_repo),
    payment_repo: PaymentRepository = Depends(get_payment_repo),
    idempotency_repo: IdempotencyRepository = Depends(get_idempotency_repo),
    fare_service: FareService = Depends(get_fare_service),
    redis=Depends(get_redis),
) -> TicketService:
    return TicketService(
        ticket_repo=ticket_repo,
        station_repo=station_repo,
        payment_repo=payment_repo,
        idempotency_repo=idempotency_repo,
        fare_service=fare_service,
        payment_gateway=get_payment_gateway(),
        railway_provider=get_railway_provider(),
        redis=redis,
    )


# --- Authentication and Authorization Dependencies ---

async def get_current_user(
    auth: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    user_repo: UserRepository = Depends(get_user_repo),
) -> User:
    """Validate bearer JWT access token and return authenticated User record."""
    if not auth or not auth.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication credentials.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_access_token(auth.credentials)
    if not payload or not payload.get("sub"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = await user_repo.get_by_id(payload["sub"])
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User associated with token does not exist.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if user.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is suspended or blocked.",
        )

    return user


async def get_optional_current_user(
    auth: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    user_repo: UserRepository = Depends(get_user_repo),
) -> Optional[User]:
    """Return authenticated User if token is provided and valid, otherwise None."""
    if not auth or not auth.credentials:
        return None
    try:
        payload = decode_access_token(auth.credentials)
        if not payload or not payload.get("sub"):
            return None
        user = await user_repo.get_by_id(payload["sub"])
        if user and user.status == "ACTIVE":
            return user
    except Exception:
        return None
    return None


def get_network_repo(db: AsyncSession = Depends(get_db)) -> "NetworkRepository":
    from app.repositories.network_repository import NetworkRepository
    return NetworkRepository(db)


def get_routing_service(
    db: AsyncSession = Depends(get_db),
    station_repo: StationRepository = Depends(get_station_repo),
    network_repo: "NetworkRepository" = Depends(get_network_repo),
) -> "RoutingService":
    from app.services.routing_service import RoutingService
    return RoutingService(db=db, station_repo=station_repo, network_repo=network_repo)


# --- Phase 4 Geofencing, Journey & Location Integrity Dependencies ---

from app.repositories.geofence_repository import GeofenceRepository
from app.repositories.journey_repository import JourneyRepository
from app.repositories.location_event_repository import LocationEventRepository
from app.repositories.fraud_event_repository import FraudEventRepository
from app.services.geofence_service import GeofenceService
from app.services.location_integrity_service import LocationIntegrityService
from app.services.journey_service import JourneyService


def get_geofence_repo(db: AsyncSession = Depends(get_db)) -> GeofenceRepository:
    return GeofenceRepository(db)


def get_journey_repo(db: AsyncSession = Depends(get_db)) -> JourneyRepository:
    return JourneyRepository(db)


def get_location_event_repo(db: AsyncSession = Depends(get_db)) -> LocationEventRepository:
    return LocationEventRepository(db)


def get_fraud_event_repo(db: AsyncSession = Depends(get_db)) -> FraudEventRepository:
    return FraudEventRepository(db)


def get_geofence_service(
    geofence_repo: GeofenceRepository = Depends(get_geofence_repo),
    station_repo: StationRepository = Depends(get_station_repo),
    redis=Depends(get_redis),
) -> GeofenceService:
    return GeofenceService(geofence_repo, station_repo, redis)


def get_location_integrity_service(
    fraud_repo: FraudEventRepository = Depends(get_fraud_event_repo),
    redis=Depends(get_redis),
) -> LocationIntegrityService:
    return LocationIntegrityService(fraud_repo, redis)


# --- Phase 5 Fraud Detection Dependencies ---
from app.repositories.fraud_repository import (
    FraudModelVersionRepository,
    FraudPredictionRepository,
    FraudDecisionRepository,
    FraudFeatureSnapshotRepository,
)
from app.services.fraud_feature_extractor import FraudFeatureExtractor
from app.services.fraud_model_service import FraudModelService
from app.services.fraud_decision_engine import FraudDecisionEngine


def get_fraud_model_repo(db: AsyncSession = Depends(get_db)) -> FraudModelVersionRepository:
    return FraudModelVersionRepository(db)


def get_fraud_prediction_repo(db: AsyncSession = Depends(get_db)) -> FraudPredictionRepository:
    return FraudPredictionRepository(db)


def get_fraud_decision_repo(db: AsyncSession = Depends(get_db)) -> FraudDecisionRepository:
    return FraudDecisionRepository(db)


def get_fraud_snapshot_repo(db: AsyncSession = Depends(get_db)) -> FraudFeatureSnapshotRepository:
    return FraudFeatureSnapshotRepository(db)


def get_fraud_model_service() -> FraudModelService:
    return FraudModelService.get_instance()


def get_fraud_feature_extractor(
    db: AsyncSession = Depends(get_db),
    redis=Depends(get_redis),
) -> FraudFeatureExtractor:
    return FraudFeatureExtractor(db, redis)


def get_fraud_decision_engine(
    db: AsyncSession = Depends(get_db),
    model_service: FraudModelService = Depends(get_fraud_model_service),
    prediction_repo: FraudPredictionRepository = Depends(get_fraud_prediction_repo),
    decision_repo: FraudDecisionRepository = Depends(get_fraud_decision_repo),
    snapshot_repo: FraudFeatureSnapshotRepository = Depends(get_fraud_snapshot_repo),
    redis=Depends(get_redis),
) -> FraudDecisionEngine:
    return FraudDecisionEngine(
        session=db,
        model_service=model_service,
        prediction_repo=prediction_repo,
        decision_repo=decision_repo,
        snapshot_repo=snapshot_repo,
        redis=redis,
    )


def get_journey_service(
    journey_repo: JourneyRepository = Depends(get_journey_repo),
    ticket_repo: TicketRepository = Depends(get_ticket_repo),
    station_repo: StationRepository = Depends(get_station_repo),
    location_repo: LocationEventRepository = Depends(get_location_event_repo),
    geofence_service: GeofenceService = Depends(get_geofence_service),
    integrity_service: LocationIntegrityService = Depends(get_location_integrity_service),
    redis=Depends(get_redis),
    decision_engine: FraudDecisionEngine = Depends(get_fraud_decision_engine),
    fraud_extractor: FraudFeatureExtractor = Depends(get_fraud_feature_extractor),
) -> JourneyService:
    return JourneyService(
        journey_repo=journey_repo,
        ticket_repo=ticket_repo,
        station_repo=station_repo,
        location_repo=location_repo,
        geofence_service=geofence_service,
        integrity_service=integrity_service,
        redis=redis,
        decision_engine=decision_engine,
        fraud_extractor=fraud_extractor,
    )


# --- Phase 7 LOCO Assist Dependencies ---
from app.repositories.assistant_repository import AssistantRepository


def get_assistant_repo(db: AsyncSession = Depends(get_db)) -> AssistantRepository:
    return AssistantRepository(db)



