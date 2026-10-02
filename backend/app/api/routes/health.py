from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.system import HealthResponse
from app.services.health import database_is_connected

router = APIRouter(tags=["system"])

SERVICE_NAME = "FleetFlow API"


@router.get(
    "/health",
    response_model=HealthResponse,
    responses={503: {"model": HealthResponse}},
)
def read_health(db: Session = Depends(get_db)) -> JSONResponse:
    connected = database_is_connected(db)
    payload = HealthResponse(
        status="ok" if connected else "unavailable",
        service=SERVICE_NAME,
        database="connected" if connected else "disconnected",
    )
    return JSONResponse(
        status_code=200 if connected else 503,
        content=payload.model_dump(),
    )
