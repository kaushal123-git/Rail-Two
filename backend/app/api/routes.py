from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from app.api.deps import get_routing_service
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.routing import (
    RouteSearchRequest,
    RouteSearchResponse,
    RouteOptionRead,
)
from app.services.routing_service import RoutingService


router = APIRouter(prefix="/routes", tags=["Routes"])


@router.post("/search", response_model=ApiResponse[RouteSearchResponse])
async def search_routes(
    request: RouteSearchRequest,
    routing_service: RoutingService = Depends(get_routing_service),
):
    """
    Search and rank optimal railway routes between two stations using the network graph.
    Computes Fastest, Fewest Transfers, and Shortest Distance alternatives.
    """
    try:
        response = await routing_service.search_routes(request)
        return ApiResponse(success=True, data=response)
    except ValueError as e:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="INVALID_ROUTE_REQUEST", message=str(e)),
        )
    except Exception as e:
        from app.core.logging import logger
        logger.error("Route calculation error: %s", e, exc_info=True)
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="ROUTE_CALCULATION_FAILED", message=f"Unable to compute route: {str(e)}"),
        )


@router.get("/search", response_model=ApiResponse[RouteSearchResponse])
async def search_routes_get(
    origin: str = Query(..., description="Origin station code or UUID"),
    destination: str = Query(..., description="Destination station code or UUID"),
    preferences: str = Query("FASTEST", description="FASTEST, FEWEST_TRANSFERS, SHORTEST_DISTANCE"),
    routing_service: RoutingService = Depends(get_routing_service),
):
    """Convenience GET endpoint for route searches."""
    req = RouteSearchRequest(
        origin_station_id=origin,
        destination_station_id=destination,
        preferences=preferences,
    )
    try:
        response = await routing_service.search_routes(req)
        return ApiResponse(success=True, data=response)
    except ValueError as e:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="INVALID_ROUTE_REQUEST", message=str(e)),
        )


@router.get("/{route_id}", response_model=ApiResponse[RouteOptionRead])
async def get_route_by_id(
    route_id: str,
    origin: Optional[str] = Query(None, description="Origin station code"),
    destination: Optional[str] = Query(None, description="Destination station code"),
    routing_service: RoutingService = Depends(get_routing_service),
):
    """Resolve and verify route information by route_id."""
    route = await routing_service.get_route_by_id(
        route_id=route_id,
        origin_code=origin,
        destination_code=destination,
    )
    if not route:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="ROUTE_NOT_FOUND", message="Route ID could not be resolved."),
        )

    return ApiResponse(success=True, data=route)
