from fastapi import APIRouter

from app.schemas.system import RootResponse

router = APIRouter(tags=["system"])


@router.get("/", response_model=RootResponse)
def read_root() -> RootResponse:
    return RootResponse(message="FleetFlow API is running", docs="/docs")
