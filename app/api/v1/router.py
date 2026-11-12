from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.db.session import get_db
from app.api.v1.auth import router as auth_router
from app.api.v1.users import router as users_router
from app.api.v1.workspace import router as workspace_router
from app.api.v1.documents import router as documents_router
from app.api.v1.chat import router as chat_router
from app.api.v1.conversation import router as conversation_router

router = APIRouter()

router.include_router(auth_router)

router.include_router(users_router)

router.include_router(workspace_router)

router.include_router(documents_router)

router.include_router(chat_router)

router.include_router(conversation_router)

@router.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "message": "Cognexa API is running"
    }

@router.get("/health/db")
def database_health(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {
        "status": "healthy",
        "database": "connected"
    }

