# Relay Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter 앱과 데스크탑 에이전트를 WebSocket으로 연결하는 릴레이 서버 구축. 사용자 인증, 메시지 중계, 에이전트 온/오프라인 상태 통보를 담당.

**Architecture:** FastAPI WebSocket 서버. 사용자 1명당 `app` 연결 1개 + `agent` 연결 1개를 인메모리 딕셔너리로 관리. 메시지는 저장 없이 즉시 상대 연결로 중계. 인증은 JWT (쿼리 파라미터로 전달).

**Tech Stack:** Python 3.12, FastAPI, aiosqlite (SQLite), python-jose (JWT), passlib/bcrypt (비밀번호), pytest + pytest-asyncio + httpx (테스트), starlette TestClient (WebSocket 테스트), uvicorn (실행)

---

## 파일 구조

```
relay_server/
├── main.py                  # FastAPI 앱 진입점, lifespan DB 초기화
├── auth.py                  # 비밀번호 해싱, JWT 생성/검증
├── models.py                # SQLite 유저 테이블 CRUD (aiosqlite)
├── session_manager.py       # 인메모리 WebSocket 세션 관리
├── routes/
│   ├── __init__.py
│   ├── auth_routes.py       # POST /auth/register, POST /auth/login
│   └── ws_routes.py         # WS /ws/app, WS /ws/agent
├── requirements.txt
├── pytest.ini
├── .env.example
├── Dockerfile
└── tests/
    ├── conftest.py          # DB 경로 패치, 픽스처
    ├── test_auth.py         # auth.py 단위 테스트
    ├── test_session_manager.py  # session_manager.py 단위 테스트
    ├── test_routes.py       # HTTP 인증 엔드포인트 테스트
    └── test_ws.py           # WebSocket 엔드포인트 + 릴레이 테스트
```

---

## Task 1: 프로젝트 초기 설정

**Files:**
- Create: `relay_server/requirements.txt`
- Create: `relay_server/pytest.ini`
- Create: `relay_server/routes/__init__.py`

- [ ] **Step 1: `relay_server/` 디렉토리와 하위 디렉토리 생성**

```bash
mkdir -p relay_server/routes relay_server/tests
```

- [ ] **Step 2: `relay_server/requirements.txt` 작성**

```
fastapi==0.115.0
uvicorn[standard]==0.30.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
aiosqlite==0.20.0
pytest==8.3.0
pytest-asyncio==0.24.0
httpx==0.27.0
python-multipart==0.0.9
```

- [ ] **Step 3: `relay_server/pytest.ini` 작성**

```ini
[pytest]
asyncio_mode = auto
```

- [ ] **Step 4: `relay_server/routes/__init__.py` 빈 파일 생성**

```bash
touch relay_server/routes/__init__.py
```

- [ ] **Step 5: 의존성 설치 확인**

```bash
cd relay_server && pip install -r requirements.txt
```

Expected: 오류 없이 설치 완료

- [ ] **Step 6: 커밋**

```bash
git add relay_server/
git commit -m "chore: relay server 프로젝트 초기 설정"
```

---

## Task 2: 사용자 모델 (DB)

**Files:**
- Create: `relay_server/models.py`
- Create: `relay_server/tests/conftest.py`
- Create: `relay_server/tests/test_models.py`

- [ ] **Step 1: 실패하는 테스트 작성 — `relay_server/tests/test_models.py`**

```python
import pytest
import models

async def test_init_db_creates_users_table():
    await models.init_db()

async def test_create_and_get_user():
    await models.init_db()
    await models.create_user("test@example.com", "hashed_pw")
    user = await models.get_user_by_email("test@example.com")
    assert user is not None
    assert user["email"] == "test@example.com"
    assert user["hashed_password"] == "hashed_pw"

async def test_get_nonexistent_user():
    await models.init_db()
    user = await models.get_user_by_email("none@example.com")
    assert user is None
```

- [ ] **Step 2: `relay_server/tests/conftest.py` 작성 — DB 경로를 테스트용으로 패치**

```python
import os
os.environ["SECRET_KEY"] = "test-secret-key-for-tests"

import models
models.DB_PATH = "test_relay.db"

import asyncio
import aiosqlite
import pytest
import pytest_asyncio

# 전체 테스트 세션에서 한 번만 DB 초기화 (sync/async 테스트 모두 대응)
@pytest.fixture(scope="session", autouse=True)
def init_db_once():
    asyncio.run(models.init_db())
    yield
    if os.path.exists(models.DB_PATH):
        os.remove(models.DB_PATH)

# async 테스트(test_models, test_routes)의 각 테스트 후 users 초기화
@pytest_asyncio.fixture(autouse=True)
async def clean_users_async():
    yield
    async with aiosqlite.connect(models.DB_PATH) as db:
        await db.execute("DELETE FROM users")
        await db.commit()
```

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
cd relay_server && pytest tests/test_models.py -v
```

Expected: `ModuleNotFoundError: No module named 'models'`

- [ ] **Step 4: `relay_server/models.py` 작성**

```python
import aiosqlite

DB_PATH = "relay.db"

async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT UNIQUE NOT NULL,
                hashed_password TEXT NOT NULL
            )
        """)
        await db.commit()

async def get_user_by_email(email: str):
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute(
            "SELECT id, email, hashed_password FROM users WHERE email = ?", (email,)
        ) as cursor:
            row = await cursor.fetchone()
            if row:
                return {"id": row[0], "email": row[1], "hashed_password": row[2]}
            return None

async def create_user(email: str, hashed_password: str):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT INTO users (email, hashed_password) VALUES (?, ?)",
            (email, hashed_password)
        )
        await db.commit()
```

- [ ] **Step 5: 테스트 재실행 — 통과 확인**

```bash
cd relay_server && pytest tests/test_models.py -v
```

Expected: 3개 테스트 모두 PASS

- [ ] **Step 6: 커밋**

```bash
git add relay_server/models.py relay_server/tests/
git commit -m "feat: 사용자 모델 및 SQLite DB 초기화"
```

---

## Task 3: 인증 모듈 (비밀번호 + JWT)

**Files:**
- Create: `relay_server/auth.py`
- Create: `relay_server/tests/test_auth.py`

- [ ] **Step 1: 실패하는 테스트 작성 — `relay_server/tests/test_auth.py`**

```python
import pytest
from jose import JWTError
import auth

def test_password_hash_and_verify():
    hashed = auth.hash_password("mypassword123")
    assert auth.verify_password("mypassword123", hashed)
    assert not auth.verify_password("wrongpassword", hashed)

def test_jwt_roundtrip():
    token = auth.create_access_token(user_id=42)
    assert auth.decode_token(token) == 42

def test_jwt_different_users():
    token_a = auth.create_access_token(user_id=1)
    token_b = auth.create_access_token(user_id=2)
    assert auth.decode_token(token_a) == 1
    assert auth.decode_token(token_b) == 2

def test_jwt_invalid_token():
    with pytest.raises(JWTError):
        auth.decode_token("this-is-not-a-valid-token")
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd relay_server && pytest tests/test_auth.py -v
```

Expected: `ModuleNotFoundError: No module named 'auth'`

- [ ] **Step 3: `relay_server/auth.py` 작성**

```python
import os
from datetime import datetime, timedelta
from passlib.context import CryptContext
from jose import jwt

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 30

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_access_token(user_id: int) -> str:
    expire = datetime.utcnow() + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    return jwt.encode(
        {"sub": str(user_id), "exp": expire},
        SECRET_KEY,
        algorithm=ALGORITHM
    )

def decode_token(token: str) -> int:
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    return int(payload["sub"])
```

- [ ] **Step 4: 테스트 재실행 — 통과 확인**

```bash
cd relay_server && pytest tests/test_auth.py -v
```

Expected: 4개 테스트 모두 PASS

- [ ] **Step 5: 커밋**

```bash
git add relay_server/auth.py relay_server/tests/test_auth.py
git commit -m "feat: 비밀번호 해싱 및 JWT 인증 모듈"
```

---

## Task 4: HTTP 인증 라우트 (회원가입 / 로그인)

**Files:**
- Create: `relay_server/main.py`
- Create: `relay_server/routes/auth_routes.py`
- Create: `relay_server/tests/test_routes.py`

- [ ] **Step 1: 실패하는 테스트 작성 — `relay_server/tests/test_routes.py`**

```python
import pytest
from httpx import AsyncClient, ASGITransport
from main import app

async def test_register_success():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.post("/auth/register", json={"email": "a@test.com", "password": "pass123"})
    assert response.status_code == 201
    assert response.json() == {"message": "registered"}

async def test_register_duplicate_email():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/auth/register", json={"email": "a@test.com", "password": "pass123"})
        response = await client.post("/auth/register", json={"email": "a@test.com", "password": "pass123"})
    assert response.status_code == 400

async def test_login_success():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/auth/register", json={"email": "a@test.com", "password": "pass123"})
        response = await client.post("/auth/login", json={"email": "a@test.com", "password": "pass123"})
    assert response.status_code == 200
    assert "access_token" in response.json()

async def test_login_wrong_password():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/auth/register", json={"email": "a@test.com", "password": "pass123"})
        response = await client.post("/auth/login", json={"email": "a@test.com", "password": "wrongpass"})
    assert response.status_code == 401

async def test_login_unknown_email():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.post("/auth/login", json={"email": "none@test.com", "password": "pass"})
    assert response.status_code == 401
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd relay_server && pytest tests/test_routes.py -v
```

Expected: `ModuleNotFoundError: No module named 'main'`

- [ ] **Step 3: `relay_server/routes/auth_routes.py` 작성**

```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from models import get_user_by_email, create_user
from auth import hash_password, verify_password, create_access_token

router = APIRouter()

class RegisterRequest(BaseModel):
    email: str
    password: str

class LoginRequest(BaseModel):
    email: str
    password: str

@router.post("/register", status_code=201)
async def register(body: RegisterRequest):
    if await get_user_by_email(body.email):
        raise HTTPException(status_code=400, detail="Email already registered")
    await create_user(body.email, hash_password(body.password))
    return {"message": "registered"}

@router.post("/login")
async def login(body: LoginRequest):
    user = await get_user_by_email(body.email)
    if not user or not verify_password(body.password, user["hashed_password"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {"access_token": create_access_token(user["id"])}
```

- [ ] **Step 4: `relay_server/main.py` 작성**

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from models import init_db
from routes.auth_routes import router as auth_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

app = FastAPI(lifespan=lifespan)
app.include_router(auth_router, prefix="/auth")
```

- [ ] **Step 5: 테스트 재실행 — 통과 확인**

```bash
cd relay_server && pytest tests/test_routes.py -v
```

Expected: 5개 테스트 모두 PASS

- [ ] **Step 6: 커밋**

```bash
git add relay_server/main.py relay_server/routes/auth_routes.py relay_server/tests/test_routes.py
git commit -m "feat: 회원가입/로그인 HTTP 엔드포인트"
```

---

## Task 5: 세션 매니저 (인메모리 연결 관리)

**Files:**
- Create: `relay_server/session_manager.py`
- Create: `relay_server/tests/test_session_manager.py`

- [ ] **Step 1: 실패하는 테스트 작성 — `relay_server/tests/test_session_manager.py`**

```python
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
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd relay_server && pytest tests/test_session_manager.py -v
```

Expected: `ModuleNotFoundError: No module named 'session_manager'`

- [ ] **Step 3: `relay_server/session_manager.py` 작성**

```python
from typing import Optional
from fastapi import WebSocket

class SessionManager:
    def __init__(self):
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
```

- [ ] **Step 4: 테스트 재실행 — 통과 확인**

```bash
cd relay_server && pytest tests/test_session_manager.py -v
```

Expected: 5개 테스트 모두 PASS

- [ ] **Step 5: 커밋**

```bash
git add relay_server/session_manager.py relay_server/tests/test_session_manager.py
git commit -m "feat: 인메모리 WebSocket 세션 매니저"
```

---

## Task 6: WebSocket 엔드포인트 및 메시지 릴레이

**Files:**
- Create: `relay_server/routes/ws_routes.py`
- Create: `relay_server/tests/test_ws.py`
- Modify: `relay_server/main.py`

- [ ] **Step 1: 실패하는 테스트 작성 — `relay_server/tests/test_ws.py`**

```python
import pytest
import json
import uuid
from starlette.testclient import TestClient
from main import app

# 각 테스트마다 고유 이메일 — clean_users_async가 sync 테스트에서 실행 안 되므로
# unique email로 users 테이블 충돌 방지
def register_and_login(client: TestClient) -> str:
    email = f"{uuid.uuid4().hex[:8]}@test.com"
    client.post("/auth/register", json={"email": email, "password": "pass123"})
    response = client.post("/auth/login", json={"email": email, "password": "pass123"})
    return response.json()["access_token"]

def test_app_ws_rejects_invalid_token():
    with TestClient(app) as client:
        with client.websocket_connect("/ws/app?token=invalid-token") as ws:
            with pytest.raises(Exception):
                ws.receive_json()

def test_app_ws_connects_and_gets_agent_status():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/app?token={token}") as ws:
            msg = ws.receive_json()
            assert msg["type"] == "agent_status"
            assert msg["online"] is False

def test_agent_ws_rejects_invalid_token():
    with TestClient(app) as client:
        with client.websocket_connect("/ws/agent?token=invalid-token") as ws:
            with pytest.raises(Exception):
                ws.receive_json()

def test_agent_connect_notifies_app():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/agent?token={token}") as agent:
            with client.websocket_connect(f"/ws/app?token={token}") as app_ws:
                status = app_ws.receive_json()
                assert status == {"type": "agent_status", "online": True}

def test_command_relay_app_to_agent():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/agent?token={token}") as agent:
            with client.websocket_connect(f"/ws/app?token={token}") as app_ws:
                app_ws.receive_json()  # consume agent_status
                app_ws.send_json({"type": "command", "text": "로그인 버그 고쳐줘"})
                msg = agent.receive_json()
                assert msg == {"type": "command", "text": "로그인 버그 고쳐줘"}

def test_response_relay_agent_to_app():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/agent?token={token}") as agent:
            with client.websocket_connect(f"/ws/app?token={token}") as app_ws:
                app_ws.receive_json()  # consume agent_status
                agent.send_json({"type": "response", "text": "수정 완료했습니다."})
                msg = app_ws.receive_json()
                assert msg == {"type": "response", "text": "수정 완료했습니다."}

def test_command_when_agent_offline_returns_error():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/app?token={token}") as app_ws:
            app_ws.receive_json()  # consume agent_status (offline)
            app_ws.send_json({"type": "command", "text": "테스트"})
            msg = app_ws.receive_json()
            assert msg["type"] == "error"

def test_agent_disconnect_notifies_app():
    with TestClient(app) as client:
        token = register_and_login(client)
        with client.websocket_connect(f"/ws/app?token={token}") as app_ws:
            with client.websocket_connect(f"/ws/agent?token={token}") as agent:
                app_ws.receive_json()  # consume agent_status (online)
            # agent disconnected — app should get offline notification
            msg = app_ws.receive_json()
            assert msg == {"type": "agent_status", "online": False}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd relay_server && pytest tests/test_ws.py -v
```

Expected: `ImportError` 또는 `404` 에러 (ws_routes 미존재)

- [ ] **Step 3: `relay_server/routes/ws_routes.py` 작성**

```python
import json
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from jose import JWTError
from auth import decode_token
from session_manager import manager

router = APIRouter()

async def _authenticate(websocket: WebSocket, token: str) -> int | None:
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
    app_ws = manager.get_app(user_id)
    if app_ws:
        await app_ws.send_text(json.dumps({
            "type": "agent_status",
            "online": True
        }))

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
```

- [ ] **Step 4: `relay_server/main.py`에 ws_router 등록**

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from models import init_db
from routes.auth_routes import router as auth_router
from routes.ws_routes import router as ws_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

app = FastAPI(lifespan=lifespan)
app.include_router(auth_router, prefix="/auth")
app.include_router(ws_router)
```

- [ ] **Step 5: 테스트 재실행 — 통과 확인**

```bash
cd relay_server && pytest tests/test_ws.py -v
```

Expected: 8개 테스트 모두 PASS

- [ ] **Step 6: 전체 테스트 스위트 실행**

```bash
cd relay_server && pytest -v
```

Expected: 모든 테스트 PASS (총 20개 이상)

- [ ] **Step 7: 커밋**

```bash
git add relay_server/routes/ws_routes.py relay_server/main.py relay_server/tests/test_ws.py
git commit -m "feat: WebSocket 엔드포인트 및 메시지 릴레이"
```

---

## Task 7: 배포 설정

**Files:**
- Create: `relay_server/Dockerfile`
- Create: `relay_server/.env.example`

- [ ] **Step 1: `relay_server/.env.example` 작성**

```
SECRET_KEY=여기에-랜덤-문자열-입력
```

- [ ] **Step 2: `relay_server/Dockerfile` 작성**

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- [ ] **Step 3: Docker 빌드 확인**

```bash
cd relay_server && docker build -t voice-relay .
```

Expected: `Successfully built ...`

- [ ] **Step 4: 로컬에서 서버 실행 확인**

```bash
cd relay_server && SECRET_KEY=test uvicorn main:app --reload
```

Expected: `INFO: Uvicorn running on http://127.0.0.1:8000`
Ctrl+C로 종료

- [ ] **Step 5: 커밋**

```bash
git add relay_server/Dockerfile relay_server/.env.example
git commit -m "chore: Dockerfile 및 환경변수 설정 파일"
```

---

## 메시지 프로토콜 참고

WebSocket을 통해 주고받는 JSON 메시지 형식:

```json
// 앱 → 릴레이 → 에이전트 (음성 명령)
{ "type": "command", "text": "로그인 버그 고쳐줘" }

// 에이전트 → 릴레이 → 앱 (작업 완료 응답)
{ "type": "response", "text": "수정 완료했습니다. 테스트 3개 통과했어요." }

// 에이전트 → 릴레이 → 앱 (작업 중 상태 보고)
{ "type": "status", "text": "파일 분석 중이에요..." }

// 릴레이 → 앱 (에이전트 온라인 상태 변경)
{ "type": "agent_status", "online": true }

// 릴레이 → 앱 (에이전트 오프라인 시 에러)
{ "type": "error", "text": "에이전트가 오프라인입니다." }
```
