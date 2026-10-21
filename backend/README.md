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

## Dependencies

Project dependencies are declared in `pyproject.toml` and locked in `uv.lock`. Use `uv add` to add dependencies and `uv remove` to remove them.

## Python Version

The project targets Python `>=3.14,<3.15`.
