from pydantic import BaseModel


class RootResponse(BaseModel):
    message: str
    docs: str


class HealthResponse(BaseModel):
    status: str
    service: str
    database: str
