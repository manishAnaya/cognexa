from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from langchain_core.documents import Document as LangChainDocument
from sqlalchemy import create_engine, func, select
from sqlalchemy.dialects import postgresql
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user
from app.api.v1 import documents as documents_api
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.document_chunk import DocumentChunk
from app.models.document_processing_job import DocumentProcessingJob
from app.models.documents import Document
from app.models.user import User
from app.models.workspace import Workspace
from app.services.chunk_storage import save_chunks
from app.services.document_jobs import (
    FAILED,
    PENDING,
    PROCESSED,
    PROCESSING,
    _claimable_jobs_statement,
    claim_next_job,
    complete_job,
    enqueue_document_job,
    fail_job,
    heartbeat_job,
)


@pytest.fixture
def database():
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(
        engine,
        tables=[
            User.__table__,
            Workspace.__table__,
            Document.__table__,
            DocumentChunk.__table__,
            DocumentProcessingJob.__table__,
        ],
    )
    test_session = sessionmaker(bind=engine, expire_on_commit=False)
    db = test_session()
    user = User(
        email="jobs-test@example.com",
        full_name="Job Test",
        hashed_password="not-a-real-password-hash",
    )
    db.add(user)
    db.flush()
    workspace = Workspace(name="Jobs", owner_id=user.id)
    db.add(workspace)
    db.commit()

    try:
        yield engine, test_session, db, user, workspace
    finally:
        db.close()
        engine.dispose()


def add_document(db, workspace: Workspace) -> Document:
    document = Document(
        workspace_id=workspace.id,
        filename="source.txt",
        file_path="uploads/source.txt",
        file_type=".txt",
        file_size=12,
        status="uploaded",
    )
    job = enqueue_document_job(db, document)
    job.available_at = datetime(2026, 11, 12, tzinfo=UTC)
    db.commit()
    return document


def test_document_and_job_are_created_in_one_transaction(database) -> None:
    _engine, _session_factory, db, _user, workspace = database
    document = Document(
        workspace_id=workspace.id,
        filename="source.txt",
        file_path="uploads/source.txt",
        file_type=".txt",
        file_size=12,
    )

    job = enqueue_document_job(db, document)
    assert document.status == PENDING
    assert job.document_id == document.id
    assert job.status == PENDING

    db.rollback()
    assert db.scalar(select(func.count()).select_from(Document)) == 0
    assert db.scalar(select(func.count()).select_from(DocumentProcessingJob)) == 0


def test_claim_changes_job_and_document_to_processing(database) -> None:
    _engine, _session_factory, db, _user, workspace = database
    document = add_document(db, workspace)

    claim = claim_next_job(
        db, worker_id=uuid.uuid4(), now=datetime(2026, 11, 13, tzinfo=UTC)
    )

    assert claim is not None
    assert claim.document_id == document.id
    assert claim.attempt_count == 1
    job = db.get(DocumentProcessingJob, claim.job_id)
    assert job.status == PROCESSING
    assert job.claim_token == claim.claim_token
    assert db.get(Document, document.id).status == PROCESSING


def test_claim_does_not_return_the_same_unexpired_job_twice(database) -> None:
    _engine, _session_factory, db, _user, workspace = database
    add_document(db, workspace)
    now = datetime(2026, 11, 13, tzinfo=UTC)
    worker_id = uuid.uuid4()

    first_claim = claim_next_job(db, worker_id=worker_id, now=now)
    second_claim = claim_next_job(db, worker_id=uuid.uuid4(), now=now)

    assert first_claim is not None
    assert second_claim is None


def test_claim_query_uses_postgres_skip_locked() -> None:
    statement = _claimable_jobs_statement(
        datetime(2026, 11, 13, tzinfo=UTC), max_attempts=3
    )

    sql = str(statement.compile(dialect=postgresql.dialect()))
    assert "FOR UPDATE SKIP LOCKED" in sql


def test_duplicate_jobs_for_one_document_are_rejected(database) -> None:
    _engine, _session_factory, db, _user, workspace = database
    document = add_document(db, workspace)

    with pytest.raises(IntegrityError):
        db.add(DocumentProcessingJob(document_id=document.id, status=PENDING))
        db.flush()
    db.rollback()

    assert db.scalar(select(func.count()).select_from(DocumentProcessingJob)) == 1


def test_heartbeat_extends_lease_and_expired_lease_is_reclaimed(database) -> None:
    _engine, _session_factory, db, _user, workspace = database
    add_document(db, workspace)
    now = datetime(2026, 11, 13, tzinfo=UTC)
    worker_id = uuid.uuid4()

    first_claim = claim_next_job(db, worker_id=worker_id, now=now, lease_seconds=10)
    assert first_claim is not None
    assert heartbeat_job(
        db, first_claim, now=now + timedelta(seconds=5), lease_seconds=10
    )

    assert (
        claim_next_job(
            db,
            worker_id=uuid.uuid4(),
            now=now + timedelta(seconds=12),
            lease_seconds=10,
        )
        is None
    )

    reclaimed = claim_next_job(
        db,
        worker_id=uuid.uuid4(),
        now=now + timedelta(seconds=16),
        lease_seconds=10,
    )
    assert reclaimed is not None
    assert reclaimed.job_id == first_claim.job_id
    assert reclaimed.attempt_count == 2
    assert reclaimed.claim_token != first_claim.claim_token
    assert not complete_job(db, first_claim)


def test_failed_attempt_retries_then_transitions_to_failed(database) -> None:
    _engine, _session_factory, db, _user, workspace = database
    document = add_document(db, workspace)
    now = datetime(2026, 11, 13, tzinfo=UTC)
    worker_id = uuid.uuid4()

    first_claim = claim_next_job(db, worker_id=worker_id, now=now)
    assert first_claim is not None
    assert fail_job(
        db,
        first_claim,
        "temporary error",
        now=now,
        max_attempts=2,
        retry_delay_seconds=2,
    )
    job = db.get(DocumentProcessingJob, first_claim.job_id)
    assert job.status == PENDING
    assert db.get(Document, document.id).status == PENDING
    assert job.available_at.replace(tzinfo=UTC) == now + timedelta(seconds=2)
    assert (
        claim_next_job(db, worker_id=worker_id, now=now + timedelta(seconds=1)) is None
    )

    second_claim = claim_next_job(
        db, worker_id=worker_id, now=now + timedelta(seconds=2)
    )
    assert second_claim is not None
    assert second_claim.attempt_count == 2
    assert fail_job(
        db,
        second_claim,
        "permanent error",
        now=now + timedelta(seconds=2),
        max_attempts=2,
    )
    assert db.get(DocumentProcessingJob, second_claim.job_id).status == FAILED
    assert db.get(Document, document.id).status == FAILED


def test_expired_final_attempt_is_marked_failed(database) -> None:
    _engine, _session_factory, db, _user, workspace = database
    document = add_document(db, workspace)
    now = datetime(2026, 11, 13, tzinfo=UTC)
    claim = claim_next_job(
        db,
        worker_id=uuid.uuid4(),
        now=now,
        lease_seconds=1,
        max_attempts=1,
    )
    assert claim is not None

    assert (
        claim_next_job(
            db,
            worker_id=uuid.uuid4(),
            now=now + timedelta(seconds=2),
            max_attempts=1,
        )
        is None
    )
    assert db.get(DocumentProcessingJob, claim.job_id).status == FAILED
    assert db.get(Document, document.id).status == FAILED


def test_successful_job_transitions_to_processed(database) -> None:
    _engine, _session_factory, db, _user, workspace = database
    document = add_document(db, workspace)
    claim = claim_next_job(db, worker_id=uuid.uuid4())
    assert claim is not None

    assert complete_job(db, claim)
    assert db.get(DocumentProcessingJob, claim.job_id).status == PROCESSED
    assert db.get(Document, document.id).status == PROCESSED


def test_chunk_persistence_reuses_ids_on_retry(database) -> None:
    _engine, _session_factory, db, _user, workspace = database
    document = add_document(db, workspace)
    chunks = [
        LangChainDocument(
            page_content=f"chunk {index}",
            metadata={"chunk_index": index, "page": index + 1},
        )
        for index in range(2)
    ]

    assert save_chunks(db, document.id, chunks) == 2
    initial_ids = [
        row.id
        for row in db.scalars(
            select(DocumentChunk)
            .where(DocumentChunk.document_id == document.id)
            .order_by(DocumentChunk.chunk_index)
        )
    ]
    assert save_chunks(db, document.id, chunks) == 2
    retried = list(
        db.scalars(
            select(DocumentChunk)
            .where(DocumentChunk.document_id == document.id)
            .order_by(DocumentChunk.chunk_index)
        )
    )

    assert len(retried) == 2
    assert [row.id for row in retried] == initial_ids
    assert [row.content for row in retried] == ["chunk 0", "chunk 1"]


def test_upload_enqueues_pending_job_and_status_endpoint_reports_it(
    database, monkeypatch, tmp_path
) -> None:
    _engine, session_factory, _db, user, workspace = database

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    monkeypatch.setattr(
        documents_api,
        "save_document",
        lambda _filename, _content, _workspace_id: (
            tmp_path / "source.txt",
            ".txt",
        ),
    )
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = lambda: user
    client = TestClient(app)
    try:
        response = client.post(
            f"/api/v1/workspaces/{workspace.id}/documents/",
            files={"file": ("source.txt", b"hello world")},
        )
        assert response.status_code == 202
        assert response.json()["status"] == PENDING
        document_id = response.json()["id"]

        status_response = client.get(
            f"/api/v1/workspaces/{workspace.id}/documents/{document_id}/status"
        )
    finally:
        client.close()
        app.dependency_overrides.clear()

    assert status_response.status_code == 200
    assert status_response.json()["document_id"] == document_id
    assert status_response.json()["status"] == PENDING
    assert status_response.json()["stage"] == "queued"
    with session_factory() as db:
        assert db.scalar(select(func.count()).select_from(Document)) == 1
        assert db.scalar(select(func.count()).select_from(DocumentProcessingJob)) == 1
