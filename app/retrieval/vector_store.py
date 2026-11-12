from langchain_chroma import Chroma
from app.core.config import settings
from app.retrieval.embeddings import get_embedding_model
from functools import lru_cache

@lru_cache(maxsize=1)
def get_vector_store() -> Chroma:
    """Create or reuse the persistent Chroma vector store."""
    return Chroma(
        collection_name="cognexa_documents",
        embedding_function=get_embedding_model(),
        persist_directory=settings.CHROMA_PERSIST_DIRECTORY
    )
