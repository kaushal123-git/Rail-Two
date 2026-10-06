from datetime import datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field, ConfigDict


class PaymentOrderCreate(BaseModel):
    payment_method: str = Field(default="UPI", description="UPI, CARD, NETBANKING, WALLET")
    idempotency_key: Optional[str] = Field(default=None, description="Client idempotency key")


class PaymentOrderResponse(BaseModel):
    payment_id: str
    ticket_id: str
    gateway: str
    gateway_order_id: str
    amount: float
    currency: str
    status: str
    key_id: Optional[str] = None
    notes: Optional[Dict[str, Any]] = None


class PaymentVerifyRequest(BaseModel):
    payment_id: Optional[str] = None
    ticket_id: Optional[str] = None
    gateway_order_id: str
    gateway_payment_id: str
    gateway_signature: str


class PaymentRead(BaseModel):
    id: str
    user_id: str
    ticket_id: str
    gateway: str
    gateway_order_id: Optional[str] = None
    gateway_payment_id: Optional[str] = None
    amount: float
    currency: str
    status: str
    failure_reason: Optional[str] = None
    created_at: datetime
    verified_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
