import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_missing_and_invalid_tokens(client: AsyncClient):
    # 1. Missing Authorization header
    res1 = await client.get("/api/v1/users/me")
    assert res1.status_code == 401

    # 2. Malformed token
    res2 = await client.get("/api/v1/users/me", headers={"Authorization": "Bearer not-a-jwt"})
    assert res2.status_code == 401

    # 3. Random forged token
    res3 = await client.get("/api/v1/users/me", headers={"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.fake_signature"})
    assert res3.status_code == 401


@pytest.mark.asyncio
async def test_security_headers_and_correlation_id(client: AsyncClient):
    res = await client.get("/api/v1/health")
    assert res.status_code == 200
    headers = res.headers

    # OWASP Security Headers
    assert headers.get("X-Content-Type-Options") == "nosniff"
    assert headers.get("X-Frame-Options") == "DENY"
    assert "Strict-Transport-Security" in headers
    assert "X-Request-ID" in headers
    assert "X-Response-Time-Ms" in headers
