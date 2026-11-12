import logging
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.workspace import Workspace
from app.models.documents import Document
from app.schemas.chat import ChatRequest, ChatResponse
from app.graphs.rag_graph import rag_graph

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/workspaces/{workspace_id}/chat", tags=["Chat"])

@router.post("/", response_model=ChatResponse)
def chat_with_documents(
    workspace_id: uuid.UUID,
    request: ChatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Verify workspace ownership.
    workspace = db.query(Workspace).filter(
        Workspace.id == workspace_id,
        Workspace.owner_id == current_user.id
    ).first()

    if not workspace:
        raise HTTPException(404, "Workspace not found")

    has_document = db.query(Document.id).filter(
        Document.workspace_id == workspace_id
    ).first()
    if has_document is None:
        raise HTTPException(
            status_code=409,
            detail="Upload at least one document to this workspace before starting a chat.",
        )

    try:
        result = rag_graph.invoke({
            "query": request.query,
            "rewritten_query": "",
            "workspace_id": str(workspace_id),
            "documents": [],
            "evidence_sufficient": False,
            "evidence_reason": "",
            "answer": "",
            "citations": []
        }, config={"configurable": {"thread_id": str(uuid.uuid4())}})

        return ChatResponse(
            workspace_id=workspace_id,
            answer=result["answer"],
            citations=result["citations"]
        )

    except Exception:
        logger.exception("RAG workflow failed")
        raise HTTPException(
            status_code=500,
            detail="Unable to process your question right now."
        )
