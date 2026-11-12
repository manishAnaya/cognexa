from langgraph.graph import StateGraph, START, END
from app.graphs.state import RAGState
from app.graphs.checkpointer import checkpointer
from app.graphs.nodes import (
    rewrite_query_node,
    retrieve_node,
    validate_evidence_node,
    generate_answer_node,
    fallback_node,
    small_talk_node,
)
from app.rag.small_talk import small_talk_intent


def route_initial_query(state: RAGState) -> str:
    if small_talk_intent(state["query"]) is not None:
        return "small_talk"
    return "rewrite_query"

def route_after_validation(state: RAGState) -> str:
    if state["evidence_sufficient"]:
        return "generate_answer"

    return "fallback"

def build_rag_graph():
    builder = StateGraph(RAGState)
    
    builder.add_node("rewrite_query", rewrite_query_node)
    builder.add_node("retrieve", retrieve_node)
    builder.add_node("validate_evidence", validate_evidence_node)
    builder.add_node("generate_answer", generate_answer_node)
    builder.add_node("fallback", fallback_node)
    builder.add_node("small_talk", small_talk_node)

    builder.add_conditional_edges(
        START,
        route_initial_query,
        {"small_talk": "small_talk", "rewrite_query": "rewrite_query"},
    )
    builder.add_edge("small_talk", END)
    builder.add_edge("rewrite_query", "retrieve")
    builder.add_edge("retrieve", "validate_evidence")

    builder.add_conditional_edges(
        "validate_evidence",
        route_after_validation,
        {
            "generate_answer": "generate_answer",
            "fallback": "fallback"
        }
    )

    builder.add_edge("generate_answer", END)
    builder.add_edge("fallback", END)

    return builder.compile(checkpointer=checkpointer)

rag_graph = build_rag_graph()
