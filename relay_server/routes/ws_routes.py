import json
from typing import Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from jose import JWTError
from auth import decode_token
from session_manager import manager

router = APIRouter()

async def _authenticate(websocket: WebSocket, token: str) -> Optional[int]:
    await websocket.accept()
    try:
        return decode_token(token)
    except JWTError:
        await websocket.close(code=1008)
        return None

@router.websocket("/ws/app")
async def app_ws(websocket: WebSocket, token: str = Query(...)):
    user_id = await _authenticate(websocket, token)
    if user_id is None:
        return

    manager.register_app(user_id, websocket)
    await websocket.send_text(json.dumps({
        "type": "agent_status",
        "online": manager.is_agent_online(user_id)
    }))

    try:
        while True:
            data = await websocket.receive_text()
            agent_ws = manager.get_agent(user_id)
            if agent_ws:
                await agent_ws.send_text(data)
            else:
                await websocket.send_text(json.dumps({
                    "type": "error",
                    "text": "에이전트가 오프라인입니다."
                }))
    except WebSocketDisconnect:
        manager.unregister_app(user_id)

@router.websocket("/ws/agent")
async def agent_ws(websocket: WebSocket, token: str = Query(...)):
    user_id = await _authenticate(websocket, token)
    if user_id is None:
        return

    manager.register_agent(user_id, websocket)

    try:
        while True:
            data = await websocket.receive_text()
            app_ws = manager.get_app(user_id)
            if app_ws:
                await app_ws.send_text(data)
    except WebSocketDisconnect:
        manager.unregister_agent(user_id)
        app_ws = manager.get_app(user_id)
        if app_ws:
            await app_ws.send_text(json.dumps({
                "type": "agent_status",
                "online": False
            }))
