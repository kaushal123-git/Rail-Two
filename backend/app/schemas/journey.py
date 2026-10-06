from typing import List, Optional, Any
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict, field_validator


class LocationEvidenceInput(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0, description="Latitude in degrees")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="Longitude in degrees")
    accuracy_meters: float = Field(..., ge=0.0, description="GPS accuracy in meters")
    altitude: Optional[float] = Field(None, description="Altitude in meters")
    speed_mps: Optional[float] = Field(None, ge=0.0, description="Speed in meters per second")
    bearing: Optional[float] = Field(None, ge=0.0, le=360.0, description="Bearing in degrees")
    timestamp_device: Optional[datetime] = Field(None, description="Device timestamp")
    provider: str = Field("gps", description="Location provider: gps, fused, network")
    is_mock: bool = Field(False, description="Device mock location indicator")
    mock_confidence: float = Field(0.0, ge=0.0, le=1.0, description="Mock location detection confidence")
    location_source: str = Field("device_stream", description="Source: device_stream, batch_upload, journey_start")
    client_event_id: Optional[str] = Field(None, description="Client idempotency / anti-replay nonce")
    device_moving_sensor: Optional[bool] = Field(None, description="Physical sensor movement indicator")


class JourneyStartRequest(BaseModel):
    ticket_id: str = Field(..., description="ID of issued ticket to start journey for")
    location: LocationEvidenceInput = Field(..., description="Current device location evidence")
    route_id: Optional[str] = Field(None, description="Planned route identifier")
    device_id: Optional[str] = Field(None, description="Originating client device identifier")


class JourneyLocationsBatchRequest(BaseModel):
    locations: List[LocationEvidenceInput] = Field(..., min_length=1, max_length=50, description="Batch of chronological location updates")


class JourneyCompleteRequest(BaseModel):
    location: LocationEvidenceInput = Field(..., description="Arrival location evidence at destination")


class JourneyAbandonRequest(BaseModel):
    reason: str = Field("User abandoned journey", description="Reason for abandoning active journey")


class GeofenceValidateRequest(BaseModel):
    station_id: str = Field(..., description="Station ID to validate against")
    location: LocationEvidenceInput = Field(..., description="Location evidence to check against station geofence")


class GeofenceValidationResult(BaseModel):
    station_id: str
    station_name: str
    distance_meters: float
    geofence_radius_meters: float
    accuracy_meters: float
    is_inside: bool
    state: str  # INSIDE, ENTERING, EXITING, OUTSIDE, LOW_CONFIDENCE, AMBIGUOUS
    confidence: float
    uncertainty_margin_meters: float
    message: str


class JourneyRead(BaseModel):
    id: str
    ticket_id: str
    user_id: str
    device_id: str
    origin_station_id: str
    origin_station_name: Optional[str] = None
    destination_station_id: str
    destination_station_name: Optional[str] = None
    route_id: Optional[str] = None
    status: str
    started_at: datetime
    completed_at: Optional[datetime] = None
    current_station_id: Optional[str] = None
    current_station_name: Optional[str] = None
    next_station_id: Optional[str] = None
    next_station_name: Optional[str] = None
    last_validated_station_id: Optional[str] = None
    security_state: str
    location_confidence: float
    risk_score: float
    progress_percent: float = 0.0
    completed_stations_count: int = 0
    total_stations_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class JourneyStatusResponse(BaseModel):
    journey: JourneyRead
    active_signals: List[str] = []
    is_route_deviated: bool = False
    deviation_details: Optional[str] = None


class LocationSecuritySummary(BaseModel):
    journey_id: str
    security_state: str
    risk_score: float
    location_confidence: float
    signals_count: int
    recent_events: List[Any] = []
