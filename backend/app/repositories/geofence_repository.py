from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.geofence import StationGeofence, GeofenceType
from app.models.station import Station
from app.core.s2 import get_s2_cell_token
from app.core.logging import logger


class GeofenceRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, geofence_id: str) -> Optional[StationGeofence]:
        result = await self.db.execute(
            select(StationGeofence).where(StationGeofence.id == geofence_id)
        )
        return result.scalars().first()

    async def get_by_station_id(self, station_id: str) -> Optional[StationGeofence]:
        result = await self.db.execute(
            select(StationGeofence)
            .where(StationGeofence.station_id == station_id, StationGeofence.is_active.is_(True))
        )
        return result.scalars().first()

    async def get_all_active(self) -> List[StationGeofence]:
        result = await self.db.execute(
            select(StationGeofence).where(StationGeofence.is_active.is_(True))
        )
        return list(result.scalars().all())

    async def create(self, geofence: StationGeofence) -> StationGeofence:
        self.db.add(geofence)
        await self.db.flush()
        return geofence

    async def seed_station_geofences_if_empty(self) -> int:
        """
        Seeds server-controlled geofences for all registered stations if no geofences exist.
        Assigns customized radii for major terminus / interchange hubs vs local halts.
        """
        existing = await self.db.execute(select(StationGeofence).limit(1))
        if existing.scalars().first() is not None:
            return 0

        stations_result = await self.db.execute(select(Station).where(Station.is_active.is_(True)))
        stations = stations_result.scalars().all()
        if not stations:
            return 0

        # High-traffic interchange junctions require wider geofences (450m) to accommodate massive station footprints
        major_junction_codes = {"DDR", "CSMT", "BVI", "ADH", "TNA", "CLA", "KYN", "MM"}

        count = 0
        for s in stations:
            radius = 450.0 if s.code in major_junction_codes else 300.0
            s2_token = get_s2_cell_token(s.latitude, s.longitude, level=15)

            geofence = StationGeofence(
                station_id=s.id,
                center_latitude=s.latitude,
                center_longitude=s.longitude,
                radius_meters=radius,
                geofence_type=GeofenceType.STATION.value,
                s2_cell_token=s2_token,
                is_active=True,
            )
            self.db.add(geofence)
            count += 1

        await self.db.flush()
        logger.info("Seeded %d station geofences in registry.", count)
        return count
