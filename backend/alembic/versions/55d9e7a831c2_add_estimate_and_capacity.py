"""add estimate to issues and capacity to sprints

Revision ID: 55d9e7a831c2
Revises: 330b072bff39
Create Date: 2026-11-15 17:15:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "55d9e7a831c2"
down_revision: str | None = "330b072bff39"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "sprints",
        sa.Column(
            "capacity",
            sa.Float(),
            nullable=True,
            comment="Planned capacity limit in story points or hours",
        ),
    )
    op.add_column(
        "issues",
        sa.Column(
            "estimate",
            sa.Float(),
            nullable=True,
            comment="Story points or time estimate for sprint planning",
        ),
    )


def downgrade() -> None:
    op.drop_column("issues", "estimate")
    op.drop_column("sprints", "capacity")
