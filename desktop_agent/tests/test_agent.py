import json
import pytest
from unittest.mock import MagicMock, AsyncMock
from agent import handle_message
from claude_runner import ClaudeRunner


@pytest.fixture
def runner():
    r = MagicMock(spec=ClaudeRunner)
    r.run.return_value = "테스트 완료했습니다."
    return r


async def test_command_message_calls_runner_and_returns_response(runner):
    raw = json.dumps({"type": "command", "text": "테스트 실행해줘"})
    result = await handle_message(raw, runner)
    assert result is not None
    parsed = json.loads(result)
    assert parsed["type"] == "response"
    assert parsed["text"] == "테스트 완료했습니다."
    runner.run.assert_called_once_with("테스트 실행해줘")


async def test_invalid_json_returns_none(runner):
    result = await handle_message("not valid json", runner)
    assert result is None
    runner.run.assert_not_called()


async def test_non_command_type_returns_none(runner):
    raw = json.dumps({"type": "status", "online": True})
    result = await handle_message(raw, runner)
    assert result is None
    runner.run.assert_not_called()


async def test_empty_text_returns_none(runner):
    raw = json.dumps({"type": "command", "text": ""})
    result = await handle_message(raw, runner)
    assert result is None
    runner.run.assert_not_called()


async def test_whitespace_only_text_returns_none(runner):
    raw = json.dumps({"type": "command", "text": "   "})
    result = await handle_message(raw, runner)
    assert result is None
    runner.run.assert_not_called()


async def test_missing_text_field_returns_none(runner):
    raw = json.dumps({"type": "command"})
    result = await handle_message(raw, runner)
    assert result is None
    runner.run.assert_not_called()
