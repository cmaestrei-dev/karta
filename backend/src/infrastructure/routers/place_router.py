from fastapi import APIRouter, Depends, HTTPException, Query, status
from src.application.place_service import PlaceService
from src.domain.geo import MENSAJE_FUERA_DE_COBERTURA, en_cobertura
from src.domain.schemas.place_schema import PlaceResponse
from src.infrastructure.dependencies import get_place_service
from typing import List

router = APIRouter(prefix="/api/v1/places", tags=["Lugares"])

@router.get("/search", response_model=List[PlaceResponse])
def search_places(
    q: str = Query(..., min_length=2, max_length=80, description='Texto a buscar, ej. "boca" o "estacion bazurto"'),
    limite: int = Query(8, ge=1, le=20),
    service: PlaceService = Depends(get_place_service),
):
    """
    Buscador de ubicaciones de Cartagena: barrios, sitios turísticos, estaciones de Transcaribe,
    universidades, hospitales y centros comerciales. No distingue tildes ni mayúsculas.
    """
    return service.search(q, limite)

@router.get("/reverse", response_model=PlaceResponse)
def reverse_geocode(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    service: PlaceService = Depends(get_place_service),
):
    """
    Nombre del punto elegido directamente en el mapa (el lugar conocido más cercano).
    """
    if not en_cobertura(lat, lon):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=MENSAJE_FUERA_DE_COBERTURA)
    return service.reverse(lat, lon)
