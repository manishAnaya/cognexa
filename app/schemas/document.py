from pydantic import BaseModel, ConfigDict
import uuid
from datetime import datetime

class DocumentResponse(BaseModel):
    id: uuid.UUID
    workspace_id: uuid.UUID
    filename: str
    file_size: int
    file_type: str
    status: str
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
