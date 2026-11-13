import uuid

from sqlalchemy.orm import Session

from app.models.document_chunk import DocumentChunk


def save_chunks(db: Session, document_id: uuid.UUID, chunks: list) -> int:
    """Replace a document's chunks using stable IDs so retries are idempotent."""
    db.query(DocumentChunk).filter(DocumentChunk.document_id == document_id).delete(
        synchronize_session=False
    )

    records = []
    for index, chunk in enumerate(chunks):
        metadata = chunk.metadata
        records.append(
            DocumentChunk(
                id=uuid.uuid5(document_id, f"chunk:{index}"),
                document_id=document_id,
                content=chunk.page_content,
                chunk_index=index,
                page_number=metadata.get("page"),
                start_index=metadata.get("start_index"),
            )
        )
    db.add_all(records)
    db.commit()
    return len(records)
