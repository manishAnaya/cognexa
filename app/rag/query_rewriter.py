from langchain_core.prompts import ChatPromptTemplate
from app.core.llm import get_chat_model

def rewrite_query(query: str, conversation_history: list[dict] | None = None) -> str:
    """Convert a follow-up question into a standalone search query."""

    if not query.strip():
        raise ValueError("Query cannot be empty")

    model = get_chat_model()

    prompt = ChatPromptTemplate.from_messages([
        (
            "system",
            """
            You are a search query optimization assistant.

            Rewrite the user's question into a clear,
            standalone search query suitable for document retrieval.

            Use conversation history only to resolve references
            and understand the latest question.

            Rules:
            - Preserve the original intent.
            - Resolve references when conversation context is provided.
            - Do not answer the question.
            - Return only the rewritten query.
            """
        ),
        (
            "human",
            """
            Conversation history:
            {conversation_history}

            Latest user question:
            {query}
            """
        )
    ])

    history_text = "\n".join(
        f"{message['role']}: {message['content']}"
        for message in (conversation_history or [])[-10:]
    )

    chain = prompt | model

    response = chain.invoke({
        "query": query,
        "conversation_history": history_text or "No previous messages."
    })

    return response.content.strip()
