from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.auth import UserRegister
from app.core.security import hash_password, verify_password


def register_user(db: Session, data: UserRegister) -> User:
    existing_user = db.query(User).filter(
        User.email == data.email
    ).first()

    if existing_user:
        raise ValueError("Email already registered")

    user = User(
        email=data.email,
        full_name=data.full_name,
        hashed_password=hash_password(data.password)
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


def authenticate_user(db: Session, email: str, password: str):

    user = db.query(User).filter(User.email == email).first()

    if not user or not verify_password(password, user.hashed_password):
        return None

    if not user.is_active:
        return None

    return user