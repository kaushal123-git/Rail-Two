from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from app.core.database import get_db
from app.core.redis import get_redis
from app.core.config import settings

router = APIRouter(prefix="", tags=["Health"])


@router.get("/health")
async def health_check():
    """Basic health check."""
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
    }


@router.get("/health/ready")
async def readiness_check(
    db: AsyncSession = Depends(get_db),
    redis=Depends(get_redis),
):
    """Deep readiness check validating database and cache connectivity."""
    db_status = "connected"
    try:
        await db.execute(text("SELECT 1"))
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    redis_status = "connected"
    try:
        await redis.ping()
    except Exception as e:
        redis_status = f"unhealthy: {str(e)}"

    is_ready = db_status == "connected" and redis_status == "connected"
    return {
        "status": "ready" if is_ready else "degraded",
        "database": db_status,
        "redis": redis_status,
    }


@router.get("/health/live")
async def liveness_check():
    """Kubernetes / Docker liveness probe."""
    return {"status": "alive"}
