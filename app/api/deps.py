import uuid
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session
from jwt.exceptions import InvalidTokenError
from app.db.session import get_db
from app.core.jwt import decode_access_token
from app.models.user import User

bearer_scheme = HTTPBearer(auto_error=False)

def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"}
    )

    if credentials is None:
        raise credentials_exception

    try:
        payload = decode_access_token(credentials.credentials)
        user_id = uuid.UUID(payload["sub"])
    except (InvalidTokenError, ValueError, KeyError):
        raise credentials_exception

    user = db.query(User).filter(User.id == user_id).first()

    if not user or not user.is_active:
        raise credentials_exception

    return user
