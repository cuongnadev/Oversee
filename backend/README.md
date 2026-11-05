# Oversee Backend

Oversee Backend is the API service for the **Oversee** task management system. It provides a versioned REST API, health checks, automatic OpenAPI documentation, and a foundation for project/task management features.

**Technology stack (from `pyproject.toml`):**

- Python `>=3.14,<3.15`
- FastAPI (with standard extras)
- Uvicorn
- Pydantic Settings
- pytest, Ruff (development)

## A. Project Overview

The backend exposes a versioned API under `/api/v1`, a root endpoint, and a health check. It is configured through environment variables (`.env`) and validates configuration at startup (fail-fast). API documentation is auto-generated at `/docs` and `/openapi.json`.

## B. Prerequisites

- **Python 3.14.x** (see `.python-version`)
- **uv** (dependency manager)

Install `uv`:

- macOS/Linux:

  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

- Windows (PowerShell):

  ```powershell
  powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
  ```

Verify:

```bash
python --version
uv --version
```

On Windows PowerShell use `python --version` and `uv --version`.

## C. Installation and Setup

Run all commands from the `backend/` directory.

1. Navigate to the backend directory:

   ```bash
   cd backend
   ```

2. Synchronize dependencies:

   ```bash
   uv sync
   ```

   `uv sync` creates/updates `.venv` and installs all dependencies from `pyproject.toml` and `uv.lock`.

3. Create your environment file:

   - macOS/Linux:

     ```bash
     cp .env.example .env
     ```

   - Windows (PowerShell):

     ```powershell
     Copy-Item .env.example .env
     ```

4. Edit `.env` and set at least `SECRET_KEY` (minimum 32 characters). See the Environment Variables table.

5. Verify the environment:

   ```bash
   uv run python --version
   uv run pytest
   ```

## D. Environment Variables

Copy `.env.example` to `.env`. Never commit `.env` (it is gitignored).

| Variable | Description | Default | Required | Example |
|----------|-------------|---------|----------|---------|
| `APP_NAME` | Application name | `Oversee Backend` | No | `Oversee Backend` |
| `APP_VERSION` | Application version | `0.1.0` | No | `0.1.0` |
| `ENVIRONMENT` | Environment (`dev`, `test`, `prod`) | `dev` | No | `dev` |
| `DEBUG` | Enable debug mode | `false` | No | `true` |
| `HOST` | Server host | `127.0.0.1` | No | `0.0.0.0` |
| `PORT` | Server port (1-65535) | `8000` | No | `8000` |
| `LOG_LEVEL` | Logging level (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`) | `INFO` | No | `DEBUG` |
| `CORS_ORIGINS` | Comma-separated allowed origins; `*` only alone (dev) | `*` | No | `https://app.example.com` |
| `SECRET_KEY` | Secret key, minimum 32 characters, must not be blank | (none) | **Yes** | `dev-secret-key-change-in-production-min-32-chars` |

Notes:
- `SECRET_KEY` is required; the app fails fast with a clear error if missing or too short.
- `CORS_ORIGINS=*` cannot be combined with other origins.
- `LOG_LEVEL` must be one of the supported values.

## E. Running the Backend

Start the development server:

```bash
uv run uvicorn app.main:app --reload
```

- `--reload` watches files and restarts automatically.
- Stop with `Ctrl+C`.
- If the port is occupied, use another port: `uv run uvicorn app.main:app --reload --port 8001`.

Successful startup shows `Uvicorn running on http://127.0.0.1:8000`.

## F. API Documentation and Verification

| URL | Purpose |
|-----|---------|
| `http://localhost:8000/` | Root endpoint |
| `http://localhost:8000/api/v1/health` | Health check |
| `http://localhost:8000/docs` | Swagger UI |
| `http://localhost:8000/redoc` | ReDoc |
| `http://localhost:8000/openapi.json` | OpenAPI schema |

Examples:

```bash
curl http://localhost:8000/
# {"message":"Oversee Backend API"}

curl http://localhost:8000/api/v1/health
# {"status":"ok","version":"0.1.0"}
```

## G. Testing

Run the full suite:

```bash
uv run pytest
```

Run a specific file:

```bash
uv run pytest tests/test_config.py
```

Run a specific test:

```bash
uv run pytest tests/test_config.py::test_default_values
```

Verbose output:

```bash
uv run pytest -v
```

## H. Code Quality: Linting and Formatting

Lint:

```bash
uv run ruff check .
```

Format check:

```bash
uv run ruff format --check .
```

Auto-format:

```bash
uv run ruff format .
```

Fix auto-fixable lint issues:

```bash
uv run ruff check --fix .
```

Run lint and format checks before committing.

## I. Project Structure

```text
backend/
├── src/
│   └── app/
│       ├── __init__.py
│       ├── main.py              # FastAPI entry point
│       ├── api/
│       │   ├── __init__.py
│       │   ├── router.py        # mounts /api/v1
│       │   └── v1/
│       │       ├── __init__.py
│       │       ├── router.py    # v1 router
│       │       └── endpoints/
│       │           ├── __init__.py
│       │           └── health.py
│       └── core/
│           ├── __init__.py
│           ├── config.py        # pydantic-settings Settings
│           └── logging.py       # logging configuration
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_config.py
│   ├── test_health.py
│   └── test_logging.py
├── .env.example
├── .python-version
├── pyproject.toml
├── README.md
└── uv.lock
```

Responsibilities:
- `main.py`: creates the FastAPI app, middleware, routers, root endpoint.
- `api/`: versioned routers and endpoints.
- `core/config.py`: typed settings loaded from `.env`/environment.
- `core/logging.py`: unified logging and request logging middleware.
- `tests/`: pytest tests; `conftest.py` provides test-only defaults.

## J. Development Conventions

- Use Python type hints where useful.
- Organize endpoints under `app/api/v1/endpoints/` and register in `v1/router.py`.
- Read configuration via `app.core.config.settings` (or `get_settings()`); never hardcode secrets.
- Log via the standard `logging` module; never log passwords, tokens, or request bodies.
- Write tests with pytest; keep them independent of developer `.env`.
- Follow Ruff formatting/linting.

## K. Git Workflow and Commit Conventions

Follow `OVERSEE_GIT_WORKFLOW_GUIDE.md` at the repository root.

- Branch from `develop`: `git switch develop && git pull --ff-only origin develop && git switch -c feat/<short-description>`.
- Branch prefixes: `feat/`, `fix/`, `docs/`, `test/`, `refactor/`, `chore/`, `ci/`.
- Pull Requests target `develop` (developer changes); only the Lead merges `develop` into `master`.
- Do not commit directly to `master` or `develop`.
- Commit message format (Conventional Commits): `<type>(<scope>): <short summary>`, e.g. `feat(tasks): add task creation endpoint`.
- Before committing run: `uv run pytest`, `uv run ruff check .`, `uv run ruff format --check .`, `git diff --check`.

## L. Troubleshooting

- **Python version mismatch**: ensure Python 3.14.x (`python --version`). Use `uv python install 3.14` if needed.
- **uv not found**: install uv (see Prerequisites) and restart the shell.
- **Dependency sync failure**: run `uv sync` again; check network; verify `uv.lock` is present.
- **Missing/invalid SECRET_KEY**: set `SECRET_KEY` in `.env` with at least 32 characters. The app fails fast with a clear error.
- **Port in use**: use `--port 8001`.
- **Module import errors**: run from `backend/` directory; ensure `uv sync` succeeded.
- **Tests failing**: ensure no stale `.env` overrides; run `uv run pytest -v`.
- **Ruff not found**: run via `uv run ruff ...`.
- **Wrong API path**: health is at `/api/v1/health`, not `/health`.

## M. Quick Start

```bash
cd backend
uv sync
cp .env.example .env   # Windows: Copy-Item .env.example .env
# edit .env: set SECRET_KEY (min 32 chars)
uv run uvicorn app.main:app --reload
```

Then verify:

```bash
curl http://localhost:8000/
curl http://localhost:8000/api/v1/health
```

Expected: `{"message":"Oversee Backend API"}` and `{"status":"ok","version":"0.1.0"}`.

---

Dependencies are declared in `pyproject.toml` and locked in `uv.lock`. Use `uv add`/`uv remove` to manage them. The project targets Python `>=3.14,<3.15`.
