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

# Límites de peticiones (OWASP API4): (máximo, ventana en segundos). Se leen en cada petición,
# así las pruebas pueden cambiarlos sin reiniciar la app.
LIMITE_REGISTRO = (int(os.getenv("LIMITE_REGISTRO_POR_HORA", "10")), 3600)  # por IP
LIMITE_LOGIN = (int(os.getenv("LIMITE_LOGIN_POR_MINUTO", "10")), 60)  # por IP
LIMITE_REPORTES = (int(os.getenv("LIMITE_REPORTES_POR_10_MIN", "6")), 600)  # por viajero
LIMITE_VOTOS = (int(os.getenv("LIMITE_VOTOS_POR_10_MIN", "30")), 600)  # por viajero
