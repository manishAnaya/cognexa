import logging
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.workspace import Workspace
from app.models.documents import Document
from app.schemas.conversation import (
    ConversationCreate,
    ConversationResponse
)
from app.schemas.message import (
    ConversationDetailResponse,
    MessageResponse
)
from app.services.conversation import (
    create_conversation,
    get_conversations,
    get_conversation,
    delete_conversation,
    get_messages,
    save_message,
)
from app.schemas.chat import ChatRequest, ChatResponse
from app.graphs.rag_graph import rag_graph

router = APIRouter(
    prefix="/workspaces/{workspace_id}/conversations",
    tags=["Conversations"]
)
logger = logging.getLogger(__name__)


def verify_workspace(
    db: Session,
    workspace_id: uuid.UUID,
    user_id: uuid.UUID
):
    workspace = db.query(Workspace).filter(
        Workspace.id == workspace_id,
        Workspace.owner_id == user_id
    ).first()

    if not workspace:
        raise HTTPException(404, "Workspace not found")

    return workspace


@router.post("/", response_model=ConversationResponse, status_code=201)
def create_new_conversation(
    workspace_id: uuid.UUID,
    data: ConversationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_workspace(db, workspace_id, current_user.id)

    return create_conversation(
        db=db,
        user_id=current_user.id,
        workspace_id=workspace_id,
        title=data.title
    )


@router.get("/", response_model=list[ConversationResponse])
def list_conversations(
    workspace_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_workspace(db, workspace_id, current_user.id)

    return get_conversations(
        db,
        current_user.id,
        workspace_id
    )


@router.get("/{conversation_id}", response_model=ConversationDetailResponse)
def read_conversation(
    workspace_id: uuid.UUID,
    conversation_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_workspace(db, workspace_id, current_user.id)

    conversation = get_conversation(
        db,
        conversation_id,
        current_user.id,
        workspace_id
    )

    if not conversation:
        raise HTTPException(404, "Conversation not found")

    return conversation


@router.get("/{conversation_id}/messages", response_model=list[MessageResponse])
def list_conversation_messages(
    workspace_id: uuid.UUID,
    conversation_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_workspace(db, workspace_id, current_user.id)

    conversation = get_conversation(
        db,
        conversation_id,
        current_user.id,
        workspace_id
    )

    if not conversation:
        raise HTTPException(404, "Conversation not found")

    return get_messages(db, conversation.id)


@router.delete("/{conversation_id}", status_code=204)
def remove_conversation(
    workspace_id: uuid.UUID,
    conversation_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_workspace(db, workspace_id, current_user.id)

    conversation = get_conversation(
        db,
        conversation_id,
        current_user.id,
        workspace_id
    )

    if not conversation:
        raise HTTPException(404, "Conversation not found")

    delete_conversation(db, conversation)

    return None


@router.post("/{conversation_id}/messages/", response_model=ChatResponse)
def send_message(
    workspace_id: uuid.UUID,
    conversation_id: uuid.UUID,
    data: ChatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_workspace(db, workspace_id, current_user.id)

    has_document = db.query(Document.id).filter(
        Document.workspace_id == workspace_id
    ).first()
    if has_document is None:
        raise HTTPException(
            status_code=409,
            detail="Upload at least one document to this workspace before starting a chat.",
        )

    conversation = get_conversation(
        db,
        conversation_id,
        current_user.id,
        workspace_id,
    )

    if not conversation:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found"
        )

    # Older clients created empty conversations with the same default title.
    # Give those conversations a useful title from their first question.
    if (
        conversation.title.strip().lower() == "new conversation"
        and not conversation.messages
    ):
        title = data.query.strip()
        conversation.title = (
            f"{title[:57].rstrip()}..." if len(title) > 60 else title
        )

    # 1. Save the current user message
    current_message = save_message(
        db,
        conversation,
        role="user",
        content=data.query,
    )

    try:
        # 2. Fetch all messages from this conversation
        previous_messages = get_messages(
            db,
            conversation.id
        )

        # 3. Exclude the current question and keep the last 10 messages
        conversation_history = [
            {
                "role": message.role,
                "content": message.content
            }
            for message in previous_messages
            if message.id != current_message.id
        ][-10:]

        # 4. Pass history to the RAG graph
        result = rag_graph.invoke(
            {
                "query": data.query,
                "workspace_id": str(workspace_id),
                "conversation_history": conversation_history,
            },
            config={
                "configurable": {"thread_id": str(conversation_id)}
            }
        )

        # 5. Save assistant response
        save_message(
            db,
            conversation,
            role="assistant",
            content=result["answer"],
            citations=result.get("citations", []),
        )

        return ChatResponse(
            workspace_id=workspace_id,
            answer=result["answer"],
            citations=result.get("citations", []),
        )

    except Exception:
        db.rollback()
        logger.exception("Conversation RAG workflow failed")
        raise HTTPException(
            status_code=500,
            detail="Failed to generate response",
        )
