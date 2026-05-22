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
