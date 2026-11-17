import hashlib
from dataclasses import replace
from datetime import datetime, timezone

from src.domain.models import CredencialesInvalidas, TipoViajero, Usuario
from src.domain.politica import VERSION_POLITICA
from src.domain.ports import PasswordHasher, TokenIssuer, UserRepository
from src.domain.reportes import alias_publico


class AuthService:
    def __init__(self, users: UserRepository, hasher: PasswordHasher, tokens: TokenIssuer):
        self.users = users
        self.hasher = hasher
        self.tokens = tokens

    def invisible(self, *, secreto: str, politica: str | None = None) -> tuple[Usuario, str]:
        """
        La cuenta invisible del teléfono: la misma cada vez que muestra su secreto, o una nueva la primera vez.
        Solo se guarda la huella del secreto (es aleatorio y largo: no hace falta un hash lento).
        Si el teléfono dice que aceptó la política vigente, la prueba queda en la misma petición que crea o renueva la
        sesión: no depende de que después haya señal.
        """
        huella = hashlib.sha256(secreto.encode()).hexdigest()
        ahora = datetime.now(timezone.utc)
        usuario = self.users.get_by_secret(huella)
        if usuario is None:
            usuario = self.users.add_invisible(huella=huella, creado_en=ahora)
        else:
            self.users.touch(usuario.id, ahora)
        return self._con_autorizacion(usuario, politica, ahora), self.tokens.issue(usuario.id)

    def _con_autorizacion(self, usuario: Usuario, politica: str | None, ahora: datetime) -> Usuario:
        """Guarda la prueba si se aceptó la versión vigente y la cuenta aún no la tenía."""
        if politica != VERSION_POLITICA or usuario.autorizacion == VERSION_POLITICA:
            return usuario
        self.users.autorizar(usuario.id, politica, ahora)
        return replace(usuario, autorizacion=politica)

    def register(self, *, email: str, password: str, nombre: str, tipo_viajero: TipoViajero,
                 actual: Usuario | None = None) -> tuple[Usuario, str]:
        """
        Caso de Uso: Registrarse. Desde la cuenta invisible, le pone correo a esa misma cuenta (conserva la
        reputación y los lugares). Lanza EmailYaRegistrado si el correo ya existe. La casilla obligatoria del
        formulario autoriza el tratamiento según la política vigente, así que su prueba queda guardada.
        """
        ahora = datetime.now(timezone.utc)
        if actual is not None and actual.sin_cuenta:
            usuario = self.users.upgrade(
                actual.id, email=email.strip().lower(), password_hash=self.hasher.hash(password),
                nombre=nombre.strip(), alias=alias_publico(nombre), tipo_viajero=tipo_viajero,
                terminos_aceptados_en=ahora,
            )
            return self._con_autorizacion(usuario, VERSION_POLITICA, ahora), self.tokens.issue(usuario.id)
        usuario = self.users.add(
            email=email.strip().lower(),
            password_hash=self.hasher.hash(password),
            nombre=nombre.strip(),
            alias=alias_publico(nombre),
            tipo_viajero=tipo_viajero,
            creado_en=ahora,
            terminos_aceptados_en=ahora,
        )
        return self._con_autorizacion(usuario, VERSION_POLITICA, ahora), self.tokens.issue(usuario.id)

    def autorizar(self, usuario: Usuario, version: str) -> None:
        """
        Caso de Uso: Aceptar el aviso de privacidad. Solo vale la versión vigente: si la política cambió, la app
        debe mostrar la nueva antes (lanza ValueError).
        """
        if version != VERSION_POLITICA:
            raise ValueError(f"La política vigente es la versión {VERSION_POLITICA}.")
        self.users.autorizar(usuario.id, version, datetime.now(timezone.utc))

    def borrar_cuenta(self, usuario: Usuario) -> None:
        """Caso de Uso: Borrar mi cuenta y mis datos (supresión, Ley 1581 art. 8). No se puede deshacer."""
        self.users.erase(usuario.id)

    def login(self, *, email: str, password: str, politica: str | None = None) -> tuple[Usuario, str]:
        """Caso de Uso: Iniciar sesión. Lanza CredencialesInvalidas sin revelar cuál dato falló."""
        usuario = self.users.get_by_email(email.strip().lower())
        if usuario is None:
            # Verificar contra un hash ficticio iguala el tiempo de respuesta,
            # así no se puede averiguar qué correos están registrados.
            self.hasher.verify(password, self.hasher.dummy_hash)
            raise CredencialesInvalidas()
        if usuario.password_hash is None or not self.hasher.verify(password, usuario.password_hash):
            raise CredencialesInvalidas()
        return self._con_autorizacion(usuario, politica, datetime.now(timezone.utc)), self.tokens.issue(usuario.id)
