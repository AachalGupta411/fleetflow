import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.router import api_router
from app.api.routes.health import router as health_router
from app.api.routes.root import router as root_router
from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger("fleetflow")


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="FleetFlow API", version="0.2.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(AppError)
    async def handle_app_error(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})

    @app.exception_handler(Exception)
    async def handle_unexpected(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled error on %s %s", request.method, request.url.path)
        return JSONResponse(
            status_code=500,
            content={"detail": "FleetFlow could not complete that request."},
        )

    app.include_router(root_router)
    app.include_router(health_router)
    app.include_router(api_router)
    return app


app = create_app()
