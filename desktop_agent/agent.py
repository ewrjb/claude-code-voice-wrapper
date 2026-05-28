import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import asyncio
import json
import logging
from typing import Optional
import websockets
from claude_runner import ClaudeRunner
from config import get_relay_url, get_token, get_working_dir

logger = logging.getLogger(__name__)

RECONNECT_DELAY = 5


async def handle_message(
    raw: str, runner: ClaudeRunner, lock: Optional[asyncio.Lock] = None
) -> Optional[str]:
    try:
        msg = json.loads(raw)
    except json.JSONDecodeError:
        return None
    msg_type = msg.get("type")
    if msg_type == "new_session":
        runner.reset_session()
        return json.dumps({"type": "response", "text": "새 세션을 시작했습니다."})
    if msg_type != "command":
        return None
    text = msg.get("text", "").strip()
    if not text:
        return None
    if lock is None:
        lock = asyncio.Lock()
    loop = asyncio.get_running_loop()
    async with lock:
        try:
            response_text = await loop.run_in_executor(None, runner.run, text)
        except Exception as exc:
            logger.error("runner 오류: %s", exc)
            return json.dumps({"type": "error", "text": str(exc)})
    return json.dumps({"type": "response", "text": response_text})


async def run_forever(relay_url: str, token: str, runner: ClaudeRunner) -> None:
    uri = f"{relay_url}/ws/agent?token={token}"
    lock = asyncio.Lock()
    while True:
        try:
            async with websockets.connect(uri) as ws:
                logger.info("릴레이 서버 연결됨")
                while True:
                    raw = await ws.recv()
                    response = await handle_message(raw, runner, lock)
                    if response:
                        await ws.send(response)
        except Exception as exc:
            logger.warning("연결 끊김: %s — %d초 후 재연결...", exc, RECONNECT_DELAY)
            await asyncio.sleep(RECONNECT_DELAY)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    relay_url = get_relay_url()
    token = get_token()
    working_dir = get_working_dir()
    runner = ClaudeRunner(working_dir=working_dir)
    logger.info("에이전트 시작 — relay=%s working_dir=%s", relay_url, working_dir)
    asyncio.run(run_forever(relay_url, token, runner))
