import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.workspace import (
    WorkspaceCreate,
    WorkspaceUpdate,
    WorkspaceResponse
)
from app.services import workspace as workspace_service

router = APIRouter(prefix="/workspaces", tags=["Workspaces"])

@router.post("/", response_model=WorkspaceResponse, status_code=201)
def create(data: WorkspaceCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return workspace_service.create_workspace(db, data, current_user)

@router.get("/", response_model=list[WorkspaceResponse])
def list_all(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return workspace_service.get_workspaces(db, current_user)

@router.get("/{workspace_id}", response_model=WorkspaceResponse)
def get_one(workspace_id: uuid.UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    workspace = workspace_service.get_workspace(db, workspace_id, current_user)
    if not workspace:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return workspace

@router.patch("/{workspace_id}", response_model=WorkspaceResponse)
def update(
    workspace_id: uuid.UUID,
    data: WorkspaceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    workspace = workspace_service.get_workspace(db, workspace_id, current_user)
    if not workspace:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return workspace_service.update_workspace(db, workspace, data)

@router.delete("/{workspace_id}", status_code=204)
def delete(workspace_id: uuid.UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    workspace = workspace_service.get_workspace(db, workspace_id, current_user)
    if not workspace:
        raise HTTPException(status_code=404, detail="Workspace not found")
    workspace_service.delete_workspace(db, workspace)
    return Response(status_code=status.HTTP_204_NO_CONTENT)