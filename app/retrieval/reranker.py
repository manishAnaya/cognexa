from functools import lru_cache
from sentence_transformers import CrossEncoder
from langchain_core.documents import Document as LangChainDocument

RERANKER_MODEL = "BAAI/bge-reranker-base"

@lru_cache(maxsize=1)
def get_reranker() -> CrossEncoder:
    """Load and reuse the cross-encoder model."""
    return CrossEncoder(
        RERANKER_MODEL,
        max_length=512,
        device="cpu"
    )

def rerank_documents(
    query: str,
    documents: list[LangChainDocument],
    top_k: int = 5
) -> list[LangChainDocument]:
    """Rerank retrieved documents using query-document relevance."""

    if not documents:
        return []

    reranker = get_reranker()

    # Each pair contains the query and one retrieved chunk.
    pairs = [
        (query, document.page_content)
        for document in documents
    ]

    scores = reranker.predict(pairs)

    # Sort documents by their cross-encoder relevance scores.
    ranked_results = sorted(
        zip(documents, scores),
        key=lambda item: float(item[1]),
        reverse=True
    )

    results = []

    for document, score in ranked_results[:top_k]:
        document.metadata["rerank_score"] = float(score)
        results.append(document)

    return results
