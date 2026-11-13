import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.document_processing_job import DocumentProcessingJob
from app.models.documents import Document
from app.models.user import User
from app.models.workspace import Workspace
from app.schemas.document import (
    DocumentProcessingStatusResponse,
    DocumentResponse,
)
from app.services.document_jobs import enqueue_document_job
from app.services.document_storage import delete_document_file, save_document

router = APIRouter(prefix="/workspaces/{workspace_id}/documents", tags=["Documents"])


@router.post("/", response_model=DocumentResponse, status_code=202)
async def upload_documents(
    workspace_id: uuid.UUID,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    workspace = (
        db.query(Workspace)
        .filter(Workspace.id == workspace_id, Workspace.owner_id == current_user.id)
        .first()
    )

    if not workspace:
        raise HTTPException(404, "Workspace not found")

    if not file.filename:
        raise HTTPException(400, "Filename is required")

    content = await file.read()

    try:
        file_path, extension = save_document(file.filename, content, workspace_id)
    except ValueError as exc:
        raise HTTPException(400, str(exc))

    document = Document(
        workspace_id=workspace_id,
        filename=file.filename,
        file_path=str(file_path),
        file_type=extension,
        file_size=len(content),
        status="pending",
    )

    # Keep the document and its durable job in the same transaction.
    try:
        enqueue_document_job(db, document)
        db.commit()
        db.refresh(document)
    except Exception:
        db.rollback()
        delete_document_file(str(file_path))
        raise

    return document


@router.get("/", response_model=list[DocumentResponse])
def list_documents(
    workspace_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    workspace = (
        db.query(Workspace)
        .filter(Workspace.id == workspace_id, Workspace.owner_id == current_user.id)
        .first()
    )

    if not workspace:
        raise HTTPException(404, "Workspace not found")

    return db.query(Document).filter(Document.workspace_id == workspace_id).all()


@router.get(
    "/{document_id}/status",
    response_model=DocumentProcessingStatusResponse,
)
def get_document_processing_status(
    workspace_id: uuid.UUID,
    document_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    workspace = (
        db.query(Workspace)
        .filter(
            Workspace.id == workspace_id,
            Workspace.owner_id == current_user.id,
        )
        .first()
    )
    if not workspace:
        raise HTTPException(404, "Workspace not found")

    document = (
        db.query(Document)
        .filter(
            Document.id == document_id,
            Document.workspace_id == workspace_id,
        )
        .first()
    )
    if document is None:
        raise HTTPException(404, "Document not found")

    job = (
        db.query(DocumentProcessingJob)
        .filter(DocumentProcessingJob.document_id == document_id)
        .first()
    )
    return DocumentProcessingStatusResponse(
        document_id=document.id,
        status=job.status if job is not None else document.status,
        stage=job.stage if job is not None else None,
        attempt_count=job.attempt_count if job is not None else 0,
        updated_at=job.updated_at if job is not None else document.created_at,
    )
