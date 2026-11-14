import tempfile
from pathlib import Path

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory


def test_alembic_config_and_metadata():
    """Verify that alembic.ini points to valid script location and target metadata."""
    backend_dir = Path(__file__).parent.parent
    ini_path = backend_dir / "alembic.ini"
    assert ini_path.exists(), "alembic.ini not found"

    alembic_cfg = Config(str(ini_path))
    script = ScriptDirectory.from_config(alembic_cfg)
    assert script.dir is not None

    env_py = Path(script.dir) / "env.py"
    assert env_py.exists(), "alembic/env.py not found"
    content = env_py.read_text(encoding="utf-8")
    assert "target_metadata = Base.metadata" in content
    assert "settings.database_url" in content


def test_alembic_upgrade_and_downgrade_execution():
    """Verify that alembic upgrade head and downgrade commands run successfully."""
    backend_dir = Path(__file__).parent.parent
    ini_path = backend_dir / "alembic.ini"

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tmp:
        db_path = tmp.name

    try:
        sqlite_url = f"sqlite:///{db_path}"
        alembic_cfg = Config(str(ini_path))
        alembic_cfg.set_main_option("sqlalchemy.url", sqlite_url)

        # Run upgrade head
        command.upgrade(alembic_cfg, "head")

        # Run downgrade base
        command.downgrade(alembic_cfg, "base")
    finally:
        db_file = Path(db_path)
        if db_file.exists():
            db_file.unlink()
