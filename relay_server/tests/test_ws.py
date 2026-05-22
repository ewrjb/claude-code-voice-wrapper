import pytest
import json
import uuid
from starlette.testclient import TestClient
from main import app
from session_manager import manager

# 각 테스트마다 고유 이메일 — clean_users_async가 sync 테스트에서 실행 안 되므로
# unique email로 users 테이블 충돌 방지

@pytest.fixture(autouse=True)
def reset_session_manager():
    """Reset session manager state between tests to prevent state leakage."""
    manager._sessions = {}
    yield
    manager._sessions = {}

def register_and_login(client: TestClient) -> str:
    email = f"{uuid.uuid4().hex[:8]}@test.com"
    client.post("/auth/register", json={"email": email, "password": "pass123"})
    response = client.post("/auth/login", json={"email": email, "password": "pass123"})
    return response.json()["access_token"]

def test_app_ws_rejects_invalid_token():
    with TestClient(app) as client:
        with client.websocket_connect("/ws/app?token=invalid-token") as ws:
            with pytest.raises(Exception):
                ws.receive_json()

def test_app_ws_connects_and_gets_agent_status():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/app?token={token}") as ws:
            msg = ws.receive_json()
            assert msg["type"] == "agent_status"
            assert msg["online"] is False

def test_agent_ws_rejects_invalid_token():
    with TestClient(app) as client:
        with client.websocket_connect("/ws/agent?token=invalid-token") as ws:
            with pytest.raises(Exception):
                ws.receive_json()

def test_agent_connect_notifies_app():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/agent?token={token}") as agent:
            with client.websocket_connect(f"/ws/app?token={token}") as app_ws:
                status = app_ws.receive_json()
                assert status == {"type": "agent_status", "online": True}

def test_command_relay_app_to_agent():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/agent?token={token}") as agent:
            with client.websocket_connect(f"/ws/app?token={token}") as app_ws:
                app_ws.receive_json()  # consume agent_status
                app_ws.send_json({"type": "command", "text": "로그인 버그 고쳐줘"})
                msg = agent.receive_json()
                assert msg == {"type": "command", "text": "로그인 버그 고쳐줘"}

def test_response_relay_agent_to_app():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/agent?token={token}") as agent:
            with client.websocket_connect(f"/ws/app?token={token}") as app_ws:
                app_ws.receive_json()  # consume agent_status
                agent.send_json({"type": "response", "text": "수정 완료했습니다."})
                msg = app_ws.receive_json()
                assert msg == {"type": "response", "text": "수정 완료했습니다."}

def test_command_when_agent_offline_returns_error():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/app?token={token}") as app_ws:
            app_ws.receive_json()  # consume agent_status (offline)
            app_ws.send_json({"type": "command", "text": "테스트"})
            msg = app_ws.receive_json()
            assert msg["type"] == "error"

def test_agent_disconnect_notifies_app():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/app?token={token}") as app_ws:
            with client.websocket_connect(f"/ws/agent?token={token}") as agent:
                app_ws.receive_json()  # consume agent_status (online)
            # agent disconnected — app should get offline notification
            msg = app_ws.receive_json()
            assert msg == {"type": "agent_status", "online": False}
