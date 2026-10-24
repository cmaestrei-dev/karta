import os
import uuid

# Se configura antes de importar `src`: la configuración se lee al importar.
os.environ.setdefault("MONGO_URI", "mongodb://karta:karta@localhost:27017/?authSource=admin")
os.environ.setdefault("JWT_SECRET", "secreto-solo-para-pruebas-0123456789abcdef")
# Las pruebas registran muchos usuarios desde la misma "IP": los límites por IP se suben aquí, y la
# prueba que verifica el 429 baja el suyo a propósito.
os.environ.setdefault("LIMITE_REGISTRO_POR_HORA", "100000")
os.environ.setdefault("LIMITE_LOGIN_POR_MINUTO", "100000")
# Siempre una base aislada y desechable, nunca la de desarrollo.
os.environ["MONGO_DB"] = f"karta_test_{uuid.uuid4().hex[:8]}"

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="session")
def api():
    from src.infrastructure.database import client, get_database
    try:
        client.admin.command("ping")
    except Exception:
        mensaje = "MongoDB no está disponible (levántalo con: docker compose up -d mongo)"
        # En integración continua una base caída debe fallar, no saltarse en silencio.
        if os.environ.get("KARTA_EXIGIR_MONGO") == "1":
            pytest.fail(mensaje)
        pytest.skip(mensaje)

    from src.infrastructure.main import app
    with TestClient(app) as test_client:
        yield test_client
    client.drop_database(get_database().name)


@pytest.fixture
def registrar(api):
    """Registra un viajero nuevo y devuelve (token, usuario)."""
    def _registrar(**cambios):
        datos = {
            "email": f"viajero-{uuid.uuid4().hex[:8]}@karta.app",
            "password": "ClaveSegura123",
            "nombre": "Viajera de Prueba",
            "tipo_viajero": "Residente",
            "acepta_terminos": True,
            **cambios,
        }
        respuesta = api.post("/api/v1/auth/register", json=datos)
        assert respuesta.status_code == 201, respuesta.text
        cuerpo = respuesta.json()
        return cuerpo["access_token"], cuerpo["usuario"]
    return _registrar
