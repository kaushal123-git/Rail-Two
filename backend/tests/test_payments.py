import json
import hmac
import hashlib
import pytest
from httpx import AsyncClient
from app.core.config import settings
from app.services.payment_gateway import get_payment_gateway


@pytest.mark.asyncio
async def test_booking_preparation_authoritative_fare(client: AsyncClient, authenticated_user_tokens):
    headers = authenticated_user_tokens["headers"]

    # Fetch Churchgate and Borivali
    st_ccg = (await client.get("/api/v1/stations/search?q=Churchgate")).json()["data"][0]["id"]
    st_bvi = (await client.get("/api/v1/stations/search?q=Borivali")).json()["data"][0]["id"]

    # 1. Prepare booking for 1 passenger, SECOND class
    prep_res = await client.post(
        "/api/v1/tickets/prepare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_bvi,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )
    assert prep_res.status_code == 200
    prep_data = prep_res.json()["data"]
    assert prep_data["booking_id"] is not None
    assert prep_data["payment_required"] is True
    assert prep_data["fare_breakdown"]["total_fare"] > 0
    single_fare = prep_data["fare_breakdown"]["total_fare"]

    # 2. Prepare booking for 2 passengers, SECOND class -> should be approximately 2x
    prep_2pax = await client.post(
        "/api/v1/tickets/prepare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_bvi,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 2,
        },
    )
    assert prep_2pax.status_code == 200
    assert prep_2pax.json()["data"]["fare_breakdown"]["total_fare"] == single_fare * 2

    # 3. Same origin and destination rejected
    same_res = await client.post(
        "/api/v1/tickets/prepare",
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
    assert same_res.json()["error"]["code"] == "BOOKING_PREPARATION_FAILED"


@pytest.mark.asyncio
async def test_payment_order_and_verification_flow(client: AsyncClient, authenticated_user_tokens):
    headers = authenticated_user_tokens["headers"]

    st_ccg = (await client.get("/api/v1/stations/search?q=Churchgate")).json()["data"][0]["id"]
    st_ddr = (await client.get("/api/v1/stations/search?q=Dadar")).json()["data"][0]["id"]

    # 1. Prepare booking
    prep = (await client.post(
        "/api/v1/tickets/prepare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_ddr,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )).json()["data"]
    ticket_id = prep["booking_id"]

    # 2. Create Payment Order
    order_res = await client.post(
        f"/api/v1/tickets/{ticket_id}/payment",
        headers={**headers, "Idempotency-Key": f"test-order-{ticket_id}"},
    )
    assert order_res.status_code == 200
    order_data = order_res.json()["data"]
    gateway_order_id = order_data["gateway_order_id"]
    assert "order_" in gateway_order_id.lower()
    assert order_data["currency"] == "INR"

    # Idempotent re-request returns same gateway order
    order_res2 = await client.post(
        f"/api/v1/tickets/{ticket_id}/payment",
        headers={**headers, "Idempotency-Key": f"test-order-{ticket_id}"},
    )
    assert order_res2.json()["data"]["gateway_order_id"] == gateway_order_id

    # 3. Test Invalid Signature Rejection
    invalid_verify = await client.post(
        "/api/v1/payments/verify",
        headers=headers,
        json={
            "ticket_id": ticket_id,
            "gateway_order_id": gateway_order_id,
            "gateway_payment_id": "pay_test_12345",
            "gateway_signature": "invalid_tampered_signature",
        },
    )
    assert invalid_verify.json()["success"] is False
    assert invalid_verify.json()["error"]["code"] == "PAYMENT_VERIFICATION_FAILED"

    # 4. Generate Valid HMAC Signature using configured test gateway
    payment_id = "pay_test_98765"
    from app.services.payment_gateway import get_payment_gateway
    gateway = get_payment_gateway()
    valid_signature = gateway.generate_test_signature(gateway_order_id, payment_id)

    # 5. Verify payment with valid signature
    valid_verify = await client.post(
        "/api/v1/payments/verify",
        headers=headers,
        json={
            "ticket_id": ticket_id,
            "gateway_order_id": gateway_order_id,
            "gateway_payment_id": payment_id,
            "gateway_signature": valid_signature,
        },
    )
    assert valid_verify.status_code == 200
    issued_ticket = valid_verify.json()["data"]
    assert issued_ticket["ticket_status"] == "ISSUED"
    assert issued_ticket["payment_status"] in ["CONFIRMED", "CAPTURED"]
    assert issued_ticket["qr_token_id"] is not None
    assert issued_ticket["valid_from"] is not None
    assert issued_ticket["valid_until"] is not None

    # 6. Verify Ticket via QR verification endpoint
    qr_verify = await client.post(
        "/api/v1/tickets/verify",
        json={
            "ticket_id": ticket_id,
            "qr_token_id": issued_ticket["qr_token_id"],
            "origin_station_id": st_ccg,
            "destination_station_id": st_ddr,
        },
    )
    assert qr_verify.status_code == 200
    assert qr_verify.json()["data"]["is_valid"] is True
    assert qr_verify.json()["data"]["ticket_id"] == ticket_id

    # 7. Check ticket appears in /tickets/active
    active_res = await client.get("/api/v1/tickets/active", headers=headers)
    assert active_res.status_code == 200
    active_ids = [t["id"] for t in active_res.json()["data"]]
    assert ticket_id in active_ids

    # 8. Cancel ticket
    cancel_res = await client.post(
        f"/api/v1/tickets/{ticket_id}/cancel",
        headers=headers,
        json={"reason": "Plans changed"},
    )
    assert cancel_res.status_code == 200
    assert cancel_res.json()["data"]["ticket_status"] == "CANCELLED"

    # Ticket should now be in /tickets/history
    history_res = await client.get("/api/v1/tickets/history", headers=headers)
    assert history_res.status_code == 200
    history_ids = [t["id"] for t in history_res.json()["data"]]
    assert ticket_id in history_ids


@pytest.mark.asyncio
async def test_payment_webhook_processing(client: AsyncClient, authenticated_user_tokens):
    headers = authenticated_user_tokens["headers"]

    st_ccg = (await client.get("/api/v1/stations/search?q=Churchgate")).json()["data"][0]["id"]
    st_ddr = (await client.get("/api/v1/stations/search?q=Dadar")).json()["data"][0]["id"]

    # 1. Prepare booking & order
    prep = (await client.post(
        "/api/v1/tickets/prepare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_ddr,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )).json()["data"]
    ticket_id = prep["booking_id"]

    order = (await client.post(
        f"/api/v1/tickets/{ticket_id}/payment",
        headers=headers,
    )).json()["data"]
    order_id = order["gateway_order_id"]

    # 2. Construct Webhook Payload for payment.captured
    webhook_payload = {
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "id": f"pay_webhook_{ticket_id[:8]}",
                    "order_id": order_id,
                    "amount": int(prep["fare_breakdown"]["total_fare"] * 100),
                    "currency": "INR",
                    "status": "captured",
                }
            }
        },
    }
    payload_bytes = json.dumps(webhook_payload).encode()
    gateway = get_payment_gateway()
    webhook_secret = getattr(gateway, "webhook_secret", None) or getattr(gateway, "secret", "loco_test_secret_key_9921")
    webhook_signature = hmac.new(
        webhook_secret.encode(),
        payload_bytes,
        hashlib.sha256,
    ).hexdigest()

    # 3. Deliver Webhook
    wh_res = await client.post(
        "/api/v1/payments/webhook",
        content=payload_bytes,
        headers={
            "Content-Type": "application/json",
            "X-Razorpay-Signature": webhook_signature,
            "Idempotency-Key": f"wh-{ticket_id}",
        },
    )
    assert wh_res.status_code == 200
    assert wh_res.json()["success"] is True

    # 4. Verify ticket was issued by webhook
    ticket_res = await client.get(f"/api/v1/tickets/{ticket_id}", headers=headers)
    assert ticket_res.status_code == 200
    assert ticket_res.json()["data"]["ticket_status"] == "ISSUED"
    assert ticket_res.json()["data"]["payment_status"] in ["CONFIRMED", "CAPTURED"]

    # 5. Redeliver same webhook (idempotency check) -> must succeed without error
    wh_res_duplicate = await client.post(
        "/api/v1/payments/webhook",
        content=payload_bytes,
        headers={
            "Content-Type": "application/json",
            "X-Razorpay-Signature": webhook_signature,
            "Idempotency-Key": f"wh-{ticket_id}",
        },
    )
    assert wh_res_duplicate.status_code == 200
    assert wh_res_duplicate.json()["success"] is True


@pytest.mark.asyncio
async def test_ticket_ownership_authorization(client: AsyncClient, authenticated_user_tokens):
    headers_user1 = authenticated_user_tokens["headers"]

    # Register second user
    req_res = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone_number": "9800000002", "name": "Second Commuter", "purpose": "LOGIN"},
    )
    import re
    msg = req_res.json()["data"]["message"]
    otp = re.search(r"Dev Code:\s*(\d+)", msg).group(1)
    verify_res = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": "9800000002", "otp": otp, "device_identifier": "device-user2-99"},
    )
    assert verify_res.status_code == 200
    token_user2 = verify_res.json()["data"]["access_token"]
    headers_user2 = {"Authorization": f"Bearer {token_user2}"}

    # User 1 creates ticket
    st_ccg = (await client.get("/api/v1/stations/search?q=Churchgate")).json()["data"][0]["id"]
    st_ddr = (await client.get("/api/v1/stations/search?q=Dadar")).json()["data"][0]["id"]
    ticket_user1 = (await client.post(
        "/api/v1/tickets/prepare",
        headers=headers_user1,
        json={"origin_station_id": st_ccg, "destination_station_id": st_ddr},
    )).json()["data"]["booking_id"]

    # User 2 attempts to fetch User 1's ticket -> Unauthorized / Not Found
    res = await client.get(f"/api/v1/tickets/{ticket_user1}", headers=headers_user2)
    assert res.json()["success"] is False
    assert res.json()["error"]["code"] == "NOT_FOUND"

    # User 2 attempts to create payment order for User 1's ticket -> Rejected
    pay_order_res = await client.post(f"/api/v1/tickets/{ticket_user1}/payment", headers=headers_user2)
    assert pay_order_res.json()["success"] is False
    assert pay_order_res.json()["error"]["code"] == "PAYMENT_ORDER_FAILED"
