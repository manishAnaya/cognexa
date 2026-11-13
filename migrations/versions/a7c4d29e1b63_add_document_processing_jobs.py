"""add durable document processing jobs and idempotent chunks

Revision ID: a7c4d29e1b63
Revises: 20bbf03c69b0
Create Date: 2026-11-13

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "a7c4d29e1b63"
down_revision: str | Sequence[str] | None = "20bbf03c69b0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Keep one existing chunk per document/index before adding the constraint.
    op.execute(
        """
        DELETE FROM document_chunks AS duplicate
        USING document_chunks AS keeper
        WHERE duplicate.document_id = keeper.document_id
          AND duplicate.chunk_index = keeper.chunk_index
          AND duplicate.id > keeper.id
        """
    )
    op.create_unique_constraint(
        "uq_document_chunks_document_index",
        "document_chunks",
        ["document_id", "chunk_index"],
    )

    op.create_table(
        "document_processing_jobs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("document_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("stage", sa.String(length=50), nullable=True),
        sa.Column("attempt_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "available_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("claim_token", sa.Uuid(), nullable=True),
        sa.Column("worker_id", sa.Uuid(), nullable=True),
        sa.Column("lease_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("heartbeat_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["document_id"], ["documents.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("document_id"),
    )
    op.create_index(
        "ix_document_processing_jobs_status_available_at",
        "document_processing_jobs",
        ["status", "available_at"],
    )
    op.create_index(
        "ix_document_processing_jobs_status_lease_expires_at",
        "document_processing_jobs",
        ["status", "lease_expires_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_document_processing_jobs_status_lease_expires_at",
        table_name="document_processing_jobs",
    )
    op.drop_index(
        "ix_document_processing_jobs_status_available_at",
        table_name="document_processing_jobs",
    )
    op.drop_table("document_processing_jobs")
    op.drop_constraint(
        "uq_document_chunks_document_index",
        "document_chunks",
        type_="unique",
    )
