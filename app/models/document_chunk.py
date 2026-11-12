import uuid
from datetime import datetime, timezone
from sqlalchemy import (Text, Integer, DateTime, ForeignKey, Uuid)
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base


class DocumentChunk(Base):

    __tablename__ = "document_chunks"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4
    )

    document_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("documents.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    content: Mapped[str] = mapped_column(
        Text,
        nullable=False
    )

    chunk_index: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )

    page_number: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    start_index: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )