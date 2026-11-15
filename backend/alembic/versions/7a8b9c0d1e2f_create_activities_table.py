"""create activities table

Revision ID: 7a8b9c0d1e2f
Revises: 55d9e7a831c2
Create Date: 2026-11-15 17:35:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "7a8b9c0d1e2f"
down_revision: str | None = "55d9e7a831c2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "activities",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("issue_id", sa.Uuid(), nullable=False),
        sa.Column("actor_id", sa.Uuid(), nullable=False),
        sa.Column(
            "action",
            sa.String(length=100),
            nullable=False,
            comment="Action type e.g. status_changed, assignee_changed, priority_changed",
        ),
        sa.Column("old_value", sa.Text(), nullable=True),
        sa.Column("new_value", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("(CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("(CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["actor_id"],
            ["users.id"],
            name=op.f("fk_activities_actor_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["issue_id"],
            ["issues.id"],
            name=op.f("fk_activities_issue_id_issues"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_activities")),
    )
    op.create_index(
        op.f("ix_activities_action"), "activities", ["action"], unique=False
    )
    op.create_index(
        op.f("ix_activities_actor_id"), "activities", ["actor_id"], unique=False
    )
    op.create_index(
        op.f("ix_activities_issue_id"), "activities", ["issue_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_activities_issue_id"), table_name="activities")
    op.drop_index(op.f("ix_activities_actor_id"), table_name="activities")
    op.drop_index(op.f("ix_activities_action"), table_name="activities")
    op.drop_table("activities")
