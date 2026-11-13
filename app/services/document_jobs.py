import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import and_, or_, select, update
from sqlalchemy.orm import Session

from app.models.document_processing_job import DocumentProcessingJob
from app.models.documents import Document

PENDING = "pending"
PROCESSING = "processing"
PROCESSED = "processed"
FAILED = "failed"

DEFAULT_MAX_ATTEMPTS = 3
DEFAULT_LEASE_SECONDS = 90
DEFAULT_RETRY_DELAY_SECONDS = 5


def utc_now() -> datetime:
    return datetime.now(UTC)


@dataclass(frozen=True)
class JobClaim:
    job_id: uuid.UUID
    document_id: uuid.UUID
    claim_token: uuid.UUID
    worker_id: uuid.UUID
    attempt_count: int


def enqueue_document_job(db: Session, document: Document) -> DocumentProcessingJob:
    """Add a pending job in the caller's document-creation transaction."""
    document.status = PENDING
    db.add(document)
    db.flush()

    job = DocumentProcessingJob(
        document_id=document.id,
        status=PENDING,
        stage="queued",
    )
    db.add(job)
    db.flush()
    return job


def _claimable_jobs_statement(now: datetime, max_attempts: int):
    is_due = and_(
        DocumentProcessingJob.status == PENDING,
        DocumentProcessingJob.available_at <= now,
    )
    lease_expired = and_(
        DocumentProcessingJob.status == PROCESSING,
        DocumentProcessingJob.lease_expires_at <= now,
        DocumentProcessingJob.attempt_count < max_attempts,
    )
    return (
        select(DocumentProcessingJob)
        .where(or_(is_due, lease_expired))
        .order_by(DocumentProcessingJob.created_at, DocumentProcessingJob.id)
        .with_for_update(skip_locked=True)
        .limit(1)
    )


def claim_next_job(
    db: Session,
    *,
    worker_id: uuid.UUID,
    now: datetime | None = None,
    lease_seconds: int = DEFAULT_LEASE_SECONDS,
    max_attempts: int = DEFAULT_MAX_ATTEMPTS,
) -> JobClaim | None:
    """Atomically claim one due or expired job using PostgreSQL row locking."""
    now = now or utc_now()

    exhausted = db.scalar(
        select(DocumentProcessingJob)
        .where(
            DocumentProcessingJob.status == PROCESSING,
            DocumentProcessingJob.lease_expires_at <= now,
            DocumentProcessingJob.attempt_count >= max_attempts,
        )
        .with_for_update(skip_locked=True)
        .limit(1)
    )
    if exhausted is not None:
        exhausted.status = FAILED
        exhausted.stage = FAILED
        exhausted.last_error = exhausted.last_error or (
            "Worker lease expired after the final attempt."
        )
        exhausted.claim_token = None
        exhausted.worker_id = None
        exhausted.lease_expires_at = None
        document = db.get(Document, exhausted.document_id)
        if document is not None:
            document.status = FAILED
        db.commit()
        return None

    job = db.scalar(_claimable_jobs_statement(now, max_attempts))
    if job is None:
        db.commit()
        return None

    claim_token = uuid.uuid4()
    job.status = PROCESSING
    job.stage = PROCESSING
    job.attempt_count += 1
    job.claim_token = claim_token
    job.worker_id = worker_id
    job.lease_expires_at = now + timedelta(seconds=lease_seconds)
    job.heartbeat_at = now
    job.last_error = None

    document = db.get(Document, job.document_id)
    if document is not None:
        document.status = PROCESSING

    claim = JobClaim(
        job_id=job.id,
        document_id=job.document_id,
        claim_token=claim_token,
        worker_id=worker_id,
        attempt_count=job.attempt_count,
    )
    db.commit()
    return claim


def heartbeat_job(
    db: Session,
    claim: JobClaim,
    *,
    now: datetime | None = None,
    lease_seconds: int = DEFAULT_LEASE_SECONDS,
) -> bool:
    now = now or utc_now()
    result = db.execute(
        update(DocumentProcessingJob)
        .where(
            DocumentProcessingJob.id == claim.job_id,
            DocumentProcessingJob.status == PROCESSING,
            DocumentProcessingJob.claim_token == claim.claim_token,
        )
        .values(
            heartbeat_at=now,
            lease_expires_at=now + timedelta(seconds=lease_seconds),
            updated_at=now,
        )
    )
    db.commit()
    return result.rowcount == 1


def complete_job(db: Session, claim: JobClaim, *, now: datetime | None = None) -> bool:
    now = now or utc_now()
    job = db.scalar(
        select(DocumentProcessingJob)
        .where(
            DocumentProcessingJob.id == claim.job_id,
            DocumentProcessingJob.status == PROCESSING,
            DocumentProcessingJob.claim_token == claim.claim_token,
        )
        .with_for_update()
    )
    if job is None:
        db.rollback()
        return False

    job.status = PROCESSED
    job.stage = PROCESSED
    job.claim_token = None
    job.worker_id = None
    job.lease_expires_at = None
    job.heartbeat_at = now
    job.updated_at = now
    document = db.get(Document, job.document_id)
    if document is not None:
        document.status = PROCESSED
    db.commit()
    return True


def fail_job(
    db: Session,
    claim: JobClaim,
    error: Exception | str,
    *,
    now: datetime | None = None,
    max_attempts: int = DEFAULT_MAX_ATTEMPTS,
    retry_delay_seconds: int = DEFAULT_RETRY_DELAY_SECONDS,
) -> bool:
    """Schedule a bounded exponential retry or mark the job terminally failed."""
    now = now or utc_now()
    job = db.scalar(
        select(DocumentProcessingJob)
        .where(
            DocumentProcessingJob.id == claim.job_id,
            DocumentProcessingJob.status == PROCESSING,
            DocumentProcessingJob.claim_token == claim.claim_token,
        )
        .with_for_update()
    )
    if job is None:
        db.rollback()
        return False

    job.last_error = str(error)[:8000]
    job.claim_token = None
    job.worker_id = None
    job.lease_expires_at = None
    job.heartbeat_at = now
    job.updated_at = now

    document = db.get(Document, job.document_id)
    if job.attempt_count < max_attempts:
        delay = retry_delay_seconds * (2 ** max(job.attempt_count - 1, 0))
        job.status = PENDING
        job.stage = "retry_wait"
        job.available_at = now + timedelta(seconds=delay)
        if document is not None:
            document.status = PENDING
    else:
        job.status = FAILED
        job.stage = FAILED
        if document is not None:
            document.status = FAILED

    db.commit()
    return True
