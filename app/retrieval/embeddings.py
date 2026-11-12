from functools import lru_cache
from langchain_huggingface import HuggingFaceEmbeddings
from app.core.config import settings

@lru_cache(maxsize=1)
def get_embedding_model() -> HuggingFaceEmbeddings:
    """Create and reuse the configured embedding model."""
    return HuggingFaceEmbeddings(
        model_name=settings.EMBEDDING_MODEL,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True}
    )


def generate_embedding(text: str) -> list[float]:
    """Generate an embedding for a single text."""
    model = get_embedding_model()
    return model.embed_query(text)
