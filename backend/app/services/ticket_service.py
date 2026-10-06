import json
import hmac
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Tuple, Any
from app.core.config import settings
from app.models.ticket import Ticket, TicketStatus
from app.models.ticket_event import TicketEventType
from app.models.payment import Payment, PaymentStatus
from app.repositories.ticket_repository import TicketRepository
from app.repositories.station_repository import StationRepository, haversine_distance_km
from app.repositories.payment_repository import PaymentRepository
from app.repositories.idempotency_repository import IdempotencyRepository
from app.services.fare_service import FareService
from app.services.payment_gateway import PaymentGateway, get_payment_gateway
from app.services.railway_provider import RailwayProvider, get_railway_provider
from app.schemas.ticket import BookingPreparedResponse, TicketVerifyResponse
from app.schemas.payment import PaymentOrderResponse


ALLOWED_TRANSITIONS: Dict[TicketStatus, List[TicketStatus]] = {
    TicketStatus.CREATED: [TicketStatus.PAYMENT_PENDING, TicketStatus.CANCELLED],
    TicketStatus.PAYMENT_PENDING: [
        TicketStatus.PAYMENT_CONFIRMED,
        TicketStatus.CANCELLED,
        TicketStatus.ISSUANCE_FAILED,
    ],
    TicketStatus.PAYMENT_CONFIRMED: [TicketStatus.ISSUING, TicketStatus.ISSUANCE_FAILED],
    TicketStatus.ISSUING: [TicketStatus.ISSUED, TicketStatus.ISSUANCE_FAILED],
    TicketStatus.ISSUED: [TicketStatus.ACTIVE, TicketStatus.CANCELLED, TicketStatus.EXPIRED],
    TicketStatus.ACTIVE: [
        TicketStatus.IN_JOURNEY,
        TicketStatus.COMPLETED,
        TicketStatus.CANCELLED,
        TicketStatus.EXPIRED,
        TicketStatus.FRAUD_BLOCKED,
    ],
    TicketStatus.IN_JOURNEY: [
        TicketStatus.COMPLETED,
        TicketStatus.EXPIRED,
        TicketStatus.FRAUD_BLOCKED,
    ],
    TicketStatus.COMPLETED: [],
    TicketStatus.CANCELLED: [],
    TicketStatus.EXPIRED: [],
    TicketStatus.FRAUD_BLOCKED: [],
    TicketStatus.ISSUANCE_FAILED: [],
}


class TicketService:
    def __init__(
        self,
        ticket_repo: TicketRepository,
        station_repo: StationRepository,
        payment_repo: Optional[PaymentRepository] = None,
        idempotency_repo: Optional[IdempotencyRepository] = None,
        fare_service: Optional[FareService] = None,
        payment_gateway: Optional[PaymentGateway] = None,
        railway_provider: Optional[RailwayProvider] = None,
        redis=None,
    ):
        self.ticket_repo = ticket_repo
        self.station_repo = station_repo
        self.payment_repo = payment_repo
        self.idempotency_repo = idempotency_repo
        self.fare_service = fare_service
        self.payment_gateway = payment_gateway or get_payment_gateway()
        self.railway_provider = railway_provider or get_railway_provider()
        self.redis = redis

    def validate_transition(self, current_status: TicketStatus, target_status: TicketStatus) -> bool:
        allowed = ALLOWED_TRANSITIONS.get(current_status, [])
        return target_status in allowed

    def calculate_fare(
        self,
        distance_km: float,
        ticket_class: str = "SECOND",
        journey_type: str = "SINGLE",
        passenger_count: int = 1,
    ) -> float:
        if distance_km <= 10:
            base = 5.0
        elif distance_km <= 20:
            base = 10.0
        elif distance_km <= 35:
            base = 15.0
        elif distance_km <= 50:
            base = 20.0
        elif distance_km <= 70:
            base = 25.0
        else:
            base = 30.0

        if ticket_class.upper() == "FIRST":
            multiplier = 7.0
            base = max(50.0, base * multiplier)
        elif ticket_class.upper() == "AC":
            multiplier = 9.0
            base = max(65.0, base * multiplier)

        type_mult = 2.0 if journey_type.upper() == "RETURN" else 1.0
        return float(round(base * type_mult * passenger_count, 2))

    async def estimate_fare(
        self,
        origin_station_id: str,
        destination_station_id: str,
        journey_type: str = "SINGLE",
        ticket_class: str = "SECOND",
        passenger_count: int = 1,
        duration: Optional[str] = "SINGLE",
    ) -> Tuple[bool, str, Optional[FareBreakdown]]:
        """Authoritatively calculate fare breakdown without creating a booking."""
        if origin_station_id == destination_station_id:
            return False, "Origin and destination stations cannot be identical.", None

        origin = await self.station_repo.get_by_id(origin_station_id)
        if not origin and hasattr(self.station_repo, "get_by_code"):
            origin = await self.station_repo.get_by_code(origin_station_id)
        dest = await self.station_repo.get_by_id(destination_station_id)
        if not dest and hasattr(self.station_repo, "get_by_code"):
            dest = await self.station_repo.get_by_code(destination_station_id)
        if not origin or not dest:
            return False, "Origin or destination station not found.", None

        if self.fare_service:
            breakdown = await self.fare_service.calculate_fare(
                origin=origin,
                destination=dest,
                journey_type=journey_type,
                ticket_class=ticket_class,
                passenger_count=passenger_count,
                duration=duration,
            )
            return True, "Fare calculated successfully.", breakdown

        dist = haversine_distance_km(origin.latitude, origin.longitude, dest.latitude, dest.longitude)
        total_fare = self.calculate_fare(dist, ticket_class, journey_type, passenger_count)
        from app.schemas.fare import FareBreakdown
        breakdown = FareBreakdown(
            base_fare=total_fare,
            distance_km=round(dist, 2),
            discount=0.0,
            tax=0.0,
            total_fare=total_fare,
            currency="INR",
            fare_rule_version="v1.0",
        )
        return True, "Fare calculated successfully.", breakdown

    async def prepare_booking(
        self,
        user_id: str,
        origin_station_id: str,
        destination_station_id: str,
        journey_type: str = "SINGLE",
        ticket_class: str = "SECOND",
        passenger_count: int = 1,
        duration: Optional[str] = "SINGLE",
        idempotency_key: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[BookingPreparedResponse]]:
        """Authoritatively validate stations and calculate tariff, creating a pending booking."""
        if origin_station_id == destination_station_id:
            return False, "Origin and destination stations cannot be identical.", None

        origin = await self.station_repo.get_by_id(origin_station_id)
        if not origin and hasattr(self.station_repo, "get_by_code"):
            origin = await self.station_repo.get_by_code(origin_station_id)
        dest = await self.station_repo.get_by_id(destination_station_id)
        if not dest and hasattr(self.station_repo, "get_by_code"):
            dest = await self.station_repo.get_by_code(destination_station_id)
        if not origin or not dest:
            return False, "Origin or destination station not found.", None

        # Check idempotency
        if idempotency_key and self.idempotency_repo:
            existing = await self.idempotency_repo.get_key(idempotency_key)
            if existing and existing.status == "COMPLETED" and existing.response_body:
                data = json.loads(existing.response_body)
                return True, "Retrieved existing booking.", BookingPreparedResponse(**data)

        if self.fare_service:
            fare_breakdown = await self.fare_service.calculate_fare(
                origin=origin,
                destination=dest,
                journey_type=journey_type,
                ticket_class=ticket_class,
                passenger_count=passenger_count,
                duration=duration,
            )
            total_fare = fare_breakdown.total_fare
        else:
            dist = haversine_distance_km(origin.latitude, origin.longitude, dest.latitude, dest.longitude)
            total_fare = self.calculate_fare(dist, ticket_class, journey_type, passenger_count)
            from app.schemas.fare import FareBreakdown
            fare_breakdown = FareBreakdown(
                base_fare=total_fare,
                distance_km=round(dist, 2),
                discount=0.0,
                tax=0.0,
                total_fare=total_fare,
                currency="INR",
                fare_rule_version="v1.0",
            )

        ticket = await self.ticket_repo.create_ticket(
            user_id=user_id,
            origin_station_id=origin.id,
            destination_station_id=dest.id,
            fare=total_fare,
            journey_type=journey_type,
            ticket_class=ticket_class,
            passenger_count=passenger_count,
            currency="INR",
        )

        now = datetime.now(timezone.utc)
        expires_at = now + timedelta(minutes=settings.BOOKING_EXPIRATION_MINUTES)

        # Store pending expiration in Redis (Section 22)
        if self.redis:
            try:
                await self.redis.set(f"booking:pending:{ticket.id}", "1", ex=settings.BOOKING_EXPIRATION_MINUTES * 60)
            except Exception:
                pass

        resp = BookingPreparedResponse(
            booking_id=ticket.id,
            ticket_id=ticket.id,
            fare_breakdown=fare_breakdown,
            currency="INR",
            status="CREATED",
            payment_required=True,
            expires_at=expires_at,
        )

        if idempotency_key and self.idempotency_repo:
            await self.idempotency_repo.create_key(
                key=idempotency_key,
                user_id=user_id,
                request_path="/tickets/prepare",
                request_hash=hashlib.sha256(f"{origin_station_id}:{destination_station_id}".encode()).hexdigest(),
            )
            await self.idempotency_repo.complete_key(
                key=idempotency_key,
                response_status_code=201,
                response_body=resp.model_dump_json(),
            )

        return True, "Booking prepared. Please proceed to payment.", resp

    async def create_payment_order(
        self,
        ticket_id: str,
        user_id: str,
        payment_method: str = "UPI",
        idempotency_key: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[PaymentOrderResponse]]:
        """Create a payment gateway order for a prepared booking."""
        ticket = await self.ticket_repo.get_by_id(ticket_id)
        if not ticket or ticket.user_id != user_id:
            return False, "Booking not found or unauthorized.", None

        # Check booking expiration (Section 21, 22)
        now = datetime.now(timezone.utc)
        created_at = ticket.created_at
        if created_at:
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
            if created_at + timedelta(minutes=settings.BOOKING_EXPIRATION_MINUTES) < now:
                ticket.ticket_status = TicketStatus.EXPIRED.value
                await self.ticket_repo.update_status(ticket, TicketStatus.EXPIRED, "BOOKING_EXPIRED", {"reason": "Booking payment window expired"})
                return False, "Booking has expired. Please create a new booking.", None

        if ticket.ticket_status not in [TicketStatus.CREATED.value, TicketStatus.PAYMENT_PENDING.value]:
            return False, f"Cannot pay for ticket with status {ticket.ticket_status}.", None

        # Check idempotency key first
        if idempotency_key and self.idempotency_repo:
            existing_key = await self.idempotency_repo.get_key(idempotency_key)
            if existing_key and existing_key.status == "COMPLETED" and existing_key.response_body:
                cached_dict = json.loads(existing_key.response_body)
                return True, "Payment order retrieved from existing key.", PaymentOrderResponse(**cached_dict)

        # Check existing captured payment to prevent double charge or return existing pending order
        if self.payment_repo:
            existing_payments = await self.payment_repo.get_by_ticket_id(ticket_id)
            for p in existing_payments:
                if p.status == PaymentStatus.CAPTURED.value:
                    return False, "This booking has already been paid and confirmed.", None
                if p.status == PaymentStatus.PENDING.value and p.gateway_order_id:
                    resp = PaymentOrderResponse(
                        payment_id=p.id,
                        ticket_id=ticket.id,
                        gateway=p.gateway,
                        gateway_order_id=p.gateway_order_id,
                        amount=p.amount,
                        currency=p.currency,
                        status="PENDING",
                        key_id=getattr(self.payment_gateway, "key_id", None),
                    )
                    if idempotency_key and self.idempotency_repo:
                        await self.idempotency_repo.create_key(
                            key=idempotency_key,
                            user_id=user_id,
                            request_path=f"/tickets/{ticket_id}/payment",
                        )
                        await self.idempotency_repo.complete_key(
                            key=idempotency_key,
                            response_code=200,
                            response_body=json.dumps(resp.model_dump()),
                        )
                    return True, "Active payment order retrieved.", resp

        order_data = await self.payment_gateway.create_order(
            amount=ticket.fare,
            currency=ticket.currency or "INR",
            receipt=f"rcpt_{ticket.id[:8]}",
            notes={"ticket_id": ticket.id, "user_id": user_id},
        )

        payment = None
        if self.payment_repo:
            payment = await self.payment_repo.create_payment(
                user_id=user_id,
                ticket_id=ticket.id,
                amount=ticket.fare,
                gateway=settings.PAYMENT_GATEWAY_PROVIDER.upper(),
                gateway_order_id=order_data["gateway_order_id"],
                currency=ticket.currency or "INR",
                status=PaymentStatus.PENDING,
            )

        # Transition ticket status to PAYMENT_PENDING
        await self.ticket_repo.update_status(
            ticket,
            TicketStatus.PAYMENT_PENDING,
            TicketEventType.PAYMENT_ORDER_CREATED.value,
            {"gateway_order_id": order_data["gateway_order_id"], "amount": ticket.fare},
        )

        resp = PaymentOrderResponse(
            payment_id=payment.id if payment else f"pay_{ticket.id[:8]}",
            ticket_id=ticket.id,
            gateway=settings.PAYMENT_GATEWAY_PROVIDER.upper(),
            gateway_order_id=order_data["gateway_order_id"],
            amount=ticket.fare,
            currency=ticket.currency or "INR",
            status="PENDING",
            key_id=order_data.get("key_id"),
            notes=order_data.get("notes"),
        )

        if idempotency_key and self.idempotency_repo:
            await self.idempotency_repo.create_key(
                key=idempotency_key,
                user_id=user_id,
                request_path=f"/tickets/{ticket_id}/payment",
            )
            await self.idempotency_repo.complete_key(
                key=idempotency_key,
                response_code=200,
                response_body=json.dumps(resp.model_dump()),
            )

        return True, "Payment order created successfully.", resp

    async def verify_payment(
        self,
        user_id: str,
        gateway_order_id: str,
        gateway_payment_id: str,
        gateway_signature: str,
        payment_id: Optional[str] = None,
        ticket_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[Ticket]]:
        """Verify client-submitted payment signature and issue ticket upon confirmation."""
        if not self.payment_repo:
            return False, "Payment repository unavailable.", None

        payment = None
        if payment_id:
            payment = await self.payment_repo.get_by_id(payment_id)
        if not payment and gateway_order_id:
            payment = await self.payment_repo.get_by_gateway_order_id(gateway_order_id)
        if not payment and ticket_id:
            existing_payments = await self.payment_repo.get_by_ticket_id(ticket_id)
            if existing_payments:
                payment = existing_payments[-1]

        if not payment or payment.user_id != user_id:
            return False, "Payment record not found or unauthorized.", None

        if payment.status == PaymentStatus.CAPTURED.value:
            # Idempotent response
            ticket = await self.ticket_repo.get_by_id(payment.ticket_id)
            return True, "Payment already verified.", ticket

        is_valid = await self.payment_gateway.verify_signature(
            gateway_order_id=gateway_order_id,
            gateway_payment_id=gateway_payment_id,
            gateway_signature=gateway_signature,
        )

        ticket = await self.ticket_repo.get_by_id(payment.ticket_id)
        if not ticket:
            return False, "Associated booking not found.", None

        # Check booking expiration (Section 21, 22)
        now = datetime.now(timezone.utc)
        created_at = ticket.created_at
        if created_at:
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
            if created_at + timedelta(minutes=settings.BOOKING_EXPIRATION_MINUTES) < now:
                ticket.ticket_status = TicketStatus.EXPIRED.value
                await self.ticket_repo.update_status(ticket, TicketStatus.EXPIRED, "BOOKING_EXPIRED", {"reason": "Booking payment window expired"})
                return False, "Booking has expired. Payment cannot be verified.", None

        if not is_valid:
            await self.payment_repo.update_status(
                payment,
                PaymentStatus.FAILED,
                gateway_payment_id=gateway_payment_id,
                gateway_signature=gateway_signature,
                failure_reason="Invalid cryptographic gateway signature.",
            )
            await self.ticket_repo.record_event(
                ticket.id,
                TicketEventType.PAYMENT_FAILED.value,
                {"gateway_order_id": gateway_order_id, "reason": "Invalid signature"},
            )
            return False, "Payment signature verification failed.", None

        # Success: update payment to CAPTURED
        await self.payment_repo.update_status(
            payment,
            PaymentStatus.CAPTURED,
            gateway_payment_id=gateway_payment_id,
            gateway_signature=gateway_signature,
        )

        ticket.payment_status = "CONFIRMED"
        ticket.issued_at = now
        ticket.valid_from = now
        if ticket.journey_type == "SEASON":
            ticket.valid_until = now + timedelta(days=30)
        elif ticket.journey_type == "RETURN":
            ticket.valid_until = now + timedelta(hours=24)
        else:
            ticket.valid_until = now + timedelta(hours=3)

        # Call railway provider abstraction
        provider_res = await self.railway_provider.create_ticket({
            "ticket_id": ticket.id,
            "origin_code": ticket.origin_station.code if ticket.origin_station else "ORIG",
            "destination_code": ticket.destination_station.code if ticket.destination_station else "DEST",
            "fare": ticket.fare,
        })
        ticket.provider = provider_res.get("provider", "LOCO_CORE")
        ticket.provider_ticket_id = provider_res.get("provider_ticket_id") or f"LOCO-{ticket.id[:8].upper()}"
        ticket.qr_token_id = self._generate_qr_token(ticket)

        if self.redis:
            try:
                await self.redis.delete(f"booking:pending:{ticket.id}")
            except Exception:
                pass

        updated_ticket = await self.ticket_repo.update_status(
            ticket,
            TicketStatus.ISSUED,
            TicketEventType.TICKET_ISSUED.value,
            {
                "payment_id": payment.id,
                "gateway_payment_id": gateway_payment_id,
                "provider": ticket.provider,
                "provider_ticket_id": ticket.provider_ticket_id,
            },
        )

        return True, "Payment verified and ticket successfully issued.", updated_ticket

    async def get_ticket(self, ticket_id: str, user_id: str) -> Optional[Ticket]:
        """Retrieve ticket ensuring user ownership."""
        ticket = await self.ticket_repo.get_by_id(ticket_id)
        if not ticket or ticket.user_id != user_id:
            return None
        return ticket

    async def list_active(self, user_id: str) -> List[Ticket]:
        """Retrieve active and in-journey tickets for user."""
        return await self.ticket_repo.list_active_by_user(user_id)

    async def list_history(self, user_id: str, skip: int = 0, limit: int = 50) -> List[Ticket]:
        """Retrieve completed, cancelled, and expired tickets with pagination."""
        return await self.ticket_repo.list_history_by_user(user_id=user_id, skip=skip, limit=limit)

    async def process_webhook(
        self,
        raw_body: bytes,
        signature_header: str,
        event_data: Optional[Dict[str, Any]] = None,
        idempotency_key: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[Payment]]:
        """Process authoritative payment gateway webhook with signature validation and idempotency."""
        is_valid = await self.payment_gateway.verify_webhook_signature(
            raw_body=raw_body,
            signature_header=signature_header,
        )
        if not is_valid:
            return False, "Invalid webhook signature.", None

        if event_data is None:
            try:
                event_data = json.loads(raw_body.decode("utf-8"))
            except Exception:
                event_data = {}

        event = event_data.get("event", "")
        payload = event_data.get("payload", {})
        order_entity = payload.get("order", {}).get("entity", {})
        payment_entity = payload.get("payment", {}).get("entity", {})
        gateway_order_id = order_entity.get("id") or payment_entity.get("order_id")

        if not gateway_order_id or not self.payment_repo:
            return True, "Webhook ignored: No order ID found.", None

        payment = await self.payment_repo.get_by_gateway_order_id(gateway_order_id)
        if not payment:
            return True, "Webhook ignored: Order not found in database.", None

        if event in ["order.paid", "payment.captured"]:
            if payment.status == PaymentStatus.CAPTURED.value:
                return True, "Idempotent: Event already processed.", payment

            ticket = await self.ticket_repo.get_by_id(payment.ticket_id)
            if ticket:
                payment = await self.payment_repo.update_status(
                    payment,
                    PaymentStatus.CAPTURED,
                    gateway_payment_id=payment_entity.get("id"),
                )
                now = datetime.now(timezone.utc)
                ticket.payment_status = "CONFIRMED"
                ticket.issued_at = now
                ticket.valid_from = now
                ticket.valid_until = now + timedelta(hours=3)
                ticket.qr_token_id = self._generate_qr_token(ticket)
                await self.ticket_repo.update_status(
                    ticket,
                    TicketStatus.ISSUED,
                    TicketEventType.TICKET_ISSUED.value,
                    {"source": "gateway_webhook", "event": event},
                )
            return True, "Webhook processed: Ticket issued.", payment

        elif event in ["payment.failed"]:
            payment = await self.payment_repo.update_status(
                payment,
                PaymentStatus.FAILED,
                failure_reason=payment_entity.get("error_description", "Payment failed at gateway"),
            )
            return True, "Webhook processed: Payment marked failed.", payment

        return True, f"Webhook event {event} acknowledged.", payment


    async def cancel_ticket(
        self,
        ticket_id: str,
        user_id: str,
        reason: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[Ticket]]:
        """Validate ticket state and cancel eligible ticket with refund processing."""
        ticket = await self.ticket_repo.get_by_id(ticket_id)
        if not ticket or ticket.user_id != user_id:
            return False, "Ticket not found or unauthorized.", None

        current = TicketStatus(ticket.ticket_status)
        if current not in [TicketStatus.ISSUED, TicketStatus.ACTIVE]:
            return False, f"Ticket in status {current.value} cannot be cancelled.", None

        now = datetime.now(timezone.utc)
        valid_until = ticket.valid_until
        if valid_until is not None:
            if valid_until.tzinfo is None:
                valid_until = valid_until.replace(tzinfo=timezone.utc)
            if valid_until < now:
                return False, "Expired tickets cannot be cancelled.", None

        # Standard Mumbai Suburban Railway clerkage refund policy (10% clerkage charge)
        clerkage = 5.0
        refund_amount = max(0.0, ticket.fare - clerkage)

        updated_ticket = await self.ticket_repo.update_status(
            ticket,
            TicketStatus.CANCELLED,
            TicketEventType.TICKET_CANCELLED.value,
            {
                "reason": reason or "User requested cancellation",
                "refund_amount": refund_amount,
                "clerkage_fee": clerkage,
            },
        )
        return True, f"Ticket cancelled successfully. Refund of ₹{refund_amount} initiated.", updated_ticket

    def _generate_qr_token(self, ticket: Ticket) -> str:
        """Generate server-signed HMAC QR token."""
        raw_payload = f"{ticket.id}:{ticket.user_id}:{ticket.origin_station_id}:{ticket.destination_station_id}:{int(ticket.valid_until.timestamp() if ticket.valid_until else 0)}"
        sig = hmac.new(settings.JWT_SECRET_KEY.encode("utf-8"), raw_payload.encode("utf-8"), hashlib.sha256).hexdigest()[:16]
        return f"LOCOQR:{ticket.id[:8]}:{sig}"

    async def get_ticket_qr(self, ticket_id: str, user_id: str) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
        """Fetch secure QR payload for active ticket."""
        ticket = await self.ticket_repo.get_by_id(ticket_id)
        if not ticket or ticket.user_id != user_id:
            return False, "Ticket not found or unauthorized.", None

        if ticket.ticket_status not in [TicketStatus.ISSUED.value, TicketStatus.ACTIVE.value, TicketStatus.IN_JOURNEY.value]:
            return False, f"QR code is not active for ticket with status {ticket.ticket_status}.", None

        now = datetime.now(timezone.utc)
        valid_until = ticket.valid_until
        if valid_until is not None:
            if valid_until.tzinfo is None:
                valid_until = valid_until.replace(tzinfo=timezone.utc)
            if valid_until < now:
                return False, "Ticket has expired.", None

        qr_payload = json.dumps({
            "ticket_id": ticket.id,
            "provider_ticket_id": ticket.provider_ticket_id or f"LOCO-{ticket.id[:8]}",
            "origin": ticket.origin_station.name if ticket.origin_station else ticket.origin_station_id,
            "destination": ticket.destination_station.name if ticket.destination_station else ticket.destination_station_id,
            "fare": ticket.fare,
            "class": ticket.ticket_class,
            "valid_until": ticket.valid_until.isoformat() if ticket.valid_until else None,
            "server_timestamp": now.isoformat(),
        })

        return True, "QR payload generated.", {
            "ticket_id": ticket.id,
            "qr_token_id": ticket.qr_token_id or self._generate_qr_token(ticket),
            "qr_payload": qr_payload,
            "valid_from": ticket.valid_from,
            "valid_until": ticket.valid_until,
            "is_valid": True,
        }

    async def verify_ticket_qr(
        self,
        ticket_id: Optional[str] = None,
        qr_token_id: Optional[str] = None,
        origin_id: Optional[str] = None,
        destination_id: Optional[str] = None,
        qr_token: Optional[str] = None,
        location: Optional[Any] = None,
        device_id: Optional[str] = None,
        decision_engine: Optional[Any] = None,
        feature_extractor: Optional[Any] = None,
    ) -> Tuple[bool, str, Optional[TicketVerifyResponse]]:
        """Section 27: Verify server-issued QR token, ticket validity, and ML fraud decision."""
        token = qr_token_id or qr_token
        tid = ticket_id
        if not tid and token and ":" in token:
            parts = token.split(":")
            if len(parts) >= 2:
                tid = parts[1]

        if not tid:
            return False, "Missing ticket identifier or token.", None

        ticket = await self.ticket_repo.get_by_id(tid)
        if not ticket:
            return False, "Ticket not found in LOCO registry.", TicketVerifyResponse(
                is_valid=False,
                message="Ticket not found.",
            )

        # Check status
        if ticket.ticket_status not in [TicketStatus.ISSUED.value, TicketStatus.ACTIVE.value, TicketStatus.IN_JOURNEY.value]:
            return True, f"Ticket is {ticket.ticket_status}.", TicketVerifyResponse(
                is_valid=False,
                ticket_id=ticket.id,
                status=ticket.ticket_status,
                message=f"Ticket invalid: status is {ticket.ticket_status}",
            )

        # Check expiration
        now = datetime.now(timezone.utc)
        valid_until = ticket.valid_until
        if valid_until:
            if valid_until.tzinfo is None:
                valid_until = valid_until.replace(tzinfo=timezone.utc)
            if valid_until < now:
                return True, "Ticket expired.", TicketVerifyResponse(
                    is_valid=False,
                    ticket_id=ticket.id,
                    status="EXPIRED",
                    message="Ticket has expired.",
                )

        # Evaluate ML Fraud Decision Engine if available
        fraud_risk = 0.0
        fraud_decision_str = "ALLOW"
        fraud_risk_state_str = "LOW_RISK"

        if decision_engine and feature_extractor:
            try:
                vector, conf = await feature_extractor.extract_features(
                    user_id=ticket.user_id,
                    ticket_id=ticket.id,
                    device_id=device_id,
                    current_location=location,
                )
                decision, prediction = await decision_engine.evaluate_decision(
                    user_id=ticket.user_id,
                    feature_vector=vector,
                    ticket=ticket,
                    context_action="TICKET_VERIFY",
                )
                fraud_risk = prediction.risk_score
                fraud_decision_str = decision.decision
                fraud_risk_state_str = decision.risk_state

                if decision.decision in ["BLOCK", "RESTRICT"]:
                    return True, decision.reason, TicketVerifyResponse(
                        is_valid=False,
                        ticket_id=ticket.id,
                        status="FRAUD_BLOCKED",
                        origin_station=ticket.origin_station.name if ticket.origin_station else ticket.origin_station_id,
                        destination_station=ticket.destination_station.name if ticket.destination_station else ticket.destination_station_id,
                        valid_until=ticket.valid_until,
                        message=f"Validation denied: {decision.reason}",
                        fraud_risk_score=fraud_risk,
                        fraud_decision=fraud_decision_str,
                        fraud_risk_state=fraud_risk_state_str,
                    )
                elif decision.decision == "CHALLENGE":
                    return True, decision.reason, TicketVerifyResponse(
                        is_valid=False,
                        ticket_id=ticket.id,
                        status=ticket.ticket_status,
                        origin_station=ticket.origin_station.name if ticket.origin_station else ticket.origin_station_id,
                        destination_station=ticket.destination_station.name if ticket.destination_station else ticket.destination_station_id,
                        valid_until=ticket.valid_until,
                        message=f"Verification challenge required: {decision.reason}",
                        fraud_risk_score=fraud_risk,
                        fraud_decision=fraud_decision_str,
                        fraud_risk_state=fraud_risk_state_str,
                    )
            except Exception as e:
                logger.warning("Fraud decision evaluation during ticket verify failed gracefully: %s", str(e))

        return True, "Ticket verified successfully.", TicketVerifyResponse(
            is_valid=True,
            ticket_id=ticket.id,
            status=ticket.ticket_status,
            origin_station=ticket.origin_station.name if ticket.origin_station else ticket.origin_station_id,
            destination_station=ticket.destination_station.name if ticket.destination_station else ticket.destination_station_id,
            valid_until=ticket.valid_until,
            message="Verified valid LOCO transit digital ticket.",
            fraud_risk_score=fraud_risk,
            fraud_decision=fraud_decision_str,
            fraud_risk_state=fraud_risk_state_str,
        )

    async def transition_ticket(
        self,
        ticket_id: str,
        user_id: str,
        target_status: TicketStatus,
        reason: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[Ticket]]:
        ticket = await self.ticket_repo.get_by_id(ticket_id)
        if not ticket:
            return False, "Ticket not found.", None

        if ticket.user_id != user_id:
            return False, "Unauthorized: You do not own this ticket.", None

        current = TicketStatus(ticket.ticket_status)
        if not self.validate_transition(current, target_status):
            return (
                False,
                f"Invalid transition from {current.value} to {target_status.value}.",
                None,
            )

        now = datetime.now(timezone.utc)
        if target_status == TicketStatus.ISSUED:
            ticket.issued_at = now
            ticket.valid_from = now
            ticket.valid_until = now + timedelta(hours=3)
            ticket.provider_ticket_id = f"LOCO-{ticket.id[:8].upper()}"
            ticket.qr_token_id = self._generate_qr_token(ticket)

        event_name = f"TRANSITION_TO_{target_status.value}"
        meta = {"previous_status": current.value, "reason": reason}
        updated_ticket = await self.ticket_repo.update_status(ticket, target_status, event_name, meta)

        return True, f"Ticket transitioned to {target_status.value}.", updated_ticket

    async def create_ticket(
        self,
        user_id: str,
        origin_station_id: str,
        destination_station_id: str,
        journey_type: str = "SINGLE",
        ticket_class: str = "SECOND",
        passenger_count: int = 1,
    ) -> Tuple[bool, str, Optional[Ticket]]:
        """Validate stations, calculate fare, and issue initial CREATED ticket."""
        if origin_station_id == destination_station_id:
            return False, "Origin and destination stations cannot be identical.", None

        origin = await self.station_repo.get_by_id(origin_station_id)
        dest = await self.station_repo.get_by_id(destination_station_id)
        if not origin or not dest:
            return False, "Origin or destination station not found.", None

        distance = haversine_distance_km(origin.latitude, origin.longitude, dest.latitude, dest.longitude)
        fare = self.calculate_fare(
            distance_km=distance,
            ticket_class=ticket_class,
            journey_type=journey_type,
            passenger_count=passenger_count,
        )

        ticket = await self.ticket_repo.create_ticket(
            user_id=user_id,
            origin_station_id=origin_station_id,
            destination_station_id=destination_station_id,
            fare=fare,
            journey_type=journey_type,
            ticket_class=ticket_class,
            passenger_count=passenger_count,
        )

        return True, "Ticket created successfully.", ticket
