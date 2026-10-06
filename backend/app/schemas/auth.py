from typing import Optional
from pydantic import BaseModel, Field
from app.schemas.user import UserRead


class OtpRequestSchema(BaseModel):
    phone_number: str = Field(..., pattern=r"^\+?[0-9]{10,15}$", description="E.164 or 10-digit Indian phone number")
    name: Optional[str] = Field("Commuter", max_length=100)
    purpose: str = Field("LOGIN", pattern=r"^(LOGIN|REGISTER|RESET_PIN)$")


class OtpRequestResponse(BaseModel):
    phone_number: str
    purpose: str
    expires_in_seconds: int
    cooldown_seconds: int
    message: str


class OtpVerifySchema(BaseModel):
    phone_number: str = Field(..., pattern=r"^\+?[0-9]{10,15}$")
    otp: str = Field(..., min_length=4, max_length=8)
    device_identifier: Optional[str] = Field(None, max_length=255)
    platform: Optional[str] = Field("android", pattern=r"^(android|ios|web)$")
    app_version: Optional[str] = Field(None, max_length=50)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int
    user: UserRead


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(..., min_length=16)


class MpinSetRequest(BaseModel):
    mpin: str = Field(..., pattern=r"^[0-9]{4}$", description="4-digit security PIN")
    confirm_mpin: str = Field(..., pattern=r"^[0-9]{4}$")


class MpinLoginRequest(BaseModel):
    phone_number: str = Field(..., pattern=r"^\+?[0-9]{10,15}$")
    mpin: str = Field(..., pattern=r"^[0-9]{4}$")
    device_identifier: Optional[str] = Field(None, max_length=255)


class SessionRead(BaseModel):
    id: str
    user_id: str
    device_id: Optional[str] = None
    created_at: Optional[str] = None
    last_used_at: Optional[str] = None
    expires_at: Optional[str] = None
    revoked_at: Optional[str] = None
    is_active: bool = True
