import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.services.routing_engine import RailwayGraph, RoutingEngine
from app.models.station import Station
from app.models.railway_line import RailwayLine
from app.models.station_connection import StationConnection
from app.services.railway_data_provider import (
    ProductionRailwayDataProvider,
    DevelopmentRailwayDataProvider,
)


@pytest.fixture
def mock_railway_graph():
    """Build a deterministic in-memory graph for algorithmic unit tests."""
    # Stations: S1 (CCG), S2 (DDR), S3 (BVI) on Line 1 (WR)
    # Station S4 (TNA) on Line 2 (CR)
    # S2 (DDR) is an interchange between Line 1 and Line 2
    s1 = Station(id="st-1", code="CCG", name="Churchgate", display_name="Churchgate (WR)", latitude=18.93, longitude=72.82, city="Mumbai", zone="Western", is_active=True)
    s2 = Station(id="st-2", code="DDR", name="Dadar", display_name="Dadar (WR/CR)", latitude=19.01, longitude=72.84, city="Mumbai", zone="Western", is_active=True)
    s3 = Station(id="st-3", code="BVI", name="Borivali", display_name="Borivali (WR)", latitude=19.22, longitude=72.85, city="Mumbai", zone="Western", is_active=True)
    s4 = Station(id="st-4", code="TNA", name="Thane", display_name="Thane (CR)", latitude=19.18, longitude=72.97, city="Mumbai", zone="Central", is_active=True)
    s_island = Station(id="st-99", code="ISL", name="Island Station", display_name="Island Station", latitude=19.99, longitude=72.99, city="Mumbai", zone="Island", is_active=True)

    l1 = RailwayLine(id="line-1", code="WR", name="Western Railway", display_name="Western Line", operator="WR", color_code="#FF5722", is_active=True)
    l2 = RailwayLine(id="line-2", code="CR", name="Central Railway", display_name="Central Line", operator="CR", color_code="#1976D2", is_active=True)

    # Connections
    # S1 <-> S2 (WR, 10km, 600s)
    # S2 <-> S3 (WR, 20km, 1200s)
    # S2 <-> S4 (CR, 25km, 1500s)
    # S2 transfer (0.1km, 180s)
    c1_fwd = StationConnection(id="c-1", from_station_id="st-1", to_station_id="st-2", line_id="line-1", sequence=1, distance_km=10.0, scheduled_travel_seconds=600, is_transfer=False, is_active=True)
    c1_rev = StationConnection(id="c-2", from_station_id="st-2", to_station_id="st-1", line_id="line-1", sequence=1, distance_km=10.0, scheduled_travel_seconds=600, is_transfer=False, is_active=True)

    c2_fwd = StationConnection(id="c-3", from_station_id="st-2", to_station_id="st-3", line_id="line-1", sequence=2, distance_km=20.0, scheduled_travel_seconds=1200, is_transfer=False, is_active=True)
    c2_rev = StationConnection(id="c-4", from_station_id="st-3", to_station_id="st-2", line_id="line-1", sequence=2, distance_km=20.0, scheduled_travel_seconds=1200, is_transfer=False, is_active=True)

    c3_fwd = StationConnection(id="c-5", from_station_id="st-2", to_station_id="st-4", line_id="line-2", sequence=1, distance_km=25.0, scheduled_travel_seconds=1500, is_transfer=False, is_active=True)
    c3_rev = StationConnection(id="c-6", from_station_id="st-4", to_station_id="st-2", line_id="line-2", sequence=1, distance_km=25.0, scheduled_travel_seconds=1500, is_transfer=False, is_active=True)

    transfer = StationConnection(id="c-7", from_station_id="st-2", to_station_id="st-2", line_id=None, sequence=1, distance_km=0.1, scheduled_travel_seconds=180, is_transfer=True, is_active=True)

    graph = RailwayGraph()
    graph.build(
        stations=[s1, s2, s3, s4, s_island],
        lines=[l1, l2],
        connections=[c1_fwd, c1_rev, c2_fwd, c2_rev, c3_fwd, c3_rev, transfer],
    )
    return graph


def test_routing_engine_direct_route(mock_railway_graph):
    """Test Dijkstra shortest path on direct single-line route."""
    engine = RoutingEngine(mock_railway_graph)
    routes = engine.search_routes(origin_id="CCG", destination_id="BVI")

    assert len(routes) >= 1
    fastest = routes[0]
    assert fastest.origin_station_code == "CCG"
    assert fastest.destination_station_code == "BVI"
    assert fastest.transfers_count == 0
    assert fastest.total_distance_km == 30.0  # 10 + 20
    assert fastest.total_duration_seconds == 1800  # 600 + 1200
    assert fastest.total_duration_minutes == 30
    assert len(fastest.legs) == 1
    assert fastest.legs[0].line_code == "WR"
    assert fastest.legs[0].station_sequence == ["Churchgate", "Dadar", "Borivali"]


def test_routing_engine_transfer_route(mock_railway_graph):
    """Test multi-leg journey with interchange between Western and Central lines."""
    engine = RoutingEngine(mock_railway_graph)
    routes = engine.search_routes(origin_id="CCG", destination_id="TNA")

    assert len(routes) >= 1
    fastest = routes[0]
    assert fastest.origin_station_code == "CCG"
    assert fastest.destination_station_code == "TNA"
    assert fastest.transfers_count == 1
    assert len(fastest.legs) == 2
    assert fastest.legs[0].line_code == "WR"
    assert fastest.legs[0].to_station_code == "DDR"
    assert fastest.legs[1].line_code == "CR"
    assert fastest.legs[1].from_station_code == "DDR"
    assert fastest.legs[1].to_station_code == "TNA"


def test_routing_engine_disconnected_island(mock_railway_graph):
    """Test search between disconnected nodes returns empty routes list."""
    engine = RoutingEngine(mock_railway_graph)
    routes = engine.search_routes(origin_id="CCG", destination_id="ISL")
    assert routes == []


def test_routing_engine_same_station(mock_railway_graph):
    """Test same origin and destination returns empty list."""
    engine = RoutingEngine(mock_railway_graph)
    routes = engine.search_routes(origin_id="CCG", destination_id="CCG")
    assert routes == []


def test_railway_data_providers():
    """Verify live data provider abstraction and strict honest status handling."""
    # 1. Production provider without API credentials must return NOT_CONFIGURED
    prod = ProductionRailwayDataProvider(api_key=None, endpoint_url=None)
    health = pytest.importorskip("asyncio").run(prod.get_provider_health())
    assert health["status"] == "NOT_CONFIGURED"
    assert health["is_healthy"] is False

    lines = pytest.importorskip("asyncio").run(prod.get_all_line_statuses())
    assert all(l["source"] == "PROVIDER_NOT_CONFIGURED" for l in lines)

    # 2. Development provider clearly identifies DEVELOPMENT_DATA
    dev = DevelopmentRailwayDataProvider()
    dev_health = pytest.importorskip("asyncio").run(dev.get_provider_health())
    assert dev_health["status"] == "HEALTHY"
    dev_lines = pytest.importorskip("asyncio").run(dev.get_all_line_statuses())
    assert all(l["source"] == "DEVELOPMENT_DATA" for l in dev_lines)


@pytest.mark.asyncio
async def test_api_routes_search(client: AsyncClient):
    """Test /api/v1/routes/search endpoint with full seeded graph."""
    # 1. Search Churchgate to Borivali (Direct Western Line)
    res = await client.post(
        "/api/v1/routes/search",
        json={
            "origin_station_id": "CCG",
            "destination_station_id": "BVI",
            "preferences": "FASTEST",
        },
    )
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    data = body["data"]
    assert data["origin_station_code"] == "CCG"
    assert data["destination_station_code"] == "BVI"
    assert len(data["routes"]) > 0

    fastest = data["routes"][0]
    assert fastest["origin_station_code"] == "CCG"
    assert fastest["destination_station_code"] == "BVI"
    assert fastest["transfers_count"] == 0
    assert "route_" in fastest["route_id"]

    # 2. Search Churchgate to Thane (Transfer via Dadar)
    res_tna = await client.post(
        "/api/v1/routes/search",
        json={
            "origin_station_id": "CCG",
            "destination_station_id": "TNA",
            "preferences": "FASTEST",
        },
    )
    assert res_tna.status_code == 200
    data_tna = res_tna.json()["data"]
    assert len(data_tna["routes"]) > 0
    route_tna = data_tna["routes"][0]
    assert route_tna["transfers_count"] >= 1


@pytest.mark.asyncio
async def test_api_network_endpoints(client: AsyncClient):
    """Test /lines, /network/status, and /services/status endpoints."""
    # 1. Lines
    res = await client.get("/api/v1/lines")
    assert res.status_code == 200
    lines = res.json()["data"]
    assert len(lines) >= 3
    codes = [l["code"] for l in lines]
    assert "WR" in codes
    assert "CR" in codes
    assert "HR" in codes

    # 2. Network Status
    res_status = await client.get("/api/v1/network/status")
    assert res_status.status_code == 200
    net = res_status.json()["data"]
    assert net["active_lines_count"] >= 3
    assert net["active_stations_count"] >= 30
    assert net["active_connections_count"] > 0

    # 3. Station Connections
    res_conn = await client.get("/api/v1/stations/DDR/connections")
    assert res_conn.status_code == 200
    conns = res_conn.json()["data"]
    assert len(conns) > 0

