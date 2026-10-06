import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_and_search_stations(client: AsyncClient):
    # 1. List stations
    list_res = await client.get("/api/v1/stations?limit=10")
    assert list_res.status_code == 200
    stations = list_res.json()["data"]
    assert len(stations) > 0

    # 2. Search station by name
    search_res = await client.get("/api/v1/stations/search?q=Dadar")
    assert search_res.status_code == 200
    results = search_res.json()["data"]
    assert len(results) > 0
    assert any("Dadar" in s["name"] for s in results)

    # 3. Search station by railway code
    code_res = await client.get("/api/v1/stations/search?q=BVI")
    assert code_res.status_code == 200
    code_results = code_res.json()["data"]
    assert len(code_results) > 0
    assert code_results[0]["code"] == "BVI"
    assert code_results[0]["name"] == "Borivali"


@pytest.mark.asyncio
async def test_nearby_stations_haversine(client: AsyncClient):
    # Dadar Coordinates: 19.0178, 72.8478
    res = await client.get("/api/v1/stations/nearby?lat=19.0178&lng=72.8478&radius_km=5.0")
    assert res.status_code == 200
    nearby = res.json()["data"]
    assert len(nearby) > 0

    # Closest station should be Dadar (distance ~ 0.0 km)
    closest = nearby[0]
    assert "Dadar" in closest["name"]
    assert closest["distance_km"] < 1.0


@pytest.mark.asyncio
async def test_get_station_by_id_or_code(client: AsyncClient):
    res = await client.get("/api/v1/stations/CCG")
    assert res.status_code == 200
    station = res.json()["data"]
    assert station["code"] == "CCG"
    assert station["name"] == "Churchgate"
