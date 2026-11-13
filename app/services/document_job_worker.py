import logging
import threading
import uuid

from sqlalchemy import text

from app.db.session import SessionLocal, engine
from app.services.document_jobs import (
    DEFAULT_LEASE_SECONDS,
    JobClaim,
    claim_next_job,
    complete_job,
    fail_job,
    heartbeat_job,
)

logger = logging.getLogger(__name__)

POLL_INTERVAL_SECONDS = 2
HEARTBEAT_INTERVAL_SECONDS = max(1, DEFAULT_LEASE_SECONDS // 3)
WORKER_ADVISORY_LOCK_ID = 7_420_261_113
WORKER_SHUTDOWN_TIMEOUT_SECONDS = 30


class DocumentJobWorker:
    """Single-threaded job poller; document processing never runs on ASGI's loop."""

    def __init__(self) -> None:
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None
        self._thread_lock = threading.Lock()
        self._worker_id = uuid.uuid4()

    def start(self) -> None:
        with self._thread_lock:
            if self._thread is not None and self._thread.is_alive():
                return
            self._stop_event.clear()
            self._worker_id = uuid.uuid4()
            self._thread = threading.Thread(
                target=self._run,
                name="cognexa-document-worker",
                daemon=True,
            )
            self._thread.start()
        logger.info("Document processing worker started")

    def stop(self, timeout: float = WORKER_SHUTDOWN_TIMEOUT_SECONDS) -> None:
        self._stop_event.set()
        thread = self._thread
        if thread is not None:
            thread.join(timeout=timeout)
            if thread.is_alive():
                logger.warning(
                    "Document worker did not stop within %.1f seconds; "
                    "its lease will allow recovery after shutdown",
                    timeout,
                )
            else:
                logger.info("Document processing worker stopped")

    def _acquire_advisory_lock(self):
        if engine.dialect.name != "postgresql":
            logger.error("Document worker requires PostgreSQL advisory locks")
            return None

        while not self._stop_event.is_set():
            connection = None
            try:
                connection = engine.connect()
                acquired = connection.execute(
                    text("SELECT pg_try_advisory_lock(:lock_id)"),
                    {"lock_id": WORKER_ADVISORY_LOCK_ID},
                ).scalar_one()
                connection.commit()
                if acquired:
                    return connection
                connection.close()
            except Exception:
                logger.exception("Could not acquire document worker lock")
                if connection is not None:
                    connection.close()
            self._stop_event.wait(POLL_INTERVAL_SECONDS)
        return None

    def _run(self) -> None:
        lock_connection = self._acquire_advisory_lock()
        if lock_connection is None:
            return

        logger.info("Document worker acquired the PostgreSQL worker lock")
        try:
            while not self._stop_event.is_set():
                try:
                    with SessionLocal() as db:
                        claim = claim_next_job(db, worker_id=self._worker_id)
                    if claim is None:
                        self._stop_event.wait(POLL_INTERVAL_SECONDS)
                        continue
                    self._process_claim(claim)
                except Exception:
                    logger.exception("Document worker loop failed")
                    self._stop_event.wait(POLL_INTERVAL_SECONDS)
        finally:
            try:
                lock_connection.execute(
                    text("SELECT pg_advisory_unlock(:lock_id)"),
                    {"lock_id": WORKER_ADVISORY_LOCK_ID},
                )
                lock_connection.commit()
            except Exception:
                logger.exception("Could not release document worker lock")
            finally:
                lock_connection.close()

    def _process_claim(self, claim: JobClaim) -> None:
        heartbeat_stop = threading.Event()
        heartbeat_thread = threading.Thread(
            target=self._heartbeat,
            args=(claim, heartbeat_stop),
            name=f"cognexa-job-heartbeat-{claim.job_id}",
            daemon=True,
        )
        heartbeat_thread.start()

        try:
            # Keep ingestion/model dependencies out of worker startup. Import
            # failures are handled like processing failures and follow retries.
            from app.models.documents import Document
            from app.services.document_processing import process_document

            with SessionLocal() as db:
                document = db.get(Document, claim.document_id)
                if document is None:
                    heartbeat_stop.set()
                    heartbeat_thread.join(timeout=HEARTBEAT_INTERVAL_SECONDS + 1)
                    fail_job(db, claim, "Document no longer exists.")
                    return

                process_document(db, document)

            heartbeat_stop.set()
            heartbeat_thread.join(timeout=HEARTBEAT_INTERVAL_SECONDS + 1)
            with SessionLocal() as db:
                complete_job(db, claim)
        except Exception as error:
            heartbeat_stop.set()
            heartbeat_thread.join(timeout=HEARTBEAT_INTERVAL_SECONDS + 1)
            with SessionLocal() as db:
                fail_job(db, claim, error)
            logger.exception("Document processing failed for job %s", claim.job_id)
        finally:
            heartbeat_stop.set()
            heartbeat_thread.join(timeout=HEARTBEAT_INTERVAL_SECONDS + 1)

    def _heartbeat(self, claim: JobClaim, stop_event: threading.Event) -> None:
        while not stop_event.wait(HEARTBEAT_INTERVAL_SECONDS):
            try:
                with SessionLocal() as db:
                    still_claimed = heartbeat_job(db, claim)
                if not still_claimed:
                    logger.warning("Lost lease for document job %s", claim.job_id)
                    return
            except Exception:
                logger.exception("Heartbeat failed for job %s", claim.job_id)


document_job_worker = DocumentJobWorker()
