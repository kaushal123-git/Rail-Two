import json
from datetime import datetime, timezone
from typing import Dict, List, Optional
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.logging import logger
from app.core.redis import redis_client
from app.models.station import Station
from app.repositories.station_repository import StationRepository
from app.repositories.network_repository import NetworkRepository
from app.services.routing_engine import RailwayGraph, RoutingEngine
from app.services.railway_data_provider import get_railway_data_provider, RailwayDataProvider
from app.schemas.routing import (
    RouteSearchRequest,
    RouteSearchResponse,
    RouteOptionRead,
)
from app.schemas.network import (
    RailwayLineRead,
    StationConnectionRead,
    RailwayServiceRead,
    ServiceUpdateRead,
    ProviderHealthRead,
    NetworkStatusResponse,
)


class RoutingService:
    def __init__(
        self,
        db: AsyncSession,
        station_repo: StationRepository,
        network_repo: NetworkRepository,
        provider: Optional[RailwayDataProvider] = None,
    ):
        self.db = db
        self.station_repo = station_repo
        self.network_repo = network_repo
        self.provider = provider or get_railway_data_provider()
        self._graph: Optional[RailwayGraph] = None

    async def get_graph(self) -> RailwayGraph:
        """Lazy-loaded, cached in-memory network graph."""
        if self._graph is not None:
            return self._graph

        stations = await self.station_repo.list_all(limit=500)
        lines = await self.network_repo.list_lines()
        connections = await self.network_repo.list_connections()

        graph = RailwayGraph()
        graph.build(stations=stations, lines=lines, connections=connections)
        self._graph = graph
        return self._graph

    def invalidate_graph_cache(self):
        """Invalidate in-memory graph when topology changes."""
        self._graph = None

    async def search_routes(self, request: RouteSearchRequest) -> RouteSearchResponse:
        origin = await self.station_repo.get_by_id(request.origin_station_id)
        if not origin:
            origin = await self.station_repo.get_by_code(request.origin_station_id)

        destination = await self.station_repo.get_by_id(request.destination_station_id)
        if not destination:
            destination = await self.station_repo.get_by_code(request.destination_station_id)

        if not origin or not destination:
            raise ValueError("Origin or destination railway station not found in network registry.")

        if origin.id == destination.id:
            raise ValueError("Origin and destination cannot be the same station.")

        # Check Redis Cache
        pref = request.preferences.upper()
        cache_key = f"route:{origin.code}:{destination.code}:{pref}"
        cached_data = await redis_client.get(cache_key)
        if cached_data:
            try:
                parsed = json.loads(cached_data)
                return RouteSearchResponse.model_validate(parsed)
            except Exception as e:
                logger.warning("Failed to deserialize cached route: %s", e)

        # Compute using graph routing engine
        graph = await self.get_graph()
        engine = RoutingEngine(graph)
        routes = engine.search_routes(
            origin_id=origin.id,
            destination_id=destination.id,
            departure_time=request.departure_time,
            preferences=pref,
        )

        # Fetch active service updates & provider status
        updates = await self.network_repo.list_active_updates()
        alerts = [u.title for u in updates]

        provider_health = await self.provider.get_provider_health()
        is_live = provider_health.get("status") == "HEALTHY" and provider_health.get("is_healthy", False)

        now = datetime.now(timezone.utc)
        response = RouteSearchResponse(
            origin_station_id=origin.id,
            origin_station_code=origin.code,
            origin_station_name=origin.name,
            destination_station_id=destination.id,
            destination_station_code=destination.code,
            destination_station_name=destination.name,
            routes=routes,
            service_alerts=alerts,
            network_status="NORMAL" if not alerts else "ADVISORY",
            is_live_data_available=is_live,
            calculated_at=now,
        )

        # Store in Redis (TTL: 300s)
        try:
            await redis_client.set(cache_key, response.model_dump_json(), ex=300)
        except Exception as e:
            logger.warning("Failed to cache route response: %s", e)

        return response

    async def get_route_by_id(
        self,
        route_id: str,
        origin_code: Optional[str] = None,
        destination_code: Optional[str] = None,
    ) -> Optional[RouteOptionRead]:
        """Resolve route options by route_id."""
        if origin_code and destination_code:
            res = await self.search_routes(
                RouteSearchRequest(
                    origin_station_id=origin_code,
                    destination_station_id=destination_code,
                )
            )
            for r in res.routes:
                if r.route_id == route_id:
                    return r
        return None

    async def get_network_status(self) -> NetworkStatusResponse:
        lines = await self.network_repo.list_lines()
        stations = await self.station_repo.list_all(limit=500)
        connections = await self.network_repo.list_connections()
        updates = await self.network_repo.list_active_updates()

        p_health = await self.provider.get_provider_health()
        provider_reads = [
            ProviderHealthRead(
                provider_name=p_health["provider_name"],
                status=p_health["status"],
                last_successful_sync=p_health.get("last_successful_sync"),
                last_error=p_health.get("last_error"),
                latency_ms=p_health.get("latency_ms"),
                is_healthy=p_health.get("is_healthy", False),
            )
        ]

        update_reads = [ServiceUpdateRead.model_validate(u) for u in updates]

        return NetworkStatusResponse(
            network_name="Mumbai Suburban Railway Network",
            network_version="1.0.0",
            operational_status="NORMAL" if not updates else "ADVISORY",
            active_lines_count=len(lines),
            active_stations_count=len(stations),
            active_connections_count=len(connections),
            provider_health=provider_reads,
            active_updates=update_reads,
            is_live_data_available=p_health.get("is_healthy", False),
            timestamp=datetime.now(timezone.utc),
        )

    async def list_lines(self) -> List[RailwayLineRead]:
        lines = await self.network_repo.list_lines()
        return [
            RailwayLineRead(
                id=l.id,
                code=l.code,
                name=l.name,
                display_name=l.display_name,
                operator=l.operator,
                color_code=l.color_code,
                is_active=l.is_active,
                station_count=0,
            )
            for l in lines
        ]

    async def get_line_by_id(self, line_id: str) -> Optional[RailwayLineRead]:
        line = await self.network_repo.get_line_by_id(line_id)
        if not line:
            line = await self.network_repo.get_line_by_code(line_id)
        if not line:
            return None
        return RailwayLineRead.model_validate(line)

    async def get_station_connections(self, station_id: str) -> List[StationConnectionRead]:
        conns = await self.network_repo.get_station_connections(station_id)
        return [StationConnectionRead.model_validate(c) for c in conns]

    async def list_services(self, line_id: Optional[str] = None) -> List[RailwayServiceRead]:
        if line_id:
            services = await self.network_repo.list_services_by_line(line_id)
        else:
            services = []
            lines = await self.network_repo.list_lines()
            for l in lines:
                s = await self.network_repo.list_services_by_line(l.id)
                services.extend(s)
        return [RailwayServiceRead.model_validate(s) for s in services]
