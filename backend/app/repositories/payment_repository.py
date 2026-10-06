from typing import Optional, List
from datetime import datetime, timezone
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.payment import Payment, PaymentStatus


class PaymentRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_payment(
        self,
        user_id: str,
        ticket_id: str,
        amount: float,
        gateway: str = "TEST",
        gateway_order_id: Optional[str] = None,
        currency: str = "INR",
        status: PaymentStatus = PaymentStatus.CREATED,
    ) -> Payment:
        payment = Payment(
            user_id=user_id,
            ticket_id=ticket_id,
            amount=amount,
            gateway=gateway,
            gateway_order_id=gateway_order_id,
            currency=currency,
            status=status.value if isinstance(status, PaymentStatus) else status,
        )
        self.db.add(payment)
        await self.db.commit()
        await self.db.refresh(payment)
        return payment

    async def get_by_id(self, payment_id: str) -> Optional[Payment]:
        result = await self.db.execute(select(Payment).where(Payment.id == payment_id))
        return result.scalar_one_or_none()

    async def get_by_gateway_order_id(self, gateway_order_id: str) -> Optional[Payment]:
        result = await self.db.execute(select(Payment).where(Payment.gateway_order_id == gateway_order_id))
        return result.scalar_one_or_none()

    async def get_by_ticket_id(self, ticket_id: str) -> List[Payment]:
        result = await self.db.execute(
            select(Payment)
            .where(Payment.ticket_id == ticket_id)
            .order_by(Payment.created_at.desc())
        )
        return list(result.scalars().all())

    async def update_status(
        self,
        payment: Payment,
        status: PaymentStatus,
        gateway_payment_id: Optional[str] = None,
        gateway_signature: Optional[str] = None,
        failure_reason: Optional[str] = None,
        verified_at: Optional[datetime] = None,
    ) -> Payment:
        payment.status = status.value if isinstance(status, PaymentStatus) else status
        if gateway_payment_id:
            payment.gateway_payment_id = gateway_payment_id
        if gateway_signature:
            payment.gateway_signature = gateway_signature
        if failure_reason:
            payment.failure_reason = failure_reason
        if verified_at:
            payment.verified_at = verified_at
        elif status == PaymentStatus.CAPTURED:
            payment.verified_at = datetime.now(timezone.utc)

        await self.db.commit()
        await self.db.refresh(payment)
        return payment
