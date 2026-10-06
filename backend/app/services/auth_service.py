from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple, Dict, Any
from app.core.config import settings
from app.core.security import (
    create_access_token,
    generate_refresh_token,
    hash_refresh_token,
    hash_secret,
    verify_secret,
)
from app.models.user import User
from app.models.device import Device
from app.models.session import Session
from app.repositories.user_repository import UserRepository
from app.repositories.device_repository import DeviceRepository
from app.repositories.session_repository import SessionRepository
from app.services.otp_service import OtpService


class AuthService:
    def __init__(
        self,
        user_repo: UserRepository,
        device_repo: DeviceRepository,
        session_repo: SessionRepository,
        otp_service: OtpService,
    ):
        self.user_repo = user_repo
        self.device_repo = device_repo
        self.session_repo = session_repo
        self.otp_service = otp_service

    async def authenticate_via_otp(
        self,
        phone_number: str,
        otp: str,
        device_identifier: Optional[str] = None,
        platform: str = "android",
        app_version: Optional[str] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
        """Verify OTP, provision or fetch user, register device, and create authenticated session."""
        # 1. Verify OTP with attempt limits
        is_valid, msg = await self.otp_service.verify_otp(phone_number, otp, purpose="LOGIN")
        if not is_valid:
            return False, msg, None

        # 2. Get or create user
        user = await self.user_repo.get_by_phone(phone_number)
        if not user:
            user = await self.user_repo.create(
                phone_number=phone_number,
                full_name="Commuter",
                phone_verified=True,
            )
        else:
            await self.user_repo.mark_phone_verified(user.id)

        await self.user_repo.update_last_login(user.id)

        # 3. Register or update device
        device_id = None
        if device_identifier:
            device = await self.device_repo.register_or_update(
                user_id=user.id,
                device_identifier=device_identifier,
                platform=platform,
                app_version=app_version,
            )
            device_id = device.id

        # 4. Generate Access and Refresh Tokens
        access_token = create_access_token(
            user_id=user.id,
            phone_number=user.phone_number,
            device_id=device_id,
        )
        refresh_token = generate_refresh_token()
        refresh_hash = hash_refresh_token(refresh_token)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

        # 5. Persist Session
        await self.session_repo.create(
            user_id=user.id,
            device_id=device_id,
            refresh_token_hash=refresh_hash,
            expires_at=refresh_expires,
            ip_hash=ip_address,
            user_agent=user_agent,
        )

        return (
            True,
            "Authentication successful.",
            {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "Bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
                "user": user,
            },
        )

    async def refresh_access_token(
        self, refresh_token: str
    ) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
        """Validate refresh token and issue a fresh access token."""
        token_hash = hash_refresh_token(refresh_token)
        session = await self.session_repo.get_active_by_token_hash(token_hash)
        if not session:
            return False, "Invalid or expired refresh token. Please sign in again.", None

        user = await self.user_repo.get_by_id(session.user_id)
        if not user or user.status != "ACTIVE":
            return False, "User account is suspended or not found.", None

        # Touch session activity
        await self.session_repo.touch(session.id)

        # Issue new access token
        access_token = create_access_token(
            user_id=user.id,
            phone_number=user.phone_number,
            device_id=session.device_id,
        )

        return (
            True,
            "Token refreshed successfully.",
            {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "Bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
                "user": user,
            },
        )

    async def logout(self, refresh_token: str) -> bool:
        """Revoke current refresh session."""
        token_hash = hash_refresh_token(refresh_token)
        session = await self.session_repo.get_active_by_token_hash(token_hash)
        if session:
            return await self.session_repo.revoke_session(session.id)
        return False

    async def logout_all(self, user_id: str) -> int:
        """Revoke all active sessions for user."""
        return await self.session_repo.revoke_all_user_sessions(user_id)

    async def list_user_sessions(self, user_id: str):
        """List all sessions registered for user."""
        return await self.session_repo.get_user_sessions(user_id)

    async def revoke_user_session(self, session_id: str, user_id: str) -> bool:
        """Revoke a specific session owned by user (IDOR safe)."""
        session = await self.session_repo.get_by_id(session_id)
        if not session or session.user_id != user_id:
            return False
        return await self.session_repo.revoke_session(session_id)

    async def set_mpin(self, user_id: str, mpin: str) -> bool:
        """Hash and update 4-digit mPIN."""
        hashed = hash_secret(mpin)
        return await self.user_repo.set_mpin(user_id, hashed)

    async def authenticate_via_mpin(
        self,
        phone_number: str,
        mpin: str,
        device_identifier: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
        """Authenticate user using registered phone number and 4-digit mPIN."""
        user = await self.user_repo.get_by_phone(phone_number)
        if not user or not user.hashed_mpin:
            return False, "User not found or mPIN not set. Please log in via OTP.", None

        if not verify_secret(mpin, user.hashed_mpin):
            return False, "Incorrect security PIN.", None

        await self.user_repo.update_last_login(user.id)

        # Register device if identifier present
        device_id = None
        if device_identifier:
            device = await self.device_repo.register_or_update(
                user_id=user.id,
                device_identifier=device_identifier,
            )
            device_id = device.id

        # Generate tokens and session
        access_token = create_access_token(
            user_id=user.id,
            phone_number=user.phone_number,
            device_id=device_id,
        )
        refresh_token = generate_refresh_token()
        refresh_hash = hash_refresh_token(refresh_token)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

        await self.session_repo.create(
            user_id=user.id,
            device_id=device_id,
            refresh_token_hash=refresh_hash,
            expires_at=refresh_expires,
        )

        return (
            True,
            "mPIN authentication successful.",
            {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "Bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
                "user": user,
            },
        )
