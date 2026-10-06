import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_ticket_creation_and_lifecycle(client: AsyncClient, authenticated_user_tokens):
    headers = authenticated_user_tokens["headers"]

    # 1. Fetch two station IDs (Churchgate and Borivali)
    st_res = await client.get("/api/v1/stations/search?q=Churchgate")
    ccg_id = st_res.json()["data"][0]["id"]

    st_bvi = await client.get("/api/v1/stations/search?q=Borivali")
    bvi_id = st_bvi.json()["data"][0]["id"]

    # 2. Create ticket
    create_res = await client.post(
        "/api/v1/tickets",
        headers=headers,
        json={
            "origin_station_id": ccg_id,
            "destination_station_id": bvi_id,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )
    assert create_res.status_code == 200
    t_body = create_res.json()
    assert t_body["success"] is True
    ticket = t_body["data"]
    ticket_id = ticket["id"]
    assert ticket["ticket_status"] == "CREATED"
    assert ticket["fare"] > 0

    # 3. Valid State Transitions: CREATED -> PAYMENT_PENDING -> PAYMENT_CONFIRMED -> ISSUING -> ISSUED
    transitions = [
        "PAYMENT_PENDING",
        "PAYMENT_CONFIRMED",
        "ISSUING",
        "ISSUED",
    ]
    for target in transitions:
        t_res = await client.post(
            f"/api/v1/tickets/{ticket_id}/transition",
            headers=headers,
            json={"target_status": target, "reason": f"Automated test step {target}"},
        )
        assert t_res.status_code == 200
        assert t_res.json()["data"]["ticket_status"] == target

    # 4. QR should now be available once ISSUED
    qr_res = await client.get(f"/api/v1/tickets/{ticket_id}/qr", headers=headers)
    assert qr_res.status_code == 200
    qr_data = qr_res.json()["data"]
    assert qr_data["is_valid"] is True
    assert "qr_payload" in qr_data

    # 5. Transition to ACTIVE -> IN_JOURNEY -> COMPLETED
    for next_step in ["ACTIVE", "IN_JOURNEY", "COMPLETED"]:
        step_res = await client.post(
            f"/api/v1/tickets/{ticket_id}/transition",
            headers=headers,
            json={"target_status": next_step},
        )
        assert step_res.status_code == 200
        assert step_res.json()["data"]["ticket_status"] == next_step


@pytest.mark.asyncio
async def test_invalid_state_transition_rejected(client: AsyncClient, authenticated_user_tokens):
    headers = authenticated_user_tokens["headers"]

    st_ccg = (await client.get("/api/v1/stations/search?q=Churchgate")).json()["data"][0]["id"]
    st_ddr = (await client.get("/api/v1/stations/search?q=Dadar")).json()["data"][0]["id"]

    # Create ticket in CREATED state
    ticket = (await client.post(
        "/api/v1/tickets",
        headers=headers,
        json={"origin_station_id": st_ccg, "destination_station_id": st_ddr},
    )).json()["data"]

    # Try invalid jump: CREATED -> COMPLETED (Not allowed)
    invalid_res = await client.post(
        f"/api/v1/tickets/{ticket['id']}/transition",
        headers=headers,
        json={"target_status": "COMPLETED"},
    )
    assert invalid_res.json()["success"] is False
    assert invalid_res.json()["error"]["code"] == "INVALID_TRANSITION"


@pytest.mark.asyncio
async def test_authoritative_fare_calculation_endpoint(client: AsyncClient, authenticated_user_tokens):
    headers = authenticated_user_tokens["headers"]

    st_ccg = (await client.get("/api/v1/stations/search?q=Churchgate")).json()["data"][0]["id"]
    st_bvi = (await client.get("/api/v1/stations/search?q=Borivali")).json()["data"][0]["id"]

    # 1. Single Journey Second Class
    single_res = await client.post(
        "/api/v1/tickets/fare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_bvi,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )
    assert single_res.status_code == 200
    single_data = single_res.json()["data"]
    assert single_data["total_fare"] > 0
    assert single_data["currency"] == "INR"

    # 2. Return Journey should be 2x single
    return_res = await client.post(
        "/api/v1/tickets/fare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_bvi,
            "journey_type": "RETURN",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )
    assert return_res.status_code == 200
    assert return_res.json()["data"]["total_fare"] == single_data["total_fare"] * 2

    # 3. First Class should be higher than Second Class
    fc_res = await client.post(
        "/api/v1/tickets/fare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_bvi,
            "journey_type": "SINGLE",
            "ticket_class": "FIRST",
            "passenger_count": 1,
        },
    )
    assert fc_res.status_code == 200
    assert fc_res.json()["data"]["total_fare"] > single_data["total_fare"]

    # 4. Season Ticket (Monthly vs Quarterly)
    season_monthly = await client.post(
        "/api/v1/tickets/fare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_bvi,
            "journey_type": "SEASON",
            "ticket_class": "SECOND",
            "passenger_count": 1,
            "duration": "MONTHLY",
        },
    )
    assert season_monthly.status_code == 200
    monthly_fare = season_monthly.json()["data"]["total_fare"]
    assert monthly_fare > single_data["total_fare"]

    season_quarterly = await client.post(
        "/api/v1/tickets/fare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_bvi,
            "journey_type": "SEASON",
            "ticket_class": "SECOND",
            "passenger_count": 1,
            "duration": "QUARTERLY",
        },
    )
    assert season_quarterly.status_code == 200
    assert season_quarterly.json()["data"]["total_fare"] > monthly_fare

    # 5. Same origin and destination rejected
    same_res = await client.post(
        "/api/v1/tickets/fare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_ccg,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )
    assert same_res.json()["success"] is False
    assert same_res.json()["error"]["code"] == "FARE_CALCULATION_FAILED"
