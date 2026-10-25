"""El tiempo real de Transcaribe hecho por sus pasajeros: avistamientos y viajes compartidos (anónimos, efímeros)."""
from fastapi import APIRouter, Depends, HTTPException, Path, Response, status

from src.application.realtime_service import RealtimeService, RutaDesconocida, ViajeTerminado
from src.domain.conocimiento import ComoSePidio
from src.domain.models import Usuario
from src.domain.schemas.realtime_schema import (
    AvistamientoRequest, ComoPediLaParadaRequest, PosicionRequest, ViajeCompartidoRequest, ViajeCompartidoResponse,
)
from src.domain.tiempo_real import Ocupacion
from src.infrastructure.dependencies import get_current_user, get_realtime_service
from src.infrastructure.limites import por_viajero
from src.infrastructure.repositories import MongoRealtimeRepository
from src.infrastructure.routers.respuestas import FUERA_DE_COBERTURA, SIN_SESION, error

router = APIRouter(prefix="/api/v1", tags=["Tiempo real"])

DEMASIADOS = {429: error("Demasiados envíos seguidos; trae el encabezado Retry-After.")}
RUTA_DESCONOCIDA = HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="No existe esa ruta.")


def _ocupacion(valor: str | None) -> Ocupacion | None:
    return Ocupacion(valor) if valor else None


@router.post("/sightings", status_code=status.HTTP_201_CREATED, summary="Vi pasar un bus",
             responses={**SIN_SESION, **FUERA_DE_COBERTURA, **DEMASIADOS})
def report_sighting(request: AvistamientoRequest,
                    usuario: Usuario = Depends(por_viajero("avistamiento", "LIMITE_AVISTAMIENTOS")),
                    service: RealtimeService = Depends(get_realtime_service)):
    """
    Un viajero vio pasar un bus de la ruta (o va en él y cuenta qué tan lleno va). No se guarda quién lo vio:
    la sesión solo sirve para limitar envíos. Vence a los 30 minutos.
    """
    try:
        service.report_sighting(request.ruta, request.latitud, request.longitud, _ocupacion(request.ocupacion))
    except RutaDesconocida:
        raise RUTA_DESCONOCIDA
    return {"mensaje": "Gracias: lo verán quienes esperan ese bus."}


@router.post("/stop-requests", status_code=status.HTTP_201_CREATED, summary="Cómo pedí la parada",
             responses={**SIN_SESION, **FUERA_DE_COBERTURA, **DEMASIADOS})
def answer_stop_request(request: ComoPediLaParadaRequest,
                        usuario: Usuario = Depends(por_viajero("parada", "LIMITE_RESPUESTAS_PARADA")),
                        service: RealtimeService = Depends(get_realtime_service)):
    """
    Al bajarse en un paradero, el viajero cuenta cómo pidió la parada: tocó el timbre, el bus paró solo o le avisó
    al conductor. No se guarda quién respondió. Con suficientes respuestas que coinciden, el aviso de pedir la
    parada dice lo que funciona allí.
    """
    try:
        service.answer_stop_request(request.ruta, request.latitud, request.longitud, ComoSePidio(request.como))
    except RutaDesconocida:
        raise RUTA_DESCONOCIDA
    return {"mensaje": "Gracias: así sabremos cómo se pide la parada aquí."}


@router.post("/trips", status_code=status.HTTP_201_CREATED, response_model=ViajeCompartidoResponse,
             summary="Empezar a compartir dónde va el bus", responses={**SIN_SESION, **FUERA_DE_COBERTURA, **DEMASIADOS})
def start_trip(request: ViajeCompartidoRequest,
               usuario: Usuario = Depends(por_viajero("posicion", "LIMITE_POSICIONES")),
               service: RealtimeService = Depends(get_realtime_service)):
    """
    Solo con el permiso explícito del viajero y mientras va en el bus. El viaje tiene un identificador aleatorio,
    sin relación con el viajero, y se borra 5 minutos después de la última posición.
    """
    try:
        viaje = service.start_trip(request.ruta, request.latitud, request.longitud)
    except RutaDesconocida:
        raise RUTA_DESCONOCIDA
    return ViajeCompartidoResponse(viaje=viaje, vence_en_s=int(MongoRealtimeRepository.VIGENCIA_VIAJE.total_seconds()))


@router.put("/trips/{viaje}", status_code=status.HTTP_204_NO_CONTENT, summary="Posición del bus",
            responses={**SIN_SESION, **FUERA_DE_COBERTURA, **DEMASIADOS,
                       404: error("El viaje ya terminó o venció; empieza otro.")})
def share_position(request: PosicionRequest, viaje: str = Path(..., min_length=10, max_length=40),
                   usuario: Usuario = Depends(por_viajero("posicion", "LIMITE_POSICIONES")),
                   service: RealtimeService = Depends(get_realtime_service)):
    try:
        service.share_position(viaje, request.latitud, request.longitud, _ocupacion(request.ocupacion))
    except ViajeTerminado:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ese viaje ya terminó o venció.")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/trips/{viaje}", status_code=status.HTTP_204_NO_CONTENT, summary="Dejar de compartir",
               responses={**SIN_SESION})
def end_trip(viaje: str = Path(..., min_length=10, max_length=40), usuario: Usuario = Depends(get_current_user),
             service: RealtimeService = Depends(get_realtime_service)):
    """Borra el viaje compartido en el acto (también vence solo)."""
    service.end_trip(viaje)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
