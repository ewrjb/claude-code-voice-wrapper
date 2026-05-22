import os
os.environ["SECRET_KEY"] = "test-secret-key-for-tests"

import models
models.DB_PATH = "test_relay.db"

import asyncio
import aiosqlite
import pytest
import pytest_asyncio


# Initialize DB once per session
@pytest.fixture(scope="session", autouse=True)
def init_db_once():
    asyncio.run(models.init_db())
    yield
    if os.path.exists(models.DB_PATH):
        os.remove(models.DB_PATH)


# Clean users table after each async test
@pytest_asyncio.fixture(autouse=True)
async def clean_users_async():
    yield
    async with aiosqlite.connect(models.DB_PATH) as db:
        await db.execute("DELETE FROM users")
        await db.commit()
