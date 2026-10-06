from typing import Optional, List
from datetime import datetime, timezone
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.fare_rule import FareRule


class FareRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_applicable_rule(
        self,
        journey_type: str,
        ticket_class: str,
        distance_km: float,
        origin_zone: str = "*",
        destination_zone: str = "*",
    ) -> Optional[FareRule]:
        """Find the most specific active fare rule matching the journey parameters."""
        stmt = (
            select(FareRule)
            .where(
                and_(
                    FareRule.active == True,
                    FareRule.journey_type == journey_type.upper(),
                    FareRule.ticket_class == ticket_class.upper(),
                    FareRule.min_distance_km <= distance_km,
                    FareRule.max_distance_km >= distance_km,
                )
            )
            .order_by(FareRule.created_at.desc())
        )
        result = await self.db.execute(stmt)
        return result.scalars().first()

    async def list_active_rules(self) -> List[FareRule]:
        stmt = select(FareRule).where(FareRule.active == True).order_by(FareRule.min_distance_km.asc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def seed_default_fare_rules(self) -> None:
        """Seed official Mumbai Suburban Railway fare slabs if none exist."""
        existing = await self.db.execute(select(FareRule).limit(1))
        if existing.scalar_one_or_none() is not None:
            return

        now = datetime.now(timezone.utc)
        slabs = [
            # Second Class Ordinary Single
            {"journey_type": "SINGLE", "ticket_class": "SECOND", "min_km": 0.0, "max_km": 10.0, "base_fare": 5.0},
            {"journey_type": "SINGLE", "ticket_class": "SECOND", "min_km": 10.1, "max_km": 20.0, "base_fare": 10.0},
            {"journey_type": "SINGLE", "ticket_class": "SECOND", "min_km": 20.1, "max_km": 35.0, "base_fare": 15.0},
            {"journey_type": "SINGLE", "ticket_class": "SECOND", "min_km": 35.1, "max_km": 50.0, "base_fare": 20.0},
            {"journey_type": "SINGLE", "ticket_class": "SECOND", "min_km": 50.1, "max_km": 70.0, "base_fare": 25.0},
            {"journey_type": "SINGLE", "ticket_class": "SECOND", "min_km": 70.1, "max_km": 9999.0, "base_fare": 30.0},
            # First Class Single
            {"journey_type": "SINGLE", "ticket_class": "FIRST", "min_km": 0.0, "max_km": 10.0, "base_fare": 50.0},
            {"journey_type": "SINGLE", "ticket_class": "FIRST", "min_km": 10.1, "max_km": 20.0, "base_fare": 70.0},
            {"journey_type": "SINGLE", "ticket_class": "FIRST", "min_km": 20.1, "max_km": 35.0, "base_fare": 105.0},
            {"journey_type": "SINGLE", "ticket_class": "FIRST", "min_km": 35.1, "max_km": 50.0, "base_fare": 140.0},
            {"journey_type": "SINGLE", "ticket_class": "FIRST", "min_km": 50.1, "max_km": 70.0, "base_fare": 165.0},
            {"journey_type": "SINGLE", "ticket_class": "FIRST", "min_km": 70.1, "max_km": 9999.0, "base_fare": 195.0},
            # AC EMU Single
            {"journey_type": "SINGLE", "ticket_class": "AC", "min_km": 0.0, "max_km": 10.0, "base_fare": 65.0},
            {"journey_type": "SINGLE", "ticket_class": "AC", "min_km": 10.1, "max_km": 20.0, "base_fare": 90.0},
            {"journey_type": "SINGLE", "ticket_class": "AC", "min_km": 20.1, "max_km": 35.0, "base_fare": 135.0},
            {"journey_type": "SINGLE", "ticket_class": "AC", "min_km": 35.1, "max_km": 50.0, "base_fare": 175.0},
            {"journey_type": "SINGLE", "ticket_class": "AC", "min_km": 50.1, "max_km": 70.0, "base_fare": 205.0},
            {"journey_type": "SINGLE", "ticket_class": "AC", "min_km": 70.1, "max_km": 9999.0, "base_fare": 240.0},
        ]

        # Duplicate slabs for RETURN with 2x multiplier
        return_slabs = []
        for slab in slabs:
            ret = dict(slab)
            ret["journey_type"] = "RETURN"
            ret["base_fare"] = slab["base_fare"] * 2.0
            return_slabs.append(ret)

        # Season slabs (Monthly base rates)
        season_slabs = [
            # Second Class Monthly
            {"journey_type": "SEASON", "ticket_class": "SECOND", "min_km": 0.0, "max_km": 10.0, "base_fare": 100.0},
            {"journey_type": "SEASON", "ticket_class": "SECOND", "min_km": 10.1, "max_km": 20.0, "base_fare": 135.0},
            {"journey_type": "SEASON", "ticket_class": "SECOND", "min_km": 20.1, "max_km": 35.0, "base_fare": 175.0},
            {"journey_type": "SEASON", "ticket_class": "SECOND", "min_km": 35.1, "max_km": 50.0, "base_fare": 215.0},
            {"journey_type": "SEASON", "ticket_class": "SECOND", "min_km": 50.1, "max_km": 70.0, "base_fare": 255.0},
            {"journey_type": "SEASON", "ticket_class": "SECOND", "min_km": 70.1, "max_km": 9999.0, "base_fare": 315.0},
            # First Class Monthly
            {"journey_type": "SEASON", "ticket_class": "FIRST", "min_km": 0.0, "max_km": 10.0, "base_fare": 345.0},
            {"journey_type": "SEASON", "ticket_class": "FIRST", "min_km": 10.1, "max_km": 20.0, "base_fare": 485.0},
            {"journey_type": "SEASON", "ticket_class": "FIRST", "min_km": 20.1, "max_km": 35.0, "base_fare": 655.0},
            {"journey_type": "SEASON", "ticket_class": "FIRST", "min_km": 35.1, "max_km": 50.0, "base_fare": 840.0},
            {"journey_type": "SEASON", "ticket_class": "FIRST", "min_km": 50.1, "max_km": 70.0, "base_fare": 1040.0},
            {"journey_type": "SEASON", "ticket_class": "FIRST", "min_km": 70.1, "max_km": 9999.0, "base_fare": 1250.0},
            # AC EMU Monthly
            {"journey_type": "SEASON", "ticket_class": "AC", "min_km": 0.0, "max_km": 10.0, "base_fare": 650.0},
            {"journey_type": "SEASON", "ticket_class": "AC", "min_km": 10.1, "max_km": 20.0, "base_fare": 945.0},
            {"journey_type": "SEASON", "ticket_class": "AC", "min_km": 20.1, "max_km": 35.0, "base_fare": 1350.0},
            {"journey_type": "SEASON", "ticket_class": "AC", "min_km": 35.1, "max_km": 50.0, "base_fare": 1750.0},
            {"journey_type": "SEASON", "ticket_class": "AC", "min_km": 50.1, "max_km": 70.0, "base_fare": 2050.0},
            {"journey_type": "SEASON", "ticket_class": "AC", "min_km": 70.1, "max_km": 9999.0, "base_fare": 2450.0},
        ]

        all_slabs = slabs + return_slabs + season_slabs
        for s in all_slabs:
            rule = FareRule(
                origin_zone="*",
                destination_zone="*",
                journey_type=s["journey_type"],
                ticket_class=s["ticket_class"],
                min_distance_km=s["min_km"],
                max_distance_km=s["max_km"],
                base_fare=s["base_fare"],
                active=True,
                version="mumbai_suburban_v2026",
                effective_from=now,
            )
            self.db.add(rule)

        await self.db.commit()
