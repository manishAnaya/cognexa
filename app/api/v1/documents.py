import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.documents import Document
from app.models.workspace import Workspace
from app.schemas.document import DocumentResponse
from app.services.document_storage import (save_document, delete_document_file)
from app.services.document_processing import process_document

router = APIRouter(prefix="/workspaces/{workspace_id}/documents", tags=["Documents"])

@router.post("/", response_model=DocumentResponse, status_code=201)
async def upload_documents(
    workspace_id: uuid.UUID,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    workspace = db.query(Workspace).filter(
        Workspace.id == workspace_id,
        Workspace.owner_id == current_user.id
    ).first()

    if not workspace:
        raise HTTPException(404, "Workspace not found")

    if not file.filename:
        raise HTTPException(400, "Filename is required")

    content = await file.read()

    try:
        file_path, extension = save_document(
            file.filename, content, workspace_id
        )
    except ValueError as exc:
        raise HTTPException(400, str(exc))

    document = Document(
        workspace_id=workspace_id,
        filename=file.filename,
        file_path=str(file_path),
        file_type=extension,
        file_size=len(content),
        status="uploaded"
    )

    # Step 1: Save document record
    try:
        db.add(document)
        db.commit()
        db.refresh(document)
    except Exception:
        db.rollback()
        delete_document_file(str(file_path))
        raise

    # Step 2: Process document
    try:
        process_document(db, document)
        db.refresh(document)
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Document processing failed: {str(exc)}"
        )
    return document

@router.get("/", response_model=list[DocumentResponse])
def list_documents(
    workspace_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    workspace = db.query(Workspace).filter(
        Workspace.id == workspace_id,
        Workspace.owner_id == current_user.id
    ).first()

    if not workspace:
        raise HTTPException(404, "Workspace not found")

    return db.query(Document).filter(
        Document.workspace_id == workspace_id
    ).all()