"""store original uploads in PostgreSQL for restart-safe processing

Revision ID: d2a8f0c91b64
Revises: a7c4d29e1b63
Create Date: 2026-11-16

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "d2a8f0c91b64"
down_revision: str | Sequence[str] | None = "a7c4d29e1b63"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("documents", sa.Column("file_content", sa.LargeBinary(), nullable=True))


def downgrade() -> None:
    op.drop_column("documents", "file_content")
