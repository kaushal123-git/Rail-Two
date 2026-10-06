from typing import Optional
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.models.otp import OtpRequest


class OtpRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(
        self,
        phone_number: str,
        hashed_otp: str,
        expires_at: datetime,
        purpose: str = "LOGIN",
        max_attempts: int = 3,
    ) -> OtpRequest:
        otp_req = OtpRequest(
            phone_number=phone_number,
            hashed_otp=hashed_otp,
            expires_at=expires_at,
            purpose=purpose,
            max_attempts=max_attempts,
            attempts=0,
        )
        self.db.add(otp_req)
        await self.db.flush()
        await self.db.refresh(otp_req)
        return otp_req

    async def get_latest_active(self, phone_number: str, purpose: str = "LOGIN") -> Optional[OtpRequest]:
        now = datetime.now(timezone.utc)
        result = await self.db.execute(
            select(OtpRequest)
            .where(
                OtpRequest.phone_number == phone_number,
                OtpRequest.purpose == purpose,
                OtpRequest.consumed_at.is_(None),
                OtpRequest.expires_at > now,
            )
            .order_by(OtpRequest.created_at.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def increment_attempts(self, otp_id: str) -> int:
        otp_req = await self.db.get(OtpRequest, otp_id)
        if otp_req:
            otp_req.attempts += 1
            await self.db.flush()
            return otp_req.attempts
        return 0

    async def consume(self, otp_id: str) -> None:
        otp_req = await self.db.get(OtpRequest, otp_id)
        if otp_req:
            otp_req.consumed_at = datetime.now(timezone.utc)
            await self.db.flush()

    async def invalidate_previous(self, phone_number: str, purpose: str = "LOGIN") -> None:
        now = datetime.now(timezone.utc)
        stmt = (
            update(OtpRequest)
            .where(
                OtpRequest.phone_number == phone_number,
                OtpRequest.purpose == purpose,
                OtpRequest.consumed_at.is_(None),
            )
            .values(consumed_at=now)
        )
        await self.db.execute(stmt)
        await self.db.flush()
