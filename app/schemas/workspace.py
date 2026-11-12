import uuid
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict

class WorkspaceCreate(BaseModel):
    name: str = Field(min_length=2, max_length=150)
    description: str | None = Field(default=None, max_length=500)

class WorkspaceUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=150)
    description: str | None = Field(default=None, max_length=500)

class WorkspaceResponse(BaseModel):
    id: uuid.UUID
    name: str
    description: str | None
    owner_id: uuid.UUID
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)