import re
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_otp_request_and_verify_flow(client: AsyncClient):
    phone = "919876543211"
    # 1. Request OTP
    res = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone_number": phone, "name": "Aayush Sinha", "purpose": "LOGIN"},
    )
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    assert "data" in body
    assert body["data"]["cooldown_seconds"] > 0

    # Extract Dev OTP
    match = re.search(r"Dev Code:\s*(\d+)", body["data"]["message"])
    assert match is not None
    otp = match.group(1)

    # 2. Verify OTP
    verify_res = await client.post(
        "/api/v1/auth/otp/verify",
        json={
            "phone_number": phone,
            "otp": otp,
            "device_identifier": "device-xyz-100",
            "platform": "android",
        },
    )
    assert verify_res.status_code == 200
    v_body = verify_res.json()
    assert v_body["success"] is True
    data = v_body["data"]
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "Bearer"
    assert data["user"]["phone_number"] == phone
    assert data["user"]["phone_verified"] is True


@pytest.mark.asyncio
async def test_otp_cannot_be_reused(client: AsyncClient):
    phone = "919876543212"
    req_res = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone_number": phone, "name": "Commuter", "purpose": "LOGIN"},
    )
    otp = re.search(r"Dev Code:\s*(\d+)", req_res.json()["data"]["message"]).group(1)

    # 1st Verify -> Success
    res1 = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": phone, "otp": otp},
    )
    assert res1.json()["success"] is True

    # 2nd Verify -> Must fail (one-time use)
    res2 = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": phone, "otp": otp},
    )
    assert res2.json()["success"] is False
    assert res2.json()["error"]["code"] == "INVALID_OTP"


@pytest.mark.asyncio
async def test_otp_invalid_code_decrements_attempts(client: AsyncClient):
    phone = "919876543213"
    await client.post(
        "/api/v1/auth/otp/request",
        json={"phone_number": phone, "name": "Commuter", "purpose": "LOGIN"},
    )

    # Try invalid code
    bad_res = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": phone, "otp": "000000"},
    )
    assert bad_res.json()["success"] is False
    assert "attempt(s) remaining" in bad_res.json()["error"]["message"]


@pytest.mark.asyncio
async def test_token_refresh_and_logout(client: AsyncClient, authenticated_user_tokens):
    refresh_token = authenticated_user_tokens["refresh_token"]

    # 1. Refresh token
    ref_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert ref_res.status_code == 200
    ref_data = ref_res.json()
    assert ref_data["success"] is True
    assert "access_token" in ref_data["data"]

    # 2. Logout
    logout_res = await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refresh_token},
    )
    assert logout_res.status_code == 200
    assert logout_res.json()["success"] is True

    # 3. Refreshing with revoked token must fail
    ref_fail_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert ref_fail_res.json()["success"] is False
    assert ref_fail_res.json()["error"]["code"] == "INVALID_REFRESH_TOKEN"


@pytest.mark.asyncio
async def test_mpin_set_and_login_flow(client: AsyncClient, authenticated_user_tokens):
    headers = authenticated_user_tokens["headers"]
    phone = authenticated_user_tokens["phone_number"]

    # 1. Set mPIN
    set_res = await client.post(
        "/api/v1/auth/mpin/set",
        headers=headers,
        json={"mpin": "4321", "confirm_mpin": "4321"},
    )
    assert set_res.status_code == 200
    assert set_res.json()["success"] is True

    # 2. Login via mPIN
    login_res = await client.post(
        "/api/v1/auth/mpin/login",
        json={"phone_number": phone, "mpin": "4321"},
    )
    assert login_res.status_code == 200
    assert login_res.json()["success"] is True
    assert "access_token" in login_res.json()["data"]

    # 3. Wrong mPIN must fail
    bad_login = await client.post(
        "/api/v1/auth/mpin/login",
        json={"phone_number": phone, "mpin": "9999"},
    )
    assert bad_login.json()["success"] is False
    assert bad_login.json()["error"]["code"] == "INVALID_CREDENTIALS"
