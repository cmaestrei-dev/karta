"""
Carga los datos de referencia (rutas, estaciones y lugares) y, en desarrollo, datos de
demostración: un usuario demo y algunos incidentes en Cartagena.
Es idempotente: no duplica el usuario y solo crea incidentes si no hay ninguno vigente.
"""
import os

from src.application.auth_service import AuthService
from src.application.incident_service import IncidentService
from src.domain.models import TipoViajero
from src.infrastructure.database import ensure_indexes, get_database
from src.infrastructure.reference_data import cargar_datos_de_referencia
from src.infrastructure.repositories import (
    MongoIncidentRepository, MongoPlaceRepository, MongoTransitRepository, MongoUserRepository,
)
from src.infrastructure.security import password_hasher, token_issuer

# (tipo, detalles, lat, lon): ejemplos realistas de lo que reporta la comunidad.
INCIDENTES_DEMO = [
    ("robo", {}, 10.4236, -75.5510),                                    # Centro Histórico
    ("trancon", {"estado": "detenido"}, 10.4150, -75.5250),             # Av. Pedro de Heredia
    ("bus_no_pasa", {"ruta": "T103", "espera": "20"}, 10.4139, -75.5244),  # Estación Bazurto
    ("calle_inundada", {"paso": "no_se_puede"}, 10.4000, -75.5560),     # Bocagrande
]

def seed():
    db = get_database()
    ensure_indexes(db)
    cargar_datos_de_referencia(db, forzar=True)
    print("✅ Rutas, estaciones y lugares de Cartagena actualizados.")

    email, password = os.getenv("DEMO_EMAIL"), os.getenv("DEMO_PASSWORD")
    if not email or not password:
        print("⚠️ DEMO_EMAIL o DEMO_PASSWORD no están definidos: no se cargan datos demo.")
        return

    users = MongoUserRepository(db)
    usuario = users.get_by_email(email.lower())
    if usuario is None:
        auth = AuthService(users, password_hasher, token_issuer)
        usuario, _ = auth.register(email=email, password=password, nombre="Viajero Demo",
                                   tipo_viajero=TipoViajero.RESIDENTE)
        print("✅ Usuario demo creado.")

    incidents = IncidentService(MongoIncidentRepository(db), users, MongoPlaceRepository(db),
                                MongoTransitRepository(db))
    if not incidents.list_active():
        for tipo, detalles, lat, lon in INCIDENTES_DEMO:
            incidents.report(usuario, tipo=tipo, detalles=detalles, latitud=lat, longitud=lon)
        print("✅ Reportes demo creados (vencen según su tipo).")

if __name__ == "__main__":
    seed()
