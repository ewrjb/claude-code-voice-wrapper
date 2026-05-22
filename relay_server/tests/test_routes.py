import pytest
from httpx import AsyncClient, ASGITransport
from main import app


async def test_register_success():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.post("/auth/register", json={"email": "a@test.com", "password": "pass123"})
    assert response.status_code == 201
    assert response.json() == {"message": "registered"}


async def test_register_duplicate_email():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/auth/register", json={"email": "a@test.com", "password": "pass123"})
        response = await client.post("/auth/register", json={"email": "a@test.com", "password": "pass123"})
    assert response.status_code == 400


async def test_login_success():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/auth/register", json={"email": "a@test.com", "password": "pass123"})
        response = await client.post("/auth/login", json={"email": "a@test.com", "password": "pass123"})
    assert response.status_code == 200
    assert "access_token" in response.json()


async def test_login_wrong_password():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/auth/register", json={"email": "a@test.com", "password": "pass123"})
        response = await client.post("/auth/login", json={"email": "a@test.com", "password": "wrongpass"})
    assert response.status_code == 401


async def test_login_unknown_email():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.post("/auth/login", json={"email": "none@test.com", "password": "pass"})
    assert response.status_code == 401
