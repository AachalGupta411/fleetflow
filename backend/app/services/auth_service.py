from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.core.security import create_access_token, hash_password, verify_password
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.auth import RegisterRequest, TokenResponse
from app.schemas.user import UserRead
from app.services.db_utils import commit, email_taken


def login(db: Session, email: str, password: str) -> TokenResponse:
    user = db.scalar(select(User).where(User.email == email.lower()))
    if user is None or not user.is_active or not verify_password(password, user.password_hash):
        raise AppError(401, "Invalid email or password")
    token = create_access_token(user.id, user.role.value)
    return TokenResponse(access_token=token, user=UserRead.model_validate(user))


def register_customer(db: Session, data: RegisterRequest) -> TokenResponse:
    email = data.email.lower()
    if email_taken(db, email):
        raise AppError(409, "Email is already in use")
    user = User(
        name=data.name.strip(),
        email=email,
        phone=data.phone.strip() if data.phone else None,
        password_hash=hash_password(data.password),
        role=UserRole.CUSTOMER,
        is_active=True,
    )
    db.add(user)
    commit(db)
    db.refresh(user)
    token = create_access_token(user.id, user.role.value)
    return TokenResponse(access_token=token, user=UserRead.model_validate(user))
