# Oversee Backend

Backend service for the Oversee task management system.

## Requirements

- Python 3.14.x
- [uv](https://docs.astral.sh/uv/)

## Setup

From the `backend` directory:

```powershell
uv sync
```

This creates or synchronizes the virtual environment and installs the dependencies declared in `pyproject.toml` and `uv.lock`.

## Development Environment

Run Python within the project environment:

```powershell
uv run python --version
```

Inspect installed dependencies:

```powershell
uv tree
```

## Build

Build the Python package:

```powershell
uv build
```

Build artifacts are generated in the `dist/` directory.

## Project Structure

```text
backend/
├── src/
│   └── app/
│       ├── __init__.py
│       └── core/
│           └── __init__.py
├── tests/
├── .python-version
├── pyproject.toml
├── README.md
└── uv.lock
```

## Environment Variables

Copy `.env.example` to `.env` and adjust values as needed:

```powershell
cp .env.example .env
```

Available variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_NAME` | Application name | `Oversee Backend` |
| `APP_VERSION` | Application version | `0.1.0` |
| `DEBUG` | Enable debug mode | `false` |
| `HOST` | Server host | `127.0.0.1` |
| `PORT` | Server port | `8000` |
| `CORS_ORIGINS` | Allowed CORS origins (comma-separated; `*` for dev only) | `*` |

Never commit `.env` or any secret. `.env` is ignored by `.gitignore`.

Project dependencies are declared in `pyproject.toml` and locked in `uv.lock`. Use `uv add` to add dependencies and `uv remove` to remove them.

## Python Version

The project targets Python `>=3.14,<3.15`.
