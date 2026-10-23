from fastapi import APIRouter, Depends, HTTPException, Response, status
from src.application.place_service import PlaceService
from src.domain.models import LimiteLugaresGuardados, LugarGuardadoNoEncontrado, MAX_LUGARES_GUARDADOS, Usuario
from src.domain.schemas.place_schema import SavedPlaceCreate, SavedPlaceResponse, SavedPlaceUpdate
from src.domain.schemas.user_schema import UserResponse
from src.infrastructure.dependencies import get_current_user, get_place_service
from src.infrastructure.routers.respuestas import FUERA_DE_COBERTURA, SIN_SESION, error
from typing import List

router = APIRouter(prefix="/api/v1/users", tags=["Usuarios"])

NO_ENCONTRADO = HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lugar guardado no encontrado.")

@router.get("/me", summary="Mi perfil", response_model=UserResponse, responses=SIN_SESION)
def read_current_user(usuario: Usuario = Depends(get_current_user)):
    """
    Perfil del viajero autenticado. La app lo usa al abrir para validar la sesión guardada.
    """
    return usuario

@router.get("/me/places", summary="Mis lugares guardados", response_model=List[SavedPlaceResponse], responses=SIN_SESION)
def list_saved_places(usuario: Usuario = Depends(get_current_user),
                      service: PlaceService = Depends(get_place_service)):
    """Lugares frecuentes del viajero ("Casa", "Trabajo")."""
    return service.list_saved(usuario)

@router.post("/me/places", summary="Guardar un lugar", response_model=SavedPlaceResponse, status_code=status.HTTP_201_CREATED,
             responses={**SIN_SESION, 409: error("Ya hay 10 lugares guardados."), **FUERA_DE_COBERTURA})
def create_saved_place(datos: SavedPlaceCreate, usuario: Usuario = Depends(get_current_user),
                       service: PlaceService = Depends(get_place_service)):
    """Guarda un lugar frecuente. Máximo 10 por viajero."""
    try:
        return service.add_saved(usuario, nombre=datos.nombre, icono=datos.icono,
                                 latitud=datos.latitud, longitud=datos.longitud)
    except LimiteLugaresGuardados:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail=f"Ya tienes {MAX_LUGARES_GUARDADOS} lugares guardados; elimina uno primero.")

@router.patch("/me/places/{place_id}", summary="Editar un lugar guardado", response_model=SavedPlaceResponse,
              responses={**SIN_SESION, 404: error("No existe o es de otro viajero."), **FUERA_DE_COBERTURA})
def update_saved_place(place_id: str, cambios: SavedPlaceUpdate, usuario: Usuario = Depends(get_current_user),
                       service: PlaceService = Depends(get_place_service)):
    """Cambia el nombre, el ícono o la ubicación de un lugar guardado propio."""
    try:
        return service.update_saved(usuario, place_id, cambios.model_dump(exclude_unset=True))
    except LugarGuardadoNoEncontrado:
        raise NO_ENCONTRADO

@router.delete("/me/places/{place_id}", summary="Eliminar un lugar guardado", status_code=status.HTTP_204_NO_CONTENT,
               responses={**SIN_SESION, 404: error("No existe o es de otro viajero.")})
def delete_saved_place(place_id: str, usuario: Usuario = Depends(get_current_user),
                       service: PlaceService = Depends(get_place_service)):
    """Elimina un lugar guardado propio."""
    try:
        service.delete_saved(usuario, place_id)
    except LugarGuardadoNoEncontrado:
        raise NO_ENCONTRADO
    return Response(status_code=status.HTTP_204_NO_CONTENT)
