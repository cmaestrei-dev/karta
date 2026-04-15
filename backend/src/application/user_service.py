from sqlalchemy.orm import Session
from src.infrastructure.models import Usuario
from src.domain.schemas.user_schema import UserCreate

class UserService:
    @staticmethod
    def create_user(db: Session, user_data: UserCreate) -> Usuario:
        """
        Caso de Uso: Registrar un nuevo viajero en Karta.
        """

        nuevo_usuario = Usuario(tipo_viajero=user_data.tipo_viajero)
        
        db.add(nuevo_usuario)
        db.commit()
        db.refresh(nuevo_usuario)
        
        return nuevo_usuario