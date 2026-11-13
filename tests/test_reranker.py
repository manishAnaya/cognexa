from __future__ import annotations

from langchain_core.documents import Document

from app.retrieval import reranker


def make_documents(count: int = 10) -> list[Document]:
    return [
        Document(
            page_content=f"content {index}",
            metadata={
                "chunk_id": f"chunk-{index}",
                "document_id": f"document-{index}",
                "filename": f"file-{index}.pdf",
                "page_number": index + 1,
            },
        )
        for index in range(count)
    ]


def test_disabled_reranker_skips_model_and_preserves_rrf_order(monkeypatch) -> None:
    documents = make_documents()
    monkeypatch.setattr(reranker.settings, "ENABLE_RERANKER", False)

    def fail_if_called():
        raise AssertionError("CrossEncoder must not be loaded when disabled")

    monkeypatch.setattr(reranker, "get_reranker", fail_if_called)

    results = reranker.rerank_documents("query", documents)

    assert results == documents[:5]
    assert [document.metadata["chunk_id"] for document in results] == [
        "chunk-0",
        "chunk-1",
        "chunk-2",
        "chunk-3",
        "chunk-4",
    ]


def test_enabled_reranker_returns_top_five_and_preserves_source_metadata(
    monkeypatch,
) -> None:
    documents = make_documents()
    monkeypatch.setattr(reranker.settings, "ENABLE_RERANKER", True)

    class FakeCrossEncoder:
        def predict(self, pairs):
            assert len(pairs) == 10
            return list(range(10))

    monkeypatch.setattr(reranker, "get_reranker", lambda: FakeCrossEncoder())

    results = reranker.rerank_documents("query", documents, top_k=5)

    assert [document.metadata["chunk_id"] for document in results] == [
        "chunk-9",
        "chunk-8",
        "chunk-7",
        "chunk-6",
        "chunk-5",
    ]
    for document in results:
        index = int(document.metadata["chunk_id"].removeprefix("chunk-"))
        assert document.metadata["document_id"] == f"document-{index}"
        assert document.metadata["filename"] == f"file-{index}.pdf"
        assert document.metadata["page_number"] == index + 1
        assert document.metadata["rerank_score"] == float(index)
