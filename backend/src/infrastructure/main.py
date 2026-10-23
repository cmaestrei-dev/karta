import os
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from src.infrastructure.routers import user_router, incident_router, route_router

load_dotenv()

app = FastAPI(
    title="Karta API",
    description="API Core para enrutamiento táctico y gestión UGC (Asset-Light)",
    version="1.0.0",
    openapi_url="/api/v1/openapi.json",
    docs_url="/api/v1/docs",
    redoc_url="/api/v1/redoc"
)

# Orígenes permitidos separados por coma (ej: "https://karta.app,http://localhost:5173").
# La API no usa cookies, así que no se habilitan credenciales en CORS.
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(user_router.router)
app.include_router(incident_router.router)
app.include_router(route_router.router)

@app.get("/", include_in_schema=False)
async def root():
    return RedirectResponse(url="/api/v1/docs")

@app.get("/api/v1/health", tags=["System"])
async def health_check():
    return {
        "status": "healthy",
        "service": "Karta Core",
        "version": "1.0.0"
    }
