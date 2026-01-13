from fastapi import FastAPI
from contextlib import asynccontextmanager
from .config import get_settings
from .database import engine, Base
from .routers import matches

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Create tables (Dev only) - In prod use Alembic
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown
    await engine.dispose()

app = FastAPI(
    title=settings.api_title,
    version=settings.api_version,
    lifespan=lifespan
)

app.include_router(matches.router, prefix="/api/v1")

@app.get("/")
async def root():
    return {"message": "SushiScout 26 API is running"}
