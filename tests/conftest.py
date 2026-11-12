"""Test setup that prevents application imports from reading the repo .env."""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

# Point app-wide settings at a non-existent file in an isolated temporary
# directory. This prevents Settings() from loading the repository's .env while
# keeping the process working directory unchanged.
_TEST_ENV_DIR = tempfile.TemporaryDirectory(prefix="cognexa-test-env-")
os.environ["COGNEXA_SETTINGS_FILE"] = str(Path(_TEST_ENV_DIR.name) / "no-secrets.env")
os.environ["DATABASE_URL"] = (
    "postgresql+psycopg://test:test@127.0.0.1:5432/cognexa_test"
)
os.environ["JWT_SECRET_KEY"] = "test-only-signing-key-never-used-outside-tests"
os.environ["GROQ_API_KEY"] = ""
os.environ["DEBUG"] = "false"
os.environ["APP_ENV"] = "test"


@pytest.fixture(autouse=True)
def reset_environment_overrides(monkeypatch: pytest.MonkeyPatch) -> None:
    """Keep each test's environment isolated from accidental mutations."""
    monkeypatch.setenv(
        "DATABASE_URL", "postgresql+psycopg://test:test@127.0.0.1:5432/cognexa_test"
    )
    monkeypatch.setenv(
        "JWT_SECRET_KEY", "test-only-signing-key-never-used-outside-tests"
    )
