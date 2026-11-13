from functools import lru_cache

from langchain_core.documents import Document as LangChainDocument

from app.core.config import settings

RERANKER_MODEL = "BAAI/bge-reranker-base"


@lru_cache(maxsize=1)
def get_reranker():
    """Load and reuse the cross-encoder model."""
    from sentence_transformers import CrossEncoder

    return CrossEncoder(
        RERANKER_MODEL,
        max_length=512,
        device="cpu",
    )


def rerank_documents(
    query: str,
    documents: list[LangChainDocument],
    top_k: int = 5,
) -> list[LangChainDocument]:
    """Rerank retrieved chunks when enabled."""

    if not documents:
        return []

    # Skip CrossEncoder entirely when disabled.
    if not settings.ENABLE_RERANKER:
        return documents[:top_k]

    reranker = get_reranker()

    pairs = [(query, document.page_content) for document in documents]

    scores = reranker.predict(pairs)

    ranked_results = sorted(
        zip(documents, scores),
        key=lambda item: float(item[1]),
        reverse=True,
    )

    results = []

    for document, score in ranked_results[:top_k]:
        document.metadata["rerank_score"] = float(score)
        results.append(document)

    return results
