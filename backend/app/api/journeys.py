from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from app.api.deps import (
    get_current_user,
    get_journey_service,
    get_journey_repo,
    get_geofence_service,
    get_fraud_event_repo,
    get_location_event_repo,
)
from app.models.user import User
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.journey import (
    JourneyStartRequest,
    JourneyLocationsBatchRequest,
    JourneyCompleteRequest,
    JourneyAbandonRequest,
    GeofenceValidateRequest,
    GeofenceValidationResult,
    JourneyRead,
    JourneyStatusResponse,
    LocationSecuritySummary,
    LocationEvidenceInput,
)
from app.services.journey_service import JourneyService
from app.services.geofence_service import GeofenceService
from app.repositories.journey_repository import JourneyRepository
from app.repositories.fraud_event_repository import FraudEventRepository
from app.repositories.location_event_repository import LocationEventRepository

router = APIRouter(prefix="/journeys", tags=["Journeys & Location Integrity"])


@router.post("/start", response_model=ApiResponse[JourneyRead])
async def start_journey(
    payload: JourneyStartRequest,
    current_user: User = Depends(get_current_user),
    journey_service: JourneyService = Depends(get_journey_service),
):
    """
    Start a server-controlled ticket journey after verifying origin station geofence evidence.
    """
    success, msg, journey = await journey_service.start_journey(
        user_id=current_user.id,
        ticket_id=payload.ticket_id,
        location=payload.location,
        device_id=payload.device_id,
        route_id=payload.route_id,
    )
    if not success or not journey:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="JOURNEY_START_REJECTED", message=msg),
        )

    journey_read = await journey_service.build_journey_read(journey)
    return ApiResponse(
        success=True,
        message=msg,
        data=journey_read,
    )


@router.get("/active", response_model=ApiResponse[Optional[JourneyRead]])
async def get_active_journey(
    current_user: User = Depends(get_current_user),
    journey_repo: JourneyRepository = Depends(get_journey_repo),
    journey_service: JourneyService = Depends(get_journey_service),
):
    """
    Retrieve the active journey for the authenticated commuter, if one exists.
    """
    journey = await journey_repo.get_active_for_user(current_user.id)
    if not journey:
        return ApiResponse(
            success=True,
            message="No active journey in progress.",
            data=None,
        )

    journey_read = await journey_service.build_journey_read(journey)
    return ApiResponse(
        success=True,
        data=journey_read,
    )


@router.post("/geofence/validate", response_model=ApiResponse[GeofenceValidationResult])
async def validate_station_geofence(
    payload: GeofenceValidateRequest,
    current_user: User = Depends(get_current_user),
    geofence_service: GeofenceService = Depends(get_geofence_service),
):
    """
    Pre-flight location verification against a station geofence with uncertainty modeling.
    """
    result = await geofence_service.validate_location_for_station(
        station_id=payload.station_id,
        location=payload.location,
        client_key=current_user.id,
    )
    return ApiResponse(
        success=True,
        data=result,
    )


@router.post("/{journey_id}/location", response_model=ApiResponse[JourneyStatusResponse])
async def submit_journey_location(
    journey_id: str,
    location: LocationEvidenceInput,
    current_user: User = Depends(get_current_user),
    journey_service: JourneyService = Depends(get_journey_service),
):
    """
    Submit real-time location observation for active journey.
    Analyzes physical movement integrity, detects current station context, and monitors route deviation.
    """
    success, msg, journey, signals = await journey_service.process_location(
        journey_id=journey_id,
        user_id=current_user.id,
        location=location,
    )
    if not success or not journey:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="LOCATION_UPDATE_FAILED", message=msg),
        )

    journey_read = await journey_service.build_journey_read(journey)
    return ApiResponse(
        success=True,
        message=msg,
        data=JourneyStatusResponse(
            journey=journey_read,
            active_signals=signals,
            is_route_deviated=journey.security_state == "ROUTE_DEVIATION",
            deviation_details=(
                "Commuter observed away from planned transit corridor"
                if journey.security_state == "ROUTE_DEVIATION"
                else None
            ),
        ),
    )


@router.post("/{journey_id}/locations/batch", response_model=ApiResponse[JourneyStatusResponse])
async def submit_journey_locations_batch(
    journey_id: str,
    payload: JourneyLocationsBatchRequest,
    current_user: User = Depends(get_current_user),
    journey_service: JourneyService = Depends(get_journey_service),
):
    """
    Submit a batched sequence of location observations to minimize client radio overhead.
    """
    success, msg, journey, signals = await journey_service.process_locations_batch(
        journey_id=journey_id,
        user_id=current_user.id,
        locations=payload.locations,
    )
    if not success or not journey:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="LOCATION_BATCH_FAILED", message=msg),
        )

    journey_read = await journey_service.build_journey_read(journey)
    return ApiResponse(
        success=True,
        message=msg,
        data=JourneyStatusResponse(
            journey=journey_read,
            active_signals=signals,
            is_route_deviated=journey.security_state == "ROUTE_DEVIATION",
        ),
    )


@router.get("/{journey_id}", response_model=ApiResponse[JourneyRead])
async def get_journey_by_id(
    journey_id: str,
    current_user: User = Depends(get_current_user),
    journey_repo: JourneyRepository = Depends(get_journey_repo),
    journey_service: JourneyService = Depends(get_journey_service),
):
    """
    Fetch journey details.
    """
    journey = await journey_repo.get_by_id(journey_id)
    if not journey:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="JOURNEY_NOT_FOUND", message="Journey not found."),
        )

    if journey.user_id != current_user.id:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="UNAUTHORIZED", message="Unauthorized to view this journey."),
        )

    journey_read = await journey_service.build_journey_read(journey)
    return ApiResponse(
        success=True,
        data=journey_read,
    )


@router.get("/{journey_id}/status", response_model=ApiResponse[JourneyStatusResponse])
async def get_journey_status(
    journey_id: str,
    current_user: User = Depends(get_current_user),
    journey_repo: JourneyRepository = Depends(get_journey_repo),
    journey_service: JourneyService = Depends(get_journey_service),
):
    """
    Fetch active Journey Guardian status, validated station sequence, and security signals.
    """
    journey = await journey_repo.get_by_id(journey_id)
    if not journey:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="JOURNEY_NOT_FOUND", message="Journey not found."),
        )

    if journey.user_id != current_user.id:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="UNAUTHORIZED", message="Unauthorized to view this journey."),
        )

    journey_read = await journey_service.build_journey_read(journey)
    return ApiResponse(
        success=True,
        data=JourneyStatusResponse(
            journey=journey_read,
            active_signals=[],
            is_route_deviated=journey.security_state == "ROUTE_DEVIATION",
        ),
    )


@router.post("/{journey_id}/complete", response_model=ApiResponse[JourneyRead])
async def complete_journey(
    journey_id: str,
    payload: JourneyCompleteRequest,
    current_user: User = Depends(get_current_user),
    journey_service: JourneyService = Depends(get_journey_service),
):
    """
    Server-controlled journey completion.
    Only completes after validating destination station geofence evidence.
    """
    success, msg, journey = await journey_service.complete_journey(
        journey_id=journey_id,
        user_id=current_user.id,
        location=payload.location,
    )
    if not success or not journey:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="COMPLETION_VALIDATION_FAILED", message=msg),
        )

    journey_read = await journey_service.build_journey_read(journey)
    return ApiResponse(
        success=True,
        message=msg,
        data=journey_read,
    )


@router.post("/{journey_id}/abandon", response_model=ApiResponse[JourneyRead])
async def abandon_journey(
    journey_id: str,
    payload: JourneyAbandonRequest,
    current_user: User = Depends(get_current_user),
    journey_service: JourneyService = Depends(get_journey_service),
):
    """
    Abandon an active journey when commuter exits network or manually cancels.
    """
    success, msg, journey = await journey_service.abandon_journey(
        journey_id=journey_id,
        user_id=current_user.id,
        reason=payload.reason,
    )
    if not success or not journey:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="ABANDON_FAILED", message=msg),
        )

    journey_read = await journey_service.build_journey_read(journey)
    return ApiResponse(
        success=True,
        message=msg,
        data=journey_read,
    )


@router.get("/{journey_id}/security", response_model=ApiResponse[LocationSecuritySummary])
async def get_journey_security_summary(
    journey_id: str,
    current_user: User = Depends(get_current_user),
    journey_repo: JourneyRepository = Depends(get_journey_repo),
    fraud_repo: FraudEventRepository = Depends(get_fraud_event_repo),
):
    """
    Auditable security summary containing risk score, confidence, and recorded fraud events.
    """
    journey = await journey_repo.get_by_id(journey_id)
    if not journey or journey.user_id != current_user.id:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="JOURNEY_NOT_FOUND", message="Journey not found."),
        )

    fraud_events = await fraud_repo.get_for_journey(journey_id)
    return ApiResponse(
        success=True,
        data=LocationSecuritySummary(
            journey_id=journey_id,
            security_state=journey.security_state,
            risk_score=journey.risk_score,
            location_confidence=journey.location_confidence,
            signals_count=len(fraud_events),
            recent_events=[
                {
                    "event_type": fe.event_type,
                    "severity": fe.severity,
                    "confidence": fe.confidence,
                    "created_at": fe.created_at.isoformat() if fe.created_at else None,
                    "metadata": json.loads(fe.metadata_json) if fe.metadata_json else {},
                }
                for fe in fraud_events[:10]
            ],
        ),
    )
