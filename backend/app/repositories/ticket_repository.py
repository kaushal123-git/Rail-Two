import json
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from sqlalchemy.orm import selectinload
from app.models.ticket import Ticket, TicketStatus
from app.models.ticket_event import TicketEvent, TicketEventType


class TicketRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, ticket_id: str) -> Optional[Ticket]:
        result = await self.db.execute(
            select(Ticket)
            .options(
                selectinload(Ticket.origin_station),
                selectinload(Ticket.destination_station),
                selectinload(Ticket.events),
                selectinload(Ticket.payments),
            )
            .where(Ticket.id == ticket_id)
        )
        return result.scalar_one_or_none()

    async def list_by_user(
        self,
        user_id: str,
        skip: int = 0,
        limit: int = 50,
        status: Optional[str] = None,
    ) -> List[Ticket]:
        query = (
            select(Ticket)
            .options(
                selectinload(Ticket.origin_station),
                selectinload(Ticket.destination_station),
            )
            .where(Ticket.user_id == user_id)
        )
        if status:
            query = query.where(Ticket.ticket_status == status)
        query = query.order_by(Ticket.created_at.desc()).offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_active_by_user(self, user_id: str) -> List[Ticket]:
        active_statuses = [
            TicketStatus.ISSUED.value,
            TicketStatus.ACTIVE.value,
            TicketStatus.IN_JOURNEY.value,
        ]
        query = (
            select(Ticket)
            .options(
                selectinload(Ticket.origin_station),
                selectinload(Ticket.destination_station),
            )
            .where(
                and_(
                    Ticket.user_id == user_id,
                    Ticket.ticket_status.in_(active_statuses),
                )
            )
            .order_by(Ticket.created_at.desc())
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_history_by_user(self, user_id: str, skip: int = 0, limit: int = 50) -> List[Ticket]:
        history_statuses = [
            TicketStatus.COMPLETED.value,
            TicketStatus.EXPIRED.value,
            TicketStatus.CANCELLED.value,
            TicketStatus.FRAUD_BLOCKED.value,
            TicketStatus.ISSUANCE_FAILED.value,
            "PAYMENT_FAILED",
        ]
        query = (
            select(Ticket)
            .options(
                selectinload(Ticket.origin_station),
                selectinload(Ticket.destination_station),
            )
            .where(
                and_(
                    Ticket.user_id == user_id,
                    Ticket.ticket_status.in_(history_statuses),
                )
            )
            .order_by(Ticket.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def create_ticket(
        self,
        user_id: str,
        origin_station_id: str,
        destination_station_id: str,
        fare: float,
        journey_type: str = "SINGLE",
        ticket_class: str = "SECOND",
        passenger_count: int = 1,
        provider: str = "LOCO_RAIL",
        currency: str = "INR",
    ) -> Ticket:
        now = datetime.now(timezone.utc)
        ticket = Ticket(
            user_id=user_id,
            origin_station_id=origin_station_id,
            destination_station_id=destination_station_id,
            fare=fare,
            currency=currency,
            journey_type=journey_type,
            ticket_class=ticket_class,
            passenger_count=passenger_count,
            provider=provider,
            booking_status="CREATED",
            payment_status="PENDING",
            ticket_status=TicketStatus.CREATED.value,
            created_at=now,
        )
        self.db.add(ticket)
        await self.db.flush()

        # Add initial audit event
        event = TicketEvent(
            ticket_id=ticket.id,
            event_type=TicketEventType.TICKET_CREATED.value,
            metadata_json=json.dumps({"fare": fare, "passenger_count": passenger_count}),
            created_at=now,
        )
        self.db.add(event)
        await self.db.commit()
        return await self.get_by_id(ticket.id)

    async def record_event(
        self,
        ticket_id: str,
        event_type: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> TicketEvent:
        event = TicketEvent(
            ticket_id=ticket_id,
            event_type=event_type,
            metadata_json=json.dumps(metadata) if metadata else None,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(event)
        await self.db.flush()
        return event

    async def update_status(
        self,
        ticket: Ticket,
        new_status: TicketStatus,
        event_type: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> Ticket:
        ticket.ticket_status = new_status.value
        ticket.updated_at = datetime.now(timezone.utc)
        await self.record_event(ticket.id, event_type, metadata)
        await self.db.commit()
        return await self.get_by_id(ticket.id)

    async def update(self, ticket: Ticket) -> Ticket:
        ticket.updated_at = datetime.now(timezone.utc)
        await self.db.flush()
        return ticket

