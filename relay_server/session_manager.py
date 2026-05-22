from typing import Optional
from fastapi import WebSocket

class SessionManager:
    def __init__(self):
        # asyncio single-threaded event loop — no lock needed for dict mutations
        self._sessions: dict[int, dict] = {}

    def _ensure(self, user_id: int):
        if user_id not in self._sessions:
            self._sessions[user_id] = {"app": None, "agent": None}

    def register_app(self, user_id: int, ws: WebSocket):
        self._ensure(user_id)
        self._sessions[user_id]["app"] = ws

    def register_agent(self, user_id: int, ws: WebSocket):
        self._ensure(user_id)
        self._sessions[user_id]["agent"] = ws

    def unregister_app(self, user_id: int):
        self._ensure(user_id)
        self._sessions[user_id]["app"] = None

    def unregister_agent(self, user_id: int):
        self._ensure(user_id)
        self._sessions[user_id]["agent"] = None

    def get_app(self, user_id: int) -> Optional[WebSocket]:
        return self._sessions.get(user_id, {}).get("app")

    def get_agent(self, user_id: int) -> Optional[WebSocket]:
        return self._sessions.get(user_id, {}).get("agent")

    def is_agent_online(self, user_id: int) -> bool:
        return self._sessions.get(user_id, {}).get("agent") is not None

manager = SessionManager()
