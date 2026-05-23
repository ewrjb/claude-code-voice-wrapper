"""
End-to-end integration test.

Starts the relay server as a real subprocess on a local port, then
exercises the full app ↔ relay ↔ agent WebSocket flow using the
`websockets` library — no TestClient, no mocks.
"""
import asyncio
import json
import os
import subprocess
import sys
import time

import httpx
import pytest
import websockets

RELAY_PORT = 19765
RELAY_HTTP = f"http://127.0.0.1:{RELAY_PORT}"
RELAY_WS = f"ws://127.0.0.1:{RELAY_PORT}"
RELAY_DIR = os.path.join(os.path.dirname(__file__), "..", "relay_server")
SECRET = "e2e-test-secret-key"


# ---------------------------------------------------------------------------
# Fixture: start relay server as subprocess
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def relay_server():
    env = {**os.environ, "SECRET_KEY": SECRET}
    proc = subprocess.Popen(
        [
            sys.executable, "-m", "uvicorn", "main:app",
            "--host", "127.0.0.1",
            "--port", str(RELAY_PORT),
            "--log-level", "error",
        ],
        cwd=RELAY_DIR,
        env=env,
    )
    # Wait up to 10 s for the server to accept connections
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        try:
            httpx.get(f"{RELAY_HTTP}/docs", timeout=0.5)
            break
        except Exception:
            time.sleep(0.3)
    else:
        proc.terminate()
        pytest.fail("Relay server did not start in time")

    yield proc

    proc.terminate()
    proc.wait(timeout=5)
    # Remove the DB created by the running server
    db_path = os.path.join(RELAY_DIR, "relay.db")
    if os.path.exists(db_path):
        os.remove(db_path)


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

async def register_and_login(email: str, password: str = "pass1234") -> str:
    async with httpx.AsyncClient() as client:
        await client.post(
            f"{RELAY_HTTP}/auth/register",
            json={"email": email, "password": password},
        )
        resp = await client.post(
            f"{RELAY_HTTP}/auth/login",
            json={"email": email, "password": password},
        )
        return resp.json()["access_token"]


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_relay_rejects_invalid_token(relay_server):
    """WebSocket with a bad token must be closed by server (recv raises)."""
    with pytest.raises(Exception):
        async with websockets.connect(f"{RELAY_WS}/ws/app?token=bad-token") as ws:
            # Server closes the connection — recv() raises ConnectionClosed
            await asyncio.wait_for(ws.recv(), timeout=3)


@pytest.mark.asyncio
async def test_app_receives_agent_offline_on_connect(relay_server):
    """App gets agent_status offline when no agent is connected."""
    token = await register_and_login("offline@e2e.test")
    async with websockets.connect(f"{RELAY_WS}/ws/app?token={token}") as app_ws:
        msg = json.loads(await asyncio.wait_for(app_ws.recv(), timeout=3))
        assert msg == {"type": "agent_status", "online": False}


@pytest.mark.asyncio
async def test_agent_connect_notifies_app(relay_server):
    """When agent connects, app receives agent_status online."""
    token = await register_and_login("notify@e2e.test")
    async with websockets.connect(f"{RELAY_WS}/ws/app?token={token}") as app_ws:
        await asyncio.wait_for(app_ws.recv(), timeout=3)  # consume offline status
        async with websockets.connect(f"{RELAY_WS}/ws/agent?token={token}"):
            msg = json.loads(await asyncio.wait_for(app_ws.recv(), timeout=3))
            assert msg == {"type": "agent_status", "online": True}


@pytest.mark.asyncio
async def test_command_relay_app_to_agent(relay_server):
    """Command sent by app arrives at agent unchanged."""
    token = await register_and_login("cmd@e2e.test")
    async with websockets.connect(f"{RELAY_WS}/ws/agent?token={token}") as agent_ws:
        async with websockets.connect(f"{RELAY_WS}/ws/app?token={token}") as app_ws:
            await asyncio.wait_for(app_ws.recv(), timeout=3)  # agent_status online
            await app_ws.send(json.dumps({"type": "command", "text": "테스트 명령어"}))
            msg = json.loads(await asyncio.wait_for(agent_ws.recv(), timeout=3))
            assert msg == {"type": "command", "text": "테스트 명령어"}


@pytest.mark.asyncio
async def test_response_relay_agent_to_app(relay_server):
    """Response sent by agent arrives at app unchanged."""
    token = await register_and_login("resp@e2e.test")
    async with websockets.connect(f"{RELAY_WS}/ws/agent?token={token}") as agent_ws:
        async with websockets.connect(f"{RELAY_WS}/ws/app?token={token}") as app_ws:
            await asyncio.wait_for(app_ws.recv(), timeout=3)  # agent_status online
            await agent_ws.send(json.dumps({"type": "response", "text": "수정 완료했습니다."}))
            msg = json.loads(await asyncio.wait_for(app_ws.recv(), timeout=3))
            assert msg == {"type": "response", "text": "수정 완료했습니다."}


@pytest.mark.asyncio
async def test_full_round_trip(relay_server):
    """Full round-trip: app sends command → agent receives → agent responds → app receives."""
    token = await register_and_login("roundtrip@e2e.test")
    async with websockets.connect(f"{RELAY_WS}/ws/agent?token={token}") as agent_ws:
        async with websockets.connect(f"{RELAY_WS}/ws/app?token={token}") as app_ws:
            await asyncio.wait_for(app_ws.recv(), timeout=3)  # agent_status online

            # App → relay → agent
            await app_ws.send(json.dumps({"type": "command", "text": "로그인 버그 고쳐줘"}))
            cmd = json.loads(await asyncio.wait_for(agent_ws.recv(), timeout=3))
            assert cmd["text"] == "로그인 버그 고쳐줘"

            # Agent → relay → app
            await agent_ws.send(json.dumps({"type": "response", "text": "버그 수정 완료"}))
            resp = json.loads(await asyncio.wait_for(app_ws.recv(), timeout=3))
            assert resp == {"type": "response", "text": "버그 수정 완료"}


@pytest.mark.asyncio
async def test_command_when_agent_offline_returns_error(relay_server):
    """Command sent with no agent connected → app receives error."""
    token = await register_and_login("noagent@e2e.test")
    async with websockets.connect(f"{RELAY_WS}/ws/app?token={token}") as app_ws:
        await asyncio.wait_for(app_ws.recv(), timeout=3)  # agent_status offline
        await app_ws.send(json.dumps({"type": "command", "text": "명령어"}))
        msg = json.loads(await asyncio.wait_for(app_ws.recv(), timeout=3))
        assert msg["type"] == "error"


@pytest.mark.asyncio
async def test_agent_disconnect_notifies_app(relay_server):
    """When agent disconnects, app receives agent_status offline."""
    token = await register_and_login("disc@e2e.test")
    async with websockets.connect(f"{RELAY_WS}/ws/app?token={token}") as app_ws:
        await asyncio.wait_for(app_ws.recv(), timeout=3)  # initial offline

        async with websockets.connect(f"{RELAY_WS}/ws/agent?token={token}"):
            await asyncio.wait_for(app_ws.recv(), timeout=3)  # online notification
        # Agent context exited → disconnected

        msg = json.loads(await asyncio.wait_for(app_ws.recv(), timeout=3))
        assert msg == {"type": "agent_status", "online": False}
