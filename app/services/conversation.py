import uuid
from sqlalchemy.orm import Session, selectinload
from app.models.conversation import Conversation
from app.models.message import Message
from datetime import datetime, timezone

def create_conversation(
    db: Session,
    user_id: uuid.UUID,
    workspace_id: uuid.UUID,
    title: str
) -> Conversation:

    conversation = Conversation(
        user_id=user_id,
        workspace_id=workspace_id,
        title=title
    )

    db.add(conversation)
    db.commit()
    db.refresh(conversation)

    return conversation


def get_conversations(
    db: Session,
    user_id: uuid.UUID,
    workspace_id: uuid.UUID
) -> list[Conversation]:

    return db.query(Conversation).filter(
        Conversation.user_id == user_id,
        Conversation.workspace_id == workspace_id
    ).order_by(
        Conversation.updated_at.desc()
    ).all()


def get_conversation(
    db: Session,
    conversation_id: uuid.UUID,
    user_id: uuid.UUID,
    workspace_id: uuid.UUID
) -> Conversation | None:

    return db.query(Conversation).options(
        selectinload(Conversation.messages)
    ).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == user_id,
        Conversation.workspace_id == workspace_id
    ).first()


def delete_conversation(
    db: Session,
    conversation: Conversation
) -> None:

    db.delete(conversation)
    db.commit()


def save_message(
    db: Session,
    conversation: Conversation,
    role: str,
    content: str,
    citations: list[dict] | None = None
) -> Message:

    if role not in {"user", "assistant"}:
        raise ValueError("Invalid message role")

    message = Message(
        conversation_id=conversation.id,
        role=role,
        content=content,
        citations=citations or []
    )

    db.add(message)

    # Update conversation activity timestamp.
    conversation.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(message)

    return message


def get_messages(
    db: Session,
    conversation_id: uuid.UUID
) -> list[Message]:

    return db.query(Message).filter(
        Message.conversation_id == conversation_id
    ).order_by(
        Message.created_at.asc()
    ).all()
