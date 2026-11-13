import os

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "Cognexa"
    APP_ENV: str = "production"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"
    CORS_ALLOWED_ORIGINS: str = ""

    DATABASE_URL: str

    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    ENABLE_RERANKER: bool = True

    # RAG currently uses Groq for query rewriting, evidence checks, and answers.
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "openai/gpt-oss-120b"

    # Embedding configuration
    EMBEDDING_MODEL: str = "sentence-transformers/all-MiniLM-L6-v2"

    # Vector database configuration
    CHROMA_PERSIST_DIRECTORY: str = "./chroma_db"

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )


# Local development continues to use .env by default. Tests and isolated
# deployments may point this at a different file without changing directories.
settings = Settings(_env_file=os.environ.get("COGNEXA_SETTINGS_FILE", ".env"))
