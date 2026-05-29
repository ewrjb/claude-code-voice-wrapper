import os
from typing import Optional
from dotenv import load_dotenv

load_dotenv()


def get_relay_url() -> str:
    return os.getenv("RELAY_URL", "ws://localhost:8000")


def get_token() -> str:
    token = os.getenv("TOKEN", "")
    if not token:
        raise ValueError("TOKEN 환경 변수가 설정되지 않았습니다.")
    return token


def get_working_dir() -> Optional[str]:
    path = os.getenv("WORKING_DIR") or None
    if path and not os.path.isdir(path):
        import warnings
        warnings.warn(
            f"WORKING_DIR='{path}'이 존재하지 않습니다. "
            "None으로 대체합니다. .env 파일을 확인해주세요.",
            stacklevel=2,
        )
        return None
    return path
