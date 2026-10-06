from typing import Optional
from fastapi import APIRouter, Depends, Header, Request, status, HTTPException
from app.api.deps import (
    get_current_user,
    get_ticket_service,
    get_payment_repo,
)
from app.models.user import User
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.payment import (
    PaymentVerifyRequest,
    PaymentRead,
)
from app.schemas.ticket import TicketRead
from app.repositories.payment_repository import PaymentRepository
from app.services.ticket_service import TicketService
from app.core.logging import logger

router = APIRouter(prefix="/payments", tags=["Payments"])


@router.post("/verify", response_model=ApiResponse[TicketRead])
async def verify_payment(
    payload: PaymentVerifyRequest,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
    current_user: User = Depends(get_current_user),
    ticket_service: TicketService = Depends(get_ticket_service),
):
    """
    Client payment verification endpoint.
    Verifies cryptographic gateway signature server-side.
    If valid, updates payment status to CAPTURED and triggers ticket issuance.
    """
    logger.info(
        "Payment verification requested by user %s for ticket %s (order: %s)",
        current_user.id,
        payload.ticket_id,
        payload.gateway_order_id,
    )
    success, msg, ticket = await ticket_service.verify_payment(
        ticket_id=payload.ticket_id,
        user_id=current_user.id,
        gateway_payment_id=payload.gateway_payment_id,
        gateway_order_id=payload.gateway_order_id,
        gateway_signature=payload.gateway_signature,
        idempotency_key=idempotency_key,
    )

    if not success or not ticket:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="PAYMENT_VERIFICATION_FAILED", message=msg),
        )

    return ApiResponse(
        success=True,
        message="Payment verified successfully. Ticket issued.",
        data=TicketRead.model_validate(ticket),
    )


@router.post("/webhook", response_model=ApiResponse[dict])
async def payment_webhook(
    request: Request,
    ticket_service: TicketService = Depends(get_ticket_service),
    x_razorpay_signature: Optional[str] = Header(None, alias="X-Razorpay-Signature"),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    """
    Authoritative server-side payment gateway webhook.
    Verifies webhook signature, processes payment.captured or payment.failed,
    updates payment ledger, and issues ticket idempotently.
    """
    raw_body = await request.body()
    signature = x_razorpay_signature or request.headers.get("x-razorpay-signature")

    logger.info("Received payment gateway webhook (size: %s bytes)", len(raw_body))

    success, msg, payment = await ticket_service.process_webhook(
        raw_body=raw_body,
        signature_header=signature,
        idempotency_key=idempotency_key,
    )

    if not success:
        logger.warning("Payment webhook processing failed: %s", msg)
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="WEBHOOK_REJECTED", message=msg),
        )

    return ApiResponse(
        success=True,
        message=msg,
        data={
            "payment_id": payment.id if payment else None,
            "status": payment.status if payment else None,
        },
    )


@router.get("/{payment_id}", response_model=ApiResponse[PaymentRead])
async def get_payment(
    payment_id: str,
    current_user: User = Depends(get_current_user),
    payment_repo: PaymentRepository = Depends(get_payment_repo),
):
    """
    Retrieve payment transaction details.
    Enforces user authorization: users can only view their own payments.
    """
    payment = await payment_repo.get_by_id(payment_id)
    if not payment or payment.user_id != current_user.id:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="NOT_FOUND", message="Payment record not found or access denied."),
        )

    return ApiResponse(
        success=True,
        data=PaymentRead.model_validate(payment),
    )
