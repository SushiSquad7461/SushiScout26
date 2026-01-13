import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import StaticPool
from typing import AsyncGenerator

from app.main import app
from app.database import Base, get_db

# Use in-memory SQLite for testing to avoid messing with real Postgres/files
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

@pytest_asyncio.fixture
async def override_get_db():
    """Context manager to override the get_db dependency."""
    engine = create_async_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    
    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    TestingSessionLocal = async_sessionmaker(bind=engine, expire_on_commit=False)

    async def _get_test_db():
        async with TestingSessionLocal() as session:
            yield session

    app.dependency_overrides[get_db] = _get_test_db
    try:
        yield _get_test_db
    finally:
        app.dependency_overrides.clear()
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.drop_all)

@pytest_asyncio.fixture
async def client(override_get_db) -> AsyncGenerator[AsyncClient, None]:
    """Async client for testing API endpoints."""
    # Note: ASGITransport needed for recent httpx versions with FastAPI
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
