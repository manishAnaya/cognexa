import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field

class ConversationCreate(BaseModel):
    title: str = Field(
        default="New Conversation",
        min_length=1,
        max_length=255
    )

class ConversationResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    workspace_id: uuid.UUID
    title: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
