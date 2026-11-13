from __future__ import annotations

from pathlib import Path

from app.core.config import Settings


def test_settings_load_defaults_and_explicit_values(monkeypatch) -> None:
    monkeypatch.setenv(
        "DATABASE_URL", "postgresql+psycopg://unit:unit@localhost/cognexa"
    )
    monkeypatch.setenv("JWT_SECRET_KEY", "unit-test-key-that-is-not-a-real-credential")
    monkeypatch.delenv("APP_ENV", raising=False)
    monkeypatch.delenv("DEBUG", raising=False)
    monkeypatch.delenv("ENABLE_RERANKER", raising=False)

    settings = Settings(_env_file=None)

    assert settings.APP_ENV == "production"
    assert settings.DEBUG is False
    assert settings.ENABLE_RERANKER is True
    assert settings.API_V1_PREFIX == "/api/v1"
    assert settings.DATABASE_URL.endswith("/cognexa")
    assert settings.JWT_SECRET_KEY == "unit-test-key-that-is-not-a-real-credential"


def test_settings_environment_overrides(monkeypatch) -> None:
    monkeypatch.setenv(
        "DATABASE_URL", "postgresql+psycopg://override:override@localhost/override_db"
    )
    monkeypatch.setenv("JWT_SECRET_KEY", "another-test-only-signing-key")
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("DEBUG", "true")
    monkeypatch.setenv(
        "CORS_ALLOWED_ORIGINS", "https://cognexa.example,https://preview.example"
    )

    settings = Settings(_env_file=None)

    assert settings.APP_ENV == "test"
    assert settings.DEBUG is True
    assert (
        settings.CORS_ALLOWED_ORIGINS
        == "https://cognexa.example,https://preview.example"
    )
    assert settings.DATABASE_URL.startswith("postgresql+psycopg://override:")
    assert settings.JWT_SECRET_KEY == "another-test-only-signing-key"


def test_settings_reranker_environment_override(monkeypatch) -> None:
    monkeypatch.setenv(
        "DATABASE_URL", "postgresql+psycopg://unit:unit@localhost/cognexa"
    )
    monkeypatch.setenv("JWT_SECRET_KEY", "unit-test-key-that-is-not-a-real-credential")
    monkeypatch.setenv("ENABLE_RERANKER", "false")

    settings = Settings(_env_file=None)

    assert settings.ENABLE_RERANKER is False


def test_settings_can_load_local_development_env_file(
    tmp_path: Path, monkeypatch
) -> None:
    for name in ("APP_ENV", "DEBUG", "DATABASE_URL", "JWT_SECRET_KEY"):
        monkeypatch.delenv(name, raising=False)

    env_file = tmp_path / ".env"
    env_file.write_text(
        "APP_ENV=development\nDEBUG=true\n"
        "DATABASE_URL=postgresql+psycopg://local:local@localhost/cognexa\n"
        "JWT_SECRET_KEY=local-test-only-secret\n",
        encoding="utf-8",
    )

    settings = Settings(_env_file=env_file)

    assert settings.APP_ENV == "development"
    assert settings.DEBUG is True
    assert settings.DATABASE_URL.endswith("/cognexa")
