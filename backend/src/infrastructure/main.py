from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from pymongo.database import Database
from pymongo.errors import PyMongoError

from src.infrastructure import config
from src.infrastructure.database import ensure_indexes, get_database
from src.infrastructure.dependencies import get_db
from src.infrastructure.limite_en_memoria import LimitarPorIp
from src.infrastructure.reference_data import cargar_datos_de_referencia
from src.infrastructure.routers import (
    auth_router, user_router, incident_router, legal_router, mapping_router, route_router, place_router, stop_router,
    realtime_router,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    db = get_database()
    ensure_indexes(db)
    cargar_datos_de_referencia(db)  # rutas, estaciones y lugares; solo si la base está vacía
    yield


app = FastAPI(
    title="Karta API",
    description=(
        "API de Karta: buscador de lugares de Cartagena, rutas sugeridas de Transcaribe con su riesgo, "
        "estaciones cercanas, lugares guardados e incidentes reportados por la comunidad. "
        "Las rutas protegidas piden un token Bearer (JWT) que entregan /auth/anonymous (la cuenta invisible del "
        "teléfono), /auth/login y /auth/register.\n\n"
        "Código fuente (AGPL 3.0 o posterior): https://github.com/cmaestrei-dev/karta"
    ),
    version="2.0.0",
    license_info={"name": "AGPL-3.0-or-later", "url": "https://www.gnu.org/licenses/agpl-3.0.html"},
    openapi_url="/api/v1/openapi.json",
    docs_url="/api/v1/docs",
    redoc_url="/api/v1/redoc",
    lifespan=lifespan,
)

# La API usa tokens Bearer en cabecera, no cookies, así que no se habilitan credenciales en CORS.
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Límite por IP en memoria para todas las rutas (OWASP API4): va por fuera de todo, así un abuso no llega ni a CORS.
app.add_middleware(LimitarPorIp)

app.include_router(auth_router.router)
app.include_router(user_router.router)
app.include_router(incident_router.router)
app.include_router(route_router.router)
app.include_router(place_router.router)
app.include_router(stop_router.router)
app.include_router(realtime_router.router)
app.include_router(mapping_router.router)
app.include_router(legal_router.router)

@app.get("/", include_in_schema=False)
async def root():
    return RedirectResponse(url="/api/v1/docs")

@app.get("/api/v1/health", tags=["Sistema"], summary="Estado del servicio y de la base de datos")
def health_check(db: Database = Depends(get_db)):
    try:
        db.command("ping")
    except PyMongoError:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Base de datos no disponible.")
    return {
        "status": "healthy",
        "service": "Karta Core",
        "version": app.version,
        "database": "up",
    }
