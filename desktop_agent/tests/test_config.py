import pytest
from config import get_relay_url, get_token, get_working_dir


def test_relay_url_default(monkeypatch):
    monkeypatch.delenv("RELAY_URL", raising=False)
    assert get_relay_url() == "ws://localhost:8000"


def test_relay_url_custom(monkeypatch):
    monkeypatch.setenv("RELAY_URL", "ws://example.com:8000")
    assert get_relay_url() == "ws://example.com:8000"


def test_token_ok(monkeypatch):
    monkeypatch.setenv("TOKEN", "abc.def.ghi")
    assert get_token() == "abc.def.ghi"


def test_token_missing_raises(monkeypatch):
    monkeypatch.delenv("TOKEN", raising=False)
    with pytest.raises(ValueError, match="TOKEN"):
        get_token()


def test_working_dir_default(monkeypatch):
    monkeypatch.delenv("WORKING_DIR", raising=False)
    assert get_working_dir() is None


def test_working_dir_custom(monkeypatch):
    monkeypatch.setenv("WORKING_DIR", "/Users/dongju/myproject")
    assert get_working_dir() == "/Users/dongju/myproject"
