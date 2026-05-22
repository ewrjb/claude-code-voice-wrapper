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
