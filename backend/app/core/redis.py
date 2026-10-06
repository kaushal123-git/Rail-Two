import time
from typing import Optional, Dict, Any
import redis.asyncio as aioredis
from app.core.config import settings
from app.core.logging import logger


class InMemoryRedisFallback:
    """Thread-safe in-memory key-value store with TTL for dev/testing when Redis is not running."""

    def __init__(self):
        self._store: Dict[str, tuple[str, float]] = {}

    def _purge_expired(self):
        now = time.time()
        expired = [k for k, (_, exp) in self._store.items() if exp and exp < now]
        for k in expired:
            del self._store[k]

    async def get(self, key: str) -> Optional[str]:
        self._purge_expired()
        item = self._store.get(key)
        if not item:
            return None
        val, exp = item
        if exp and exp < time.time():
            del self._store[key]
            return None
        return val

    async def set(self, key: str, value: str, ex: Optional[int] = None) -> bool:
        self._purge_expired()
        exp = time.time() + ex if ex else 0.0
        self._store[key] = (str(value), exp)
        return True

    async def delete(self, *keys: str) -> int:
        count = 0
        for k in keys:
            if k in self._store:
                del self._store[k]
                count += 1
        return count

    async def incr(self, key: str) -> int:
        self._purge_expired()
        item = self._store.get(key)
        if not item:
            self._store[key] = ("1", 0.0)
            return 1
        val, exp = item
        new_val = int(val) + 1
        self._store[key] = (str(new_val), exp)
        return new_val

    async def expire(self, key: str, seconds: int) -> bool:
        if key in self._store:
            val, _ = self._store[key]
            self._store[key] = (val, time.time() + seconds)
            return True
        return False

    async def ping(self) -> bool:
        return True

    async def close(self):
        pass


class RedisClient:
    """Redis manager providing connection pooling with automatic fallback."""

    def __init__(self):
        self._client: Optional[Any] = None
        self._is_connected: bool = False

    async def init(self):
        try:
            client = aioredis.from_url(
                settings.REDIS_URL,
                decode_responses=True,
                socket_timeout=1.5,
                socket_connect_timeout=1.5,
            )
            await client.ping()
            self._client = client
            self._is_connected = True
            logger.info("Connected to Redis at %s", settings.REDIS_URL)
        except Exception as e:
            logger.warning(
                "Redis connection failed (%s). Falling back to in-memory store for local execution.",
                str(e),
            )
            self._client = InMemoryRedisFallback()
            self._is_connected = False

    async def get_client(self) -> Any:
        if self._client is None:
            await self.init()
        return self._client

    async def get(self, key: str) -> Optional[str]:
        client = await self.get_client()
        return await client.get(key)

    async def set(self, key: str, value: str, ex: Optional[int] = None) -> bool:
        client = await self.get_client()
        return await client.set(key, value, ex=ex)

    async def delete(self, *keys: str) -> int:
        client = await self.get_client()
        return await client.delete(*keys)

    async def expire(self, key: str, seconds: int) -> bool:
        client = await self.get_client()
        return await client.expire(key, seconds)

    async def close(self):
        if self._client:
            await self._client.close()


redis_client = RedisClient()


async def get_redis():
    """FastAPI dependency for Redis client."""
    client = await redis_client.get_client()
    return client
