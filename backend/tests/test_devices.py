import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_device_registration_and_revocation(client: AsyncClient, authenticated_user_tokens):
    headers = authenticated_user_tokens["headers"]

    # 1. Register device
    reg_res = await client.post(
        "/api/v1/devices/register",
        headers=headers,
        json={
            "device_identifier": "pixel-7-hardware-uuid-8888",
            "platform": "android",
            "app_version": "1.0.0",
            "os_version": "Android 14",
        },
    )
    assert reg_res.status_code == 200
    reg_data = reg_res.json()
    assert reg_data["success"] is True
    device_id = reg_data["data"]["id"]

    # 2. List devices
    list_res = await client.get("/api/v1/devices", headers=headers)
    assert list_res.status_code == 200
    devices = list_res.json()["data"]
    assert any(d["id"] == device_id for d in devices)

    # 3. Revoke device
    del_res = await client.delete(f"/api/v1/devices/{device_id}", headers=headers)
    assert del_res.status_code == 200
    assert del_res.json()["success"] is True

    # 4. List devices again -> should be filtered out
    list_after = await client.get("/api/v1/devices", headers=headers)
    assert not any(d["id"] == device_id for d in list_after.json()["data"])
