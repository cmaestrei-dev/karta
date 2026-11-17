"""
Límite de peticiones por IP, en memoria y para todas las rutas, incluidas las que no piden sesión (OWASP API4).

Rechazar con 429 cuesta un milisegundo y no toca la base. Así, un abuso desde un solo equipo ya no copa las
ejecuciones simultáneas de Lambda de la cuenta, que hoy son 10, ni las operaciones de Atlas. Cada instancia
de Lambda lleva su propia cuenta: con varias instancias el límite real es algo mayor, lo que también le da aire
a las IP que comparten muchos teléfonos (los operadores móviles, la universidad). Lo que pide sesión se sigue
limitando además por viajero, en la base (limites.py).
"""
import threading
import time
from collections import OrderedDict
from ipaddress import IPv6Address, ip_address

from starlette.responses import JSONResponse

from src.infrastructure import config


def clave_de_ip(host: str | None) -> str:
    """La IP tal cual; una IPv6, por su red /64, porque cada teléfono puede estrenar direcciones dentro de ella."""
    try:
        ip = ip_address(host or "")
    except ValueError:
        return host or "desconocida"
    if isinstance(ip, IPv6Address):
        return format(IPv6Address(int(ip) >> 64 << 64)) + "/64"
    return str(ip)


class LimitePorIp:
    """Un balde de fichas por clave: se llena a `por_minuto` y deja gastar de golpe hasta `rafaga`."""

    def __init__(self, max_claves: int = 20_000, reloj=time.monotonic):
        self._baldes: OrderedDict[str, tuple[float, float]] = OrderedDict()  # clave → (fichas, cuándo)
        self._max_claves = max_claves
        self._reloj = reloj
        self._candado = threading.Lock()

    def permitir(self, clave: str, por_minuto: int, rafaga: int) -> int | None:
        """None si puede pasar; si no, cuántos segundos esperar (para Retry-After)."""
        ahora = self._reloj()
        por_segundo = por_minuto / 60
        with self._candado:
            fichas, antes = self._baldes.pop(clave, (float(rafaga), ahora))
            fichas = min(float(rafaga), fichas + (ahora - antes) * por_segundo)
            permitido = fichas >= 1
            if permitido:
                fichas -= 1
            self._baldes[clave] = (fichas, ahora)  # al final: la más reciente
            while len(self._baldes) > self._max_claves:
                self._baldes.popitem(last=False)  # se olvida la que lleva más tiempo quieta
        return None if permitido else max(1, round((1 - fichas) / por_segundo))


def grupos_de(ruta: str) -> list[tuple[str, str]]:
    """Los límites que cuenta una petición: todas van al general; planificar y buscar, además, al suyo."""
    grupos = [("general", "LIMITE_IP_GENERAL")]
    if ruta in ("/api/v1/routes/suggest", "/api/v1/routes/risk"):
        grupos.append(("planificar", "LIMITE_IP_PLANIFICAR"))
    elif ruta.startswith("/api/v1/places/"):
        grupos.append(("buscar", "LIMITE_IP_BUSCAR"))
    return grupos


class LimitarPorIp:
    """
    Middleware ASGI: responde 429 con Retry-After antes de llegar a la API. Es ASGI puro (sin BaseHTTPMiddleware),
    así que no añade casi nada a cada petición. Los límites se leen de config en cada una.
    """

    def __init__(self, app, limite: LimitePorIp | None = None):
        self.app = app
        self.limite = limite or LimitePorIp()

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            cliente = scope.get("client")
            ip = clave_de_ip(cliente[0] if cliente else None)
            for grupo, nombre in grupos_de(scope["path"]):
                por_minuto, rafaga = getattr(config, nombre)
                espera = self.limite.permitir(f"{grupo}:{ip}", por_minuto, rafaga)
                if espera is not None:
                    minutos = max(1, round(espera / 60))
                    respuesta = JSONResponse(
                        status_code=429, headers={"Retry-After": str(espera)},
                        content={"detail": f"Demasiadas peticiones seguidas. Vuelve a intentarlo en {minutos} min."})
                    await respuesta(scope, receive, send)
                    return
        await self.app(scope, receive, send)
