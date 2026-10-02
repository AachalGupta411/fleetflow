import uuid
from pathlib import Path

import httpx

from app.core.config import BACKEND_ROOT, get_settings
from app.core.errors import AppError

ALLOWED_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}
MAX_BYTES = 5_000_000


class ObjectStorage:
    def save(self, data: bytes, content_type: str, prefix: str) -> str:
        raise NotImplementedError

    def read(self, key: str) -> tuple[bytes, str]:
        raise NotImplementedError


def validate_image(data: bytes, content_type: str, *, signature: bool = False) -> str:
    if not data:
        raise AppError(422, "The file is empty")
    if len(data) > MAX_BYTES:
        raise AppError(422, "The file is larger than 5 MB")
    normalized = content_type.split(";")[0].strip().lower()
    if signature and normalized != "image/png":
        raise AppError(422, "The signature must be a PNG image")
    if normalized not in ALLOWED_TYPES:
        raise AppError(422, "Upload a JPEG, PNG, or WebP image")
    return normalized


class LocalObjectStorage(ObjectStorage):
    def __init__(self, root: Path) -> None:
        self.root = root

    def save(self, data: bytes, content_type: str, prefix: str) -> str:
        extension = ALLOWED_TYPES[content_type]
        key = f"{prefix}/{uuid.uuid4().hex}{extension}"
        path = self._path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return key

    def read(self, key: str) -> tuple[bytes, str]:
        path = self._path(key)
        if not path.is_file():
            raise AppError(404, "Stored file not found")
        extension = path.suffix.lower()
        content_type = next((mime for mime, ext in ALLOWED_TYPES.items() if ext == extension), "application/octet-stream")
        return path.read_bytes(), content_type

    def _path(self, key: str) -> Path:
        relative = Path(key)
        if relative.is_absolute() or ".." in relative.parts:
            raise AppError(422, "Invalid stored file name")
        return self.root / relative


class SupabaseObjectStorage(ObjectStorage):
    def __init__(self, url: str, service_key: str, bucket: str) -> None:
        if not url or not service_key:
            raise AppError(
                503,
                "Supabase storage is not configured. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY, or use STORAGE_PROVIDER=local.",
            )
        self.url = url.rstrip("/")
        self.service_key = service_key
        self.bucket = bucket

    def save(self, data: bytes, content_type: str, prefix: str) -> str:
        extension = ALLOWED_TYPES[content_type]
        key = f"{prefix}/{uuid.uuid4().hex}{extension}"
        response = httpx.post(
            f"{self.url}/storage/v1/object/{self.bucket}/{key}",
            content=data,
            headers={
                "Authorization": f"Bearer {self.service_key}",
                "apikey": self.service_key,
                "Content-Type": content_type,
                "x-upsert": "true",
            },
            timeout=20,
        )
        if response.status_code >= 400:
            raise AppError(502, "The storage service rejected the file")
        return key

    def read(self, key: str) -> tuple[bytes, str]:
        response = httpx.get(
            f"{self.url}/storage/v1/object/{self.bucket}/{key}",
            headers={"Authorization": f"Bearer {self.service_key}", "apikey": self.service_key},
            timeout=20,
        )
        if response.status_code == 404:
            raise AppError(404, "Stored file not found")
        if response.status_code >= 400:
            raise AppError(502, "The storage service could not return the file")
        content_type = response.headers.get("content-type", "application/octet-stream").split(";")[0]
        return response.content, content_type


def get_storage() -> ObjectStorage:
    settings = get_settings()
    provider = settings.storage_provider.strip().lower() or "local"
    if provider == "local":
        root = Path(settings.storage_local_dir) if settings.storage_local_dir else BACKEND_ROOT / "var" / "storage"
        return LocalObjectStorage(root)
    if provider == "supabase":
        return SupabaseObjectStorage(settings.supabase_url, settings.supabase_service_role_key, settings.supabase_bucket)
    raise AppError(503, "STORAGE_PROVIDER must be local or supabase")
