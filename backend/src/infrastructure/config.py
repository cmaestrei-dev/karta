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

# Política de tratamiento de datos: fecha de vigencia y contacto del responsable. Van en la configuración del
# servidor, no en el repositorio público.
POLITICA_VIGENTE_DESDE = os.getenv("POLITICA_VIGENTE_DESDE", "[por definir]")
RESPONSABLE_CORREO = os.getenv("RESPONSABLE_CORREO", "[por definir]")
RESPONSABLE_TELEFONO = os.getenv("RESPONSABLE_TELEFONO", "[por definir]")
RESPONSABLE_DIRECCION = os.getenv("RESPONSABLE_DIRECCION", "[por definir]")

# Orígenes permitidos separados por coma (ej: "https://karta.app,http://localhost:5173").
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").split(",")

# Límites de peticiones (OWASP API4): (máximo, ventana en segundos). Se leen en cada petición,
# así las pruebas pueden cambiarlos sin reiniciar la app.
LIMITE_REGISTRO = (int(os.getenv("LIMITE_REGISTRO_POR_HORA", "10")), 3600)  # por IP
LIMITE_LOGIN = (int(os.getenv("LIMITE_LOGIN_POR_MINUTO", "10")), 60)  # por IP
# Cuentas invisibles: una red con muchos teléfonos (la universidad) las crea seguido la primera vez.
LIMITE_CUENTAS_INVISIBLES = (int(os.getenv("LIMITE_CUENTAS_INVISIBLES_POR_HORA", "60")), 3600)  # por IP
LIMITE_REPORTES = (int(os.getenv("LIMITE_REPORTES_POR_10_MIN", "6")), 600)  # por viajero
LIMITE_VOTOS = (int(os.getenv("LIMITE_VOTOS_POR_10_MIN", "30")), 600)  # por viajero
LIMITE_AVISTAMIENTOS = (int(os.getenv("LIMITE_AVISTAMIENTOS_POR_10_MIN", "20")), 600)  # por viajero
# Un viaje compartido envía una posición cada ~30 s: 40 en 10 min dejan margen sin permitir abuso.
LIMITE_RESPUESTAS_PARADA = (int(os.getenv("LIMITE_RESPUESTAS_PARADA_POR_10_MIN", "5")), 600)  # por viajero
LIMITE_MARCAS = (int(os.getenv("LIMITE_MARCAS_POR_10_MIN", "10")), 600)  # por viajero
LIMITE_VIAJES_DE_MAPEO = (int(os.getenv("LIMITE_VIAJES_DE_MAPEO_POR_HORA", "6")), 3600)  # por viajero
LIMITE_POSICIONES = (int(os.getenv("LIMITE_POSICIONES_POR_10_MIN", "40")), 600)  # por viajero
LIMITE_RESULTADOS_DE_VIAJE = (int(os.getenv("LIMITE_RESULTADOS_DE_VIAJE_POR_HORA", "6")), 3600)  # por viajero
