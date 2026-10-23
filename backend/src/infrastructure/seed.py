"""
Datos de demostración para desarrollo: un usuario demo y algunos incidentes en Cartagena.
Es idempotente: no duplica el usuario y solo crea incidentes si no hay ninguno vigente.
"""
import os

from src.application.auth_service import AuthService
from src.application.incident_service import IncidentService
from src.domain.models import CategoriaIncidente, TipoViajero
from src.domain.schemas.incident_schema import IncidentCreate
from src.infrastructure.database import ensure_indexes, get_database
from src.infrastructure.repositories import MongoIncidentRepository, MongoUserRepository
from src.infrastructure.security import password_hasher, token_issuer

INCIDENTES_DEMO = [
    (CategoriaIncidente.SEGURIDAD, 4, 10.4236, -75.5510),  # Centro Histórico
    (CategoriaIncidente.TRAFICO, 3, 10.4205, -75.5465),    # Getsemaní
    (CategoriaIncidente.TRAFICO, 5, 10.4150, -75.5250),    # Av. Pedro de Heredia
    (CategoriaIncidente.SEGURIDAD, 2, 10.4000, -75.5560),  # Bocagrande
]

def seed():
    email, password = os.getenv("DEMO_EMAIL"), os.getenv("DEMO_PASSWORD")
    if not email or not password:
        print("⚠️ DEMO_EMAIL o DEMO_PASSWORD no están definidos: no se cargan datos demo.")
        return

    db = get_database()
    ensure_indexes(db)

    users = MongoUserRepository(db)
    usuario = users.get_by_email(email.lower())
    if usuario is None:
        auth = AuthService(users, password_hasher, token_issuer)
        usuario, _ = auth.register(email=email, password=password, nombre="Viajero Demo",
                                   tipo_viajero=TipoViajero.RESIDENTE)
        print("✅ Usuario demo creado.")

    incidents = IncidentService(MongoIncidentRepository(db))
    if not incidents.list_active():
        for categoria, intensidad, lat, lon in INCIDENTES_DEMO:
            incidents.report(usuario, IncidentCreate(categoria=categoria, intensidad=intensidad,
                                                     latitud=lat, longitud=lon))
        print("✅ Incidentes demo creados (expiran según su categoría).")

if __name__ == "__main__":
    seed()
