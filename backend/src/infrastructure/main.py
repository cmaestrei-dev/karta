from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from pymongo.database import Database
from pymongo.errors import PyMongoError

from src.infrastructure import config
from src.infrastructure.database import ensure_indexes, get_database
from src.infrastructure.dependencies import get_db
from src.infrastructure.reference_data import cargar_datos_de_referencia
from src.infrastructure.routers import (
    auth_router, user_router, incident_router, route_router, place_router, stop_router, realtime_router,
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
        "Las rutas protegidas piden un token Bearer (JWT) que entregan /auth/login y /auth/register."
    ),
    version="2.0.0",
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

app.include_router(auth_router.router)
app.include_router(user_router.router)
app.include_router(incident_router.router)
app.include_router(route_router.router)
app.include_router(place_router.router)
app.include_router(stop_router.router)
app.include_router(realtime_router.router)

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
