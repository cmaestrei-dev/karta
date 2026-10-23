from fastapi import APIRouter, Depends
from src.domain.models import Usuario
from src.domain.schemas.user_schema import UserResponse
from src.infrastructure.dependencies import get_current_user

router = APIRouter(prefix="/api/v1/users", tags=["Usuarios"])

@router.get("/me", response_model=UserResponse)
def read_current_user(usuario: Usuario = Depends(get_current_user)):
    """
    Perfil del viajero autenticado. La app lo usa al abrir para validar la sesión guardada.
    """
    return usuario
