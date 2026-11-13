from __future__ import annotations

import uuid
from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_current_user
from app.api.v1 import conversation as conversation_api
from app.db.session import get_db
from app.graphs import nodes as graph_nodes
from app.main import app
from app.models.documents import Document
from app.models.workspace import Workspace
from app.services import document_storage


class FakeQuery:
    def __init__(self, result: object) -> None:
        self.result = result

    def filter(self, *_criteria: object) -> FakeQuery:
        return self

    def first(self) -> object:
        return self.result


class FakeDB:
    def __init__(self, workspace: Workspace) -> None:
        self.workspace = workspace

    def query(self, *_entities: object) -> FakeQuery:
        return FakeQuery(self.workspace)

    def add(self, instance: object) -> None:
        if isinstance(instance, Document):
            instance.id = uuid.uuid4()
            instance.created_at = datetime.now(UTC)

    def commit(self) -> None:
        pass

    def refresh(self, _instance: object) -> None:
        pass

    def rollback(self) -> None:
        pass


@pytest.fixture
def api_context() -> tuple[TestClient, uuid.UUID, uuid.UUID]:
    user_id = uuid.uuid4()
    workspace_id = uuid.uuid4()
    user = SimpleNamespace(id=user_id, is_active=True)
    workspace = Workspace(id=workspace_id, owner_id=user_id, name="Test workspace")
    db = FakeDB(workspace)

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user
    # TestClient's context manager would run the app lifespan and open the real
    # LangGraph PostgreSQL checkpointer. Keep lifespan disabled in these tests.
    client = TestClient(app)
    try:
        yield client, user_id, workspace_id
    finally:
        client.close()
        app.dependency_overrides.clear()


def test_health_endpoint(api_context: tuple[TestClient, uuid.UUID, uuid.UUID]) -> None:
    client, _, _ = api_context
    response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "healthy",
        "message": "Cognexa API is running",
    }


@pytest.mark.parametrize(
    "origin",
    [
        "https://cognexa-frontend-neon.vercel.app",
        "http://localhost:3000",
        "http://127.0.0.1:5173",
    ],
)
def test_cors_allows_frontend_and_local_origins(origin: str) -> None:
    client = TestClient(app)
    try:
        response = client.get("/", headers={"Origin": origin})
    finally:
        client.close()

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin
    assert response.headers["access-control-allow-credentials"] == "true"


def test_cors_preflight_allows_methods_and_headers() -> None:
    client = TestClient(app)
    try:
        response = client.options(
            "/api/v1/workspaces/",
            headers={
                "Origin": "https://cognexa-frontend-neon.vercel.app",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "authorization,content-type",
            },
        )
    finally:
        client.close()

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == (
        "https://cognexa-frontend-neon.vercel.app"
    )
    assert response.headers["access-control-allow-credentials"] == "true"
    assert "POST" in response.headers["access-control-allow-methods"]
    allowed_headers = response.headers["access-control-allow-headers"].lower()
    assert "authorization" in allowed_headers
    assert "content-type" in allowed_headers


def test_health_does_not_expose_configured_credentials(
    api_context: tuple[TestClient, uuid.UUID, uuid.UUID],
) -> None:
    client, _, _ = api_context
    response = client.get("/api/v1/health")
    body = response.text

    assert "test-only-signing-key" not in body
    assert "postgresql+psycopg" not in body


def test_query_rewriting_does_not_print_user_content(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setattr(
        graph_nodes, "rewrite_query", lambda **_kwargs: "safe rewritten query"
    )

    result = graph_nodes.rewrite_query_node(
        {
            "query": "private prompt marker",
            "conversation_history": [{"content": "private history marker"}],
        }
    )

    assert result["rewritten_query"] == "safe rewritten query"
    assert capsys.readouterr().out == ""


def test_protected_document_route_rejects_missing_token() -> None:
    app.dependency_overrides.clear()
    client = TestClient(app)
    response = client.get(f"/api/v1/workspaces/{uuid.uuid4()}/documents/")
    client.close()

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid or expired token"


def test_upload_rejects_unsupported_extension(
    api_context: tuple[TestClient, uuid.UUID, uuid.UUID],
    tmp_path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client, _, workspace_id = api_context
    monkeypatch.setattr(document_storage, "UPLOAD_DIR", tmp_path)

    response = client.post(
        f"/api/v1/workspaces/{workspace_id}/documents/",
        files={"file": ("payload.exe", b"not an allowed document")},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Unsupported file format"


def test_upload_rejects_file_over_20_mib(
    api_context: tuple[TestClient, uuid.UUID, uuid.UUID],
    tmp_path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client, _, workspace_id = api_context
    monkeypatch.setattr(document_storage, "UPLOAD_DIR", tmp_path)

    response = client.post(
        f"/api/v1/workspaces/{workspace_id}/documents/",
        files={"file": ("oversized.txt", b"x" * (20 * 1024 * 1024 + 1))},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "File size exceeds 20 MB"


def test_upload_accepts_allowed_extension_without_external_processing(
    api_context: tuple[TestClient, uuid.UUID, uuid.UUID],
    tmp_path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.api.v1 import documents as documents_api

    client, _, workspace_id = api_context
    monkeypatch.setattr(document_storage, "UPLOAD_DIR", tmp_path)
    monkeypatch.setattr(
        documents_api,
        "enqueue_document_job",
        lambda db, document: db.add(document),
    )

    response = client.post(
        f"/api/v1/workspaces/{workspace_id}/documents/",
        files={"file": ("notes.md", b"local test content")},
    )

    assert response.status_code == 202
    assert response.json()["filename"] == "notes.md"
    assert response.json()["file_type"] == ".md"
    assert response.json()["file_size"] == len(b"local test content")


def test_conversation_create_and_list_routes(
    api_context: tuple[TestClient, uuid.UUID, uuid.UUID],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client, user_id, workspace_id = api_context
    now = datetime.now(UTC)
    conversation = SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user_id,
        workspace_id=workspace_id,
        title="Release notes",
        created_at=now,
        updated_at=now,
    )
    monkeypatch.setattr(
        conversation_api, "create_conversation", lambda **_kwargs: conversation
    )
    monkeypatch.setattr(
        conversation_api, "get_conversations", lambda *_args: [conversation]
    )

    created = client.post(
        f"/api/v1/workspaces/{workspace_id}/conversations/",
        json={"title": "Release notes"},
    )
    listed = client.get(f"/api/v1/workspaces/{workspace_id}/conversations/")

    assert created.status_code == 201
    assert created.json()["title"] == "Release notes"
    assert listed.status_code == 200
    assert [item["id"] for item in listed.json()] == [str(conversation.id)]


def test_conversation_routes_require_authentication() -> None:
    app.dependency_overrides.clear()
    client = TestClient(app)
    response = client.get(f"/api/v1/workspaces/{uuid.uuid4()}/conversations/")
    client.close()

    assert response.status_code == 401
