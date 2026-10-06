import secrets
import hmac
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
import jwt
import bcrypt

from app.core.config import settings


def generate_secure_otp(length: int = 6) -> str:
    """Generate cryptographically secure numeric OTP."""
    # secrets.randbelow is cryptographically secure (uses os.urandom)
    code = "".join(str(secrets.randbelow(10)) for _ in range(length))
    return code


def hash_otp(phone_number: str, otp: str) -> str:
    """
    Hash OTP using HMAC-SHA256 with JWT_SECRET_KEY as pepper and phone as salt.
    Prevents rainbow table attacks and protects stored OTPs.
    """
    salt = phone_number.strip().encode("utf-8")
    key = settings.JWT_SECRET_KEY.encode("utf-8")
    h = hmac.new(key, salt + otp.encode("utf-8"), hashlib.sha256)
    return h.hexdigest()


def verify_otp_hash(phone_number: str, candidate_otp: str, stored_hash: str) -> bool:
    """Verify candidate OTP against stored hash using constant-time comparison."""
    expected_hash = hash_otp(phone_number, candidate_otp)
    return hmac.compare_digest(expected_hash, stored_hash)


def hash_secret(secret_value: str) -> str:
    """Hash password or mPIN using bcrypt with random salt."""
    salt = bcrypt.gensalt(rounds=12)
    hashed = bcrypt.hashpw(secret_value.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def verify_secret(secret_value: str, hashed_value: str) -> bool:
    """Verify candidate password or mPIN against bcrypt hash."""
    try:
        return bcrypt.checkpw(secret_value.encode("utf-8"), hashed_value.encode("utf-8"))
    except Exception:
        return False


def create_access_token(
    user_id: str,
    phone_number: str,
    device_id: Optional[str] = None,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Create short-lived signed JWT access token."""
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    payload = {
        "sub": user_id,
        "phone": phone_number,
        "device_id": device_id,
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "type": "access",
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    """Decode and validate JWT access token."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        if payload.get("type") != "access":
            return None
        return payload
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return None


def generate_refresh_token() -> str:
    """Generate a high-entropy cryptographically secure refresh token string."""
    return secrets.token_urlsafe(64)


def hash_refresh_token(refresh_token: str) -> str:
    """Hash refresh token using SHA-256 for database storage."""
    return hashlib.sha256(refresh_token.encode("utf-8")).hexdigest()
