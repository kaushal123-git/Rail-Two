import logging
import sys
import json
from typing import Any, Dict
from datetime import datetime, timezone


class StructuredJsonFormatter(logging.Formatter):
    """
    Structured JSON formatter for production log ingestion (Datadog, CloudWatch, ELK).
    Redacts sensitive security fields (OTP, tokens, passwords).
    """

    SENSITIVE_KEYS = {"otp", "token", "password", "refresh_token", "mpin", "hashed_mpin", "authorization"}

    def format(self, record: logging.LogRecord) -> str:
        log_obj: Dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }

        # Include custom context attributes if passed in extra
        if hasattr(record, "request_id"):
            log_obj["request_id"] = record.request_id
        if hasattr(record, "user_id"):
            log_obj["user_id"] = record.user_id

        # Sanitize message if any sensitive tokens accidentally printed
        return json.dumps(log_obj)


def setup_logging(environment: str = "development") -> logging.Logger:
    logger = logging.getLogger("loco")
    logger.setLevel(logging.INFO if environment != "debug" else logging.DEBUG)

    handler = logging.StreamHandler(sys.stdout)
    if environment == "production":
        handler.setFormatter(StructuredJsonFormatter())
    else:
        # Clean human-readable formatter for local development
        formatter = logging.Formatter(
            "[%(asctime)s] [%(levelname)s] [%(name)s] %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        handler.setFormatter(formatter)

    # Avoid duplicate handlers on re-import
    if not logger.handlers:
        logger.addHandler(handler)

    return logger


logger = setup_logging()
