import json
import os
from typing import Optional, List, Tuple
from app.models.station import Station
from app.repositories.station_repository import StationRepository
from app.core.logging import logger

MUMBAI_SUBURBAN_DEFAULT_STATIONS = [
    {"code": "CCG", "name": "Churchgate", "display_name": "Churchgate (WR)", "latitude": 18.9352, "longitude": 72.8272, "zone": "Western"},
    {"code": "MEL", "name": "Marine Lines", "display_name": "Marine Lines (WR)", "latitude": 18.9460, "longitude": 72.8236, "zone": "Western"},
    {"code": "CYR", "name": "Charni Road", "display_name": "Charni Road (WR)", "latitude": 18.9517, "longitude": 72.8183, "zone": "Western"},
    {"code": "GTR", "name": "Grant Road", "display_name": "Grant Road (WR)", "latitude": 18.9633, "longitude": 72.8162, "zone": "Western"},
    {"code": "MMCT", "name": "Mumbai Central", "display_name": "Mumbai Central (WR)", "latitude": 18.9697, "longitude": 72.8193, "zone": "Western"},
    {"code": "MX", "name": "Mahalaxmi", "display_name": "Mahalaxmi (WR)", "latitude": 18.9827, "longitude": 72.8242, "zone": "Western"},
    {"code": "PL", "name": "Lower Parel", "display_name": "Lower Parel (WR)", "latitude": 18.9953, "longitude": 72.8306, "zone": "Western"},
    {"code": "PBHD", "name": "Prabhadevi", "display_name": "Prabhadevi (WR)", "latitude": 19.0125, "longitude": 72.8361, "zone": "Western"},
    {"code": "DDR", "name": "Dadar", "display_name": "Dadar Junction (WR/CR)", "latitude": 19.0178, "longitude": 72.8478, "zone": "Western"},
    {"code": "MRU", "name": "Matunga Road", "display_name": "Matunga Road (WR)", "latitude": 19.0274, "longitude": 72.8458, "zone": "Western"},
    {"code": "MM", "name": "Mahim", "display_name": "Mahim Junction (WR/HR)", "latitude": 19.0410, "longitude": 72.8436, "zone": "Western"},
    {"code": "BA", "name": "Bandra", "display_name": "Bandra Junction (WR/HR)", "latitude": 19.0553, "longitude": 72.8406, "zone": "Western"},
    {"code": "KHAR", "name": "Khar Road", "display_name": "Khar Road (WR)", "latitude": 19.0694, "longitude": 72.8383, "zone": "Western"},
    {"code": "STC", "name": "Santa Cruz", "display_name": "Santa Cruz (WR)", "latitude": 19.0817, "longitude": 72.8400, "zone": "Western"},
    {"code": "VLP", "name": "Vile Parle", "display_name": "Vile Parle (WR)", "latitude": 19.0988, "longitude": 72.8438, "zone": "Western"},
    {"code": "ADH", "name": "Andheri", "display_name": "Andheri (WR/Metro)", "latitude": 19.1197, "longitude": 72.8464, "zone": "Western"},
    {"code": "JOS", "name": "Jogeshwari", "display_name": "Jogeshwari (WR)", "latitude": 19.1360, "longitude": 72.8488, "zone": "Western"},
    {"code": "RMAR", "name": "Ram Mandir", "display_name": "Ram Mandir (WR)", "latitude": 19.1519, "longitude": 72.8494, "zone": "Western"},
    {"code": "GMN", "name": "Goregaon", "display_name": "Goregaon (WR/HR)", "latitude": 19.1633, "longitude": 72.8489, "zone": "Western"},
    {"code": "MDD", "name": "Malad", "display_name": "Malad (WR)", "latitude": 19.1866, "longitude": 72.8486, "zone": "Western"},
    {"code": "KLE", "name": "Kandivali", "display_name": "Kandivali (WR)", "latitude": 19.2045, "longitude": 72.8519, "zone": "Western"},
    {"code": "BVI", "name": "Borivali", "display_name": "Borivali (WR)", "latitude": 19.2291, "longitude": 72.8569, "zone": "Western"},
    {"code": "BYR", "name": "Bhayandar", "display_name": "Bhayandar (WR)", "latitude": 19.3015, "longitude": 72.8524, "zone": "Western"},
    {"code": "BSR", "name": "Vasai Road", "display_name": "Vasai Road (WR)", "latitude": 19.3828, "longitude": 72.8322, "zone": "Western"},
    {"code": "VR", "name": "Virar", "display_name": "Virar (WR)", "latitude": 19.4554, "longitude": 72.8105, "zone": "Western"},
    {"code": "CSMT", "name": "Mumbai CSMT", "display_name": "Chhatrapati Shivaji Maharaj Terminus (CR)", "latitude": 18.9400, "longitude": 72.8354, "zone": "Central"},
    {"code": "BY", "name": "Byculla", "display_name": "Byculla (CR)", "latitude": 18.9774, "longitude": 72.8336, "zone": "Central"},
    {"code": "CLA", "name": "Kurla", "display_name": "Kurla Junction (CR/HR)", "latitude": 19.0657, "longitude": 72.8794, "zone": "Central"},
    {"code": "GC", "name": "Ghatkopar", "display_name": "Ghatkopar (CR/Metro)", "latitude": 19.0864, "longitude": 72.9081, "zone": "Central"},
    {"code": "TNA", "name": "Thane", "display_name": "Thane (CR)", "latitude": 19.1860, "longitude": 72.9757, "zone": "Central"},
    {"code": "KYN", "name": "Kalyan", "display_name": "Kalyan Junction (CR)", "latitude": 19.2354, "longitude": 73.1303, "zone": "Central"},
]


class StationService:
    def __init__(self, station_repo: StationRepository):
        self.repo = station_repo

    async def list_stations(
        self,
        skip: int = 0,
        limit: int = 100,
        zone: Optional[str] = None,
    ) -> List[Station]:
        return await self.repo.list_all(skip=skip, limit=limit, zone=zone)

    async def get_station_by_id(self, station_id: str) -> Optional[Station]:
        return await self.repo.get_by_id(station_id)

    async def get_station_by_code(self, code: str) -> Optional[Station]:
        return await self.repo.get_by_code(code)

    async def search_stations(self, query: str, limit: int = 20) -> List[Station]:
        if not query or not query.strip():
            return []
        return await self.repo.search(query.strip(), limit=limit)

    async def get_nearby_stations(
        self,
        latitude: float,
        longitude: float,
        radius_km: float = 10.0,
        limit: int = 10,
    ) -> List[Tuple[Station, float]]:
        return await self.repo.find_nearby(latitude, longitude, radius_km=radius_km, limit=limit)

    async def seed_stations_if_empty(self):
        """Seed station database on startup if no records exist."""
        existing = await self.repo.list_all(limit=1)
        if existing:
            return

        logger.info("Seeding Mumbai suburban railway station database...")
        for st in MUMBAI_SUBURBAN_DEFAULT_STATIONS:
            await self.repo.create_or_update(
                code=st["code"],
                name=st["name"],
                display_name=st["display_name"],
                latitude=st["latitude"],
                longitude=st["longitude"],
                city="Mumbai",
                zone=st["zone"],
            )
        logger.info("Seeded %d Mumbai railway stations successfully.", len(MUMBAI_SUBURBAN_DEFAULT_STATIONS))
