from sqlalchemy.orm import Session
from app.models.documents import Document
from app.ingestion.extractors import extract_document
from app.ingestion.chunker import split_documents
from app.services.chunk_storage import save_chunks
from app.services.indexing import index_document_chunks

def process_document(db: Session, document: Document):
    try:
        document.status = "processing"
        db.commit()
        # Extract text
        pages = extract_document(document.file_path)
        # Generate chunks
        chunks = split_documents(pages)
        if not chunks:
            raise ValueError("No extractable text found")
        # Save chunks
        total_chunks = save_chunks(db, document.id, chunks)
        # Keep PostgreSQL chunk records and Chroma vectors in sync.
        index_document_chunks(db, document.id)
        document.status = "processed"
        db.commit()
        return total_chunks
    except Exception:
        db.rollback()
        document.status = "failed"
        db.commit()
        raise
