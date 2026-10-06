from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from app.api.deps import get_current_user, get_device_service
from app.models.user import User
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.device import DeviceRegisterRequest, DeviceRead
from app.services.device_service import DeviceService

router = APIRouter(prefix="/devices", tags=["Devices"])


@router.post("/register", response_model=ApiResponse[DeviceRead])
async def register_device(
    payload: DeviceRegisterRequest,
    current_user: User = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
):
    """Register or update device hardware information."""
    device = await device_service.register_device(
        user_id=current_user.id,
        device_identifier=payload.device_identifier,
        platform=payload.platform,
        app_version=payload.app_version,
        os_version=payload.os_version,
        public_key=payload.public_key,
    )
    return ApiResponse(
        success=True,
        message="Device registered successfully.",
        data=DeviceRead.model_validate(device),
    )


@router.get("", response_model=ApiResponse[List[DeviceRead]])
async def list_devices(
    current_user: User = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
):
    """List active devices registered for commuter."""
    devices = await device_service.list_user_devices(current_user.id)
    return ApiResponse(
        success=True,
        data=[DeviceRead.model_validate(d) for d in devices],
    )


@router.delete("/{device_id}", response_model=ApiResponse[bool])
async def revoke_device(
    device_id: str,
    current_user: User = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
):
    """Revoke authorization for a specific device."""
    success = await device_service.revoke_device(device_id, current_user.id)
    if not success:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="NOT_FOUND", message="Device not found or not owned by user."),
        )
    return ApiResponse(
        success=True,
        message="Device revoked successfully.",
        data=True,
    )
