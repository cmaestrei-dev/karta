import math
from fastapi import APIRouter, Depends, HTTPException, Query, status
from src.application.trip_service import TripService
from src.domain.geo import MENSAJE_FUERA_DE_COBERTURA, en_cobertura
from src.domain.trip_planning import FACTOR_RODEO, minutos_caminando
from src.domain.schemas.place_schema import StopResponse
from src.infrastructure.dependencies import get_trip_service
from typing import List

router = APIRouter(prefix="/api/v1/stops", tags=["Transcaribe"])

@router.get("/nearby", summary="Estaciones de Transcaribe cercanas", response_model=List[StopResponse])
def nearby_stops(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    radio_m: int = Query(1500, ge=100, le=5000),
    limite: int = Query(5, ge=1, le=20),
    service: TripService = Depends(get_trip_service),
):
    """
    Estaciones de Transcaribe cercanas, de la más cercana a la más lejana, con las rutas que paran en cada una.
    """
    if not en_cobertura(lat, lon):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=MENSAJE_FUERA_DE_COBERTURA)
    return [
        StopResponse(id=e.id, nombre=e.nombre, latitud=e.latitud, longitud=e.longitud, rutas=e.rutas,
                     distancia_m=round(distancia), caminata_m=round(distancia * FACTOR_RODEO),
                     caminata_min=max(1, math.ceil(minutos_caminando(distancia))))
        for e, distancia in service.nearby_stations(lat, lon, radio_m, limite)
    ]
