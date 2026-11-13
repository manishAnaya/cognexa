from uuid import UUID

from langchain_core.documents import Document as LangChainDocument
from sqlalchemy.orm import Session

from app.retrieval.hybrid import hybrid_search
from app.retrieval.reranker import rerank_documents


def retrieve_relevant_chunks(
    db: Session,
    query: str,
    workspace_id: UUID,
    document_id: UUID | None = None,
    candidate_k: int = 10,
    top_k: int = 5,
) -> list[LangChainDocument]:
    """
    Complete retrieval pipeline:
    1. Dense + BM25 retrieval
    2. Reciprocal Rank Fusion
    3. Optional cross-encoder reranking
    """
    if not query.strip():
        raise ValueError("Search query cannot be empty")

    if candidate_k < top_k or top_k < 1:
        raise ValueError("candidate_k must be >= top_k, and top_k must be positive")

    # Retrieve candidate chunks using hybrid search.
    candidates = hybrid_search(
        db=db,
        query=query,
        workspace_id=workspace_id,
        document_id=document_id,
        top_k=candidate_k,
    )

    if not candidates:
        return []

    # Rerank candidates and return the most relevant chunks.
    results = rerank_documents(query=query, documents=candidates, top_k=top_k)

    return results
