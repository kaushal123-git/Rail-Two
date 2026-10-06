from typing import List, Optional
from fastapi import APIRouter, Depends, Query, HTTPException, status
from app.api.deps import get_routing_service
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.network import (
    RailwayLineRead,
    RailwayServiceRead,
    ServiceUpdateRead,
    NetworkStatusResponse,
)
from app.services.routing_service import RoutingService


router = APIRouter(tags=["Network & Services"])


@router.get("/lines", response_model=ApiResponse[List[RailwayLineRead]])
async def list_lines(
    routing_service: RoutingService = Depends(get_routing_service),
):
    """List all registered railway network lines."""
    lines = await routing_service.list_lines()
    return ApiResponse(success=True, data=lines)


@router.get("/lines/{line_id}", response_model=ApiResponse[RailwayLineRead])
async def get_line(
    line_id: str,
    routing_service: RoutingService = Depends(get_routing_service),
):
    """Fetch railway line by UUID or line code (e.g. WR, CR, HR)."""
    line = await routing_service.get_line_by_id(line_id)
    if not line:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="LINE_NOT_FOUND", message="Railway line not found."),
        )
    return ApiResponse(success=True, data=line)


@router.get("/services/status", response_model=ApiResponse[List[RailwayServiceRead]])
async def get_service_status(
    line_id: Optional[str] = Query(None, description="Filter by railway line ID"),
    routing_service: RoutingService = Depends(get_routing_service),
):
    """Retrieve operational status and scheduled delays across railway services."""
    services = await routing_service.list_services(line_id=line_id)
    return ApiResponse(success=True, data=services)


@router.get("/services/updates", response_model=ApiResponse[List[ServiceUpdateRead]])
async def get_service_updates(
    routing_service: RoutingService = Depends(get_routing_service),
):
    """Retrieve active maintenance blocks, jumbo blocks, and operational bulletins."""
    updates = await routing_service.network_repo.list_active_updates()
    return ApiResponse(
        success=True,
        data=[ServiceUpdateRead.model_validate(u) for u in updates],
    )


@router.get("/network/status", response_model=ApiResponse[NetworkStatusResponse])
async def get_network_status(
    routing_service: RoutingService = Depends(get_routing_service),
):
    """
    Get full railway network operational status, provider synchronization health,
    and active service advisories.
    """
    status_response = await routing_service.get_network_status()
    return ApiResponse(success=True, data=status_response)
