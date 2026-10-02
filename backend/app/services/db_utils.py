from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.models.user import User


def commit(db: Session) -> None:
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise AppError(409, "This record conflicts with existing data") from exc


def email_taken(db: Session, email: str, ignore_user_id=None) -> bool:
    statement = select(User.id).where(User.email == email)
    if ignore_user_id is not None:
        statement = statement.where(User.id != ignore_user_id)
    return db.scalar(statement) is not None
