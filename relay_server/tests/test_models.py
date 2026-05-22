import pytest
import models


async def test_init_db_creates_users_table():
    await models.init_db()


async def test_create_and_get_user():
    await models.init_db()
    await models.create_user("test@example.com", "hashed_pw")
    user = await models.get_user_by_email("test@example.com")
    assert user is not None
    assert user["email"] == "test@example.com"
    assert user["hashed_password"] == "hashed_pw"


async def test_get_nonexistent_user():
    await models.init_db()
    user = await models.get_user_by_email("none@example.com")
    assert user is None
