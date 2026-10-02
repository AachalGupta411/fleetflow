from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.delivery import DeviceTokenRequest, NotificationRead
from app.services import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationRead])
def list_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list:
    return notification_service.list_notifications(db, current_user)


@router.post("/device-token", status_code=status.HTTP_204_NO_CONTENT)
def register_device_token(
    payload: DeviceTokenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    notification_service.register_token(db, current_user, payload.token, payload.platform)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/device-token", status_code=status.HTTP_204_NO_CONTENT)
def unregister_device_token(
    payload: DeviceTokenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    notification_service.unregister_token(db, current_user, payload.token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
