from datetime import datetime, timedelta, timezone

import jwt
from pwdlib import PasswordHash

from src.infrastructure import config


class Argon2PasswordHasher:
    """Hash de contraseñas con Argon2id (recomendación actual de OWASP)."""

    def __init__(self):
        self._hasher = PasswordHash.recommended()
        self.dummy_hash = self._hasher.hash("karta-dummy-password")

    def hash(self, password: str) -> str:
        return self._hasher.hash(password)

    def verify(self, password: str, password_hash: str) -> bool:
        return self._hasher.verify(password, password_hash)


class JwtTokenIssuer:
    ALGORITMO = "HS256"

    def issue(self, user_id: str) -> str:
        ahora = datetime.now(timezone.utc)
        payload = {
            "sub": user_id,
            "iat": ahora,
            "exp": ahora + timedelta(minutes=config.JWT_EXPIRE_MINUTES),
        }
        return jwt.encode(payload, config.JWT_SECRET, algorithm=self.ALGORITMO)

    def read_subject(self, token: str) -> str | None:
        """Devuelve el id del usuario si el token es válido y vigente; si no, None."""
        try:
            payload = jwt.decode(
                token, config.JWT_SECRET, algorithms=[self.ALGORITMO],
                options={"require": ["exp", "sub"]},
            )
        except jwt.InvalidTokenError:
            return None
        return payload["sub"]


# Instancias únicas: el hash ficticio se calcula una sola vez por proceso.
password_hasher = Argon2PasswordHasher()
token_issuer = JwtTokenIssuer()
