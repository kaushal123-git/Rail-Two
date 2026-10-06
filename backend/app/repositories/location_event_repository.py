from typing import List, Optional
from datetime import datetime
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.location_event import LocationEvent


class LocationEventRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, event: LocationEvent) -> LocationEvent:
        self.db.add(event)
        await self.db.flush()
        return event

    async def create_batch(self, events: List[LocationEvent]) -> List[LocationEvent]:
        self.db.add_all(events)
        await self.db.flush()
        return events

    async def get_recent_for_journey(self, journey_id: str, limit: int = 20) -> List[LocationEvent]:
        result = await self.db.execute(
            select(LocationEvent)
            .where(LocationEvent.journey_id == journey_id)
            .order_by(LocationEvent.timestamp_server.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_last_for_journey(self, journey_id: str) -> Optional[LocationEvent]:
        result = await self.db.execute(
            select(LocationEvent)
            .where(LocationEvent.journey_id == journey_id)
            .order_by(LocationEvent.timestamp_server.desc())
            .limit(1)
        )
        return result.scalars().first()

    async def get_last_for_user(self, user_id: str) -> Optional[LocationEvent]:
        result = await self.db.execute(
            select(LocationEvent)
            .where(LocationEvent.user_id == user_id)
            .order_by(LocationEvent.timestamp_server.desc())
            .limit(1)
        )
        return result.scalars().first()

    async def delete_older_than(self, cutoff: datetime) -> int:
        """
        Data minimization & privacy retention strategy:
        Removes raw high-frequency location records older than cutoff window.
        """
        stmt = delete(LocationEvent).where(LocationEvent.created_at < cutoff)
        result = await self.db.execute(stmt)
        await self.db.flush()
        return result.rowcount
