from datetime import datetime, timezone

from src.domain.models import CredencialesInvalidas, TipoViajero, Usuario
from src.domain.ports import PasswordHasher, TokenIssuer, UserRepository


class AuthService:
    def __init__(self, users: UserRepository, hasher: PasswordHasher, tokens: TokenIssuer):
        self.users = users
        self.hasher = hasher
        self.tokens = tokens

    def register(self, *, email: str, password: str, nombre: str,
                 tipo_viajero: TipoViajero) -> tuple[Usuario, str]:
        """Caso de Uso: Registrarse. Lanza EmailYaRegistrado si el correo ya existe."""
        ahora = datetime.now(timezone.utc)
        usuario = self.users.add(
            email=email.strip().lower(),
            password_hash=self.hasher.hash(password),
            nombre=nombre.strip(),
            tipo_viajero=tipo_viajero,
            creado_en=ahora,
            terminos_aceptados_en=ahora,
        )
        return usuario, self.tokens.issue(usuario.id)

    def login(self, *, email: str, password: str) -> tuple[Usuario, str]:
        """Caso de Uso: Iniciar sesión. Lanza CredencialesInvalidas sin revelar cuál dato falló."""
        usuario = self.users.get_by_email(email.strip().lower())
        if usuario is None:
            # Verificar contra un hash ficticio iguala el tiempo de respuesta,
            # así no se puede averiguar qué correos están registrados.
            self.hasher.verify(password, self.hasher.dummy_hash)
            raise CredencialesInvalidas()
        if not self.hasher.verify(password, usuario.password_hash):
            raise CredencialesInvalidas()
        return usuario, self.tokens.issue(usuario.id)
