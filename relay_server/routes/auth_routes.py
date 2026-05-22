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
