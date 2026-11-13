from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import router
from app.core.config import settings
from app.graphs.checkpointer import pool, setup_checkpointer
from app.services.document_job_worker import document_job_worker


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create checkpoint tables and open the connection pool.
    setup_checkpointer()
    document_job_worker.start()

    try:
        yield
    finally:
        # Stop the worker before closing application database resources.
        document_job_worker.stop()
        pool.close()


app = FastAPI(
    title=settings.APP_NAME,
    description="Enterprise AI Research Assistant",
    version="0.1.0",
    debug=settings.DEBUG,
    lifespan=lifespan,
)

# Flutter web runs on a local development origin and sends a preflight request
# when posting JSON or an Authorization header. Allow local dev ports here.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://cognexa-frontend-neon.vercel.app",
        *(
            origin.strip()
            for origin in settings.CORS_ALLOWED_ORIGINS.split(",")
            if origin.strip()
        ),
    ],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix=settings.API_V1_PREFIX)


@app.get("/")
async def root():
    return {"message": "Welcome to Cognexa", "status": "running"}
