from typing import Optional
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field, ConfigDict


class UserBase(BaseModel):
    phone_number: str = Field(..., pattern=r"^\+?[0-9]{10,15}$")
    full_name: str = Field(default="Commuter", max_length=100)
    email: Optional[EmailStr] = None
    profile_image_url: Optional[str] = None


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    full_name: Optional[str] = Field(None, max_length=100)
    email: Optional[EmailStr] = None
    profile_image_url: Optional[str] = None


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    phone_number: str
    phone_verified: bool
    email: Optional[str] = None
    full_name: str
    profile_image_url: Optional[str] = None
    status: str
    rwallet_balance: float
    created_at: datetime
    last_login_at: Optional[datetime] = None
