import uuid
import hashlib
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.logging import logger
from app.models.user import User
from app.api.deps import (
    get_optional_current_user,
    get_current_user,
    get_station_repo,
    get_network_repo,
    get_ticket_repo,
    get_journey_repo,
    get_assistant_repo,
    get_routing_service,
    get_ticket_service,
)
from app.repositories.station_repository import StationRepository
from app.repositories.network_repository import NetworkRepository
from app.repositories.ticket_repository import TicketRepository
from app.repositories.journey_repository import JourneyRepository
from app.repositories.assistant_repository import AssistantRepository
from app.services.routing_service import RoutingService
from app.services.ticket_service import TicketService
from app.services.assist_tools import AssistToolRegistry, AssistToolError
from app.services.assist_router import AssistRouter
from app.services.assist_composer import AssistComposer
from app.schemas.assist import (
    AssistChatRequest,
    AssistChatResponse,
    AssistActionConfirmRequest,
    AssistActionConfirmResponse,
    AssistToolInfo,
)

router = APIRouter(prefix="/assist", tags=["LOCO Assist"])


@router.post("/chat", response_model=AssistChatResponse)
async def chat_with_loco_assist(
    req: AssistChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_current_user),
    station_repo: StationRepository = Depends(get_station_repo),
    network_repo: NetworkRepository = Depends(get_network_repo),
    ticket_repo: TicketRepository = Depends(get_ticket_repo),
    journey_repo: JourneyRepository = Depends(get_journey_repo),
    assistant_repo: AssistantRepository = Depends(get_assistant_repo),
    routing_service: RoutingService = Depends(get_routing_service),
    ticket_service: TicketService = Depends(get_ticket_service),
) -> AssistChatResponse:
    """
    Main LOCO Assist conversational gateway.
    Understands intent, invokes verified backend tools, and composes rich structured answers.
    """
    request_id = str(uuid.uuid4())
    user_id = current_user.id if current_user else None

    # 1. Initialize registry and router
    registry = AssistToolRegistry(
        db=db,
        station_repo=station_repo,
        network_repo=network_repo,
        ticket_repo=ticket_repo,
        journey_repo=journey_repo,
        assistant_repo=assistant_repo,
        routing_service=routing_service,
        ticket_service=ticket_service,
    )
    assist_router = AssistRouter(registry)

    # 2. Route query to verified tools
    routed = await assist_router.route_and_execute(
        query=req.query,
        context=req.context,
        current_user_id=user_id,
    )

    intent = routed["intent"]
    tool_name = routed["tool_name"]
    tool_result = routed["tool_result"]
    error = routed["error"]
    res_status = routed["status"]
    error_code = routed.get("error_code")

    # 3. Audit Logging
    tool_args_hash = None
    if tool_result:
        tool_args_hash = hashlib.sha256(str(tool_result).encode()).hexdigest()[:16]

    try:
        await assistant_repo.create_request_log(
            request_id=request_id,
            query=req.query,
            intent=intent,
            tool_name=tool_name,
            tool_arguments_hash=tool_args_hash,
            result_status=res_status,
            user_id=user_id,
            session_id=req.session_id,
            error_code=error_code,
        )
    except Exception as e:
        logger.warning("Failed to record assistant audit log: %s", str(e))

    # 4. Compose user-facing response with rich cards
    response = AssistComposer.compose(
        request_id=request_id,
        intent=intent,
        tool_name=tool_name,
        tool_result=tool_result,
        error=error,
        status=res_status,
    )

    return response


@router.post("/actions/confirm", response_model=AssistActionConfirmResponse)
async def confirm_assistant_action(
    req: AssistActionConfirmRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    station_repo: StationRepository = Depends(get_station_repo),
    network_repo: NetworkRepository = Depends(get_network_repo),
    ticket_repo: TicketRepository = Depends(get_ticket_repo),
    journey_repo: JourneyRepository = Depends(get_journey_repo),
    assistant_repo: AssistantRepository = Depends(get_assistant_repo),
    routing_service: RoutingService = Depends(get_routing_service),
    ticket_service: TicketService = Depends(get_ticket_service),
) -> AssistActionConfirmResponse:
    """
    Execute or cancel a staged sensitive action requiring explicit user confirmation
    (e.g., ticket cancellation).
    """
    action = await assistant_repo.get_action_by_id(req.action_id)
    if not action or action.confirmation_token != req.confirmation_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid confirmation token or action ID.",
        )

    if action.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Unauthorized: You do not own this action.",
        )

    if not req.confirmed:
        await assistant_repo.update_action_status(action, "CANCELLED")
        return AssistActionConfirmResponse(
            success=True,
            action_type=action.action_type,
            status="CANCELLED",
            message="Action was cancelled by the commuter. Your ticket remains active.",
            details={"action_id": action.id},
        )

    # Initialize registry to execute confirmed action
    registry = AssistToolRegistry(
        db=db,
        station_repo=station_repo,
        network_repo=network_repo,
        ticket_repo=ticket_repo,
        journey_repo=journey_repo,
        assistant_repo=assistant_repo,
        routing_service=routing_service,
        ticket_service=ticket_service,
    )

    try:
        res = await registry.execute_cancel_ticket(
            action_id=req.action_id,
            confirmation_token=req.confirmation_token,
            current_user_id=current_user.id,
        )
        return AssistActionConfirmResponse(
            success=True,
            action_type=action.action_type,
            status="EXECUTED",
            message=res["message"],
            details=res,
        )
    except AssistToolError as ate:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=ate.message,
        )


@router.get("/tools", response_model=List[AssistToolInfo])
async def list_available_tools() -> List[AssistToolInfo]:
    """Catalog of verified LOCO Assist tools and permissions."""
    return [
        AssistToolInfo(
            name="search_station",
            description="Search Mumbai suburban stations by name or code",
            is_sensitive=False,
            requires_auth=False,
            parameters={"query": "str", "limit": "int"},
        ),
        AssistToolInfo(
            name="get_station_details",
            description="Get station details, serving lines, and interchange facilities",
            is_sensitive=False,
            requires_auth=False,
            parameters={"identifier": "str"},
        ),
        AssistToolInfo(
            name="get_nearby_stations",
            description="Find nearest railway stations using GPS coordinates",
            is_sensitive=False,
            requires_auth=False,
            parameters={"latitude": "float", "longitude": "float", "radius_km": "float"},
        ),
        AssistToolInfo(
            name="get_route",
            description="Find verified route options from LOCO Phase 3 routing engine",
            is_sensitive=False,
            requires_auth=False,
            parameters={"origin_query": "str", "destination_query": "str", "preference": "str"},
        ),
        AssistToolInfo(
            name="get_fare",
            description="Authoritatively calculate fare without creating a booking",
            is_sensitive=False,
            requires_auth=False,
            parameters={"origin_query": "str", "destination_query": "str", "ticket_class": "str", "journey_type": "str"},
        ),
        AssistToolInfo(
            name="get_live_route_status",
            description="Get live operational status of suburban lines",
            is_sensitive=False,
            requires_auth=False,
            parameters={"line": "Optional[str]"},
        ),
        AssistToolInfo(
            name="get_service_alerts",
            description="Check verified operational bulletins and mega blocks",
            is_sensitive=False,
            requires_auth=False,
            parameters={"line": "Optional[str]"},
        ),
        AssistToolInfo(
            name="get_ticket",
            description="View digital ticket details (IDOR protected)",
            is_sensitive=False,
            requires_auth=True,
            parameters={"ticket_id": "str"},
        ),
        AssistToolInfo(
            name="get_ticket_status",
            description="Check validity status of a commuter's ticket",
            is_sensitive=False,
            requires_auth=True,
            parameters={"ticket_id": "str"},
        ),
        AssistToolInfo(
            name="get_ticket_history",
            description="List recent commuter tickets",
            is_sensitive=False,
            requires_auth=True,
            parameters={"limit": "int"},
        ),
        AssistToolInfo(
            name="get_journey_status",
            description="Monitor live journey from Journey Guardian",
            is_sensitive=False,
            requires_auth=True,
            parameters={},
        ),
        AssistToolInfo(
            name="get_current_station",
            description="Get commuter current station context",
            is_sensitive=False,
            requires_auth=False,
            parameters={"latitude": "Optional[float]", "longitude": "Optional[float]"},
        ),
        AssistToolInfo(
            name="get_destination",
            description="Get destination station for commuter active journey",
            is_sensitive=False,
            requires_auth=True,
            parameters={},
        ),
        AssistToolInfo(
            name="check_ticket_validity",
            description="Verify ticket expiration against authoritative server time",
            is_sensitive=False,
            requires_auth=True,
            parameters={"ticket_id": "str"},
        ),
        AssistToolInfo(
            name="get_app_help",
            description="Retrieve verified policy and app documentation",
            is_sensitive=False,
            requires_auth=False,
            parameters={"topic": "str"},
        ),
        AssistToolInfo(
            name="get_security_status",
            description="Check user-facing journey safety status (zero fraud secrets leaked)",
            is_sensitive=False,
            requires_auth=True,
            parameters={},
        ),
        AssistToolInfo(
            name="prepare_cancel_ticket",
            description="Stage a ticket cancellation and issue a confirmation challenge",
            is_sensitive=True,
            requires_auth=True,
            parameters={"ticket_id": "str"},
        ),
    ]
