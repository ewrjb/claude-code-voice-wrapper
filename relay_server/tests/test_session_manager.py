from unittest.mock import MagicMock, AsyncMock
from session_manager import SessionManager

def make_ws():
    ws = MagicMock()
    ws.send_text = AsyncMock()
    return ws

def test_register_and_get_app():
    sm = SessionManager()
    ws = make_ws()
    sm.register_app(user_id=1, ws=ws)
    assert sm.get_app(1) is ws

def test_register_and_get_agent():
    sm = SessionManager()
    ws = make_ws()
    sm.register_agent(user_id=1, ws=ws)
    assert sm.get_agent(1) is ws

def test_agent_online_status():
    sm = SessionManager()
    assert not sm.is_agent_online(1)
    ws = make_ws()
    sm.register_agent(1, ws)
    assert sm.is_agent_online(1)
    sm.unregister_agent(1)
    assert not sm.is_agent_online(1)

def test_unregister_app():
    sm = SessionManager()
    sm.register_app(1, make_ws())
    sm.unregister_app(1)
    assert sm.get_app(1) is None

def test_independent_users():
    sm = SessionManager()
    ws1 = make_ws()
    ws2 = make_ws()
    sm.register_app(1, ws1)
    sm.register_app(2, ws2)
    assert sm.get_app(1) is ws1
    assert sm.get_app(2) is ws2
