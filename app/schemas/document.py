import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class DocumentResponse(BaseModel):
    id: uuid.UUID
    workspace_id: uuid.UUID
    filename: str
    file_size: int
    file_type: str
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DocumentProcessingStatusResponse(BaseModel):
    document_id: uuid.UUID
    status: str
    stage: str | None = None
    attempt_count: int = 0
    updated_at: datetime
