from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


class FareEstimateRequest(BaseModel):
    origin_station_id: str
    destination_station_id: str
    journey_type: str = Field(default="SINGLE", description="SINGLE, RETURN, SEASON")
    ticket_class: str = Field(default="SECOND", description="SECOND, FIRST, AC")
    passenger_count: int = Field(default=1, ge=1, le=6)
    duration: Optional[str] = Field(default="SINGLE", description="SINGLE, MONTHLY, QUARTERLY, HALF_YEARLY, YEARLY")


class FareBreakdown(BaseModel):
    base_fare: float
    distance_km: float
    discount: float
    tax: float
    total_fare: float
    currency: str = "INR"
    fare_rule_version: str = "v1.0"


class FareRuleRead(BaseModel):
    id: str
    origin_zone: str
    destination_zone: str
    journey_type: str
    ticket_class: str
    min_distance_km: float
    max_distance_km: float
    base_fare: float
    per_km_rate: float
    discount_percentage: float
    tax_percentage: float
    active: bool
    version: str

    model_config = ConfigDict(from_attributes=True)
