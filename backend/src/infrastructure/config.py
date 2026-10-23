"""Configuración leída del entorno (archivo .env en desarrollo). Falla rápido si falta algo crítico."""
import os
from dotenv import load_dotenv

load_dotenv()


def _required(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise ValueError(f"Error Crítico: {name} no está configurada en el entorno.")
    return value


MONGO_URI = _required("MONGO_URI")
MONGO_DB = os.getenv("MONGO_DB", "karta")

JWT_SECRET = _required("JWT_SECRET")
if len(JWT_SECRET) < 32:
    raise ValueError("Error Crítico: JWT_SECRET debe tener al menos 32 caracteres.")
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "10080"))  # 7 días

# Orígenes permitidos separados por coma (ej: "https://karta.app,http://localhost:5173").
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").split(",")
