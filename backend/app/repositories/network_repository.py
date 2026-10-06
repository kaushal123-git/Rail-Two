from typing import Dict, List, Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func
from app.models.railway_line import RailwayLine
from app.models.station_connection import StationConnection
from app.models.railway_service import RailwayService
from app.models.service_update import ServiceUpdate
from app.models.provider_health import ProviderHealth
from app.models.station import Station
from app.core.logging import logger


MUMBAI_SUBURBAN_LINES = [
    {
        "code": "WR",
        "name": "Western Railway",
        "display_name": "Western Line (Churchgate - Virar - Dahanu)",
        "operator": "Western Railway Suburban",
        "color_code": "#FF5722",
    },
    {
        "code": "CR",
        "name": "Central Railway",
        "display_name": "Central Main Line (CSMT - Dadar - Thane - Kalyan)",
        "operator": "Central Railway Suburban",
        "color_code": "#1976D2",
    },
    {
        "code": "HR",
        "name": "Harbour Line",
        "display_name": "Harbour Line (CSMT - Kurla - Panvel / Andheri)",
        "operator": "Central Railway Harbour Division",
        "color_code": "#388E3C",
    },
]

# Sequential station codes for Western Line
WR_STATION_CODES = [
    "CCG", "MEL", "CYR", "GTR", "MMCT", "MX", "PL", "PBHD",
    "DDR", "MRU", "MM", "BA", "KHAR", "STC", "VLP", "ADH",
    "JOS", "RMAR", "GMN", "MDD", "KLE", "BVI", "BYR", "BSR", "VR",
]

# Sequential station codes for Central Main Line
CR_STATION_CODES = [
    "CSMT", "BY", "DDR", "CLA", "GC", "TNA", "KYN",
]


class NetworkRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_lines(self, is_active: bool = True) -> List[RailwayLine]:
        stmt = select(RailwayLine).where(RailwayLine.is_active == is_active).order_by(RailwayLine.code.asc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_line_by_id(self, line_id: str) -> Optional[RailwayLine]:
        stmt = select(RailwayLine).where(RailwayLine.id == line_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_line_by_code(self, code: str) -> Optional[RailwayLine]:
        stmt = select(RailwayLine).where(func.upper(RailwayLine.code) == code.upper().strip())
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def list_connections(self, is_active: bool = True) -> List[StationConnection]:
        stmt = select(StationConnection).where(StationConnection.is_active == is_active)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_station_connections(self, station_id: str) -> List[StationConnection]:
        stmt = select(StationConnection).where(
            StationConnection.is_active == True,
            or_(
                StationConnection.from_station_id == station_id,
                StationConnection.to_station_id == station_id,
            ),
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def list_active_updates(self) -> List[ServiceUpdate]:
        stmt = select(ServiceUpdate).where(ServiceUpdate.is_active == True)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def list_services_by_line(self, line_id: str) -> List[RailwayService]:
        stmt = select(RailwayService).where(RailwayService.line_id == line_id, RailwayService.is_active == True)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_provider_health(self, provider_name: str) -> Optional[ProviderHealth]:
        stmt = select(ProviderHealth).where(ProviderHealth.provider_name == provider_name)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def upsert_provider_health(
        self,
        provider_name: str,
        status: str,
        last_successful_sync=None,
        last_error=None,
        latency_ms=None,
    ) -> ProviderHealth:
        ph = await self.get_provider_health(provider_name)
        if not ph:
            ph = ProviderHealth(
                provider_name=provider_name,
                status=status,
                last_successful_sync=last_successful_sync,
                last_error=last_error,
                latency_ms=latency_ms,
            )
            self.db.add(ph)
        else:
            ph.status = status
            if last_successful_sync:
                ph.last_successful_sync = last_successful_sync
            ph.last_error = last_error
            ph.latency_ms = latency_ms
        await self.db.flush()
        return ph

    async def seed_network_graph_if_empty(self):
        """Seed lines and network connectivity edges if no records exist."""
        existing_lines = await self.list_lines()
        if existing_lines:
            return

        logger.info("Seeding Mumbai Suburban Railway lines and network graph...")

        # 1. Create Railway Lines
        created_lines: Dict[str, RailwayLine] = {}
        for l_data in MUMBAI_SUBURBAN_LINES:
            line = RailwayLine(
                code=l_data["code"],
                name=l_data["name"],
                display_name=l_data["display_name"],
                operator=l_data["operator"],
                color_code=l_data["color_code"],
                is_active=True,
            )
            self.db.add(line)
            created_lines[l_data["code"]] = line

        await self.db.flush()

        # 2. Fetch Station IDs map by code
        stmt = select(Station)
        st_res = await self.db.execute(stmt)
        stations = {st.code.upper(): st for st in st_res.scalars().all()}

        # 3. Build Western Line Sequential Connections
        wr_line = created_lines["WR"]
        seq = 1
        for i in range(len(WR_STATION_CODES) - 1):
            c1, c2 = WR_STATION_CODES[i], WR_STATION_CODES[i + 1]
            st1, st2 = stations.get(c1), stations.get(c2)
            if not st1 or not st2:
                continue

            # Average travel time ~ 3 minutes per stop, dist ~ 2.2 km
            dist = 2.2
            time_sec = 180

            # Forward connection (DOWN train toward Virar)
            conn_fwd = StationConnection(
                from_station_id=st1.id,
                to_station_id=st2.id,
                line_id=wr_line.id,
                sequence=seq,
                distance_km=dist,
                scheduled_travel_seconds=time_sec,
                is_transfer=False,
                is_active=True,
            )
            # Reverse connection (UP train toward Churchgate)
            conn_rev = StationConnection(
                from_station_id=st2.id,
                to_station_id=st1.id,
                line_id=wr_line.id,
                sequence=seq,
                distance_km=dist,
                scheduled_travel_seconds=time_sec,
                is_transfer=False,
                is_active=True,
            )
            self.db.add_all([conn_fwd, conn_rev])
            seq += 1

        # 4. Build Central Line Sequential Connections
        cr_line = created_lines["CR"]
        seq = 1
        for i in range(len(CR_STATION_CODES) - 1):
            c1, c2 = CR_STATION_CODES[i], CR_STATION_CODES[i + 1]
            st1, st2 = stations.get(c1), stations.get(c2)
            if not st1 or not st2:
                continue

            dist = 4.5  # Central line longer distances between major hubs
            time_sec = 300

            conn_fwd = StationConnection(
                from_station_id=st1.id,
                to_station_id=st2.id,
                line_id=cr_line.id,
                sequence=seq,
                distance_km=dist,
                scheduled_travel_seconds=time_sec,
                is_transfer=False,
                is_active=True,
            )
            conn_rev = StationConnection(
                from_station_id=st2.id,
                to_station_id=st1.id,
                line_id=cr_line.id,
                sequence=seq,
                distance_km=dist,
                scheduled_travel_seconds=time_sec,
                is_transfer=False,
                is_active=True,
            )
            self.db.add_all([conn_fwd, conn_rev])
            seq += 1

        # 5. Build Interchanges (Dadar WR <-> CR transfer)
        ddr_st = stations.get("DDR")
        if ddr_st:
            # Dadar acts as cross-line interchange hub with 3 min foot overbridge transfer
            transfer_conn = StationConnection(
                from_station_id=ddr_st.id,
                to_station_id=ddr_st.id,
                line_id=None,
                sequence=1,
                distance_km=0.1,
                scheduled_travel_seconds=180,  # 3 min walk
                is_transfer=True,
                is_active=True,
            )
            self.db.add(transfer_conn)

        # 6. Default Services
        wr_fast = RailwayService(
            line_id=wr_line.id,
            service_code="FAST",
            service_name="Churchgate - Virar Fast Local",
            direction="BOTH",
            status="ACTIVE",
            delay_seconds=0,
            source="SCHEDULED",
            is_active=True,
        )
        wr_slow = RailwayService(
            line_id=wr_line.id,
            service_code="SLOW",
            service_name="Churchgate - Borivali Slow Local",
            direction="BOTH",
            status="ACTIVE",
            delay_seconds=0,
            source="SCHEDULED",
            is_active=True,
        )
        cr_fast = RailwayService(
            line_id=cr_line.id,
            service_code="FAST",
            service_name="CSMT - Kalyan Fast Express",
            direction="BOTH",
            status="ACTIVE",
            delay_seconds=0,
            source="SCHEDULED",
            is_active=True,
        )
        self.db.add_all([wr_fast, wr_slow, cr_fast])

        await self.db.flush()
        logger.info("Successfully seeded Mumbai Suburban railway network graph.")
