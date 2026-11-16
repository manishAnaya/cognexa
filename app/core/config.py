import os

from pydantic import field_validator
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

    @field_validator("DEBUG", mode="before")
    @classmethod
    def normalize_debug_setting(cls, value):
        # Some hosting environments provide DEBUG as an environment label
        # (for example, "release") instead of a boolean string.
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"release", "production", "prod"}:
                return False
            if normalized in {"debug", "development", "dev"}:
                return True
        return value

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )


# Local development continues to use .env by default. Tests and isolated
# deployments may point this at a different file without changing directories.
settings = Settings(_env_file=os.environ.get("COGNEXA_SETTINGS_FILE", ".env"))
