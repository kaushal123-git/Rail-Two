from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict
from app.models.ticket import TicketStatus
from app.schemas.station import StationRead
from app.schemas.fare import FareBreakdown


class TicketCreateRequest(BaseModel):
    origin_station_id: str
    destination_station_id: str
    journey_type: str = Field("SINGLE", pattern=r"^(SINGLE|RETURN|SEASON)$")
    ticket_class: str = Field("SECOND", pattern=r"^(FIRST|SECOND|AC)$")
    passenger_count: int = Field(1, ge=1, le=6)
    duration: Optional[str] = Field("SINGLE")
    idempotency_key: Optional[str] = None


class TicketPrepareRequest(BaseModel):
    origin_station_id: str
    destination_station_id: str
    journey_type: str = Field("SINGLE", pattern=r"^(SINGLE|RETURN|SEASON)$")
    ticket_class: str = Field("SECOND", pattern=r"^(FIRST|SECOND|AC)$")
    passenger_count: int = Field(1, ge=1, le=6)
    duration: Optional[str] = Field("SINGLE")
    idempotency_key: Optional[str] = None


class BookingPreparedResponse(BaseModel):
    booking_id: str
    ticket_id: str
    fare_breakdown: FareBreakdown
    currency: str = "INR"
    status: str
    payment_required: bool = True
    expires_at: datetime


class TicketEventRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    event_type: str
    metadata_json: Optional[str] = None
    created_at: datetime


class TicketRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    provider: str
    provider_ticket_id: Optional[str] = None
    origin_station_id: str
    destination_station_id: str
    origin_station: Optional[StationRead] = None
    destination_station: Optional[StationRead] = None
    journey_type: str
    ticket_class: str
    passenger_count: int
    fare: float
    currency: str = "INR"
    booking_status: str
    payment_status: str
    ticket_status: TicketStatus
    issued_at: Optional[datetime] = None
    valid_from: Optional[datetime] = None
    valid_until: Optional[datetime] = None
    qr_token_id: Optional[str] = None
    created_at: datetime


class TicketTransitionRequest(BaseModel):
    target_status: TicketStatus
    reason: Optional[str] = None


class TicketCancelRequest(BaseModel):
    reason: Optional[str] = Field(default="User initiated cancellation")


class TicketQrResponse(BaseModel):
    ticket_id: str
    qr_token_id: str
    qr_payload: str
    valid_from: Optional[datetime] = None
    valid_until: Optional[datetime] = None
    is_valid: bool


from app.schemas.journey import LocationEvidenceInput


class TicketVerifyRequest(BaseModel):
    ticket_id: Optional[str] = None
    qr_token_id: Optional[str] = None
    qr_token: Optional[str] = None
    origin_station_id: Optional[str] = None
    destination_station_id: Optional[str] = None
    device_id: Optional[str] = None
    location: Optional[LocationEvidenceInput] = None


class TicketVerifyResponse(BaseModel):
    is_valid: bool
    ticket_id: Optional[str] = None
    status: Optional[str] = None
    origin_station: Optional[str] = None
    destination_station: Optional[str] = None
    valid_until: Optional[datetime] = None
    message: str
    fraud_risk_score: Optional[float] = None
    fraud_decision: Optional[str] = None
    fraud_risk_state: Optional[str] = None
