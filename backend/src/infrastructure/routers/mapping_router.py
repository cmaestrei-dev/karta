"""«Marca este paradero»: la comunidad ubica los paraderos oficiales que no tienen coordenadas (Kartógrafos)."""
from fastapi import APIRouter, Depends, HTTPException, Path, Response, status

from src.application.mapping_service import MappingService
from src.domain.mapeo import (
    LejosDelRecorrido, LejosParaConfirmar, Marca, MarcaNoEncontrada, MarcaPendiente, ParaderoNoEncontrado,
    ParaderoYaUbicado, VotoPropio, VotoRepetido,
)
from src.domain.models import Usuario
from src.domain.schemas.mapping_schema import (
    MarcaResponse, MarcarRequest, ParaderoResponse, ParaderosDeRutaResponse, PistaResponse, SentidoResponse,
    SubidaRequest, VotoDeMarcaRequest,
)
from src.infrastructure.dependencies import get_mapping_service, get_optional_user
from src.infrastructure.limites import por_viajero
from src.infrastructure.routers.respuestas import FUERA_DE_COBERTURA, SIN_SESION, error

router = APIRouter(prefix="/api/v1", tags=["Kartógrafos"])

DEMASIADOS = {429: error("Demasiados envíos seguidos; trae el encabezado Retry-After.")}


def _marca(m: Marca, usuario: Usuario | None) -> MarcaResponse:
    voto = next((v.esta_aqui for v in m.votos if usuario and v.usuario == usuario.id), None)
    return MarcaResponse(id=m.id, paradero=m.paradero, latitud=m.latitud, longitud=m.longitud, apoyo=m.apoyo,
                         estado=m.estado.value, mia=bool(usuario and m.propuesto_por == usuario.id), mi_voto=voto)


@router.get("/routes/{codigo}/stops", response_model=ParaderosDeRutaResponse, summary="Paraderos de una ruta",
            responses={404: error("No existe esa ruta.")})
def route_stops(codigo: str = Path(..., pattern=r"^[ATXC]\d{3}E?$"),
                usuario: Usuario | None = Depends(get_optional_user),
                service: MappingService = Depends(get_mapping_service)):
    """
    Los paraderos oficiales de la ruta (archivo de Transcaribe de 2025), por sentido y en orden, con su estado:
    `estacion`, `direccion` (ubicado por su dirección), `estimado` (su dirección, con un cruce que falta en OSM
    estimado sobre la misma vía), `comunidad` (lo ubicaron los viajeros), `por_confirmar` o `sin_ubicar`. Las pistas son lugares donde varios viajeros se subieron a la ruta.
    """
    datos = service.route_stops(codigo)
    if datos is None:
        raise HTTPException(status_code=404, detail=f"No existe la ruta {codigo}.")
    sentidos: dict[str, list[ParaderoResponse]] = {}
    for p in datos.paraderos:
        marca = datos.marcas.get(p.id) if p.longitud is None else None
        estado = p.precision or ("por_confirmar" if marca else "sin_ubicar")
        sentidos.setdefault(p.sentido, []).append(ParaderoResponse(
            id=p.id, orden=p.orden, nombre=p.nombre, estado=estado, modulo=p.modulo,
            latitud=p.latitud, longitud=p.longitud, marca=_marca(marca, usuario) if marca else None))
    ubicados = sum(1 for p in datos.paraderos if p.longitud is not None)
    return ParaderosDeRutaResponse(
        ruta=codigo, ubicados=ubicados, total=len(datos.paraderos),
        sentidos=[SentidoResponse(sentido=s, hacia=datos.hacia.get(f"{codigo}-{s}"), paraderos=ps)
                  for s, ps in sentidos.items()],
        pistas=[PistaResponse(latitud=p.latitud, longitud=p.longitud, subidas=p.subidas) for p in datos.pistas],
    )


@router.post("/stops/{paradero_id}/marks", status_code=status.HTTP_201_CREATED, response_model=MarcaResponse,
             summary="Marcar dónde está un paradero",
             responses={**SIN_SESION, **FUERA_DE_COBERTURA, **DEMASIADOS, 404: error("No existe ese paradero."),
                        409: error("Ya está ubicado, o ya hay una marca por confirmar."),
                        422: error("Ese punto no está sobre el recorrido de la ruta.")})
def mark_stop(request: MarcarRequest, paradero_id: str = Path(..., max_length=40),
              usuario: Usuario = Depends(por_viajero("marca", "LIMITE_MARCAS")),
              service: MappingService = Depends(get_mapping_service)):
    """Un Kartógrafo marca un paradero sin ubicar. Queda en el mapa cuando otros viajeros que están allí lo confirman."""
    try:
        return _marca(service.mark(paradero_id, usuario, request.latitud, request.longitud), usuario)
    except ParaderoNoEncontrado:
        raise HTTPException(status_code=404, detail="No existe ese paradero.")
    except ParaderoYaUbicado:
        raise HTTPException(status_code=409, detail="Ese paradero ya está en el mapa.")
    except MarcaPendiente:
        raise HTTPException(status_code=409, detail="Ya hay una marca por confirmar para ese paradero: "
                                                    "confírmala o di que no está ahí.")
    except LejosDelRecorrido:
        raise HTTPException(status_code=422, detail="Ese punto no está sobre la calle por donde pasa la ruta.")


@router.post("/stops/marks/{marca_id}/votes", response_model=MarcaResponse, summary="¿Está aquí el paradero?",
             responses={**SIN_SESION, **FUERA_DE_COBERTURA, **DEMASIADOS, 403: error("Es tu propia marca."),
                        404: error("No existe o ya se resolvió."), 409: error("Ya respondiste."),
                        422: error("Hay que estar a menos de 300 m para confirmarla.")})
def vote_mark(request: VotoDeMarcaRequest, marca_id: str = Path(..., max_length=40),
              usuario: Usuario = Depends(por_viajero("voto", "LIMITE_VOTOS")),
              service: MappingService = Depends(get_mapping_service)):
    """Se responde estando allí. Con apoyo suficiente el paradero queda en el mapa; con suficientes «no», se descarta."""
    try:
        return _marca(service.vote(marca_id, usuario, request.esta_aqui, request.latitud, request.longitud), usuario)
    except MarcaNoEncontrada:
        raise HTTPException(status_code=404, detail="Esa marca no existe o ya se resolvió.")
    except VotoPropio:
        raise HTTPException(status_code=403, detail="No puedes confirmar tu propia marca.")
    except VotoRepetido:
        raise HTTPException(status_code=409, detail="Ya respondiste por esta marca.")
    except LejosParaConfirmar:
        raise HTTPException(status_code=422, detail="Confírmala cuando estés cerca del paradero (a menos de 300 m).")


@router.post("/stops/boardings", status_code=status.HTTP_204_NO_CONTENT, summary="Me subí aquí",
             responses={**SIN_SESION, **FUERA_DE_COBERTURA, **DEMASIADOS, 404: error("No existe esa ruta.")})
def board(request: SubidaRequest, usuario: Usuario = Depends(por_viajero("subida", "LIMITE_AVISTAMIENTOS")),
          service: MappingService = Depends(get_mapping_service)):
    """
    El viajero se subió a la ruta fuera de una estación. Se guarda solo la ruta y el punto, sin quién: sirve de
    pista para ubicar los paraderos. Vence a los 180 días.
    """
    try:
        service.boarding(request.ruta, request.latitud, request.longitud)
    except ParaderoNoEncontrado:
        raise HTTPException(status_code=404, detail="No existe esa ruta.")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
