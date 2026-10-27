from fastapi import APIRouter, Depends, HTTPException, status
from src.application.auth_service import AuthService
from src.domain.models import CredencialesInvalidas, EmailYaRegistrado, Usuario
from src.domain.schemas.user_schema import (
    InvisibleRequest, LoginRequest, RegisterRequest, TokenResponse, UserResponse,
)
from src.infrastructure.dependencies import get_auth_service, get_optional_user
from src.infrastructure.limites import por_ip
from src.infrastructure.routers.respuestas import error

router = APIRouter(prefix="/api/v1/auth", tags=["Autenticación"])

@router.post("/anonymous", summary="Cuenta invisible del teléfono", response_model=TokenResponse,
             dependencies=[Depends(por_ip("cuenta_invisible", "LIMITE_CUENTAS_INVISIBLES"))],
             responses={429: error("Demasiadas cuentas nuevas desde esta red.")})
def anonymous(datos: InvisibleRequest, auth: AuthService = Depends(get_auth_service)):
    """
    Entra sin registrarse: el teléfono manda su secreto y recibe la sesión de su cuenta invisible (la misma
    siempre). Sin nombre ni correo. Si se borra la app, la cuenta queda huérfana y se borra a los 180 días.
    Con `politica`, la versión del aviso que se aceptó en el teléfono, queda la prueba de la autorización.
    """
    usuario, token = auth.invisible(secreto=datos.secreto, politica=datos.politica)
    return TokenResponse(access_token=token, usuario=UserResponse.model_validate(usuario))

@router.post("/register", summary="Registrarse", response_model=TokenResponse, status_code=status.HTTP_201_CREATED,
             dependencies=[Depends(por_ip("registro", "LIMITE_REGISTRO"))],
             responses={409: error("El correo ya está registrado."), 429: error("Demasiados registros desde esta red.")})
def register(datos: RegisterRequest, auth: AuthService = Depends(get_auth_service),
             actual: Usuario | None = Depends(get_optional_user)):
    """
    Registra un nuevo viajero y devuelve su sesión iniciada. Con la sesión de la cuenta invisible, le pone
    correo a esa misma cuenta: conserva la reputación y los lugares guardados.
    """
    try:
        usuario, token = auth.register(
            email=datos.email, password=datos.password,
            nombre=datos.nombre, tipo_viajero=datos.tipo_viajero, actual=actual,
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
        usuario, token = auth.login(email=datos.email, password=datos.password, politica=datos.politica)
    except CredencialesInvalidas:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Correo o contraseña incorrectos.")
    return TokenResponse(access_token=token, usuario=UserResponse.model_validate(usuario))
