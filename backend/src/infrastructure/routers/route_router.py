from fastapi import APIRouter, Depends
from src.application.incident_service import IncidentService
from src.application.trip_service import TripService
from src.domain.route_risk import ResultadoRiesgo
from src.domain.schemas.route_schema import (
    IncidentRiskDetail, LineaGeoJSON, RiesgoResumen, RouteOptionResponse, RouteRiskRequest, RouteRiskResponse,
    RouteSuggestRequest, RouteSuggestResponse, TramoResponse,
)
from src.domain.trip_planning import OpcionViaje
from src.infrastructure.dependencies import get_incident_service, get_trip_service

router = APIRouter(prefix="/api/v1/routes", tags=["Rutas"])

NOTA_ESTIMACION = ("Tiempos estimados con velocidades promedio y caminatas en línea recta con rodeo; "
                   "no incluyen transbordos entre rutas.")
FUENTE_RUTAS = "Rutas de Transcaribe: © colaboradores de OpenStreetMap (ODbL)."

@router.post("/risk", summary="Riesgo de un recorrido", response_model=RouteRiskResponse)
def evaluate_route_risk(request: RouteRiskRequest, service: IncidentService = Depends(get_incident_service)):
    """Escanea la ruta trazada y calcula su nivel de riesgo según los incidentes a menos de 500 m."""
    resultado = service.evaluate_route_risk(request)
    return RouteRiskResponse(
        score=resultado.score,
        nivel=resultado.nivel,
        total_incidentes=len(resultado.incidentes),
        detalle_incidentes=[IncidentRiskDetail.model_validate(i) for i in resultado.incidentes],
    )

@router.post("/suggest", summary="Rutas sugeridas", response_model=RouteSuggestResponse)
def suggest_routes(request: RouteSuggestRequest, service: TripService = Depends(get_trip_service)):
    """
    Rutas sugeridas entre dos puntos de Cartagena: a pie o en Transcaribe (caminata + una ruta + caminata).
    Las opciones se ordenan por tiempo estimado más una penalización según el riesgo de su recorrido.
    """
    sugerencias = service.suggest(
        (request.origen.lon, request.origen.lat), (request.destino.lon, request.destino.lat),
        request.origen.nombre, request.destino.nombre,
    )
    nota = NOTA_ESTIMACION if sugerencias else (
        "No encontramos una ruta directa de Transcaribe que pase cerca de ambos puntos.")
    return RouteSuggestResponse(
        opciones=[_a_respuesta(opcion, riesgo) for opcion, riesgo in sugerencias],
        nota=nota,
        fuente=FUENTE_RUTAS,
    )

def _minutos(valor: float) -> int:
    return max(1, round(valor)) if valor > 0 else 0

def _a_respuesta(opcion: OpcionViaje, riesgo: ResultadoRiesgo) -> RouteOptionResponse:
    ruta = opcion.ruta
    return RouteOptionResponse(
        resumen=f"Transcaribe {ruta.id}" if ruta else "A pie",
        tiempo_total_min=_minutos(opcion.tiempo_total_min),
        distancia_caminata_m=round(opcion.distancia_caminata_m),
        tramos=[
            TramoResponse(
                modo=t.modo, desde=t.desde, hasta=t.hasta,
                distancia_m=round(t.distancia_m), duracion_min=_minutos(t.duracion_min),
                espera_min=_minutos(t.espera_min),
                ruta=t.ruta.id if t.ruta else None,
                nombre_ruta=t.ruta.nombre if t.ruta else None,
                tipo_ruta=t.ruta.tipo if t.ruta else None,
                geometria=LineaGeoJSON(coordinates=[[round(lon, 6), round(lat, 6)] for lon, lat in t.coordenadas]),
            )
            for t in opcion.tramos
        ],
        riesgo=RiesgoResumen(score=riesgo.score, nivel=riesgo.nivel, total_incidentes=len(riesgo.incidentes)),
    )
