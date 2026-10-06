from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class RouteLegRead(BaseModel):
    leg_index: int
    line_id: Optional[str] = None
    line_code: str
    line_name: str
    line_color: str = "#FF5722"
    from_station_id: str
    from_station_code: str
    from_station_name: str
    to_station_id: str
    to_station_code: str
    to_station_name: str
    station_sequence: List[str] = Field(default_factory=list)
    station_codes: List[str] = Field(default_factory=list)
    duration_seconds: int
    duration_minutes: int
    distance_km: float
    is_transfer: bool = False
    transfer_instructions: Optional[str] = None
    service_type: str = "SLOW"  # SLOW, FAST, AC_FAST, TRANSFER

    model_config = {"from_attributes": True}


class RouteOptionRead(BaseModel):
    route_id: str
    title: str = "FASTEST"  # FASTEST, FEWEST_TRANSFERS, SHORTEST_DISTANCE, ALTERNATIVE
    badge_text: str = "⚡ Fastest"
    origin_station_id: str
    origin_station_code: str
    origin_station_name: str
    destination_station_id: str
    destination_station_code: str
    destination_station_name: str
    total_duration_seconds: int
    total_duration_minutes: int
    total_distance_km: float
    transfers_count: int = 0
    total_stops: int = 0
    legs: List[RouteLegRead] = Field(default_factory=list)
    fare_estimate: int = 10
    ac_fare_estimate: int = 65
    service_status: str = "ACTIVE"
    network_version: str = "1.0.0"
    calculated_at: datetime

    model_config = {"from_attributes": True}


class RouteSearchRequest(BaseModel):
    origin_station_id: str = Field(..., description="Origin station UUID or Code")
    destination_station_id: str = Field(..., description="Destination station UUID or Code")
    departure_time: Optional[datetime] = None
    passenger_count: int = Field(1, ge=1, le=6)
    preferred_class: str = Field("SECOND", description="SECOND, FIRST, AC")
    preferences: str = Field("FASTEST", description="FASTEST, FEWEST_TRANSFERS, SHORTEST_DISTANCE")


class RouteSearchResponse(BaseModel):
    origin_station_id: str
    origin_station_code: str
    origin_station_name: str
    destination_station_id: str
    destination_station_code: str
    destination_station_name: str
    routes: List[RouteOptionRead] = Field(default_factory=list)
    service_alerts: List[str] = Field(default_factory=list)
    network_status: str = "NORMAL"
    is_live_data_available: bool = False
    calculated_at: datetime
