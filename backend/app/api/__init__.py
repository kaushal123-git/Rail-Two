from fastapi import APIRouter
from app.api.auth import router as auth_router
from app.api.users import router as users_router
from app.api.devices import router as devices_router
from app.api.stations import router as stations_router
from app.api.tickets import router as tickets_router
from app.api.payments import router as payments_router
from app.api.health import router as health_router
from app.api.routes import router as routes_router
from app.api.network import router as network_router
from app.api.journeys import router as journeys_router
from app.api.fraud import router as fraud_router
from app.api.assist import router as assist_router

api_router = APIRouter()

api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(devices_router)
api_router.include_router(stations_router)
api_router.include_router(tickets_router)
api_router.include_router(payments_router)
api_router.include_router(routes_router)
api_router.include_router(network_router)
api_router.include_router(journeys_router)
api_router.include_router(fraud_router)
api_router.include_router(assist_router)
