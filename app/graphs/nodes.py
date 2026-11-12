import uuid
from app.db.session import SessionLocal
from app.rag.query_rewriter import rewrite_query
from app.retrieval.pipeline import retrieve_relevant_chunks
from app.rag.evidence_validator import validate_evidence
from app.rag.answer_generator import generate_answer
from app.rag.small_talk import small_talk_intent, small_talk_reply


def small_talk_node(state: dict) -> dict:
    intent = small_talk_intent(state["query"])
    if intent is None:
        raise ValueError("small_talk_node called for a non-small-talk query")

    return {"answer": small_talk_reply(intent), "citations": []}

def rewrite_query_node(state: dict) -> dict:
    rewritten = rewrite_query(
        query=state["query"],
        conversation_history=state.get("conversation_history", [])
    )
    print("\n========== QUERY REWRITING ==========")
    print("Original:", state["query"])
    print("History:", state.get("conversation_history", []))
    print("Rewritten:", rewritten)
    return {"rewritten_query": rewritten}

def retrieve_node(state: dict) -> dict:
    db = SessionLocal()
    try:
        documents = retrieve_relevant_chunks(
            db=db,
            query=state["rewritten_query"],
            workspace_id=uuid.UUID(state["workspace_id"]),
            candidate_k=10,
            top_k=5
        )
        print("\n========== RETRIEVAL ==========")
        print("Workspace:", state["workspace_id"])
        print("Query:", state["rewritten_query"])
        print("Retrieved chunks:", len(documents))

        for i, doc in enumerate(documents):
            print(f"Chunk {i + 1}:")
            print("Metadata:", doc.metadata)
            print("Content:", doc.page_content[:200])
        return {"documents": documents}
    finally:
        db.close()

def validate_evidence_node(state: dict) -> dict:
    validation = validate_evidence(
        state["rewritten_query"],
        state["documents"]
    )
    print("\n========== EVIDENCE VALIDATION ==========")
    print("Sufficient:", validation.sufficient)
    print("Reason:", validation.reason)

    return {
        "evidence_sufficient": validation.sufficient,
        "evidence_reason": validation.reason
    }

def generate_answer_node(state: dict) -> dict:
    # Reconstruct validation result for the answer generator.
    from app.rag.evidence_validator import EvidenceValidation

    validation = EvidenceValidation(
        sufficient=state["evidence_sufficient"],
        reason=state["evidence_reason"]
    )

    result = generate_answer(
        query=state["rewritten_query"],
        documents=state["documents"],
        evidence_validation=validation
    )

    return {
        "answer": result.answer,
        "citations": [
            citation.model_dump()
            for citation in result.citations
        ]
    }

def fallback_node(state: dict) -> dict:
    return {
        "answer": (
            "I couldn't find sufficient information in the "
            "uploaded documents to answer this question reliably."
        ),
        "citations": []
    }
