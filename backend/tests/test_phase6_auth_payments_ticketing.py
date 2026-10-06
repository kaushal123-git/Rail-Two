import re
import json
import pytest
from httpx import AsyncClient
from app.services.payment_gateway import get_payment_gateway


@pytest.mark.asyncio
async def test_phase6_otp_full_lifecycle_and_rate_limiting(client: AsyncClient):
    """
    Phase 6: Real OTP Authentication Lifecycle, Attempt Limits, Cooldown, and One-Time Use.
    (Sections 4, 5, 6, 7)
    """
    phone = "919811223344"

    # 1. Request OTP
    req_res = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone_number": phone, "name": "Aditya Verma", "purpose": "LOGIN"},
    )
    assert req_res.status_code == 200
    req_body = req_res.json()
    assert req_body["success"] is True
    assert req_body["data"]["cooldown_seconds"] > 0

    # Extract dev OTP from debug message in testing environment
    match = re.search(r"Dev Code:\s*(\d+)", req_body["data"]["message"])
    assert match is not None, "Dev code should be present in test environment"
    valid_otp = match.group(1)

    # 2. Immediate Repeat Request triggers Cooldown Rate Limit
    repeat_res = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone_number": phone, "name": "Aditya Verma", "purpose": "LOGIN"},
    )
    repeat_body = repeat_res.json()
    assert repeat_body["success"] is False
    assert repeat_body["error"]["code"] == "RATE_LIMIT_EXCEEDED"
    assert "wait" in repeat_body["error"]["message"].lower()

    # 3. Invalid OTP Decrements Attempts
    bad_verify = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": phone, "otp": "000000"},
    )
    bad_body = bad_verify.json()
    assert bad_body["success"] is False
    assert "attempt(s) remaining" in bad_body["error"]["message"]

    # 4. Valid OTP Verification Succeeds and Issues Tokens
    verify_res = await client.post(
        "/api/v1/auth/otp/verify",
        json={
            "phone_number": phone,
            "otp": valid_otp,
            "device_identifier": "device-pixel-8-pro",
            "platform": "android",
            "app_version": "2.4.0",
        },
    )
    assert verify_res.status_code == 200
    verify_body = verify_res.json()
    assert verify_body["success"] is True
    data = verify_body["data"]
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "Bearer"
    assert data["user"]["phone_number"] == phone

    # 5. One-Time Use: Invalidate consumed OTP
    reused_res = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": phone, "otp": valid_otp},
    )
    assert reused_res.json()["success"] is False
    assert reused_res.json()["error"]["code"] == "INVALID_OTP"


@pytest.mark.asyncio
async def test_phase6_session_rotation_and_revocation(client: AsyncClient, authenticated_user_tokens):
    """
    Phase 6: Session Management, Rotation, and Revocation.
    (Sections 7, 8, 12)
    """
    headers = authenticated_user_tokens["headers"]
    refresh_token = authenticated_user_tokens["refresh_token"]

    # 1. Rotate access token via refresh token
    rotate_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert rotate_res.status_code == 200
    rotate_body = rotate_res.json()
    assert rotate_body["success"] is True
    assert "access_token" in rotate_body["data"]

    # 2. List user sessions
    sessions_res = await client.get("/api/v1/auth/sessions", headers=headers)
    assert sessions_res.status_code == 200
    sessions_body = sessions_res.json()
    assert sessions_body["success"] is True
    sessions = sessions_body["data"]
    assert len(sessions) >= 1
    session_id = sessions[0]["id"]
    assert sessions[0]["is_active"] is True

    # 3. Revoke specific session
    revoke_res = await client.delete(f"/api/v1/auth/sessions/{session_id}", headers=headers)
    assert revoke_res.status_code == 200
    assert revoke_res.json()["success"] is True

    # 4. Refresh token with revoked session fails
    stale_refresh = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert stale_refresh.json()["success"] is False
    assert stale_refresh.json()["error"]["code"] == "INVALID_REFRESH_TOKEN"

    # 5. Logout-all revokes all remaining sessions
    logout_all_res = await client.post("/api/v1/auth/logout-all", headers=headers)
    assert logout_all_res.status_code == 200
    assert logout_all_res.json()["success"] is True


@pytest.mark.asyncio
async def test_phase6_payment_order_and_cryptographic_verification(client: AsyncClient, authenticated_user_tokens):
    """
    Phase 6: Server-Authoritative Payments, Idempotency, and Cryptographic Signature Verification.
    (Sections 13, 14, 15, 16, 17, 18)
    """
    headers = authenticated_user_tokens["headers"]

    st_ccg = (await client.get("/api/v1/stations/search?q=Churchgate")).json()["data"][0]["id"]
    st_and = (await client.get("/api/v1/stations/search?q=Andheri")).json()["data"][0]["id"]

    # 1. Authoritative Booking Preparation
    prep_res = await client.post(
        "/api/v1/tickets/prepare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_and,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )
    assert prep_res.status_code == 200
    booking = prep_res.json()["data"]
    ticket_id = booking["booking_id"]
    fare = booking["fare_breakdown"]["total_fare"]
    assert fare > 0

    # 2. Server-Side Payment Order with Idempotency Key
    idempotency_key = f"idemp-p6-order-{ticket_id}"
    order_res = await client.post(
        f"/api/v1/tickets/{ticket_id}/payment",
        headers={**headers, "Idempotency-Key": idempotency_key},
    )
    assert order_res.status_code == 200
    order_data = order_res.json()["data"]
    order_id = order_data["gateway_order_id"]
    assert order_data["amount"] == fare

    # Idempotent re-submission returns identical order
    order_res_dup = await client.post(
        f"/api/v1/tickets/{ticket_id}/payment",
        headers={**headers, "Idempotency-Key": idempotency_key},
    )
    assert order_res_dup.json()["data"]["gateway_order_id"] == order_id

    # 3. Invalid Signature Verification Fails
    tampered_res = await client.post(
        "/api/v1/payments/verify",
        headers=headers,
        json={
            "ticket_id": ticket_id,
            "gateway_order_id": order_id,
            "gateway_payment_id": "pay_tampered_123",
            "gateway_signature": "fake_tampered_hex_sig",
        },
    )
    assert tampered_res.json()["success"] is False
    assert tampered_res.json()["error"]["code"] == "PAYMENT_VERIFICATION_FAILED"

    # 4. Valid Cryptographic Verification Succeeds and Issues Ticket
    gateway = get_payment_gateway()
    payment_id = "pay_valid_p6_789"
    valid_signature = gateway.generate_test_signature(order_id, payment_id)

    verify_res = await client.post(
        "/api/v1/payments/verify",
        headers=headers,
        json={
            "ticket_id": ticket_id,
            "gateway_order_id": order_id,
            "gateway_payment_id": payment_id,
            "gateway_signature": valid_signature,
        },
    )
    assert verify_res.status_code == 200
    verify_body = verify_res.json()
    assert verify_body["success"] is True
    ticket = verify_body["data"]
    assert ticket["ticket_status"] == "ISSUED"
    assert ticket["payment_status"] == "CONFIRMED"
    assert ticket["provider"] == "LOCO_CORE"
    assert ticket["provider_ticket_id"].startswith("LOCO-")
    assert ticket["valid_from"] is not None
    assert ticket["valid_until"] is not None
    assert ticket["qr_token_id"] is not None

    # 5. Idempotent re-verification does not double issue
    dup_verify = await client.post(
        "/api/v1/payments/verify",
        headers=headers,
        json={
            "ticket_id": ticket_id,
            "gateway_order_id": order_id,
            "gateway_payment_id": payment_id,
            "gateway_signature": valid_signature,
        },
    )
    assert dup_verify.status_code == 200
    assert dup_verify.json()["success"] is True


@pytest.mark.asyncio
async def test_phase6_railway_provider_issuance_and_cancellation(client: AsyncClient, authenticated_user_tokens):
    """
    Phase 6: Railway Provider Issuance, Turnstile QR Validation, and Cancellation.
    (Sections 19, 20, 24, 26, 29)
    """
    headers = authenticated_user_tokens["headers"]

    st_ccg = (await client.get("/api/v1/stations/search?q=Churchgate")).json()["data"][0]["id"]
    st_bvi = (await client.get("/api/v1/stations/search?q=Borivali")).json()["data"][0]["id"]

    # 1. Prepare and Issue Ticket
    prep = (await client.post(
        "/api/v1/tickets/prepare",
        headers=headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_bvi,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )).json()["data"]
    ticket_id = prep["booking_id"]

    order = (await client.post(f"/api/v1/tickets/{ticket_id}/payment", headers=headers)).json()["data"]
    order_id = order["gateway_order_id"]
    payment_id = "pay_turnstile_p6"
    sig = get_payment_gateway().generate_test_signature(order_id, payment_id)

    issued = (await client.post(
        "/api/v1/payments/verify",
        headers=headers,
        json={
            "ticket_id": ticket_id,
            "gateway_order_id": order_id,
            "gateway_payment_id": payment_id,
            "gateway_signature": sig,
        },
    )).json()["data"]

    # 2. Turnstile QR Verification with Phase 5 ML Fraud Check
    turnstile_res = await client.post(
        "/api/v1/tickets/verify",
        json={
            "ticket_id": ticket_id,
            "qr_token_id": issued["qr_token_id"],
            "origin_station_id": st_ccg,
            "destination_station_id": st_bvi,
            "device_id": "turnstile_gate_04",
        },
    )
    assert turnstile_res.status_code == 200
    turnstile_body = turnstile_res.json()
    assert turnstile_body["data"]["is_valid"] is True
    assert turnstile_body["data"]["ticket_id"] == ticket_id

    # 3. Ticket Cancellation & Clerkage Refund Calculation
    cancel_res = await client.post(
        f"/api/v1/tickets/{ticket_id}/cancel",
        headers=headers,
        json={"reason": "Meeting rescheduled"},
    )
    assert cancel_res.status_code == 200
    cancel_data = cancel_res.json()["data"]
    assert cancel_data["ticket_status"] == "CANCELLED"

    # 4. Attempting to Cancel already cancelled ticket fails
    recancel_res = await client.post(
        f"/api/v1/tickets/{ticket_id}/cancel",
        headers=headers,
        json={"reason": "Retry cancellation"},
    )
    assert recancel_res.json()["success"] is False
    assert "cannot be cancelled" in recancel_res.json()["error"]["message"]


@pytest.mark.asyncio
async def test_phase6_idor_and_authorization_protection(client: AsyncClient, authenticated_user_tokens):
    """
    Phase 6: IDOR Protection and Cross-User Data Isolation.
    (Sections 32, 33)
    """
    user_a_headers = authenticated_user_tokens["headers"]

    # 1. User A creates and issues a ticket
    st_ccg = (await client.get("/api/v1/stations/search?q=Churchgate")).json()["data"][0]["id"]
    st_ddr = (await client.get("/api/v1/stations/search?q=Dadar")).json()["data"][0]["id"]

    prep = (await client.post(
        "/api/v1/tickets/prepare",
        headers=user_a_headers,
        json={
            "origin_station_id": st_ccg,
            "destination_station_id": st_ddr,
            "journey_type": "SINGLE",
            "ticket_class": "SECOND",
            "passenger_count": 1,
        },
    )).json()["data"]
    user_a_ticket_id = prep["booking_id"]

    order = (await client.post(f"/api/v1/tickets/{user_a_ticket_id}/payment", headers=user_a_headers)).json()["data"]
    order_id = order["gateway_order_id"]
    sig = get_payment_gateway().generate_test_signature(order_id, "pay_idor_test")
    await client.post(
        "/api/v1/payments/verify",
        headers=user_a_headers,
        json={
            "ticket_id": user_a_ticket_id,
            "gateway_order_id": order_id,
            "gateway_payment_id": "pay_idor_test",
            "gateway_signature": sig,
        },
    )

    # 2. Register User B
    user_b_phone = "919777888999"
    otp_res = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone_number": user_b_phone, "name": "User B", "purpose": "LOGIN"},
    )
    dev_otp_b = re.search(r"Dev Code:\s*(\d+)", otp_res.json()["data"]["message"]).group(1)
    verify_b = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": user_b_phone, "otp": dev_otp_b},
    )
    user_b_token = verify_b.json()["data"]["access_token"]
    user_b_headers = {"Authorization": f"Bearer {user_b_token}"}

    # 3. IDOR Attack 1: User B tries to view User A's ticket
    idor_view = await client.get(f"/api/v1/tickets/{user_a_ticket_id}", headers=user_b_headers)
    assert idor_view.json()["success"] is False
    assert idor_view.json()["error"]["code"] == "NOT_FOUND"

    # 4. IDOR Attack 2: User B tries to cancel User A's ticket
    idor_cancel = await client.post(
        f"/api/v1/tickets/{user_a_ticket_id}/cancel",
        headers=user_b_headers,
        json={"reason": "Malicious cancellation attempt"},
    )
    assert idor_cancel.json()["success"] is False
    assert "not found" in idor_cancel.json()["error"]["message"].lower() or "unauthorized" in idor_cancel.json()["error"]["message"].lower()

    # 5. IDOR Attack 3: User B tries to access User A's session
    user_a_sessions = (await client.get("/api/v1/auth/sessions", headers=user_a_headers)).json()["data"]
    user_a_session_id = user_a_sessions[0]["id"]

    idor_session_revoke = await client.delete(
        f"/api/v1/auth/sessions/{user_a_session_id}",
        headers=user_b_headers,
    )
    assert idor_session_revoke.json()["success"] is False
    assert idor_session_revoke.json()["error"]["code"] == "NOT_FOUND"
