import os
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=True,
        extra="allow",
    )

    PROJECT_NAME: str = "LOCO Railway Platform"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = Field(default="development", validation_alias="ENVIRONMENT")

    # Database Settings
    DATABASE_URL: str = Field(
        default="postgresql+asyncpg://postgres:postgres@localhost:5432/loco_db",
        validation_alias="DATABASE_URL",
    )
    SYNC_DATABASE_URL: str = Field(
        default="postgresql://postgres:postgres@localhost:5432/loco_db",
        validation_alias="SYNC_DATABASE_URL",
    )

    # Redis Settings
    REDIS_URL: str = Field(default="redis://localhost:6379/0", validation_alias="REDIS_URL")

    # Security & JWT Settings
    JWT_SECRET_KEY: str = Field(
        default="loco_prod_jwt_super_secret_signing_key_railway_2026_x89a",
        validation_alias="JWT_SECRET_KEY",
    )
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60  # 1 hour
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30    # 30 days

    # OTP Architecture Settings
    OTP_EXPIRE_MINUTES: int = 5
    OTP_MAX_ATTEMPTS: int = 3
    OTP_RESEND_COOLDOWN_SECONDS: int = 60
    OTP_RATE_LIMIT_PER_HOUR: int = 5
    OTP_PROVIDER: str = Field(default="mock", validation_alias="OTP_PROVIDER")  # "mock" | "twilio" | "smtp"
    OTP_DEV_CODE: Optional[str] = Field(default=None, validation_alias="OTP_DEV_CODE")  # isolated to dev/tests

    # SMS / Email Provider Settings (Optional)
    TWILIO_ACCOUNT_SID: Optional[str] = Field(default=None, validation_alias="TWILIO_ACCOUNT_SID")
    TWILIO_AUTH_TOKEN: Optional[str] = Field(default=None, validation_alias="TWILIO_AUTH_TOKEN")
    TWILIO_PHONE_NUMBER: Optional[str] = Field(default=None, validation_alias="TWILIO_PHONE_NUMBER")

    SMTP_HOST: Optional[str] = Field(default="smtp.gmail.com", validation_alias="SMTP_HOST")
    SMTP_PORT: int = Field(default=587, validation_alias="SMTP_PORT")
    SMTP_USER: Optional[str] = Field(default=None, validation_alias="SMTP_USER")
    SMTP_PASSWORD: Optional[str] = Field(default=None, validation_alias="SMTP_PASSWORD")
    SMTP_FROM_NAME: str = Field(default="LOCO Verification", validation_alias="SMTP_FROM_NAME")

    # Payment Gateway Settings (Phase 2)
    PAYMENT_GATEWAY_PROVIDER: str = Field(default="test", validation_alias="PAYMENT_GATEWAY_PROVIDER")  # "razorpay" | "test"
    PAYMENT_MODE: str = Field(default="test", validation_alias="PAYMENT_MODE")  # "test" | "live"
    RAZORPAY_KEY_ID: Optional[str] = Field(default="rzp_test_loco2026mockkey", validation_alias="RAZORPAY_KEY_ID")
    RAZORPAY_KEY_SECRET: Optional[str] = Field(default="loco_test_secret_key_9921", validation_alias="RAZORPAY_KEY_SECRET")
    RAZORPAY_WEBHOOK_SECRET: Optional[str] = Field(default="loco_webhook_sec_8841", validation_alias="RAZORPAY_WEBHOOK_SECRET")

    # Railway Provider Integration Settings (Phase 2)
    RAILWAY_PROVIDER: str = Field(default="loco_core", validation_alias="RAILWAY_PROVIDER")  # "loco_core" | "uts_stub"
    BOOKING_EXPIRATION_MINUTES: int = 15
    IDEMPOTENCY_EXPIRE_HOURS: int = 24

    # CORS
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://127.0.0.1",
        "http://127.0.0.1:8000",
        "http://10.0.2.2",  # Android emulator host loopback
    ]
    CORS_ORIGIN_REGEX: str = (
        r"^https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(?:1[6-9]|2\d|3[0-1])\.\d+\.\d+)(:\d+)?$"
    )


settings = Settings()
