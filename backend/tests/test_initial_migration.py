import tempfile
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect


def test_initial_migration_schema():
    """Verify that the initial migration creates all 7 domain tables with accurate schema."""
    backend_dir = Path(__file__).parent.parent
    ini_path = backend_dir / "alembic.ini"
    assert ini_path.exists(), "alembic.ini not found"

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tmp:
        db_path = tmp.name

    try:
        sqlite_url = f"sqlite:///{db_path}"
        alembic_cfg = Config(str(ini_path))
        alembic_cfg.set_main_option("sqlalchemy.url", sqlite_url)

        # 1. Upgrade to head
        command.upgrade(alembic_cfg, "head")

        engine = create_engine(sqlite_url)
        inspector = inspect(engine)
        table_names = set(inspector.get_table_names())

        expected_tables = {
            "users",
            "workspaces",
            "projects",
            "workspace_members",
            "project_members",
            "sprints",
            "issues",
            "alembic_version",
        }
        assert expected_tables.issubset(table_names), (
            f"Missing tables: {expected_tables - table_names}"
        )

        # 2. Inspect users table
        user_cols = {col["name"] for col in inspector.get_columns("users")}
        expected_user_cols = {
            "id",
            "email",
            "hashed_password",
            "full_name",
            "avatar_url",
            "is_active",
            "created_at",
            "updated_at",
            "deleted_at",
        }
        assert expected_user_cols.issubset(user_cols)

        # 3. Inspect workspaces table
        ws_cols = {col["name"] for col in inspector.get_columns("workspaces")}
        assert {"id", "name", "slug", "description", "owner_id", "created_at"}.issubset(
            ws_cols
        )

        # 4. Inspect projects table
        project_cols = {col["name"] for col in inspector.get_columns("projects")}
        assert {"id", "name", "key", "workspace_id", "created_at"}.issubset(
            project_cols
        )

        # 5. Inspect workspace_members table
        wm_cols = {col["name"] for col in inspector.get_columns("workspace_members")}
        assert {"id", "workspace_id", "user_id", "role", "created_at"}.issubset(wm_cols)

        # 6. Inspect project_members table
        pm_cols = {col["name"] for col in inspector.get_columns("project_members")}
        assert {"id", "project_id", "user_id", "role", "created_at"}.issubset(pm_cols)

        # 7. Inspect sprints table
        sprint_cols = {col["name"] for col in inspector.get_columns("sprints")}
        assert {
            "id",
            "project_id",
            "name",
            "goal",
            "start_date",
            "end_date",
            "status",
        }.issubset(sprint_cols)

        # 8. Inspect issues table
        issue_cols = {col["name"] for col in inspector.get_columns("issues")}
        assert {
            "id",
            "project_id",
            "issue_number",
            "title",
            "description",
            "type",
            "status",
            "priority",
            "reporter_id",
            "assignee_id",
            "parent_id",
            "sprint_id",
            "backlog_rank",
        }.issubset(issue_cols)

        engine.dispose()

        # 9. Downgrade to base
        command.downgrade(alembic_cfg, "base")

        engine = create_engine(sqlite_url)
        inspector = inspect(engine)
        remaining_tables = set(inspector.get_table_names())
        # All domain tables should be dropped
        assert not (expected_tables - {"alembic_version"}).intersection(
            remaining_tables
        )
        engine.dispose()

        # 10. Re-upgrade to head (idempotency)
        command.upgrade(alembic_cfg, "head")
        engine = create_engine(sqlite_url)
        inspector = inspect(engine)
        table_names_reup = set(inspector.get_table_names())
        assert expected_tables.issubset(table_names_reup)
        engine.dispose()

    finally:
        db_file = Path(db_path)
        if db_file.exists():
            db_file.unlink()
