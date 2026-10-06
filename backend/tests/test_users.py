import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_and_update_my_profile(client: AsyncClient, authenticated_user_tokens):
    headers = authenticated_user_tokens["headers"]

    # 1. Get profile
    res = await client.get("/api/v1/users/me", headers=headers)
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    assert body["data"]["phone_number"] == authenticated_user_tokens["phone_number"]

    # 2. Update profile
    update_res = await client.put(
        "/api/v1/users/me",
        headers=headers,
        json={"full_name": "Aayush Sinha Commuter", "email": "aayush.commuter@gmail.com"},
    )
    assert update_res.status_code == 200
    u_body = update_res.json()
    assert u_body["success"] is True
    assert u_body["data"]["full_name"] == "Aayush Sinha Commuter"
    assert u_body["data"]["email"] == "aayush.commuter@gmail.com"


@pytest.mark.asyncio
async def test_unauthenticated_profile_access_denied(client: AsyncClient):
    res = await client.get("/api/v1/users/me")
    assert res.status_code == 401
