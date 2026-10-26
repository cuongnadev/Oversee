from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router

app = FastAPI(
    title="Oversee Backend",
    version="0.1.0",
    description="Backend API for Oversee task management system",
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
