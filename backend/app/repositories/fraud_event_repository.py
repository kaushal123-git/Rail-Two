from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.fraud_event import FraudEvent


class FraudEventRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, event: FraudEvent) -> FraudEvent:
        self.db.add(event)
        await self.db.flush()
        return event

    async def get_for_journey(self, journey_id: str) -> List[FraudEvent]:
        result = await self.db.execute(
            select(FraudEvent)
            .where(FraudEvent.journey_id == journey_id)
            .order_by(FraudEvent.created_at.desc())
        )
        return list(result.scalars().all())

    async def get_for_user(self, user_id: str, limit: int = 50) -> List[FraudEvent]:
        result = await self.db.execute(
            select(FraudEvent)
            .where(FraudEvent.user_id == user_id)
            .order_by(FraudEvent.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())
