from datetime import UTC, datetime, timedelta
from uuid import UUID

import bcrypt
import jwt
from jwt import InvalidTokenError

from app.core.config import get_settings
from app.core.errors import AppError

ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except ValueError:
        return False


def create_access_token(user_id: UUID, role: str) -> str:
    settings = get_settings()
    expires = datetime.now(UTC) + timedelta(minutes=settings.jwt_expire_minutes)
    payload = {"sub": str(user_id), "role": role, "exp": expires}
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict:
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
    except InvalidTokenError as exc:
        raise AppError(401, "Invalid or expired token") from exc
    if not payload.get("sub"):
        raise AppError(401, "Invalid or expired token")
    return payload
