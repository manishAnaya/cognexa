from __future__ import annotations

import builtins
import threading
import uuid
from unittest.mock import MagicMock

from app.models.documents import Document
from app.services import document_job_worker as worker_module
from app.services.document_jobs import JobClaim


def make_claim() -> JobClaim:
    return JobClaim(
        job_id=uuid.uuid4(),
        document_id=uuid.uuid4(),
        claim_token=uuid.uuid4(),
        worker_id=uuid.uuid4(),
        attempt_count=1,
    )


def mock_session_factory(monkeypatch, document: Document) -> list[MagicMock]:
    sessions = []

    def session_local():
        session = MagicMock()
        session.__enter__.return_value = session
        session.__exit__.return_value = False
        session.get.return_value = document
        sessions.append(session)
        return session

    monkeypatch.setattr(worker_module, "SessionLocal", session_local)
    return sessions


def test_successful_job_calls_existing_pipeline_and_completes(monkeypatch) -> None:
    document = MagicMock(spec=Document)
    mock_session_factory(monkeypatch, document)
    process_document = MagicMock(return_value=3)
    complete_job = MagicMock(return_value=True)
    fail_job = MagicMock()
    monkeypatch.setattr(
        "app.services.document_processing.process_document", process_document
    )
    monkeypatch.setattr(worker_module, "complete_job", complete_job)
    monkeypatch.setattr(worker_module, "fail_job", fail_job)

    worker_module.DocumentJobWorker()._process_claim(make_claim())

    process_document.assert_called_once()
    assert process_document.call_args.args[1] is document
    complete_job.assert_called_once()
    fail_job.assert_not_called()


def test_processing_error_is_sent_to_retry_service(monkeypatch) -> None:
    document = MagicMock(spec=Document)
    mock_session_factory(monkeypatch, document)
    processing_error = ValueError("temporary indexing failure")
    process_document = MagicMock(side_effect=processing_error)
    fail_job = MagicMock(return_value=True)
    complete_job = MagicMock()
    monkeypatch.setattr(
        "app.services.document_processing.process_document", process_document
    )
    monkeypatch.setattr(worker_module, "fail_job", fail_job)
    monkeypatch.setattr(worker_module, "complete_job", complete_job)

    claim = make_claim()
    worker_module.DocumentJobWorker()._process_claim(claim)

    fail_job.assert_called_once()
    assert fail_job.call_args.args[1] == claim
    assert fail_job.call_args.args[2] is processing_error
    complete_job.assert_not_called()


def test_worker_startup_and_shutdown_do_not_load_processing_models(monkeypatch) -> None:
    worker = worker_module.DocumentJobWorker()
    lock_connection = MagicMock()
    monkeypatch.setattr(worker, "_acquire_advisory_lock", lambda: lock_connection)
    claim_attempted = threading.Event()

    def no_jobs(_db, *, worker_id):
        claim_attempted.set()
        worker._stop_event.set()

    class EmptySession:
        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

    monkeypatch.setattr(worker_module, "SessionLocal", EmptySession)
    monkeypatch.setattr(worker_module, "claim_next_job", no_jobs)

    original_import = builtins.__import__
    attempted_model_imports = []

    def guarded_import(name, *args, **kwargs):
        if name.startswith(("sentence_transformers", "langchain_huggingface")):
            attempted_model_imports.append(name)
            raise AssertionError(f"Unexpected model import during startup: {name}")
        return original_import(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", guarded_import)

    worker.start()
    assert claim_attempted.wait(timeout=2)
    worker.stop(timeout=2)

    assert worker._thread is not None
    assert not worker._thread.is_alive()
    assert attempted_model_imports == []
    lock_connection.close.assert_called_once()


def test_worker_loop_contains_unexpected_job_errors(monkeypatch) -> None:
    worker = worker_module.DocumentJobWorker()
    lock_connection = MagicMock()
    monkeypatch.setattr(worker, "_acquire_advisory_lock", lambda: lock_connection)

    class EmptySession:
        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

    monkeypatch.setattr(worker_module, "SessionLocal", EmptySession)
    claim = make_claim()
    worker._process_claim = MagicMock(side_effect=RuntimeError("worker-side error"))
    calls = 0

    def claim_once(_db, *, worker_id):
        nonlocal calls
        calls += 1
        return claim if calls == 1 else None

    monkeypatch.setattr(worker_module, "claim_next_job", claim_once)
    original_wait = worker._stop_event.wait

    def stop_after_retry(delay=None):
        worker._stop_event.set()
        return original_wait(0)

    monkeypatch.setattr(worker._stop_event, "wait", stop_after_retry)

    worker._run()

    worker._process_claim.assert_called_once_with(claim)
    lock_connection.close.assert_called_once()


def test_worker_does_not_start_a_second_job_until_first_finishes(monkeypatch) -> None:
    worker = worker_module.DocumentJobWorker()
    lock_connection = MagicMock()
    monkeypatch.setattr(worker, "_acquire_advisory_lock", lambda: lock_connection)

    class EmptySession:
        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

    monkeypatch.setattr(worker_module, "SessionLocal", EmptySession)
    first_claim = make_claim()
    events = []
    claim_count = 0

    def claim_in_order(_db, *, worker_id):
        nonlocal claim_count
        claim_count += 1
        events.append(f"claim-{claim_count}")
        if claim_count == 1:
            return first_claim
        worker._stop_event.set()

    def process_in_order(claim):
        assert claim is first_claim
        events.extend(("processing-started", "processing-finished"))

    monkeypatch.setattr(worker_module, "claim_next_job", claim_in_order)
    worker._process_claim = process_in_order

    worker._run()

    assert events == ["claim-1", "processing-started", "processing-finished", "claim-2"]
