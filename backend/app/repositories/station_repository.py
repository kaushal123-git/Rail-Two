import math
from typing import Optional, List, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, func
from app.models.station import Station


def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate great-circle distance between two points on the Earth (in km)."""
    r = 6371.0  # Earth radius in kilometers
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return round(r * c, 2)


class StationRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, station_id: str) -> Optional[Station]:
        result = await self.db.execute(select(Station).where(Station.id == station_id))
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str) -> Optional[Station]:
        result = await self.db.execute(
            select(Station).where(func.upper(Station.code) == code.upper().strip())
        )
        return result.scalar_one_or_none()

    async def list_all(
        self,
        skip: int = 0,
        limit: int = 100,
        zone: Optional[str] = None,
        is_active: bool = True,
    ) -> List[Station]:
        query = select(Station).where(Station.is_active == is_active)
        if zone:
            query = query.where(Station.zone.ilike(f"%{zone}%"))
        query = query.order_by(Station.name.asc()).offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def get_all_active(self) -> List[Station]:
        return await self.list_all(limit=1000, is_active=True)

    async def search(self, query: str, limit: int = 20) -> List[Station]:
        cleaned = f"%{query.strip()}%"
        stmt = (
            select(Station)
            .where(
                Station.is_active == True,
                or_(
                    Station.name.ilike(cleaned),
                    Station.code.ilike(cleaned),
                    Station.display_name.ilike(cleaned),
                ),
            )
            .order_by(Station.name.asc())
            .limit(limit)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def find_nearby(
        self,
        latitude: float,
        longitude: float,
        radius_km: float = 10.0,
        limit: int = 10,
    ) -> List[Tuple[Station, float]]:
        # Fetch active stations within a coarse bounding box (~1 deg lat is ~111 km)
        lat_delta = radius_km / 111.0
        lon_delta = radius_km / (111.0 * math.cos(math.radians(latitude)))

        stmt = select(Station).where(
            Station.is_active == True,
            Station.latitude.between(latitude - lat_delta, latitude + lat_delta),
            Station.longitude.between(longitude - lon_delta, longitude + lon_delta),
        )
        result = await self.db.execute(stmt)
        candidates = result.scalars().all()

        nearby: List[Tuple[Station, float]] = []
        for station in candidates:
            dist = haversine_distance_km(latitude, longitude, station.latitude, station.longitude)
            if dist <= radius_km:
                nearby.append((station, dist))

        nearby.sort(key=lambda x: x[1])
        return nearby[:limit]

    async def create_or_update(
        self,
        code: str,
        name: str,
        display_name: str,
        latitude: float,
        longitude: float,
        city: str = "Mumbai",
        zone: str = "Western",
    ) -> Station:
        existing = await self.get_by_code(code)
        if existing:
            existing.name = name
            existing.display_name = display_name
            existing.latitude = latitude
            existing.longitude = longitude
            existing.city = city
            existing.zone = zone
            await self.db.flush()
            return existing

        station = Station(
            code=code.upper().strip(),
            name=name,
            display_name=display_name,
            latitude=latitude,
            longitude=longitude,
            city=city,
            zone=zone,
        )
        self.db.add(station)
        await self.db.flush()
        await self.db.refresh(station)
        return station
