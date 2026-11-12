from uuid import UUID
from langchain_core.documents import Document as LangChainDocument
from langchain_community.retrievers import BM25Retriever
from sqlalchemy.orm import Session
from app.models.document_chunk import DocumentChunk
from app.models.documents import Document
from app.retrieval.retriever import search_documents

def reciprocal_rank_fusion(
    result_lists: list[list[LangChainDocument]],
    k: int = 60
) -> list[LangChainDocument]:
    """Combine ranked results using Reciprocal Rank Fusion."""

    scores = {}
    documents = {}

    for result_list in result_lists:
        for rank, doc in enumerate(result_list, start=1):
            chunk_id = doc.metadata["chunk_id"]

            scores[chunk_id] = (
                scores.get(chunk_id, 0) + 1 / (k + rank)
            )

            documents[chunk_id] = doc

    ranked_ids = sorted(
        scores,
        key=lambda chunk_id: scores[chunk_id],
        reverse=True
    )

    return [documents[chunk_id] for chunk_id in ranked_ids]


def hybrid_search(
    db: Session,
    query: str,
    workspace_id: UUID,
    document_id: UUID | None = None,
    top_k: int = 5
) -> list[LangChainDocument]:
    """Combine BM25 keyword search and dense semantic search."""

    # 1. Fetch workspace chunks from PostgreSQL
    db_query = (
        db.query(DocumentChunk, Document)
        .join(Document, Document.id == DocumentChunk.document_id)
        .filter(Document.workspace_id == workspace_id)
    )

    if document_id:
        db_query = db_query.filter(
            DocumentChunk.document_id == document_id
        )

    rows = db_query.all()

    if not rows:
        return []

    # 2. Convert PostgreSQL chunks into LangChain documents
    documents = []

    for chunk, document in rows:
        metadata = {
            "chunk_id": str(chunk.id),
            "document_id": str(document.id),
            "workspace_id": str(document.workspace_id),
            "filename": document.filename,
            "chunk_index": chunk.chunk_index,
        }

        if chunk.page_number is not None:
            metadata["page_number"] = chunk.page_number

        documents.append(
            LangChainDocument(
                page_content=chunk.content,
                metadata=metadata
            )
        )

    # 3. BM25 keyword retrieval
    bm25 = BM25Retriever.from_documents(documents)
    bm25.k = top_k
    keyword_results = bm25.invoke(query)

    # 4. Dense semantic retrieval
    semantic_results = search_documents(
        query=query,
        workspace_id=workspace_id,
        document_id=document_id,
        top_k=top_k
    )

    # 5. Combine both rankings
    fused_results = reciprocal_rank_fusion(
        [keyword_results, semantic_results]
    )

    return fused_results[:top_k]
