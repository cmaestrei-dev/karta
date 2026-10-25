from typing import List, Literal

from fastapi import APIRouter, Depends, HTTPException, Path, Query
from src.application.incident_service import IncidentService
from src.application.realtime_service import RealtimeService, RutaDesconocida
from src.application.trip_service import TripService
from src.domain.route_risk import ResultadoRiesgo
from src.domain.schemas.route_schema import (
    EstacionDeRuta, FranjaDeServicio, HorarioDeRuta, IncidentRiskDetail, LineaGeoJSON, ParadaDelTramo, RiesgoResumen,
    RouteGeometryResponse, RouteOptionResponse, RoutePageResponse, RouteRiskRequest, RouteRiskResponse,
    RouteSuggestRequest, RouteSuggestResponse, TramoResponse,
)
from src.domain.trip_planning import OpcionViaje
from src.domain.schemas.realtime_schema import LlegadaResponse
from src.infrastructure.dependencies import get_incident_service, get_realtime_service, get_trip_service

router = APIRouter(prefix="/api/v1/routes", tags=["Rutas"])

NOTA_ESTIMACION = ("Tiempos estimados con velocidades promedio, esperas típicas y caminatas en línea recta "
                   "con rodeo.")
FUENTE_RUTAS = ("Rutas de Transcaribe: © colaboradores de OpenStreetMap (ODbL). Horarios: «Rutas_Transcaribe "
                "2025», Portal de Datos Abiertos de Cartagena (CC-BY 4.0).")

@router.get("/", summary="Rutas de Transcaribe", response_model=List[RouteGeometryResponse])
def list_routes(tipo: Literal["troncal", "pretroncal", "alimentadora", "complementaria"] | None = Query(None),
                service: TripService = Depends(get_trip_service)):
    """Rutas con su trazado (GeoJSON), opcionalmente de un solo tipo; el mapa dibuja así la troncal."""
    return [RouteGeometryResponse(codigo=r.id, nombre=r.nombre, tipo=r.tipo,
                                  geometria={"type": "LineString", "coordinates": [list(c) for c in r.coordenadas]})
            for r in service.routes(tipo)]

@router.get("/{codigo}", summary="Página de una ruta", response_model=RoutePageResponse,
            responses={404: {"description": "No existe esa ruta"}})
def route_page(codigo: str = Path(..., pattern=r"^[ATXC]\d{3}E?$", description='Código de la ruta, ej. "T103"'),
               service: TripService = Depends(get_trip_service)):
    """Recorrido, estaciones en el orden en que las recorre y horario de servicio de una ruta de Transcaribe."""
    pagina = service.route_page(codigo)
    if pagina is None:
        raise HTTPException(status_code=404, detail=f"No existe la ruta {codigo}.")
    ruta, horario = pagina.ruta, pagina.horario

    def franja(dia: str) -> FranjaDeServicio | None:
        valor = horario.por_dia.get(dia) if horario else None
        return FranjaDeServicio(primera=valor[0].strftime("%H:%M"), ultima=valor[1].strftime("%H:%M")) if valor else None

    return RoutePageResponse(
        codigo=ruta.id, nombre=ruta.nombre, tipo=ruta.tipo, desde=ruta.desde, hasta=ruta.hasta,
        geometria={"type": "LineString", "coordinates": [list(c) for c in ruta.coordenadas]},
        estaciones=[EstacionDeRuta(id=e.id, nombre=e.nombre, latitud=e.latitud, longitud=e.longitud)
                    for e in pagina.estaciones],
        horario=HorarioDeRuta(lunes_a_viernes=franja("lunes_a_viernes"), sabado=franja("sabado"),
                              domingo_y_festivos=franja("domingo_y_festivos")) if horario else None,
        hoy=pagina.hoy,
        opera_ahora=pagina.opera_ahora,
    )

@router.get("/{codigo}/live", summary="Cuándo llega el próximo bus", response_model=LlegadaResponse,
            responses={404: {"description": "No existe esa ruta"}})
def next_arrival(codigo: str = Path(..., pattern=r"^[ATXC]\d{3}E?$"),
                 desde_lat: float = Query(..., ge=-90, le=90), desde_lon: float = Query(..., ge=-180, le=180),
                 hasta_lat: float = Query(..., ge=-90, le=90), hasta_lon: float = Query(..., ge=-180, le=180),
                 service: RealtimeService = Depends(get_realtime_service)):
    """
    Cuánto le falta al próximo bus de la ruta para llegar a la subida (`desde`), en el sentido de la bajada
    (`hasta`), según lo que vieron los viajeros en la última media hora. Sin observaciones no se inventa nada:
    `minutos` es null.
    """
    try:
        estimacion = service.arrival(codigo, (desde_lon, desde_lat), (hasta_lon, hasta_lat))
    except RutaDesconocida:
        raise HTTPException(status_code=404, detail=f"No existe la ruta {codigo}.")
    if estimacion is None:
        return LlegadaResponse()
    return LlegadaResponse(
        minutos=estimacion.minutos, fuentes=estimacion.fuentes,
        ocupacion=estimacion.ocupacion.value if estimacion.ocupacion else None,
        visto_hace_min=estimacion.visto_hace_min,
    )

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
    Rutas sugeridas entre dos puntos de Cartagena: a pie o en Transcaribe, con una ruta o con un transbordo,
    solo con las rutas que operan a la hora de salida. Se ordenan según el criterio: tiempo más una
    penalización por el riesgo del recorrido, que pesa el triple en la más segura.
    """
    sugerencias = service.suggest(
        (request.origen.lon, request.origen.lat), (request.destino.lon, request.destino.lat),
        request.origen.nombre, request.destino.nombre,
        criterio=request.criterio, salida=request.salida,
    )
    if sugerencias.opciones:
        nota = NOTA_ESTIMACION
    elif request.criterio == "sin_transbordo":
        nota = "No hay una sola ruta de Transcaribe que pase cerca de los dos puntos; prueba con transbordo."
    else:
        nota = "No encontramos rutas de Transcaribe que te acerquen a ese destino desde ahí."
    return RouteSuggestResponse(
        opciones=[_a_respuesta(opcion, riesgo) for opcion, riesgo in sugerencias.opciones],
        criterio=sugerencias.criterio,
        salida=sugerencias.salida,
        aviso=sugerencias.aviso,
        nota=nota,
        fuente=FUENTE_RUTAS,
    )

def _minutos(valor: float) -> int:
    return max(1, round(valor)) if valor > 0 else 0

def _a_respuesta(opcion: OpcionViaje, riesgo: ResultadoRiesgo) -> RouteOptionResponse:
    codigos = [r.id for r in opcion.rutas]
    return RouteOptionResponse(
        resumen=f"Transcaribe {' y '.join(codigos)}" if codigos else "A pie",
        tiempo_total_min=_minutos(opcion.tiempo_total_min),
        distancia_caminata_m=round(opcion.distancia_caminata_m),
        transbordos=opcion.transbordos,
        tramos=[
            TramoResponse(
                modo=t.modo, desde=t.desde, hasta=t.hasta,
                distancia_m=round(t.distancia_m), duracion_min=_minutos(t.duracion_min),
                espera_min=_minutos(t.espera_min),
                ruta=t.ruta.id if t.ruta else None,
                nombre_ruta=t.ruta.nombre if t.ruta else None,
                tipo_ruta=t.ruta.tipo if t.ruta else None,
                paradas=[ParadaDelTramo(nombre=e.nombre, latitud=e.latitud, longitud=e.longitud) for e in t.paradas],
                geometria=LineaGeoJSON(coordinates=[[round(lon, 6), round(lat, 6)] for lon, lat in t.coordenadas]),
            )
            for t in opcion.tramos
        ],
        riesgo=RiesgoResumen(score=riesgo.score, nivel=riesgo.nivel, total_incidentes=len(riesgo.incidentes)),
    )
