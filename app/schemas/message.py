import uuid
from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.conversation import ConversationResponse

class MessageResponse(BaseModel):
    id: uuid.UUID
    conversation_id: uuid.UUID
    role: str
    content: str
    citations: list[dict[str, Any]]
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ConversationDetailResponse(ConversationResponse):
     messages: list[MessageResponse] = Field(default_factory=list)
