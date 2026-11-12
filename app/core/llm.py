from langchain_groq import ChatGroq

from app.core.config import settings


def get_chat_model() -> ChatGroq:
    """Build the configured Groq chat model or raise a clear setup error."""
    if not settings.GROQ_API_KEY:
        raise RuntimeError("Set GROQ_API_KEY in .env to use document chat.")

    return ChatGroq(
        model=settings.GROQ_MODEL,
        temperature=0,
        api_key=settings.GROQ_API_KEY,
    )
