from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_roles
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.delivery import (
    ArrivalRequest,
    DeliveryConfig,
    DeliveryEventRead,
    FailureRequest,
    ProofRead,
)
from app.services import delivery_service

router = APIRouter(prefix="/deliveries", tags=["deliveries"])


@router.get("/config", response_model=DeliveryConfig)
def delivery_config(_: User = Depends(get_current_user)) -> dict:
    return delivery_service.delivery_config()


@router.get("/events/recent", response_model=list[DeliveryEventRead])
def recent_events(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.ADMIN, UserRole.FLEET_MANAGER)),
) -> list[DeliveryEventRead]:
    return delivery_service.recent_events(db, current_user)


@router.post("/{delivery_id}/arrive", response_model=ProofRead)
def arrive(
    delivery_id: UUID,
    payload: ArrivalRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.DRIVER)),
) -> ProofRead:
    return delivery_service.arrive(db, current_user, delivery_id, payload)


@router.post("/{delivery_id}/fail", response_model=ProofRead)
def fail_delivery(
    delivery_id: UUID,
    payload: FailureRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.DRIVER)),
) -> ProofRead:
    return delivery_service.fail(db, current_user, delivery_id, payload)


@router.post("/{delivery_id}/pod", response_model=ProofRead)
async def submit_pod(
    delivery_id: UUID,
    recipient_name: str = Form(),
    latitude: float = Form(),
    longitude: float = Form(),
    client_operation_id: str = Form(),
    photo: UploadFile = File(),
    signature: UploadFile = File(),
    recipient_phone: str | None = Form(default=None),
    notes: str | None = Form(default=None),
    accuracy: float | None = Form(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.DRIVER)),
) -> ProofRead:
    return delivery_service.submit_pod(
        db,
        current_user,
        delivery_id,
        recipient_name=recipient_name,
        recipient_phone=recipient_phone,
        notes=notes,
        latitude=latitude,
        longitude=longitude,
        accuracy=accuracy,
        photo=await photo.read(),
        photo_type=photo.content_type or "application/octet-stream",
        signature=await signature.read(),
        signature_type=signature.content_type or "application/octet-stream",
        client_operation_id=client_operation_id,
    )


@router.get("/{delivery_id}/pod", response_model=ProofRead)
def get_pod(
    delivery_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ProofRead:
    return delivery_service.proof(db, current_user, delivery_id)


@router.get("/{delivery_id}/pod/photo")
def pod_photo(
    delivery_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    content, content_type = delivery_service.proof_file(db, current_user, delivery_id, "photo")
    return Response(content=content, media_type=content_type)


@router.get("/{delivery_id}/pod/signature")
def pod_signature(
    delivery_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    content, content_type = delivery_service.proof_file(db, current_user, delivery_id, "signature")
    return Response(content=content, media_type=content_type)


@router.get("/{delivery_id}/events", response_model=list[DeliveryEventRead])
def delivery_events(
    delivery_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[DeliveryEventRead]:
    return delivery_service.list_events(db, current_user, delivery_id)
