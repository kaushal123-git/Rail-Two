import pytest
from httpx import AsyncClient
from app.core.s2 import calculate_haversine_distance, get_s2_cell_token
from app.schemas.journey import LocationEvidenceInput
from app.services.geofence_service import GeofenceService
from app.repositories.geofence_repository import GeofenceRepository
from app.repositories.station_repository import StationRepository


@pytest.mark.asyncio
async def test_s2_and_haversine_calculations():
    # Borivali (19.2290, 72.8573) to Dadar (19.0192, 72.8438)
    dist = calculate_haversine_distance(19.2290, 72.8573, 19.0192, 72.8438)
    assert 22000.0 < dist < 25000.0

    token_bvi = get_s2_cell_token(19.2290, 72.8573, level=15)
    assert len(token_bvi) >= 4
    # Identical coordinates must produce identical tokens
    assert token_bvi == get_s2_cell_token(19.2290, 72.8573, level=15)


@pytest.mark.asyncio
async def test_geofence_inside_and_outside(client: AsyncClient, authenticated_user_tokens: dict):
    # 1. Fetch stations to obtain real station IDs
    res = await client.get("/api/v1/stations")
    assert res.status_code == 200
    stations = res.json()["data"]
    bvi = next((s for s in stations if s["code"] == "BVI"), stations[0])

    token = authenticated_user_tokens["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Inside Borivali geofence (at station coordinates with 8m accuracy)
    inside_payload = {
        "station_id": bvi["id"],
        "location": {
            "latitude": bvi["latitude"],
            "longitude": bvi["longitude"],
            "accuracy_meters": 8.0,
            "provider": "gps",
            "is_mock": False,
        },
    }
    res_inside = await client.post(
        "/api/v1/journeys/geofence/validate",
        json=inside_payload,
        headers=headers,
    )
    assert res_inside.status_code == 200
    data_inside = res_inside.json()["data"]
    assert data_inside["is_inside"] is True
    assert data_inside["state"] == "INSIDE"
    assert data_inside["distance_meters"] < 5.0
    assert data_inside["confidence"] >= 0.8

    # 3. Outside Borivali geofence (10km away at Colaba)
    outside_payload = {
        "station_id": bvi["id"],
        "location": {
            "latitude": 18.9067,
            "longitude": 72.8147,
            "accuracy_meters": 12.0,
            "provider": "gps",
            "is_mock": False,
        },
    }
    res_outside = await client.post(
        "/api/v1/journeys/geofence/validate",
        json=outside_payload,
        headers=headers,
    )
    assert res_outside.status_code == 200
    data_outside = res_outside.json()["data"]
    assert data_outside["is_inside"] is False
    assert data_outside["state"] == "OUTSIDE"
    assert data_outside["distance_meters"] > 10000.0


@pytest.mark.asyncio
async def test_geofence_low_accuracy_and_boundary_jitter(client: AsyncClient, authenticated_user_tokens: dict):
    res = await client.get("/api/v1/stations")
    stations = res.json()["data"]
    bvi = next((s for s in stations if s["code"] == "BVI"), stations[0])

    token = authenticated_user_tokens["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Low accuracy test: user claims to be at station, but accuracy uncertainty is 400m
    low_acc_payload = {
        "station_id": bvi["id"],
        "location": {
            "latitude": bvi["latitude"],
            "longitude": bvi["longitude"],
            "accuracy_meters": 400.0,
            "provider": "cell",
            "is_mock": False,
        },
    }
    res_low = await client.post(
        "/api/v1/journeys/geofence/validate",
        json=low_acc_payload,
        headers=headers,
    )
    assert res_low.status_code == 200
    data_low = res_low.json()["data"]
    assert data_low["state"] == "LOW_CONFIDENCE"
    assert data_low["is_inside"] is False
    assert data_low["confidence"] < 0.5


@pytest.mark.asyncio
async def test_nearby_station_ambiguity_resolution(client: AsyncClient):
    from tests.conftest import TestingSessionLocal
    async with TestingSessionLocal() as session:
        station_repo = StationRepository(session)
        geofence_repo = GeofenceRepository(session)
        geofence_service = GeofenceService(geofence_repo, station_repo)

        stations = await station_repo.get_all_active()
        if len(stations) >= 2:
            s1 = stations[0]
            s2 = stations[1]
            # Location midway between s1 and s2 with high uncertainty
            mid_lat = (s1.latitude + s2.latitude) / 2.0
            mid_lng = (s1.longitude + s2.longitude) / 2.0

            loc = LocationEvidenceInput(
                latitude=mid_lat,
                longitude=mid_lng,
                accuracy_meters=500.0,
            )
            best_id, is_ambiguous, reason = await geofence_service.check_nearby_station_ambiguity(
                loc,
                [s1.id, s2.id],
            )
            assert best_id in (s1.id, s2.id)
