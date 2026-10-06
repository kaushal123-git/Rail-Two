from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Header, HTTPException, status
from app.api.deps import (
    get_current_user,
    get_ticket_service,
    get_ticket_repo,
    get_fraud_decision_engine,
    get_fraud_feature_extractor,
)
from app.services.fraud_decision_engine import FraudDecisionEngine
from app.services.fraud_feature_extractor import FraudFeatureExtractor
from app.models.user import User
from app.models.ticket import TicketStatus
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.ticket import (
    TicketCreateRequest,
    TicketPrepareRequest,
    BookingPreparedResponse,
    TicketRead,
    TicketTransitionRequest,
    TicketCancelRequest,
    TicketQrResponse,
    TicketVerifyRequest,
    TicketVerifyResponse,
)
from app.schemas.fare import FareEstimateRequest, FareBreakdown
from app.schemas.payment import PaymentOrderResponse
from app.repositories.ticket_repository import TicketRepository
from app.services.ticket_service import TicketService
from app.core.logging import logger

router = APIRouter(prefix="/tickets", tags=["Tickets"])


@router.post("", response_model=ApiResponse[TicketRead])
async def create_ticket(
    payload: TicketCreateRequest,
    current_user: User = Depends(get_current_user),
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """
    Create a new railway ticket in CREATED state with server-calculated fare.
    """
    success, msg, ticket = await ticket_service.create_ticket(
        user_id=current_user.id,
        origin_station_id=payload.origin_station_id,
        destination_station_id=payload.destination_station_id,
        journey_type=payload.journey_type,
        ticket_class=payload.ticket_class,
        passenger_count=payload.passenger_count,
    )
    if not success or not ticket:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="TICKET_CREATION_FAILED", message=msg),
        )

    return ApiResponse(
        success=True,
        message="Ticket created successfully.",
        data=TicketRead.model_validate(ticket),
    )


@router.post("/fare", response_model=ApiResponse[FareBreakdown])
async def calculate_fare_estimate(
    payload: FareEstimateRequest,
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """
    Authoritative server fare calculation endpoint (Section 9).
    Calculates exact fare breakdown based on origin, destination, journey type, class, and passengers
    without creating a booking in the database.
    """
    success, msg, fare_breakdown = await ticket_service.estimate_fare(
        origin_station_id=payload.origin_station_id,
        destination_station_id=payload.destination_station_id,
        journey_type=payload.journey_type,
        ticket_class=payload.ticket_class,
        passenger_count=payload.passenger_count,
        duration=payload.duration,
    )
    if not success or not fare_breakdown:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="FARE_CALCULATION_FAILED", message=msg),
        )

    return ApiResponse(
        success=True,
        message="Authoritative fare calculated successfully.",
        data=fare_breakdown,
    )


@router.post("/prepare", response_model=ApiResponse[BookingPreparedResponse])
async def prepare_booking(
    payload: TicketPrepareRequest,
    current_user: User = Depends(get_current_user),
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """
    Authoritative booking preparation endpoint.
    Validates origin and destination stations, passenger count, class,
    calculates server-authoritative fare and returns booking details with payment order readiness.
    """
    logger.info(
        "User %s requested booking preparation: %s -> %s (%s, %s, %s pax)",
        current_user.id,
        payload.origin_station_id,
        payload.destination_station_id,
        payload.journey_type,
        payload.ticket_class,
        payload.passenger_count,
    )
    success, msg, booking_resp = await ticket_service.prepare_booking(
        user_id=current_user.id,
        origin_station_id=payload.origin_station_id,
        destination_station_id=payload.destination_station_id,
        journey_type=payload.journey_type,
        ticket_class=payload.ticket_class,
        passenger_count=payload.passenger_count,
        duration=payload.duration,
    )

    if not success or not booking_resp:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="BOOKING_PREPARATION_FAILED", message=msg),
        )

    return ApiResponse(
        success=True,
        message="Booking prepared successfully with authoritative fare.",
        data=booking_resp,
    )


@router.post("/{ticket_id}/payment", response_model=ApiResponse[PaymentOrderResponse])
async def create_payment_order(
    ticket_id: str,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
    current_user: User = Depends(get_current_user),
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """
    Create a payment gateway order for a prepared booking.
    Verifies ticket ownership and generates server-side gateway order.
    """
    logger.info(
        "User %s initiated payment order creation for ticket %s (idempotency=%s)",
        current_user.id,
        ticket_id,
        idempotency_key,
    )
    success, msg, order_resp = await ticket_service.create_payment_order(
        ticket_id=ticket_id,
        user_id=current_user.id,
        idempotency_key=idempotency_key,
    )

    if not success or not order_resp:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="PAYMENT_ORDER_FAILED", message=msg),
        )

    return ApiResponse(
        success=True,
        message="Payment order created successfully.",
        data=order_resp,
    )


@router.get("/active", response_model=ApiResponse[List[TicketRead]])
async def list_active_tickets(
    current_user: User = Depends(get_current_user),
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """
    Retrieve all currently active and in-journey tickets for the authenticated user.
    Used by Flutter commuter home screen and active journey widgets.
    """
    tickets = await ticket_service.list_active(user_id=current_user.id)
    return ApiResponse(
        success=True,
        data=[TicketRead.model_validate(t) for t in tickets],
    )


@router.get("/history", response_model=ApiResponse[List[TicketRead]])
async def list_ticket_history(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """
    Retrieve completed, cancelled, and expired ticket history with pagination.
    """
    tickets = await ticket_service.list_history(
        user_id=current_user.id,
        skip=skip,
        limit=limit,
    )
    return ApiResponse(
        success=True,
        data=[TicketRead.model_validate(t) for t in tickets],
    )


@router.post("/verify", response_model=ApiResponse[TicketVerifyResponse])
async def verify_ticket_qr(
    payload: TicketVerifyRequest,
    ticket_service: TicketService = Depends(get_ticket_service),
    decision_engine: FraudDecisionEngine = Depends(get_fraud_decision_engine),
    feature_extractor: FraudFeatureExtractor = Depends(get_fraud_feature_extractor),
):
    """
    Backend ticket QR token verification endpoint.
    Used by transit turnstiles / TTE verification terminals to validate cryptographic token,
    journey validity, status, and ML fraud risk decision.
    """
    success, msg, verify_resp = await ticket_service.verify_ticket_qr(
        ticket_id=payload.ticket_id,
        qr_token_id=payload.qr_token_id,
        qr_token=payload.qr_token,
        origin_id=payload.origin_station_id,
        destination_id=payload.destination_station_id,
        location=payload.location,
        device_id=payload.device_id,
        decision_engine=decision_engine,
        feature_extractor=feature_extractor,
    )

    if not success or not verify_resp:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="VERIFICATION_FAILED", message=msg),
        )

    return ApiResponse(
        success=True,
        message="Ticket verification completed.",
        data=verify_resp,
    )


@router.get("", response_model=ApiResponse[List[TicketRead]])
async def list_tickets(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    ticket_status: Optional[str] = Query(None, description="Filter by TicketStatus"),
    current_user: User = Depends(get_current_user),
    ticket_repo: TicketRepository = Depends(get_ticket_repo),
):
    """Retrieve ticket history and active tickets for commuter."""
    tickets = await ticket_repo.list_by_user(
        user_id=current_user.id,
        skip=skip,
        limit=limit,
        status=ticket_status,
    )
    return ApiResponse(
        success=True,
        data=[TicketRead.model_validate(t) for t in tickets],
    )


@router.get("/{ticket_id}", response_model=ApiResponse[TicketRead])
async def get_ticket(
    ticket_id: str,
    current_user: User = Depends(get_current_user),
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """Fetch ticket details and lifecycle audit events. Enforces user ownership."""
    ticket = await ticket_service.get_ticket(ticket_id, current_user.id)
    if not ticket:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="NOT_FOUND", message="Ticket not found or unauthorized."),
        )

    return ApiResponse(
        success=True,
        data=TicketRead.model_validate(ticket),
    )


@router.post("/{ticket_id}/cancel", response_model=ApiResponse[TicketRead])
async def cancel_ticket(
    ticket_id: str,
    payload: Optional[TicketCancelRequest] = None,
    current_user: User = Depends(get_current_user),
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """
    Cancel an issued or active ticket.
    Enforces state machine rules (cannot cancel completed/expired tickets).
    Initiates server-side refund calculation and records audit events.
    """
    reason = payload.reason if payload else "User requested cancellation"
    logger.info("User %s requested cancellation of ticket %s: %s", current_user.id, ticket_id, reason)

    success, msg, cancelled_ticket = await ticket_service.cancel_ticket(
        ticket_id=ticket_id,
        user_id=current_user.id,
        reason=reason,
    )

    if not success or not cancelled_ticket:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="CANCELLATION_FAILED", message=msg),
        )

    return ApiResponse(
        success=True,
        message=msg,
        data=TicketRead.model_validate(cancelled_ticket),
    )


@router.post("/{ticket_id}/transition", response_model=ApiResponse[TicketRead])
async def transition_ticket_state(
    ticket_id: str,
    payload: TicketTransitionRequest,
    current_user: User = Depends(get_current_user),
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """
    Transition ticket to a new state under strict state machine rules.
    Logs transition audit event.
    """
    success, msg, updated = await ticket_service.transition_ticket(
        ticket_id=ticket_id,
        user_id=current_user.id,
        target_status=payload.target_status,
        reason=payload.reason,
    )
    if not success or not updated:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="INVALID_TRANSITION", message=msg),
        )

    return ApiResponse(
        success=True,
        message=msg,
        data=TicketRead.model_validate(updated),
    )


@router.get("/{ticket_id}/qr", response_model=ApiResponse[TicketQrResponse])
async def get_ticket_qr(
    ticket_id: str,
    current_user: User = Depends(get_current_user),
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """
    Generate server-signed dynamic QR payload for active ticket.
    Server timestamps and cryptographic hash prevent client tampering.
    """
    success, msg, qr_dict = await ticket_service.get_ticket_qr(
        ticket_id=ticket_id,
        user_id=current_user.id,
    )
    if not success or not qr_dict:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="QR_UNAVAILABLE", message=msg),
        )

    return ApiResponse(
        success=True,
        message="QR payload generated.",
        data=TicketQrResponse.model_validate(qr_dict),
    )


@router.post("/verify", response_model=ApiResponse[TicketVerifyResponse])
async def verify_ticket(
    payload: TicketVerifyRequest,
    ticket_service: TicketService = Depends(get_ticket_service),
    decision_engine: FraudDecisionEngine = Depends(get_fraud_decision_engine),
    fraud_extractor: FraudFeatureExtractor = Depends(get_fraud_feature_extractor),
):
    """
    Authoritative ticket verification and turnstile QR validation endpoint.
    Combines server-side lifecycle verification with the LOCO Custom ML Fraud Decision Engine.
    """
    success, msg, res = await ticket_service.verify_ticket_qr(
        ticket_id=payload.ticket_id,
        qr_token_id=payload.qr_token_id,
        origin_id=payload.origin_station_id,
        destination_id=payload.destination_station_id,
        qr_token=payload.qr_token,
        location=payload.location,
        device_id=payload.device_id,
        decision_engine=decision_engine,
        feature_extractor=fraud_extractor,
    )
    if not res:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="VERIFICATION_FAILED", message=msg),
        )
    return ApiResponse(
        success=res.is_valid,
        message=msg,
        data=res,
    )

