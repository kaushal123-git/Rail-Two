from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict


class DeviceRegisterRequest(BaseModel):
    device_identifier: str = Field(..., min_length=4, max_length=255)
    platform: str = Field(default="android", pattern=r"^(android|ios|web)$")
    app_version: Optional[str] = Field(None, max_length=50)
    os_version: Optional[str] = Field(None, max_length=50)
    public_key: Optional[str] = None


class DeviceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    device_identifier: str
    platform: str
    app_version: Optional[str] = None
    os_version: Optional[str] = None
    integrity_status: str
    last_seen_at: datetime
    created_at: datetime
    revoked_at: Optional[datetime] = None
