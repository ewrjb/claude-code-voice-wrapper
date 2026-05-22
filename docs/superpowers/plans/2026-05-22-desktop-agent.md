# Desktop Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사용자 데스크탑에서 백그라운드 데몬으로 실행되며, 릴레이 서버로부터 음성 명령을 수신해 Claude Code CLI를 호출하고 응답을 릴레이로 전송하는 Python 에이전트를 구현한다.

**Architecture:** `agent.py`가 릴레이 서버의 `/ws/agent` WebSocket에 연결하고, 수신한 `{"type":"command","text":"..."}` 메시지에 음성 최적화 프롬프트를 앞에 붙여 `claude -p --permission-mode auto` (첫 호출) 또는 `claude -p -c --permission-mode auto` (이후 호출)로 subprocess 실행한 뒤 결과를 `{"type":"response","text":"..."}` JSON으로 반송한다. 연결이 끊기면 5초 후 자동 재연결한다.

**Tech Stack:** Python 3.11+, websockets 12, python-dotenv, pytest, pytest-asyncio

---

## 파일 구조

```
desktop_agent/
├── agent.py           # WebSocket 루프 + handle_message (테스트 가능한 순수 함수)
├── claude_runner.py   # Claude Code CLI subprocess 래퍼, 세션 연속성 관리
├── config.py          # 환경 변수 로드 (RELAY_URL, TOKEN, WORKING_DIR)
├── requirements.txt
├── pytest.ini
├── .env.example
├── com.voicedev.agent.plist   # macOS launchd 데몬 설정 템플릿
└── tests/
    ├── conftest.py
    ├── test_config.py
    ├── test_claude_runner.py
    └── test_agent.py
```

---

## Task 1: 프로젝트 초기 설정

**Files:**
- Create: `desktop_agent/requirements.txt`
- Create: `desktop_agent/pytest.ini`
- Create: `desktop_agent/.env.example`
- Create: `desktop_agent/tests/conftest.py`

- [ ] **Step 1: desktop_agent 디렉터리 및 파일 생성**

```bash
mkdir -p desktop_agent/tests
touch desktop_agent/tests/__init__.py
```

`desktop_agent/requirements.txt`:
```
websockets==12.0
python-dotenv==1.0.1
pytest==8.3.0
pytest-asyncio==0.24.0
```

`desktop_agent/pytest.ini`:
```ini
[pytest]
asyncio_mode = auto
asyncio_default_fixture_loop_scope = function
```

`desktop_agent/.env.example`:
```
# 릴레이 서버 WebSocket URL (ws:// 또는 wss://)
RELAY_URL=ws://localhost:8000

# 릴레이 서버 로그인 후 발급받은 JWT 토큰
TOKEN=여기에-JWT-토큰-입력

# Claude Code 명령을 실행할 프로젝트 디렉터리 (생략 시 에이전트 실행 위치 사용)
# WORKING_DIR=/Users/yourname/yourproject
```

`desktop_agent/tests/conftest.py`:
```python
```
(내용 없음, pytest가 tests/ 를 패키지로 인식하기 위한 빈 파일)

- [ ] **Step 2: 의존성 설치**

```bash
cd desktop_agent
pip install -r requirements.txt
```

Expected: Successfully installed websockets-12.0, python-dotenv-1.0.1, pytest-8.3.0, pytest-asyncio-0.24.0

- [ ] **Step 3: Commit**

```bash
git add desktop_agent/
git commit -m "chore: 데스크탑 에이전트 프로젝트 초기 설정"
```

---

## Task 2: Config 모듈

**Files:**
- Create: `desktop_agent/config.py`
- Create: `desktop_agent/tests/test_config.py`

- [ ] **Step 1: 테스트 작성**

`desktop_agent/tests/test_config.py`:
```python
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
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd desktop_agent && python -m pytest tests/test_config.py -v
```

Expected: ERROR (ModuleNotFoundError: No module named 'config')

- [ ] **Step 3: 구현**

`desktop_agent/config.py`:
```python
import os
from dotenv import load_dotenv

load_dotenv()


def get_relay_url() -> str:
    return os.getenv("RELAY_URL", "ws://localhost:8000")


def get_token() -> str:
    token = os.getenv("TOKEN", "")
    if not token:
        raise ValueError("TOKEN 환경 변수가 설정되지 않았습니다.")
    return token


def get_working_dir() -> str | None:
    return os.getenv("WORKING_DIR") or None
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd desktop_agent && python -m pytest tests/test_config.py -v
```

Expected: 6 passed

- [ ] **Step 5: Commit**

```bash
git add desktop_agent/config.py desktop_agent/tests/test_config.py
git commit -m "feat: config 모듈 (RELAY_URL, TOKEN, WORKING_DIR)"
```

---

## Task 3: Claude Runner

**Files:**
- Create: `desktop_agent/claude_runner.py`
- Create: `desktop_agent/tests/test_claude_runner.py`

Claude Code CLI를 subprocess로 호출하는 클래스. 첫 번째 호출에는 `-c` 플래그 없이, 이후 호출에는 `-c` 플래그를 붙여 대화 연속성을 유지한다. 매 호출마다 음성 최적화 프롬프트를 사용자 명령 앞에 삽입한다.

- [ ] **Step 1: 테스트 작성**

`desktop_agent/tests/test_claude_runner.py`:
```python
import subprocess
from unittest.mock import patch, MagicMock
import pytest
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
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd desktop_agent && python -m pytest tests/test_claude_runner.py -v
```

Expected: ERROR (ModuleNotFoundError: No module named 'claude_runner')

- [ ] **Step 3: 구현**

`desktop_agent/claude_runner.py`:
```python
import subprocess


class ClaudeRunner:
    VOICE_PROMPT = """당신은 음성 인터페이스를 통해 개발자와 대화하는 코딩 어시스턴트입니다.
반드시 다음 규칙을 따르세요:
- 한국어로 답변
- 구어체, 전화 통화하듯 자연스럽게
- 상태 보고는 1~2문장으로
- 코드 블록, 마크다운 절대 사용 금지
- 불확실한 결정은 사용자에게 질문
- 작업 완료 시 무엇을 했는지 짧게 요약"""

    def __init__(self, working_dir: str | None = None):
        self._has_session = False
        self._working_dir = working_dir

    def run(self, command: str) -> str:
        prompt = f"{self.VOICE_PROMPT}\n\n{command}"
        args = ["claude", "-p", "--permission-mode", "auto"]
        if self._has_session:
            args.append("-c")
        args.append(prompt)
        result = subprocess.run(
            args,
            capture_output=True,
            text=True,
            cwd=self._working_dir,
        )
        self._has_session = True
        return result.stdout.strip() or result.stderr.strip()
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd desktop_agent && python -m pytest tests/test_claude_runner.py -v
```

Expected: 8 passed

- [ ] **Step 5: Commit**

```bash
git add desktop_agent/claude_runner.py desktop_agent/tests/test_claude_runner.py
git commit -m "feat: ClaudeRunner — Claude Code CLI subprocess 래퍼"
```

---

## Task 4: WebSocket 에이전트

**Files:**
- Create: `desktop_agent/agent.py`
- Create: `desktop_agent/tests/test_agent.py`

`handle_message(raw, runner)` 는 순수 async 함수로 분리해 WebSocket 없이 단독 테스트 가능하다. `run_forever`는 WebSocket 연결 루프로, 테스트하지 않는다. subprocess 호출은 `run_in_executor`로 실행해 이벤트 루프를 블록하지 않는다.

- [ ] **Step 1: 테스트 작성**

`desktop_agent/tests/test_agent.py`:
```python
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
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd desktop_agent && python -m pytest tests/test_agent.py -v
```

Expected: ERROR (ModuleNotFoundError: No module named 'agent')

- [ ] **Step 3: 구현**

`desktop_agent/agent.py`:
```python
import asyncio
import json
import logging
import websockets
from claude_runner import ClaudeRunner
from config import get_relay_url, get_token, get_working_dir

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

RECONNECT_DELAY = 5


async def handle_message(raw: str, runner: ClaudeRunner) -> str | None:
    try:
        msg = json.loads(raw)
    except json.JSONDecodeError:
        return None
    if msg.get("type") != "command":
        return None
    text = msg.get("text", "").strip()
    if not text:
        return None
    loop = asyncio.get_event_loop()
    response_text = await loop.run_in_executor(None, runner.run, text)
    return json.dumps({"type": "response", "text": response_text})


async def run_forever(relay_url: str, token: str, runner: ClaudeRunner) -> None:
    uri = f"{relay_url}/ws/agent?token={token}"
    while True:
        try:
            async with websockets.connect(uri) as ws:
                logger.info("릴레이 서버 연결됨")
                while True:
                    raw = await ws.recv()
                    response = await handle_message(raw, runner)
                    if response:
                        await ws.send(response)
        except Exception as exc:
            logger.warning("연결 끊김: %s — %d초 후 재연결...", exc, RECONNECT_DELAY)
            await asyncio.sleep(RECONNECT_DELAY)


if __name__ == "__main__":
    relay_url = get_relay_url()
    token = get_token()
    working_dir = get_working_dir()
    runner = ClaudeRunner(working_dir=working_dir)
    logger.info("에이전트 시작 — relay=%s working_dir=%s", relay_url, working_dir)
    asyncio.run(run_forever(relay_url, token, runner))
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd desktop_agent && python -m pytest tests/test_agent.py -v
```

Expected: 6 passed

- [ ] **Step 5: 전체 테스트 통과 확인**

```bash
cd desktop_agent && python -m pytest tests/ -v
```

Expected: 20 passed

- [ ] **Step 6: Commit**

```bash
git add desktop_agent/agent.py desktop_agent/tests/test_agent.py
git commit -m "feat: WebSocket 에이전트 — 연결 루프 및 메시지 핸들러"
```

---

## Task 5: macOS 데몬 설정

**Files:**
- Create: `desktop_agent/com.voicedev.agent.plist`
- Create: `desktop_agent/README.md`

부팅 시 자동 실행되는 macOS launchd 유저 에이전트 plist. 환경 변수를 plist 안에 직접 포함시켜 별도 .env 없이도 동작한다.

- [ ] **Step 1: launchd plist 생성**

`desktop_agent/com.voicedev.agent.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.voicedev.agent</string>

    <key>ProgramArguments</key>
    <array>
        <!-- python3 경로: which python3 으로 확인 후 수정 -->
        <string>/usr/bin/python3</string>
        <!-- agent.py 절대 경로로 수정 -->
        <string>/Users/YOURUSERNAME/Projects/claude_code_voice_wrapper_v2/desktop_agent/agent.py</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
        <!-- 릴레이 서버 주소 (wss:// 권장, 배포 후 수정) -->
        <key>RELAY_URL</key>
        <string>ws://localhost:8000</string>

        <!-- 릴레이 서버 로그인 후 발급받은 JWT 토큰 -->
        <key>TOKEN</key>
        <string>여기에-JWT-토큰-입력</string>

        <!-- Claude 명령을 실행할 프로젝트 디렉터리 -->
        <key>WORKING_DIR</key>
        <string>/Users/YOURUSERNAME/Projects/myproject</string>
    </dict>

    <!-- 부팅 시 자동 시작 -->
    <key>RunAtLoad</key>
    <true/>

    <!-- 크래시 시 자동 재시작 -->
    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/voicedev-agent.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/voicedev-agent.log</string>
</dict>
</plist>
```

- [ ] **Step 2: README 작성**

`desktop_agent/README.md`:
```markdown
# Desktop Agent

Claude Code Voice Wrapper의 데스크탑 에이전트.  
릴레이 서버로부터 음성 명령을 수신해 Claude Code CLI를 실행하고 응답을 반송한다.

## 요구 사항

- Python 3.11+
- Claude Code CLI 설치 및 로그인 완료 (`claude --version`으로 확인)

## 설치

```bash
cd desktop_agent
pip install -r requirements.txt
```

## 실행 (수동)

```bash
# .env 파일 설정
cp .env.example .env
# .env 편집: RELAY_URL, TOKEN, WORKING_DIR 입력

cd desktop_agent
python agent.py
```

## JWT 토큰 발급

릴레이 서버에 계정이 없으면 먼저 가입:

```bash
curl -X POST http://YOUR_RELAY_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"yourpassword"}'
```

로그인하여 토큰 발급:

```bash
curl -X POST http://YOUR_RELAY_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"yourpassword"}'
# 응답: {"access_token": "eyJ..."}
```

## macOS 부팅 시 자동 실행 (launchd)

1. `com.voicedev.agent.plist` 파일을 열어 세 곳을 수정:
   - `ProgramArguments[1]`: `agent.py`의 절대 경로
   - `TOKEN`: 위에서 발급한 JWT 토큰
   - `WORKING_DIR`: Claude가 작업할 프로젝트 디렉터리

2. plist를 LaunchAgents에 복사:

```bash
cp com.voicedev.agent.plist ~/Library/LaunchAgents/
```

3. 등록 및 시작:

```bash
launchctl load ~/Library/LaunchAgents/com.voicedev.agent.plist
```

4. 로그 확인:

```bash
tail -f /tmp/voicedev-agent.log
```

5. 중지:

```bash
launchctl unload ~/Library/LaunchAgents/com.voicedev.agent.plist
```
```

- [ ] **Step 3: 수동 실행 스모크 테스트**

릴레이 서버가 실행 중인 상태에서:

```bash
cd desktop_agent
RELAY_URL=ws://localhost:8000 TOKEN=<유효한JWT> python agent.py
```

Expected 로그 출력:
```
2026-05-22 ... INFO 에이전트 시작 — relay=ws://localhost:8000 working_dir=None
2026-05-22 ... INFO 릴레이 서버 연결됨
```

릴레이 서버가 없으면:
```
2026-05-22 ... WARNING 연결 끊김: ... — 5초 후 재연결...
```
(5초마다 재시도하면 정상)

`Ctrl+C`로 종료.

- [ ] **Step 4: 전체 테스트 최종 확인**

```bash
cd desktop_agent && python -m pytest tests/ -v
```

Expected: 20 passed

- [ ] **Step 5: Commit**

```bash
git add desktop_agent/com.voicedev.agent.plist desktop_agent/README.md
git commit -m "chore: macOS launchd 데몬 설정 및 README"
```
