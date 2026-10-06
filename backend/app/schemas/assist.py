from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class AssistContext(BaseModel):
    current_ticket_id: Optional[str] = None
    active_journey_id: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    origin_station_id: Optional[str] = None
    destination_station_id: Optional[str] = None


class AssistChatRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=1000)
    context: Optional[AssistContext] = None
    session_id: Optional[str] = None


class AssistActionPayload(BaseModel):
    action_type: str  # e.g., "PLAN_JOURNEY", "VIEW_TICKET", "CONFIRM_ACTION", "ACTIVATE_GUARDIAN"
    label: str
    target_screen: Optional[str] = None
    parameters: Optional[Dict[str, str]] = None


class AssistChatResponse(BaseModel):
    request_id: str
    text: str
    intent: str
    tool_name: Optional[str] = None
    card_type: str = "TEXT"  # TEXT, ROUTE_CARD, STATION_CARD, TICKET_CARD, JOURNEY_CARD, ALERT_CARD, CONFIRMATION_CARD, ERROR_CARD
    card_data: Optional[Dict[str, Any]] = None
    quick_replies: List[str] = []
    action_payload: Optional[AssistActionPayload] = None
    requires_auth: bool = False


class AssistActionConfirmRequest(BaseModel):
    action_id: str
    confirmation_token: str
    confirmed: bool


class AssistActionConfirmResponse(BaseModel):
    success: bool
    action_type: str
    status: str
    message: str
    details: Optional[Dict[str, Any]] = None


class AssistToolInfo(BaseModel):
    name: str
    description: str
    is_sensitive: bool
    requires_auth: bool
    parameters: Dict[str, Any]
