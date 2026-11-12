from sqlalchemy.orm import Session
from app.models.document_chunk import DocumentChunk

def save_chunks(db: Session, document_id, chunks: list):
    records = []
    for chunk in chunks:
        metadata = chunk.metadata
        records.append(
            DocumentChunk(
                document_id=document_id,
                content=chunk.page_content,
                chunk_index=metadata["chunk_index"],
                page_number=metadata.get("page"),
                start_index=metadata.get("start_index")
            )
        )
    db.add_all(records)
    db.commit()
    return len(records)