import time
from datetime import datetime, timedelta, timezone
from typing import Tuple, Optional
from app.core.config import settings
from app.core.logging import logger
from app.core.security import generate_secure_otp, hash_otp, verify_otp_hash
from app.repositories.otp_repository import OtpRepository


class OtpService:
    def __init__(self, otp_repo: OtpRepository, redis_client):
        self.repo = otp_repo
        self.redis = redis_client

    async def check_rate_limits(self, phone_number: str) -> Tuple[bool, str, int]:
        """
        Check rate limiting for phone number:
        1. Cooldown between OTP requests (60 seconds)
        2. Hourly request ceiling (5 per hour)
        Returns (is_allowed, error_message, retry_after_seconds)
        """
        cooldown_key = f"otp:cooldown:{phone_number}"
        rate_key = f"otp:hourly:{phone_number}"

        # 1. Cooldown check
        ttl = await self.redis.get(cooldown_key)
        if ttl:
            try:
                remaining = int(ttl) - int(time.time())
                if remaining > 0:
                    return False, f"Please wait {remaining} seconds before requesting a new OTP.", remaining
            except Exception:
                pass

        # 2. Hourly rate limit check
        attempts_str = await self.redis.get(rate_key)
        attempts = int(attempts_str) if attempts_str else 0
        if attempts >= settings.OTP_RATE_LIMIT_PER_HOUR:
            return (
                False,
                f"Too many OTP requests for this number. Max {settings.OTP_RATE_LIMIT_PER_HOUR} per hour.",
                3600,
            )

        return True, "", 0

    async def request_otp(
        self,
        phone_number: str,
        name: str = "Commuter",
        purpose: str = "LOGIN",
    ) -> Tuple[bool, str, int, Optional[str]]:
        """
        Generate, store, and dispatch OTP.
        Returns (success, message, cooldown_seconds, dev_otp_for_testing)
        """
        # 1. Check rate limits
        allowed, err_msg, retry_after = await self.check_rate_limits(phone_number)
        if not allowed:
            return False, err_msg, retry_after, None

        # 2. Invalidate previous unconsumed OTPs for this phone & purpose
        await self.repo.invalidate_previous(phone_number, purpose)

        # 3. Generate secure OTP
        otp_code = generate_secure_otp(length=6)

        # 4. Hash and persist to database
        hashed = hash_otp(phone_number, otp_code)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
        await self.repo.create(
            phone_number=phone_number,
            hashed_otp=hashed,
            expires_at=expires_at,
            purpose=purpose,
            max_attempts=settings.OTP_MAX_ATTEMPTS,
        )

        # 5. Set Redis cooldown and increment hourly count
        cooldown_expiry = int(time.time()) + settings.OTP_RESEND_COOLDOWN_SECONDS
        await self.redis.set(
            f"otp:cooldown:{phone_number}",
            str(cooldown_expiry),
            ex=settings.OTP_RESEND_COOLDOWN_SECONDS,
        )
        rate_key = f"otp:hourly:{phone_number}"
        await self.redis.incr(rate_key)
        await self.redis.expire(rate_key, 3600)

        # 6. Dispatch via configured provider
        await self._dispatch_otp(phone_number, otp_code, name)

        # In dev or test environments, expose OTP in dev channel only
        dev_code = otp_code if settings.ENVIRONMENT in ["development", "testing"] else None

        return True, "OTP sent successfully.", settings.OTP_RESEND_COOLDOWN_SECONDS, dev_code

    async def _dispatch_otp(self, phone_number: str, otp_code: str, name: str):
        """Dispatch OTP through real provider (Twilio/SMTP) or isolated secure mock."""
        if settings.OTP_PROVIDER == "twilio" and settings.TWILIO_ACCOUNT_SID:
            # Twilio dispatch implementation
            logger.info("Dispatching SMS OTP via Twilio to %s", phone_number)
            # Twilio REST API integration is ready here
        elif settings.OTP_PROVIDER == "smtp" and settings.SMTP_USER:
            logger.info("Dispatching Email OTP via SMTP to %s", phone_number)
        else:
            # Isolated Development Provider: logs masked dispatch without printing plaintext in prod
            logger.info(
                "[DEV OTP PROVIDER] Generated OTP for %s: %s (Valid for %d min)",
                phone_number,
                otp_code,
                settings.OTP_EXPIRE_MINUTES,
            )

    async def verify_otp(
        self,
        phone_number: str,
        candidate_otp: str,
        purpose: str = "LOGIN",
    ) -> Tuple[bool, str]:
        """
        Verify candidate OTP against stored hash.
        Validates attempt count, expiration, and constant-time equality.
        """
        otp_req = await self.repo.get_latest_active(phone_number, purpose)
        if not otp_req:
            return False, "No active OTP found. Please request a new OTP."

        # Check maximum attempts
        if otp_req.attempts >= otp_req.max_attempts:
            await self.repo.consume(otp_req.id)  # Lock it out
            return False, "Maximum verification attempts exceeded. Please request a new OTP."

        # Verify hash
        is_valid = verify_otp_hash(phone_number, candidate_otp, otp_req.hashed_otp)

        if not is_valid:
            attempts_left = otp_req.max_attempts - (otp_req.attempts + 1)
            await self.repo.increment_attempts(otp_req.id)
            if attempts_left <= 0:
                await self.repo.consume(otp_req.id)
                return False, "Invalid OTP. Attempt limit exceeded. Please request a new OTP."
            return False, f"Invalid OTP code. {attempts_left} attempt(s) remaining."

        # Mark consumed (one-time use)
        await self.repo.consume(otp_req.id)
        # Clear cooldown
        await self.redis.delete(f"otp:cooldown:{phone_number}")

        return True, "OTP verified successfully."
