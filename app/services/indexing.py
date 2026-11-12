from uuid import UUID
from sqlalchemy.orm import Session
from langchain_core.documents import Document as LangChainDocument
from app.models.documents import Document
from app.models.document_chunk import DocumentChunk
from app.retrieval.vector_store import get_vector_store

def index_document_chunks(db: Session, document_id: UUID) -> int:
    """Index a document's PostgreSQL chunks in Chroma."""
    document = db.query(Document).filter(
        Document.id == document_id
    ).first()
    
    if not document:
        raise ValueError("Document not found")

    chunks = db.query(DocumentChunk).filter(
        DocumentChunk.document_id == document_id
    ).order_by(DocumentChunk.chunk_index).all()

    if not chunks:
        raise ValueError("No chunks found for this document")

    langchain_docs = []
    chunk_ids = []

    for chunk in chunks:
        metadata = {
            "document_id": str(document.id),
            "chunk_id": str(chunk.id),
            "workspace_id": str(document.workspace_id),
            "filename": document.filename,
            "chunk_index": chunk.chunk_index,
        }

        if chunk.page_number is not None:
            metadata["page_number"] = chunk.page_number

        if chunk.start_index is not None:
            metadata["start_index"] = chunk.start_index

        langchain_docs.append(
            LangChainDocument(
                page_content=chunk.content,
                metadata=metadata
            )
        )

        # Stable IDs prevent duplicate entries during re-indexing.
        chunk_ids.append(str(chunk.id))

    vector_store = get_vector_store()

    vector_store.add_documents(
        documents=langchain_docs,
        ids=chunk_ids
    )

    return len(langchain_docs)
