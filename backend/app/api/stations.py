from typing import List, Optional
from fastapi import APIRouter, Depends, Query, HTTPException, status
from app.api.deps import get_station_service, get_network_repo
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.station import StationRead, StationNearbyRead
from app.services.station_service import StationService

router = APIRouter(prefix="/stations", tags=["Stations"])


@router.get("", response_model=ApiResponse[List[StationRead]])
async def list_stations(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    zone: Optional[str] = Query(None, description="Western, Central, Harbour"),
    station_service: StationService = Depends(get_station_service),
):
    """List railway stations with optional zone filter and pagination."""
    stations = await station_service.list_stations(skip=skip, limit=limit, zone=zone)
    return ApiResponse(
        success=True,
        data=[StationRead.model_validate(s) for s in stations],
    )


@router.get("/search", response_model=ApiResponse[List[StationRead]])
async def search_stations(
    q: str = Query(..., min_length=1, max_length=50, description="Station name or code"),
    limit: int = Query(20, ge=1, le=50),
    station_service: StationService = Depends(get_station_service),
):
    """Case-insensitive search by station name or railway code."""
    stations = await station_service.search_stations(query=q, limit=limit)
    return ApiResponse(
        success=True,
        data=[StationRead.model_validate(s) for s in stations],
    )


@router.get("/nearby", response_model=ApiResponse[List[StationNearbyRead]])
async def get_nearby_stations(
    lat: float = Query(..., ge=-90.0, le=90.0, description="GPS Latitude"),
    lng: float = Query(..., ge=-180.0, le=180.0, description="GPS Longitude"),
    radius_km: float = Query(10.0, ge=0.5, le=50.0, description="Search radius in kilometers"),
    limit: int = Query(10, ge=1, le=30),
    station_service: StationService = Depends(get_station_service),
):
    """Find nearest railway stations using great-circle Haversine coordinates."""
    results = await station_service.get_nearby_stations(
        latitude=lat,
        longitude=lng,
        radius_km=radius_km,
        limit=limit,
    )
    data = []
    for station, dist in results:
        item = StationNearbyRead(
            id=station.id,
            code=station.code,
            name=station.name,
            display_name=station.display_name,
            latitude=station.latitude,
            longitude=station.longitude,
            city=station.city,
            zone=station.zone,
            is_active=station.is_active,
            distance_km=dist,
        )
        data.append(item)

    return ApiResponse(success=True, data=data)


@router.get("/{station_id}", response_model=ApiResponse[StationRead])
async def get_station(
    station_id: str,
    station_service: StationService = Depends(get_station_service),
):
    """Fetch station by UUID or code."""
    station = await station_service.get_station_by_id(station_id)
    if not station:
        station = await station_service.get_station_by_code(station_id)
    if not station:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="NOT_FOUND", message="Station not found."),
        )

    return ApiResponse(
        success=True,
        data=StationRead.model_validate(station),
    )


@router.get("/{station_id}/connections", response_model=ApiResponse)
async def get_station_connections(
    station_id: str,
    station_service: StationService = Depends(get_station_service),
    network_repo = Depends(get_network_repo),
):
    """Fetch all track connections and interchanges departing or arriving at this station."""
    from app.schemas.network import StationConnectionRead

    st = await station_service.get_station_by_id(station_id)
    if not st:
        st = await station_service.get_station_by_code(station_id)
    if not st:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="NOT_FOUND", message="Station not found."),
        )

    conns = await network_repo.get_station_connections(st.id)
    return ApiResponse(
        success=True,
        data=[StationConnectionRead.model_validate(c) for c in conns],
    )

