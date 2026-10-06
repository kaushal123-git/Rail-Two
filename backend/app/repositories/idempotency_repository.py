from typing import Optional
from datetime import datetime, timezone, timedelta
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.idempotency import IdempotencyKey


class IdempotencyRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_key(self, key: str) -> Optional[IdempotencyKey]:
        result = await self.db.execute(select(IdempotencyKey).where(IdempotencyKey.key == key))
        return result.scalar_one_or_none()

    async def create_key(
        self,
        key: str,
        user_id: Optional[str] = None,
        request_path: str = "",
        request_hash: str = "",
        expires_in_hours: int = 24,
    ) -> IdempotencyKey:
        now = datetime.now(timezone.utc)
        record = IdempotencyKey(
            key=key,
            user_id=user_id,
            request_path=request_path,
            request_hash=request_hash or "nohash",
            status="PROCESSING",
            created_at=now,
            expires_at=now + timedelta(hours=expires_in_hours),
        )
        self.db.add(record)
        await self.db.commit()
        await self.db.refresh(record)
        return record

    async def complete_key(
        self,
        key: str,
        response_status_code: int = 200,
        response_body: str = "",
        response_code: Optional[int] = None,
    ) -> Optional[IdempotencyKey]:
        record = await self.get_key(key)
        if record:
            record.status = "COMPLETED"
            record.response_status_code = response_code if response_code is not None else response_status_code
            record.response_body = response_body
            await self.db.commit()
            await self.db.refresh(record)
        return record

    async def fail_key(self, key: str) -> Optional[IdempotencyKey]:
        record = await self.get_key(key)
        if record:
            record.status = "FAILED"
            await self.db.commit()
            await self.db.refresh(record)
        return record
