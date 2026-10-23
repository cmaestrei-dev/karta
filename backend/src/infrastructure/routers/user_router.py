from fastapi import APIRouter, Depends, HTTPException, Response, status
from src.application.place_service import PlaceService
from src.domain.models import LimiteLugaresGuardados, LugarGuardadoNoEncontrado, MAX_LUGARES_GUARDADOS, Usuario
from src.domain.schemas.place_schema import SavedPlaceCreate, SavedPlaceResponse, SavedPlaceUpdate
from src.domain.schemas.user_schema import UserResponse
from src.infrastructure.dependencies import get_current_user, get_place_service
from typing import List

router = APIRouter(prefix="/api/v1/users", tags=["Usuarios"])

NO_ENCONTRADO = HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lugar guardado no encontrado.")

@router.get("/me", response_model=UserResponse)
def read_current_user(usuario: Usuario = Depends(get_current_user)):
    """
    Perfil del viajero autenticado. La app lo usa al abrir para validar la sesión guardada.
    """
    return usuario

@router.get("/me/places", response_model=List[SavedPlaceResponse])
def list_saved_places(usuario: Usuario = Depends(get_current_user),
                      service: PlaceService = Depends(get_place_service)):
    """Lugares frecuentes del viajero ("Casa", "Trabajo")."""
    return service.list_saved(usuario)

@router.post("/me/places", response_model=SavedPlaceResponse, status_code=status.HTTP_201_CREATED)
def create_saved_place(datos: SavedPlaceCreate, usuario: Usuario = Depends(get_current_user),
                       service: PlaceService = Depends(get_place_service)):
    """Guarda un lugar frecuente. Máximo 10 por viajero."""
    try:
        return service.add_saved(usuario, nombre=datos.nombre, icono=datos.icono,
                                 latitud=datos.latitud, longitud=datos.longitud)
    except LimiteLugaresGuardados:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail=f"Ya tienes {MAX_LUGARES_GUARDADOS} lugares guardados; elimina uno primero.")

@router.patch("/me/places/{place_id}", response_model=SavedPlaceResponse)
def update_saved_place(place_id: str, cambios: SavedPlaceUpdate, usuario: Usuario = Depends(get_current_user),
                       service: PlaceService = Depends(get_place_service)):
    """Cambia el nombre, el ícono o la ubicación de un lugar guardado propio."""
    try:
        return service.update_saved(usuario, place_id, cambios.model_dump(exclude_unset=True))
    except LugarGuardadoNoEncontrado:
        raise NO_ENCONTRADO

@router.delete("/me/places/{place_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_saved_place(place_id: str, usuario: Usuario = Depends(get_current_user),
                       service: PlaceService = Depends(get_place_service)):
    """Elimina un lugar guardado propio."""
    try:
        service.delete_saved(usuario, place_id)
    except LugarGuardadoNoEncontrado:
        raise NO_ENCONTRADO
    return Response(status_code=status.HTTP_204_NO_CONTENT)
