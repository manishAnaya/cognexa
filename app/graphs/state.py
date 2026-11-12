from typing import TypedDict, NotRequired
from langchain_core.documents import Document

class RAGState(TypedDict):
    query: str
    rewritten_query: str
    workspace_id: str
    documents: list[Document]
    evidence_sufficient: bool
    evidence_reason: str
    answer: str
    citations: list[dict]
    conversation_history: NotRequired[list[dict]]
