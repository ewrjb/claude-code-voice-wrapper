import json
import pytest
from unittest.mock import MagicMock
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


async def test_runner_exception_returns_error_response(runner):
    runner.run.side_effect = RuntimeError("claude 실행 실패")
    raw = json.dumps({"type": "command", "text": "명령어"})
    result = await handle_message(raw, runner)
    assert result is not None
    parsed = json.loads(result)
    assert parsed["type"] == "error"
    assert "claude 실행 실패" in parsed["text"]


async def test_concurrent_commands_are_serialized(runner):
    """Second command starts only after first has ended — lock enforces ordering."""
    import asyncio as _asyncio
    import threading

    call_order = []
    first_entered = threading.Event()
    first_can_exit = threading.Event()

    def first_run(text):
        call_order.append("start:첫 번째")
        first_entered.set()         # signal: first is now inside its call
        first_can_exit.wait(timeout=2)  # wait until unblocked
        call_order.append("end:첫 번째")
        return "done"

    def second_run(text):
        call_order.append("start:두 번째")
        call_order.append("end:두 번째")
        return "done"

    # side_effect as callable so the mock actually calls first_run/second_run
    calls_made = [0]
    fns = [first_run, second_run]
    def dispatch(text):
        idx = calls_made[0]
        calls_made[0] += 1
        return fns[idx](text)

    runner.run.side_effect = dispatch
    lock = _asyncio.Lock()
    loop = _asyncio.get_running_loop()

    raw1 = json.dumps({"type": "command", "text": "첫 번째"})
    raw2 = json.dumps({"type": "command", "text": "두 번째"})

    async def run_second_then_unblock():
        # Wait for first to be inside its thread call
        await loop.run_in_executor(None, lambda: first_entered.wait(timeout=2))
        # Schedule second (will block on the lock — first still holds it)
        second_task = _asyncio.ensure_future(handle_message(raw2, runner, lock))
        # Now unblock first so it can finish and release the lock
        first_can_exit.set()
        return await second_task

    results = await _asyncio.gather(
        handle_message(raw1, runner, lock),
        run_second_then_unblock(),
    )

    assert all(r is not None for r in results)
    # Lock ensures: first ends before second starts
    assert call_order.index("end:첫 번째") < call_order.index("start:두 번째")
