import os
import sys
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

# Add backend directory and project root to sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
project_root = os.path.dirname(backend_dir)
if project_root not in sys.path:
    sys.path.insert(0, project_root)
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)


from sqlalchemy.pool import StaticPool
from app.core.config import settings
from app.core.database import Base, get_db
from app.core.redis import InMemoryRedisFallback, get_redis
from app.main import app
from app.repositories.station_repository import StationRepository
from app.services.station_service import StationService

TEST_DATABASE_URL = "sqlite+aiosqlite:///file:memdb1?mode=memory&cache=shared&uri=true"

test_engine = create_async_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False, "uri": True},
    poolclass=StaticPool,
)

TestingSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

test_redis_store = InMemoryRedisFallback()


async def override_get_db():
    async with TestingSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def override_get_redis():
    return test_redis_store


app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_redis] = override_get_redis


@pytest_asyncio.fixture(scope="session", autouse=True)
async def setup_test_database():
    """Create all tables in memory once for test session and seed stations."""
    import app.models  # noqa: F401
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Seed test stations and fare rules
    async with TestingSessionLocal() as session:
        station_repo = StationRepository(session)
        station_service = StationService(station_repo)
        await station_service.seed_stations_if_empty()

        from app.repositories.fare_repository import FareRepository
        fare_repo = FareRepository(session)
        await fare_repo.seed_default_fare_rules()

        from app.repositories.network_repository import NetworkRepository
        network_repo = NetworkRepository(session)
        await network_repo.seed_network_graph_if_empty()

        from app.repositories.geofence_repository import GeofenceRepository
        geofence_repo = GeofenceRepository(session)
        await geofence_repo.seed_station_geofences_if_empty()

        await session.commit()

    yield



@pytest_asyncio.fixture
async def client():
    """Async HTTP test client."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture
async def authenticated_user_tokens(client: AsyncClient):
    """Fixture providing valid access and refresh tokens for testing."""
    import uuid
    phone = f"98{uuid.uuid4().int % 100000000:08d}"
    # Request OTP
    req_res = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone_number": phone, "name": "Test Commuter", "purpose": "LOGIN"},
    )
    assert req_res.status_code == 200
    msg = req_res.json()["data"]["message"]
    # Extract dev code
    import re
    match = re.search(r"Dev Code:\s*(\d+)", msg)
    assert match, "Dev OTP code must be present in dev response"
    otp = match.group(1)

    verify_res = await client.post(
        "/api/v1/auth/otp/verify",
        json={
            "phone_number": phone,
            "otp": otp,
            "device_identifier": "test-device-uuid-1234",
            "platform": "android",
        },
    )
    assert verify_res.status_code == 200
    data = verify_res.json()["data"]
    return {
        "access_token": data["access_token"],
        "refresh_token": data["refresh_token"],
        "user_id": data["user"]["id"],
        "phone_number": phone,
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
    }
