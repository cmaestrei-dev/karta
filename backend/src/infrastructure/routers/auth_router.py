from fastapi import APIRouter, Depends, HTTPException, status
from src.application.auth_service import AuthService
from src.domain.models import CredencialesInvalidas, EmailYaRegistrado
from src.domain.schemas.user_schema import LoginRequest, RegisterRequest, TokenResponse, UserResponse
from src.infrastructure.dependencies import get_auth_service
from src.infrastructure.limites import por_ip
from src.infrastructure.routers.respuestas import error

router = APIRouter(prefix="/api/v1/auth", tags=["Autenticación"])

@router.post("/register", summary="Registrarse", response_model=TokenResponse, status_code=status.HTTP_201_CREATED,
             dependencies=[Depends(por_ip("registro", "LIMITE_REGISTRO"))],
             responses={409: error("El correo ya está registrado."), 429: error("Demasiados registros desde esta red.")})
def register(datos: RegisterRequest, auth: AuthService = Depends(get_auth_service)):
    """Registra un nuevo viajero y devuelve su sesión iniciada."""
    try:
        usuario, token = auth.register(
            email=datos.email, password=datos.password,
            nombre=datos.nombre, tipo_viajero=datos.tipo_viajero,
        )
    except EmailYaRegistrado:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="El correo ya está registrado.")
    return TokenResponse(access_token=token, usuario=UserResponse.model_validate(usuario))

@router.post("/login", summary="Iniciar sesión", response_model=TokenResponse,
             dependencies=[Depends(por_ip("login", "LIMITE_LOGIN"))],
             responses={401: error("Correo o contraseña incorrectos (el mismo mensaje en ambos casos)."),
                        429: error("Demasiados intentos; vuelve a intentarlo en un minuto.")})
def login(datos: LoginRequest, auth: AuthService = Depends(get_auth_service)):
    """Valida las credenciales y devuelve un token Bearer (JWT)."""
    try:
        usuario, token = auth.login(email=datos.email, password=datos.password)
    except CredencialesInvalidas:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Correo o contraseña incorrectos.")
    return TokenResponse(access_token=token, usuario=UserResponse.model_validate(usuario))
