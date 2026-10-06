import pytest
from httpx import AsyncClient
from app.models.ticket import TicketStatus


async def _create_test_ticket(client: AsyncClient, headers: dict) -> dict:
    stations_res = await client.get("/api/v1/stations")
    stations = stations_res.json()["data"]
    bvi = next((s for s in stations if s["code"] == "BVI"), stations[0])
    ddr = next((s for s in stations if s["code"] == "DDR"), stations[1])

    # 1. Create ticket
    create_res = await client.post(
        "/api/v1/tickets",
        json={
            "origin_station_id": bvi["id"],
            "destination_station_id": ddr["id"],
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
        headers=headers,
    )
    assert create_res.status_code in (200, 201)
    ticket_data = create_res.json()["data"]
    ticket_id = ticket_data["id"]

    # 2. Transition ticket to ISSUED so it is valid for journey start
    from tests.conftest import TestingSessionLocal
    from app.repositories.ticket_repository import TicketRepository
    async with TestingSessionLocal() as session:
        t_repo = TicketRepository(session)
        t = await t_repo.get_by_id(ticket_id)
        t.ticket_status = TicketStatus.ISSUED.value
        await t_repo.update(t)
        await session.commit()

    return {
        "ticket_id": ticket_id,
        "origin_station": bvi,
        "destination_station": ddr,
    }


@pytest.mark.asyncio
async def test_journey_start_success_and_wrong_location(client: AsyncClient, authenticated_user_tokens: dict):
    token = authenticated_user_tokens["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    ticket_info = await _create_test_ticket(client, headers)
    ticket_id = ticket_info["ticket_id"]
    origin = ticket_info["origin_station"]

    # 1. Attempt to start journey with location 15km away from origin (outside geofence)
    wrong_loc_payload = {
        "ticket_id": ticket_id,
        "location": {
            "latitude": 18.9067,
            "longitude": 72.8147,
            "accuracy_meters": 10.0,
            "provider": "gps",
            "is_mock": False,
        },
    }
    reject_res = await client.post("/api/v1/journeys/start", json=wrong_loc_payload, headers=headers)
    assert reject_res.status_code == 200
    reject_data = reject_res.json()
    assert reject_data["success"] is False
    assert reject_data["error"]["code"] == "JOURNEY_START_REJECTED"

    # 2. Start journey with valid location at origin station
    valid_loc_payload = {
        "ticket_id": ticket_id,
        "location": {
            "latitude": origin["latitude"],
            "longitude": origin["longitude"],
            "accuracy_meters": 8.0,
            "provider": "gps",
            "is_mock": False,
        },
    }
    start_res = await client.post("/api/v1/journeys/start", json=valid_loc_payload, headers=headers)
    assert start_res.status_code == 200
    start_data = start_res.json()
    assert start_data["success"] is True
    journey = start_data["data"]
    assert journey["status"] == "ACTIVE"
    assert journey["origin_station_id"] == origin["id"]
    assert journey["security_state"] == "NORMAL"

    # 3. Prevent duplicate active journey for same ticket
    dup_res = await client.post("/api/v1/journeys/start", json=valid_loc_payload, headers=headers)
    assert dup_res.status_code == 200
    dup_data = dup_res.json()
    assert dup_data["success"] is False
    assert dup_data["error"]["code"] == "JOURNEY_START_REJECTED"


@pytest.mark.asyncio
async def test_journey_location_stream_and_station_progress(client: AsyncClient, authenticated_user_tokens: dict):
    token = authenticated_user_tokens["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    ticket_info = await _create_test_ticket(client, headers)
    ticket_id = ticket_info["ticket_id"]
    origin = ticket_info["origin_station"]
    dest = ticket_info["destination_station"]

    # Start journey at origin
    start_res = await client.post(
        "/api/v1/journeys/start",
        json={
            "ticket_id": ticket_id,
            "location": {
                "latitude": origin["latitude"],
                "longitude": origin["longitude"],
                "accuracy_meters": 10.0,
            },
        },
        headers=headers,
    )
    assert start_res.status_code == 200
    journey_id = start_res.json()["data"]["id"]

    # Ingest intermediate location update near intermediate station (e.g. Andheri: 19.1197, 72.8464)
    loc_payload = {
        "latitude": 19.1197,
        "longitude": 72.8464,
        "accuracy_meters": 12.0,
        "provider": "gps",
        "is_mock": False,
    }
    loc_res = await client.post(
        f"/api/v1/journeys/{journey_id}/location",
        json=loc_payload,
        headers=headers,
    )
    assert loc_res.status_code == 200
    loc_data = loc_res.json()["data"]
    assert loc_data["journey"]["status"] == "ACTIVE"

    # Fetch status
    status_res = await client.get(f"/api/v1/journeys/{journey_id}/status", headers=headers)
    assert status_res.status_code == 200
    assert status_res.json()["data"]["journey"]["id"] == journey_id


@pytest.mark.asyncio
async def test_server_controlled_journey_completion(client: AsyncClient, authenticated_user_tokens: dict):
    token = authenticated_user_tokens["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    ticket_info = await _create_test_ticket(client, headers)
    ticket_id = ticket_info["ticket_id"]
    origin = ticket_info["origin_station"]
    dest = ticket_info["destination_station"]

    # 1. Start journey
    start_res = await client.post(
        "/api/v1/journeys/start",
        json={
            "ticket_id": ticket_id,
            "location": {
                "latitude": origin["latitude"],
                "longitude": origin["longitude"],
                "accuracy_meters": 10.0,
            },
        },
        headers=headers,
    )
    assert start_res.status_code == 200
    journey_id = start_res.json()["data"]["id"]

    # 2. Attempt complete journey while NOT at destination (still at origin)
    premature_res = await client.post(
        f"/api/v1/journeys/{journey_id}/complete",
        json={
            "location": {
                "latitude": origin["latitude"],
                "longitude": origin["longitude"],
                "accuracy_meters": 10.0,
            }
        },
        headers=headers,
    )
    assert premature_res.status_code == 200
    premature_data = premature_res.json()
    assert premature_data["success"] is False
    assert premature_data["error"]["code"] == "COMPLETION_VALIDATION_FAILED"

    # 3. Complete journey at actual destination station geofence
    complete_res = await client.post(
        f"/api/v1/journeys/{journey_id}/complete",
        json={
            "location": {
                "latitude": dest["latitude"],
                "longitude": dest["longitude"],
                "accuracy_meters": 10.0,
            }
        },
        headers=headers,
    )
    assert complete_res.status_code == 200
    complete_data = complete_res.json()
    assert complete_data["success"] is True
    assert complete_data["data"]["status"] == "COMPLETED"
    assert complete_data["data"]["progress_percent"] == 100.0


@pytest.mark.asyncio
async def test_journey_abandon_and_batch_locations(client: AsyncClient, authenticated_user_tokens: dict):
    token = authenticated_user_tokens["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    ticket_info = await _create_test_ticket(client, headers)
    ticket_id = ticket_info["ticket_id"]
    origin = ticket_info["origin_station"]

    # Start journey
    start_res = await client.post(
        "/api/v1/journeys/start",
        json={
            "ticket_id": ticket_id,
            "location": {
                "latitude": origin["latitude"],
                "longitude": origin["longitude"],
                "accuracy_meters": 10.0,
            },
        },
        headers=headers,
    )
    journey_id = start_res.json()["data"]["id"]

    # Batch submission
    batch_payload = {
        "locations": [
            {
                "latitude": origin["latitude"] - 0.001,
                "longitude": origin["longitude"],
                "accuracy_meters": 12.0,
            },
            {
                "latitude": origin["latitude"] - 0.002,
                "longitude": origin["longitude"],
                "accuracy_meters": 10.0,
            },
        ]
    }
    batch_res = await client.post(
        f"/api/v1/journeys/{journey_id}/locations/batch",
        json=batch_payload,
        headers=headers,
    )
    assert batch_res.status_code == 200
    assert batch_res.json()["success"] is True

    # Abandon journey
    abandon_res = await client.post(
        f"/api/v1/journeys/{journey_id}/abandon",
        json={"reason": "Emergency stop by passenger"},
        headers=headers,
    )
    assert abandon_res.status_code == 200
    assert abandon_res.json()["data"]["status"] == "ABANDONED"
