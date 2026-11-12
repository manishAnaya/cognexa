from uuid import UUID
from langchain_core.documents import Document as LangChainDocument
from app.retrieval.vector_store import get_vector_store

def search_documents(
    query: str,
    workspace_id: UUID,
    document_id: UUID | None = None,
    top_k: int = 5
) -> list[LangChainDocument]:
    """Retrieve relevant chunks from a workspace."""
    vector_store = get_vector_store()
    filters = {
        "workspace_id": str(workspace_id)
    }
    if document_id:
        filters["document_id"] = str(document_id)
    results = vector_store.similarity_search(
        query=query,
        k=top_k,
        filter=filters
    )
    return results
