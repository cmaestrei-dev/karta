from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status

from src.application.incident_service import IncidentService
from src.domain.models import Usuario
from src.domain.reportes import (
    NOMBRE_GRUPO, DetallesInvalidos, GraciasRepetidas, Grupo, IncidenteNoEncontrado, VotoPropio, VotoRepetido,
)
from src.domain.schemas.incident_schema import (
    GrupoReporteResponse, IncidentCreate, IncidentDetailResponse, IncidentResponse, VoteRequest, VoteResponse,
)
from src.infrastructure.dependencies import get_incident_service, get_optional_user
from src.infrastructure.limites import por_viajero
from src.infrastructure.routers.respuestas import FUERA_DE_COBERTURA, SIN_SESION, error

router = APIRouter(prefix="/api/v1/incidents", tags=["Incidentes"])

NO_ENCONTRADO = HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ese reporte ya no está vigente.")
DEMASIADOS = {429: error("Demasiados reportes o votos seguidos; trae el encabezado Retry-After.")}


@router.get("/types", summary="Tipos de reporte", response_model=List[GrupoReporteResponse])
def report_types(service: IncidentService = Depends(get_incident_service)):
    """Catálogo de lo que se puede reportar, agrupado, con las preguntas concretas de cada tipo."""
    grupos = []
    for grupo in Grupo:
        tipos = [t for t in service.catalogo() if t.grupo == grupo]
        grupos.append({
            "clave": grupo.value, "nombre": NOMBRE_GRUPO[grupo],
            "tipos": [{
                "clave": t.clave, "nombre": t.nombre, "vigencia_min": int(t.vigencia.total_seconds() // 60),
                "campos": [{
                    "clave": c.clave, "pregunta": c.pregunta, "tipo": c.tipo, "obligatorio": c.obligatorio,
                    "opciones": [{"valor": v, "etiqueta": e} for v, e in c.opciones],
                } for c in t.campos],
            } for t in tipos],
        })
    return grupos


@router.post("/", summary="Reportar", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED,
             responses={**SIN_SESION, **FUERA_DE_COBERTURA, **DEMASIADOS})
def report_incident(
    datos: IncidentCreate,
    usuario: Usuario = Depends(por_viajero("reportar", "LIMITE_REPORTES")),
    service: IncidentService = Depends(get_incident_service),
):
    """
    Reporta algo del catálogo con sus detalles. Requiere sesión: el autor sale del token, nunca del cuerpo.
    El reporte vive lo que dice su tipo; las confirmaciones de otros viajeros lo renuevan.
    """
    try:
        return service.report(usuario, tipo=datos.tipo, detalles=datos.detalles,
                              latitud=datos.latitud, longitud=datos.longitud)
    except DetallesInvalidos as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(e))


@router.get("/", summary="Reportes vigentes", response_model=List[IncidentResponse])
def get_incidents(
    lon_min: float | None = Query(None, ge=-180, le=180), lat_min: float | None = Query(None, ge=-90, le=90),
    lon_max: float | None = Query(None, ge=-180, le=180), lat_max: float | None = Query(None, ge=-90, le=90),
    service: IncidentService = Depends(get_incident_service),
):
    """Reportes vigentes con sus coordenadas. Con los cuatro límites, solo los del área visible del mapa."""
    limites = (lon_min, lat_min, lon_max, lat_max)
    caja = limites if all(v is not None for v in limites) else None
    return service.list_active(caja)


@router.get("/{incidente_id}", summary="Detalle de un reporte", response_model=IncidentDetailResponse,
            responses={404: error("No existe o ya venció.")})
def get_incident(incidente_id: str, usuario: Usuario | None = Depends(get_optional_user),
                 service: IncidentService = Depends(get_incident_service)):
    """El reporte con el alias de quien lo hizo y, si hay sesión, si ya lo validaste."""
    try:
        detalle = service.detail(incidente_id, usuario)
    except IncidenteNoEncontrado:
        raise NO_ENCONTRADO
    return IncidentDetailResponse(**IncidentResponse.model_validate(detalle.incidente).model_dump(),
                                  reportado_por_alias=detalle.alias_autor, es_mio=detalle.es_mio,
                                  mi_voto=detalle.mi_voto, mis_gracias=detalle.mis_gracias)


@router.post("/{incidente_id}/thanks", summary="Gracias", response_model=IncidentResponse,
             responses={**SIN_SESION, 403: error("No puedes agradecer tu propio reporte."),
                        404: error("No existe o ya venció."), 409: error("Ya le diste las gracias."),
                        **DEMASIADOS})
def thank_incident(
    incidente_id: str,
    usuario: Usuario = Depends(por_viajero("votar", "LIMITE_VOTOS")),
    service: IncidentService = Depends(get_incident_service),
):
    """Quien usó el reporte se lo agradece a quien lo hizo. Suma a «Tu impacto» del autor; no da reputación."""
    try:
        return service.thank(usuario, incidente_id)
    except IncidenteNoEncontrado:
        raise NO_ENCONTRADO
    except VotoPropio:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No puedes agradecer tu propio reporte.")
    except GraciasRepetidas:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya le diste las gracias.")


@router.post("/{incidente_id}/votes", summary="¿Sigue ahí?", response_model=VoteResponse,
             responses={**SIN_SESION, 403: error("No puedes validar tu propio reporte."),
                        404: error("No existe o ya venció."), 409: error("Ya validaste este reporte."),
                        **DEMASIADOS})
def vote_incident(
    incidente_id: str, voto: VoteRequest,
    usuario: Usuario = Depends(por_viajero("votar", "LIMITE_VOTOS")),
    service: IncidentService = Depends(get_incident_service),
):
    """
    Confirma («sigue ahí») o desmiente («ya no está») un reporte. Confirmar renueva su vigencia;
    dos «ya no está» seguidos lo retiran. La reputación de quien reportó sube o baja en consecuencia.
    """
    try:
        resultado = service.vote(usuario, incidente_id, voto.sigue)
    except IncidenteNoEncontrado:
        raise NO_ENCONTRADO
    except VotoPropio:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No puedes validar tu propio reporte.")
    except VotoRepetido:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya validaste este reporte.")
    return VoteResponse(incidente=IncidentResponse.model_validate(resultado.incidente), retirado=resultado.retirado)
