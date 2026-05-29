import os
import shutil
import subprocess
from typing import Optional


def _find_claude_binary() -> str:
    """claude 실행파일 경로를 반환한다. ~/.local/bin 등 일반적인 위치도 탐색한다."""
    # 먼저 현재 PATH에서 찾기
    found = shutil.which("claude")
    if found:
        return found
    # PATH에 없으면 일반적인 설치 위치 직접 탐색
    candidates = [
        os.path.expanduser("~/.local/bin/claude"),
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
    ]
    for path in candidates:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return "claude"  # 찾지 못하면 원래대로 (FileNotFoundError로 이어짐)


_CLAUDE_BIN = _find_claude_binary()


class ClaudeRunner:
    VOICE_PROMPT = """당신은 음성 인터페이스를 통해 개발자와 대화하는 코딩 어시스턴트입니다.
반드시 다음 규칙을 따르세요:
- 한국어로 답변
- 구어체, 전화 통화하듯 자연스럽게
- 상태 보고는 1~2문장으로
- 코드 블록, 마크다운 절대 사용 금지
- 불확실한 결정은 사용자에게 질문
- 작업 완료 시 무엇을 했는지 짧게 요약"""

    def __init__(self, working_dir: Optional[str] = None):
        self._use_continue = False  # start fresh; set True after first success
        self._working_dir = working_dir

    def reset_session(self) -> None:
        """다음 run() 호출을 새로운 독립 Claude 세션으로 시작한다."""
        self._use_continue = False

    def run(self, command: str) -> str:
        prompt = f"{self.VOICE_PROMPT}\n\n{command}"
        args = [_CLAUDE_BIN, "-p", "--permission-mode", "auto"]
        if self._use_continue:
            args.append("--continue")
        args.append(prompt)

        # subprocess가 쉘과 동일한 PATH를 사용하도록 현재 환경변수를 그대로 전달
        env = os.environ.copy()
        # ~/.local/bin이 PATH에 없으면 추가
        local_bin = os.path.expanduser("~/.local/bin")
        if local_bin not in env.get("PATH", ""):
            env["PATH"] = local_bin + os.pathsep + env.get("PATH", "")

        try:
            result = subprocess.run(
                args,
                capture_output=True,
                text=True,
                cwd=self._working_dir,
                env=env,
                timeout=120,
            )
        except FileNotFoundError:
            return "오류: claude 명령을 찾을 수 없습니다."
        except subprocess.TimeoutExpired:
            return "오류: Claude Code 응답 시간 초과"
        if result.returncode != 0:
            stdout = result.stdout.strip()
            stderr = result.stderr.strip()
            return stdout or stderr or "오류: Claude Code 실행 실패"
        # 성공 후에는 항상 --continue 사용
        self._use_continue = True
        stdout = result.stdout.strip()
        stderr = result.stderr.strip()
        return stdout or stderr or "(응답 없음)"
