from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.delivery import SyncRequest, SyncResponse
from app.services import delivery_service

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/delivery-actions", response_model=SyncResponse)
def sync_delivery_actions(
    payload: SyncRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SyncResponse:
    return delivery_service.sync_actions(db, current_user, payload)
