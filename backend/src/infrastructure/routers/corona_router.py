"""Rey o reina de la estación (docs/plan-juego.md, fase B): la corona, el apodo del día y si se participa."""
from fastapi import APIRouter, Depends, HTTPException, Path

from src.application.corona_service import (
    ApodoPropio, ApodoYaPuesto, CoronaService, EstacionNoEncontrada, NoParticipas, NoReinas, SinApodo,
)
from src.domain.apodos import ApodoRechazado
from src.domain.coronas import EstadoDeCorona
from src.domain.models import AjustesDeCorona, Usuario
from src.domain.schemas.corona_schema import (
    AjustesDeCoronaRequest, AjustesDeCoronaResponse, ApodoDelDiaResponse, ApodoRequest, CoronaResponse,
    ReporteDeApodoResponse, ReyResponse, TuCoronaResponse,
)
from src.infrastructure.dependencies import get_corona_service, get_optional_user
from src.infrastructure.limites import por_viajero, viajero_autorizado
from src.infrastructure.routers.respuestas import SIN_SESION, error

router = APIRouter(prefix="/api/v1", tags=["Coronas"])

ESTACION = Path(..., pattern=r"^[a-z][a-z-]{1,39}$", description="El id de la estación («bazurto»)")
NO_EXISTE = {404: error("No existe esa estación.")}
DEMASIADOS = {429: error("Demasiados envíos seguidos; trae el encabezado Retry-After.")}


def _respuesta(e: EstadoDeCorona, con_sesion: bool) -> CoronaResponse:
    return CoronaResponse(
        estacion=e.estacion,
        rey=ReyResponse(nombre=e.rey, desde=e.desde) if e.rey and e.desde else None,
        eres_rey=e.eres_rey,
        apodo_del_dia=ApodoDelDiaResponse(texto=e.apodo.texto, hasta=e.apodo.hasta) if e.apodo else None,
        tu=TuCoronaResponse(participas=e.participas, llevas=e.llevas, faltan=e.faltan,
                            puedes_poner_apodo=e.puedes_poner_apodo, otro_apodo_desde=e.otro_apodo_desde,
                            reportaste_el_apodo=e.reportaste_el_apodo) if con_sesion else None,
    )


def _ajustes(a: AjustesDeCorona) -> AjustesDeCoronaResponse:
    return AjustesDeCoronaResponse(participa=a.participa, visible=a.visible, apodo=a.apodo)


@router.get("/stations/{estacion}/crown", response_model=CoronaResponse, summary="La corona de una estación",
            responses=NO_EXISTE)
def crown(estacion: str = ESTACION, usuario: Usuario | None = Depends(get_optional_user),
          service: CoronaService = Depends(get_corona_service)):
    """
    Quién reina (siempre «un karteño», salvo que pidiera mostrar su apodo de karteño), desde cuándo y el apodo del día
    si hay uno. Con sesión, también lo del viajero: si participa, cuántos días lleva y cuántos le faltan.
    """
    try:
        return _respuesta(service.corona(estacion, usuario), usuario is not None)
    except EstacionNoEncontrada:
        raise HTTPException(status_code=404, detail="No existe esa estación.")


@router.put("/stations/{estacion}/crown/nickname", response_model=CoronaResponse, summary="Poner el apodo del día",
            responses={**SIN_SESION, **NO_EXISTE, **DEMASIADOS, 403: error("No reinas en esta estación."),
                       409: error("Ya pusiste el apodo de esta semana."), 422: error("Ese apodo no se puede.")})
def set_nickname(request: ApodoRequest, estacion: str = ESTACION,
                 usuario: Usuario = Depends(por_viajero("apodo", "LIMITE_APODOS")),
                 service: CoronaService = Depends(get_corona_service)):
    """Quien reina le pone a la estación un nombre por 24 horas, al ganar la corona y una vez por semana."""
    try:
        return _respuesta(service.poner_apodo(estacion, usuario, request.texto), True)
    except EstacionNoEncontrada:
        raise HTTPException(status_code=404, detail="No existe esa estación.")
    except NoReinas:
        raise HTTPException(status_code=403, detail="Solo quien reina en la estación le pone el apodo del día.")
    except ApodoYaPuesto:
        raise HTTPException(status_code=409, detail="Ya pusiste el apodo de esta semana.")
    except ApodoRechazado as e:
        raise HTTPException(status_code=422, detail=str(e))


@router.post("/stations/{estacion}/crown/nickname/reports", response_model=ReporteDeApodoResponse,
             summary="Reportar el apodo del día",
             responses={**SIN_SESION, **NO_EXISTE, **DEMASIADOS, 403: error("Es tu propio apodo."),
                        404: error("No hay un apodo vigente.")})
def report_nickname(estacion: str = ESTACION, usuario: Usuario = Depends(por_viajero("voto", "LIMITE_VOTOS")),
                    service: CoronaService = Depends(get_corona_service)):
    """Dos reportes de viajeros de nivel 3 o más, o cuatro de cualquiera, lo ocultan; quien lo puso pierde la corona
    y no puede reinar en 30 días."""
    try:
        return ReporteDeApodoResponse(oculto=service.reportar_apodo(estacion, usuario))
    except EstacionNoEncontrada:
        raise HTTPException(status_code=404, detail="No existe esa estación.")
    except SinApodo:
        raise HTTPException(status_code=404, detail="Esta estación no tiene apodo del día.")
    except ApodoPropio:
        raise HTTPException(status_code=403, detail="No puedes reportar tu propio apodo.")


@router.get("/users/me/crown", response_model=AjustesDeCoronaResponse, summary="Mis ajustes de las coronas",
            responses=SIN_SESION)
def my_crown(usuario: Usuario = Depends(viajero_autorizado)):
    return _ajustes(usuario.corona)


@router.put("/users/me/crown", response_model=AjustesDeCoronaResponse, summary="Participar en las coronas",
            responses={**SIN_SESION, 409: error("Para mostrarte en una corona, primero participa."),
                       422: error("Ese apodo de karteño no se puede.")})
def set_my_crown(request: AjustesDeCoronaRequest, usuario: Usuario = Depends(viajero_autorizado),
                 service: CoronaService = Depends(get_corona_service)):
    """
    Si participa en las coronas: responder «sí» es la autorización para esa finalidad (política, sección 2). Dejar de
    participar borra sus aportes y le quita la corona que tenga. Con «visible» y un apodo de karteño, si reina se le
    ve ese apodo; si no, «un karteño».
    """
    try:
        return _ajustes(service.ajustar(usuario, participa=request.participa, visible=request.visible,
                                        apodo=request.apodo))
    except NoParticipas:
        raise HTTPException(status_code=409, detail="Para mostrarte en una corona, primero participa.")
    except ApodoRechazado as e:
        raise HTTPException(status_code=422, detail=str(e))
