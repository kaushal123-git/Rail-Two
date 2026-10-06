from typing import Optional, List
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.journey import Journey, JourneyStatus


class JourneyRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, journey_id: str) -> Optional[Journey]:
        result = await self.db.execute(
            select(Journey).where(Journey.id == journey_id)
        )
        return result.scalars().first()

    async def get_by_ticket_id(self, ticket_id: str) -> Optional[Journey]:
        result = await self.db.execute(
            select(Journey).where(Journey.ticket_id == ticket_id)
        )
        return result.scalars().first()

    async def get_active_for_ticket(self, ticket_id: str) -> Optional[Journey]:
        active_statuses = [
            JourneyStatus.STARTING.value,
            JourneyStatus.ACTIVE.value,
            JourneyStatus.TRANSFER.value,
            JourneyStatus.ARRIVING.value,
        ]
        result = await self.db.execute(
            select(Journey).where(
                and_(
                    Journey.ticket_id == ticket_id,
                    Journey.status.in_(active_statuses),
                )
            )
        )
        return result.scalars().first()

    async def get_active_for_user(self, user_id: str) -> Optional[Journey]:
        active_statuses = [
            JourneyStatus.STARTING.value,
            JourneyStatus.ACTIVE.value,
            JourneyStatus.TRANSFER.value,
            JourneyStatus.ARRIVING.value,
        ]
        result = await self.db.execute(
            select(Journey).where(
                and_(
                    Journey.user_id == user_id,
                    Journey.status.in_(active_statuses),
                )
            )
        )
        return result.scalars().first()

    async def create(self, journey: Journey) -> Journey:
        self.db.add(journey)
        await self.db.flush()
        return journey

    async def update(self, journey: Journey) -> Journey:
        await self.db.flush()
        return journey
