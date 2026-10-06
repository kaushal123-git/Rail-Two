from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class RailwayLineRead(BaseModel):
    id: str
    code: str
    name: str
    display_name: str
    operator: str
    color_code: str
    is_active: bool
    station_count: int = 0

    model_config = {"from_attributes": True}


class StationConnectionRead(BaseModel):
    id: str
    from_station_id: str
    to_station_id: str
    line_id: Optional[str] = None
    sequence: int
    distance_km: float
    scheduled_travel_seconds: int
    is_transfer: bool
    is_active: bool

    model_config = {"from_attributes": True}


class RailwayServiceRead(BaseModel):
    id: str
    line_id: str
    service_code: str
    service_name: str
    direction: str
    status: str
    delay_seconds: int
    source: str
    is_active: bool

    model_config = {"from_attributes": True}


class ServiceUpdateRead(BaseModel):
    id: str
    line_id: Optional[str] = None
    station_id: Optional[str] = None
    title: str
    description: str
    severity: str
    source: str
    effective_from: datetime
    effective_until: Optional[datetime] = None
    is_active: bool

    model_config = {"from_attributes": True}


class ProviderHealthRead(BaseModel):
    provider_name: str
    status: str
    last_successful_sync: Optional[datetime] = None
    last_error: Optional[str] = None
    latency_ms: Optional[int] = None
    is_healthy: bool = False

    model_config = {"from_attributes": True}


class NetworkStatusResponse(BaseModel):
    network_name: str = "Mumbai Suburban Railway Network"
    network_version: str = "1.0.0"
    operational_status: str = "NORMAL"  # NORMAL, DEGRADED, DISRUPTED
    active_lines_count: int = 0
    active_stations_count: int = 0
    active_connections_count: int = 0
    provider_health: List[ProviderHealthRead] = Field(default_factory=list)
    active_updates: List[ServiceUpdateRead] = Field(default_factory=list)
    is_live_data_available: bool = False
    timestamp: datetime
