from fastapi import APIRouter

from app.api.routes import (
    analytics,
    auth,
    deliveries,
    drivers,
    fuel,
    notifications,
    operations,
    shipments,
    sync,
    tracking,
    users,
    vehicles,
)

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(drivers.router)
api_router.include_router(vehicles.router)
api_router.include_router(shipments.router)
api_router.include_router(tracking.router)
api_router.include_router(deliveries.router)
api_router.include_router(notifications.router)
api_router.include_router(sync.router)
api_router.include_router(fuel.router)
api_router.include_router(operations.router)
api_router.include_router(analytics.router)
