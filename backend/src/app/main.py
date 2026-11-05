from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router

tags_metadata = [
    {
        "name": "health",
        "description": "Service health check endpoints.",
    },
    {
        "name": "root",
        "description": "Root endpoint.",
    },
]

app = FastAPI(
    title="Oversee Backend",
    version="0.1.0",
    description="Backend API for Oversee task management system",
    openapi_tags=tags_metadata,
    contact={
        "name": "Oversee Team",
        "url": "https://github.com/cuongnadev/Oversee",
    },
    license_info={
        "name": "MIT",
    },
)

app.add_middleware(
    CORSMiddleware,
    # Development-only: allow all origins until frontend origin is known.
    # Restrict allow_origins to the real frontend origin before production.
    # allow_credentials must stay False while allow_origins is ["*"].
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/", tags=["root"])
def root():
    return {"message": "Oversee Backend API"}
