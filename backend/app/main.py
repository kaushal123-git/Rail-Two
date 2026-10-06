import os
import sys
import uuid
import time
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

# Ensure project root is on sys.path for ml package resolution
_backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_root_dir = os.path.dirname(_backend_dir)
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)


from app.core.config import settings
from app.core.logging import logger
from app.core.database import init_db, AsyncSessionLocal
from app.core.redis import redis_client
from app.repositories.station_repository import StationRepository
from app.services.station_service import StationService
from app.api import api_router


class SecurityHeadersAndCorrelationMiddleware(BaseHTTPMiddleware):
    """
    Middleware injecting correlation X-Request-ID and applying OWASP secure headers.
    """

    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        start_time = time.time()

        # Attach request_id to request state for downstream handlers
        request.state.request_id = request_id

        response = await call_next(request)

        duration = round((time.time() - start_time) * 1000, 2)
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Response-Time-Ms"] = str(duration)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["X-XSS-Protection"] = "1; mode=block"

        logger.info(
            "%s %s -> %s (%sms) [req_id=%s]",
            request.method,
            request.url.path,
            response.status_code,
            duration,
            request_id,
        )
        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown lifecycle management."""
    logger.info("Initializing %s v%s in %s mode...", settings.PROJECT_NAME, settings.VERSION, settings.ENVIRONMENT)

    # 1. Initialize tables (safe no-op if Alembic already ran)
    await init_db()

    # 2. Initialize Redis connection with fallback
    await redis_client.init()

    # 3. Seed station registry and fare rules if empty
    async with AsyncSessionLocal() as session:
        from app.repositories.fare_repository import FareRepository
        station_repo = StationRepository(session)
        station_service = StationService(station_repo)
        await station_service.seed_stations_if_empty()

        fare_repo = FareRepository(session)
        await fare_repo.seed_default_fare_rules()

        from app.repositories.network_repository import NetworkRepository
        network_repo = NetworkRepository(session)
        await network_repo.seed_network_graph_if_empty()

        from app.repositories.geofence_repository import GeofenceRepository
        geofence_repo = GeofenceRepository(session)
        await geofence_repo.seed_station_geofences_if_empty()

        # Seed active fraud model version in database if empty
        from app.repositories.fraud_repository import FraudModelVersionRepository
        from app.models.fraud_model_version import FraudModelVersion
        from app.services.fraud_model_service import FraudModelService
        import json

        fraud_model_service = FraudModelService.get_instance()
        fraud_model_repo = FraudModelVersionRepository(session)
        active_version = await fraud_model_repo.get_active()
        if not active_version:
            meta = fraud_model_service.metadata
            v_record = FraudModelVersion(
                model_name=meta.get("model_name", "LOCO Custom ML Fraud Detector"),
                version=meta.get("model_version", "LOCO-FRAUD-v1.0"),
                algorithm=meta.get("algorithm", "GradientBoosting"),
                training_dataset_version=meta.get("training_dataset_version", "LOCO-FRAUD-DATASET-v1.0-CONTROLLED"),
                feature_schema_version=meta.get("feature_schema_version", "LOCO-FRAUD-FEATURE-v1.0"),
                metrics_json=json.dumps(meta.get("metrics", {})),
                thresholds_json=json.dumps(meta.get("thresholds", {})),
                artifact_location="app/ml/models/loco_fraud_v1.0.joblib",
                is_active=True,
            )
            await fraud_model_repo.create(v_record)
            logger.info("Seeded active fraud model version %s in database.", v_record.version)

        await session.commit()

    logger.info("LOCO Backend is ready to serve requests.")
    yield

    # Shutdown
    logger.info("Shutting down %s...", settings.PROJECT_NAME)
    await redis_client.close()


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description=(
        "Production backend for LOCO: Real User. Real Location. Real Ticket. Real Journey. "
        "Provides cryptographic authentication, session rotation, device registration, "
        "spatial station query, and ticket state machine validation."
    ),
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

# 1. Security Headers & Correlation Middleware
app.add_middleware(SecurityHeadersAndCorrelationMiddleware)

# 2. CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_origin_regex=settings.CORS_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)


# Global Exception Handler protecting sensitive stack traces (Section 21)
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    request_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    logger.exception("Unhandled server exception on %s [req_id=%s]: %s", request.url.path, request_id, str(exc))
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "An unexpected error occurred. Our engineering team has been notified.",
                "details": {"request_id": request_id},
            },
        },
    )


# Mount API V1 routes
app.include_router(api_router, prefix=settings.API_V1_STR)
