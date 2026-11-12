import uuid
from sqlalchemy.orm import Session
from app.models.workspace import Workspace
from app.models.user import User
from app.schemas.workspace import WorkspaceCreate, WorkspaceUpdate

def create_workspace(db: Session, data: WorkspaceCreate, user: User):
    workspace = Workspace(name=data.name, description=data.description, owner_id=user.id)
    db.add(workspace)
    db.commit()
    db.refresh(workspace)
    return workspace

def get_workspaces(db: Session, user: User):
    return db.query(Workspace).filter(
        Workspace.owner_id == user.id
    ).all()

def get_workspace(db: Session, workspace_id: uuid.UUID, user: User):
    return db.query(Workspace).filter(
        Workspace.id == workspace_id,
        Workspace.owner_id == user.id
    ).first()

def update_workspace(db: Session, workspace: Workspace, data: WorkspaceUpdate):
    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(workspace, key, value)
    db.commit()
    db.refresh(workspace)
    return workspace

def delete_workspace(db: Session, workspace: Workspace):
    db.delete(workspace)
    db.commit()