from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


class StationBase(BaseModel):
    code: str = Field(..., max_length=10)
    name: str = Field(..., max_length=100)
    display_name: str = Field(..., max_length=150)
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    city: str = Field(default="Mumbai", max_length=50)
    zone: str = Field(default="Western", max_length=50)
    is_active: bool = True


class StationCreate(StationBase):
    pass


class StationRead(StationBase):
    model_config = ConfigDict(from_attributes=True)

    id: str


class StationNearbyRead(StationRead):
    distance_km: float
