import subprocess
from unittest.mock import patch, MagicMock
from claude_runner import ClaudeRunner


def _mock_result(stdout="응답입니다.", stderr="", returncode=0):
    m = MagicMock()
    m.stdout = stdout
    m.stderr = stderr
    m.returncode = returncode
    return m


def test_first_call_has_no_continue_flag():
    runner = ClaudeRunner()
    with patch("subprocess.run", return_value=_mock_result()) as mock_run:
        runner.run("테스트 실행해줘")
    args = mock_run.call_args[0][0]
    assert "-c" not in args


def test_second_call_has_continue_flag():
    runner = ClaudeRunner()
    with patch("subprocess.run", return_value=_mock_result()):
        runner.run("첫 번째 명령")
    with patch("subprocess.run", return_value=_mock_result()) as mock_run:
        runner.run("두 번째 명령")
    args = mock_run.call_args[0][0]
    assert "-c" in args


def test_args_include_required_flags():
    runner = ClaudeRunner()
    with patch("subprocess.run", return_value=_mock_result()) as mock_run:
        runner.run("명령어")
    args = mock_run.call_args[0][0]
    assert "claude" in args
    assert "-p" in args
    assert "--permission-mode" in args
    assert "auto" in args


def test_voice_prompt_prepended_to_command():
    runner = ClaudeRunner()
    with patch("subprocess.run", return_value=_mock_result()) as mock_run:
        runner.run("로그인 버그 고쳐줘")
    prompt_arg = mock_run.call_args[0][0][-1]
    assert "음성 인터페이스" in prompt_arg
    assert "로그인 버그 고쳐줘" in prompt_arg


def test_returns_stdout():
    runner = ClaudeRunner()
    with patch("subprocess.run", return_value=_mock_result("완료했습니다.")):
        result = runner.run("명령어")
    assert result == "완료했습니다."


def test_falls_back_to_stderr_when_stdout_empty():
    runner = ClaudeRunner()
    with patch("subprocess.run", return_value=_mock_result(stdout="", stderr="오류 발생")):
        result = runner.run("명령어")
    assert result == "오류 발생"


def test_working_dir_passed_to_subprocess():
    runner = ClaudeRunner(working_dir="/some/project")
    with patch("subprocess.run", return_value=_mock_result()) as mock_run:
        runner.run("명령어")
    kwargs = mock_run.call_args[1]
    assert kwargs["cwd"] == "/some/project"


def test_no_working_dir_passes_none():
    runner = ClaudeRunner()
    with patch("subprocess.run", return_value=_mock_result()) as mock_run:
        runner.run("명령어")
    kwargs = mock_run.call_args[1]
    assert kwargs["cwd"] is None


def test_empty_stdout_and_stderr_returns_fallback():
    runner = ClaudeRunner()
    with patch("subprocess.run", return_value=_mock_result(stdout="", stderr="")):
        result = runner.run("명령어")
    assert result == "(응답 없음)"


def test_failed_run_does_not_advance_session():
    runner = ClaudeRunner()
    failed = _mock_result(stdout="", stderr="오류", returncode=1)
    with patch("subprocess.run", return_value=failed):
        runner.run("실패 명령")
    # Session not advanced, second call should have no -c flag
    with patch("subprocess.run", return_value=_mock_result()) as mock_run:
        runner.run("두 번째 명령")
    args = mock_run.call_args[0][0]
    assert "-c" not in args


def test_file_not_found_returns_error_message():
    runner = ClaudeRunner()
    with patch("subprocess.run", side_effect=FileNotFoundError):
        result = runner.run("명령어")
    assert "claude" in result.lower() or "오류" in result


def test_timeout_returns_error_message():
    runner = ClaudeRunner()
    with patch("subprocess.run", side_effect=subprocess.TimeoutExpired(cmd="claude", timeout=120)):
        result = runner.run("명령어")
    assert "시간 초과" in result or "오류" in result
