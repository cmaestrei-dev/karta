from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.infrastructure.routers import user_router
from src.infrastructure.routers import user_router, incident_router
from src.infrastructure.routers import user_router, incident_router, route_router

app = FastAPI(
    title="Karta API", # ¡Actualizamos el nombre aquí también!
    description="API Core para enrutamiento táctico y gestión UGC (Asset-Light)",
    version="1.0.0",
    openapi_url="/api/v1/openapi.json",
    docs_url="/api/v1/docs",
    redoc_url="/api/v1/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(user_router.router)
app.include_router(incident_router.router)
app.include_router(route_router.router)

@app.get("/api/v1/health", tags=["System"])
async def health_check():
    return {
        "status": "healthy",
        "service": "Karta Core",
        "version": "1.0.0"
    }