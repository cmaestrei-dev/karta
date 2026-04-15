from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from src.infrastructure.database import get_db
from src.domain.schemas.user_schema import UserCreate, UserResponse
from src.application.user_service import UserService

router = APIRouter(prefix="/api/v1/users", tags=["Usuarios"])

@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    """
    Registra un nuevo Doliente (Viajero) en la plataforma Karta.
    """
    return UserService.create_user(db, user)