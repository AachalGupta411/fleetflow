from uuid import UUID

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User

bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AppError(401, "Not authenticated")
    payload = decode_access_token(credentials.credentials)
    try:
        user_id = UUID(payload["sub"])
    except (KeyError, ValueError) as exc:
        raise AppError(401, "Invalid or expired token") from exc
    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise AppError(401, "Invalid or expired token")
    return user


def require_roles(*roles: UserRole):
    allowed = set(roles)

    def checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in allowed:
            raise AppError(403, "You do not have access to this resource")
        return user

    return checker
