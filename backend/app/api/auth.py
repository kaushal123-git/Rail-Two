from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.api.deps import get_auth_service, get_otp_service, get_current_user
from app.models.user import User
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.auth import (
    OtpRequestSchema,
    OtpRequestResponse,
    OtpVerifySchema,
    TokenResponse,
    RefreshTokenRequest,
    MpinSetRequest,
    MpinLoginRequest,
    SessionRead,
)
from app.schemas.user import UserRead
from app.services.auth_service import AuthService
from app.services.otp_service import OtpService

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/otp/request", response_model=ApiResponse[OtpRequestResponse])
async def request_otp(
    payload: OtpRequestSchema,
    otp_service: OtpService = Depends(get_otp_service),
):
    """
    Request 6-digit numeric OTP for phone authentication.
    Applies cooldown and rate-limits (max 5/hr).
    """
    success, msg, cooldown, dev_otp = await otp_service.request_otp(
        phone_number=payload.phone_number,
        name=payload.name or "Commuter",
        purpose=payload.purpose,
    )
    if not success:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="RATE_LIMIT_EXCEEDED", message=msg),
        )

    res_data = OtpRequestResponse(
        phone_number=payload.phone_number,
        purpose=payload.purpose,
        expires_in_seconds=300,
        cooldown_seconds=cooldown,
        message=f"{msg} (Dev Code: {dev_otp})" if dev_otp else msg,
    )
    return ApiResponse(success=True, message=msg, data=res_data)


@router.post("/otp/verify", response_model=ApiResponse[TokenResponse])
async def verify_otp(
    payload: OtpVerifySchema,
    request: Request,
    auth_service: AuthService = Depends(get_auth_service),
):
    """
    Verify OTP code, provision/retrieve user, register device, and issue JWT session.
    """
    ip_addr = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent", None)

    success, msg, token_dict = await auth_service.authenticate_via_otp(
        phone_number=payload.phone_number,
        otp=payload.otp,
        device_identifier=payload.device_identifier,
        platform=payload.platform or "android",
        app_version=payload.app_version,
        ip_address=ip_addr,
        user_agent=user_agent,
    )
    if not success or not token_dict:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="INVALID_OTP", message=msg),
        )

    user_read = UserRead.model_validate(token_dict["user"])
    token_response = TokenResponse(
        access_token=token_dict["access_token"],
        refresh_token=token_dict["refresh_token"],
        token_type=token_dict["token_type"],
        expires_in=token_dict["expires_in"],
        user=user_read,
    )
    return ApiResponse(success=True, message="Authentication successful.", data=token_response)


@router.post("/refresh", response_model=ApiResponse[TokenResponse])
async def refresh_token(
    payload: RefreshTokenRequest,
    auth_service: AuthService = Depends(get_auth_service),
):
    """Rotate access token using valid refresh token."""
    success, msg, token_dict = await auth_service.refresh_access_token(payload.refresh_token)
    if not success or not token_dict:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="INVALID_REFRESH_TOKEN", message=msg),
        )

    user_read = UserRead.model_validate(token_dict["user"])
    token_response = TokenResponse(
        access_token=token_dict["access_token"],
        refresh_token=token_dict["refresh_token"],
        token_type=token_dict["token_type"],
        expires_in=token_dict["expires_in"],
        user=user_read,
    )
    return ApiResponse(success=True, message="Token refreshed.", data=token_response)


@router.post("/logout", response_model=ApiResponse[bool])
async def logout(
    payload: RefreshTokenRequest,
    auth_service: AuthService = Depends(get_auth_service),
):
    """Revoke specific refresh session."""
    revoked = await auth_service.logout(payload.refresh_token)
    return ApiResponse(success=True, message="Logged out successfully.", data=revoked)


@router.post("/logout-all", response_model=ApiResponse[int])
async def logout_all(
    current_user: User = Depends(get_current_user),
    auth_service: AuthService = Depends(get_auth_service),
):
    """Revoke all active sessions for current authenticated user."""
    revoked_count = await auth_service.logout_all(current_user.id)
    return ApiResponse(
        success=True,
        message=f"Revoked {revoked_count} active sessions.",
        data=revoked_count,
    )


@router.get("/sessions", response_model=ApiResponse[List[SessionRead]])
async def list_sessions(
    current_user: User = Depends(get_current_user),
    auth_service: AuthService = Depends(get_auth_service),
):
    """List all registered login sessions for authenticated commuter."""
    sessions = await auth_service.list_user_sessions(current_user.id)
    session_list = [
        SessionRead(
            id=s.id,
            user_id=s.user_id,
            device_id=s.device_id,
            created_at=s.created_at.isoformat() if s.created_at else None,
            last_used_at=s.last_used_at.isoformat() if s.last_used_at else None,
            expires_at=s.expires_at.isoformat() if s.expires_at else None,
            revoked_at=s.revoked_at.isoformat() if s.revoked_at else None,
            is_active=s.revoked_at is None,
        )
        for s in sessions
    ]
    return ApiResponse(success=True, data=session_list)


@router.delete("/sessions/{session_id}", response_model=ApiResponse[bool])
async def revoke_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    auth_service: AuthService = Depends(get_auth_service),
):
    """Revoke specific login session (IDOR protected)."""
    revoked = await auth_service.revoke_user_session(session_id, current_user.id)
    if not revoked:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="NOT_FOUND", message="Session not found or not owned by user."),
        )
    return ApiResponse(success=True, message="Session revoked successfully.", data=True)


@router.post("/mpin/set", response_model=ApiResponse[bool])
async def set_mpin(
    payload: MpinSetRequest,
    current_user: User = Depends(get_current_user),
    auth_service: AuthService = Depends(get_auth_service),
):
    """Set or update 4-digit security PIN for authenticated commuter."""
    if payload.mpin != payload.confirm_mpin:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="PIN_MISMATCH", message="mPIN and confirmation do not match."),
        )

    success = await auth_service.set_mpin(current_user.id, payload.mpin)
    return ApiResponse(success=success, message="Security mPIN set successfully.", data=success)


@router.post("/mpin/login", response_model=ApiResponse[TokenResponse])
async def mpin_login(
    payload: MpinLoginRequest,
    auth_service: AuthService = Depends(get_auth_service),
):
    """Fast login via registered phone number and 4-digit security PIN."""
    success, msg, token_dict = await auth_service.authenticate_via_mpin(
        phone_number=payload.phone_number,
        mpin=payload.mpin,
        device_identifier=payload.device_identifier,
    )
    if not success or not token_dict:
        return ApiResponse(
            success=False,
            error=ErrorDetail(code="INVALID_CREDENTIALS", message=msg),
        )

    user_read = UserRead.model_validate(token_dict["user"])
    token_response = TokenResponse(
        access_token=token_dict["access_token"],
        refresh_token=token_dict["refresh_token"],
        token_type=token_dict["token_type"],
        expires_in=token_dict["expires_in"],
        user=user_read,
    )
    return ApiResponse(success=True, message="Login successful.", data=token_response)
