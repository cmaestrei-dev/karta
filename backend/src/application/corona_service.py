"""
Casos de uso de las coronas de las estaciones (docs/plan-juego.md, fase B): anotar aportes, ver la corona, poner
y reportar el apodo del día, y decidir si se participa.
"""
from dataclasses import replace
from datetime import datetime, timedelta, timezone

from src.domain.apodos import revisar_apodo
from src.domain.coronas import (
    CASTIGO, NOMBRE_ANONIMO, RADIO_DE_ESTACION_M, VENTANA_DIAS, VIGENCIA_DEL_APORTE, Corona, EstadoDeCorona,
    apodo_vigente, cuando_puede_otra_vez, dia_de, faltan, poner, puede_poner_apodo, recalcular, reportar,
)
from src.domain.models import AjustesDeCorona, Estacion, Usuario
from src.domain.ports import CrownRepository, TransitRepository, UserRepository


class EstacionNoEncontrada(Exception):
    pass


class NoReinas(Exception):
    pass


class ApodoYaPuesto(Exception):
    def __init__(self, otra_vez: datetime | None):
        self.otra_vez = otra_vez


class SinApodo(Exception):
    pass


class ApodoPropio(Exception):
    pass


class NoParticipas(Exception):
    pass


def _ahora() -> datetime:
    return datetime.now(timezone.utc)


class CoronaService:
    def __init__(self, coronas: CrownRepository, transit: TransitRepository, users: UserRepository, reloj=_ahora):
        self.coronas = coronas
        self.transit = transit
        self.users = users
        self.reloj = reloj

    # Aportes ------------------------------------------------------------------------------------------------------

    def estacion_cercana(self, longitud: float, latitud: float) -> Estacion | None:
        cerca = self.transit.stations_near(longitud, latitud, RADIO_DE_ESTACION_M, 1)
        return cerca[0][0] if cerca else None

    def anotar(self, usuario_id: str, longitud: float, latitud: float, ahora: datetime | None = None) -> None:
        """Un aporte validado en ese punto. Cuenta solo si es en una estación y si esa persona participa."""
        usuario = self.users.get_by_id(usuario_id)
        if usuario is None or usuario.corona.participa is not True:
            return
        estacion = self.estacion_cercana(longitud, latitud)
        if estacion is None:
            return
        ahora = ahora or self.reloj()
        self.coronas.anotar_aporte(usuario_id, estacion.id, dia_de(ahora).isoformat(), ahora + VIGENCIA_DEL_APORTE)

    # La corona ----------------------------------------------------------------------------------------------------

    def _estacion(self, estacion_id: str) -> Estacion:
        estacion = next((e for e in self.transit.list_stations() if e.id == estacion_id), None)
        if estacion is None:
            raise EstacionNoEncontrada(estacion_id)
        return estacion

    def _al_dia(self, estacion_id: str, ahora: datetime) -> Corona:
        """La corona de hoy. Se calcula la primera vez que alguien la mira cada día, con los 30 días anteriores. Un
        apodo vencido se borra, con quienes lo reportaron (la política dice que dura 24 horas)."""
        hoy = dia_de(ahora)
        corona = self.coronas.corona(estacion_id) or Corona(estacion=estacion_id)
        if corona.apodo is not None and corona.apodo.hasta <= ahora:
            corona = replace(corona, apodo=None)
            self.coronas.guardar(corona)
        if corona.calculada_para == hoy:
            return corona
        aportes = self.coronas.aportes(estacion_id, (hoy - timedelta(days=VENTANA_DIAS)).isoformat(), hoy.isoformat())
        nueva = recalcular(corona, aportes, self.coronas.vetados(ahora), hoy)
        self.coronas.guardar(nueva)
        return nueva

    def corona(self, estacion_id: str, usuario: Usuario | None) -> EstadoDeCorona:
        self._estacion(estacion_id)
        ahora = self.reloj()
        hoy = dia_de(ahora)
        corona = self._al_dia(estacion_id, ahora)
        rey = self.users.get_by_id(corona.rey) if corona.rey else None
        nombre = None
        if rey is not None:
            nombre = rey.corona.apodo if rey.corona.visible and rey.corona.apodo else NOMBRE_ANONIMO
        eres_rey = usuario is not None and corona.rey == usuario.id
        desde = (hoy - timedelta(days=VENTANA_DIAS)).isoformat()
        llevas = self.coronas.dias_de(usuario.id, estacion_id, desde) if usuario else 0
        dias_del_rey = None
        if rey is not None and not eres_rey:
            del_rey = self.coronas.aportes(estacion_id, desde, hoy.isoformat()).get(rey.id)
            dias_del_rey = del_rey.dias if del_rey else 0
        apodo = apodo_vigente(corona, ahora)
        puede = usuario is not None and puede_poner_apodo(corona, usuario.id, ahora)
        return EstadoDeCorona(
            estacion=estacion_id, rey=nombre, desde=corona.desde if rey else None, eres_rey=eres_rey, apodo=apodo,
            participas=usuario.corona.participa if usuario else None, llevas=llevas,
            faltan=faltan(llevas, dias_del_rey, eres_rey) if usuario else None,
            puedes_poner_apodo=puede,
            otro_apodo_desde=None if puede or not eres_rey else cuando_puede_otra_vez(corona),
            reportaste_el_apodo=bool(apodo and usuario and any(u == usuario.id for u, _ in apodo.reportes)),
        )

    # El apodo del día ---------------------------------------------------------------------------------------------

    def poner_apodo(self, estacion_id: str, usuario: Usuario, texto: str) -> EstadoDeCorona:
        """Quien reina le pone nombre a la estación por 24 horas. ApodoRechazado si no pasa el filtro."""
        self._estacion(estacion_id)
        ahora = self.reloj()
        corona = self._al_dia(estacion_id, ahora)
        if corona.rey != usuario.id:
            raise NoReinas()
        if not puede_poner_apodo(corona, usuario.id, ahora):
            raise ApodoYaPuesto(cuando_puede_otra_vez(corona))
        self.coronas.guardar(poner(corona, revisar_apodo(texto), usuario.id, ahora))
        return self.corona(estacion_id, usuario)

    def reportar_apodo(self, estacion_id: str, usuario: Usuario) -> bool:
        """Un reporte del apodo vigente. Si con este queda oculto, quien lo puso pierde la corona por 30 días.
        Devuelve si quedó oculto."""
        self._estacion(estacion_id)
        ahora = self.reloj()
        corona = self._al_dia(estacion_id, ahora)
        apodo = apodo_vigente(corona, ahora)
        if apodo is None:
            raise SinApodo()
        if apodo.puesto_por == usuario.id:
            raise ApodoPropio()
        reportado = reportar(apodo, usuario.id, usuario.nivel)
        corona = replace(corona, apodo=reportado)
        if reportado.oculto:
            self.coronas.vetar(apodo.puesto_por, ahora + CASTIGO)
            if corona.rey == apodo.puesto_por:
                corona = replace(corona, rey=None, desde=None, ultimo_apodo=None)
        self.coronas.guardar(corona)
        return reportado.oculto

    # Participar ---------------------------------------------------------------------------------------------------

    def ajustar(self, usuario: Usuario, *, participa: bool | None = None, visible: bool | None = None,
                apodo: str | None = None) -> AjustesDeCorona:
        """
        Responder si participa (la autorización para esta finalidad) y cómo se muestra. Dejar de participar borra sus
        aportes y le quita la corona que tenga. El apodo de karteño pasa por el mismo filtro que el del día.
        """
        actual = usuario.corona
        nuevo = AjustesDeCorona(
            participa=actual.participa if participa is None else participa,
            visible=actual.visible if visible is None else visible,
            apodo=actual.apodo if apodo is None else (revisar_apodo(apodo) if apodo.strip() else None),
        )
        if nuevo.participa is not True:
            if visible or apodo:
                raise NoParticipas()  # mostrarse en una corona sin participar no tiene sentido
            nuevo = replace(nuevo, visible=False)
        if nuevo.visible and not nuevo.apodo:
            nuevo = replace(nuevo, visible=False)  # sin apodo, se ve «un karteño»
        self.users.ajustar_corona(usuario.id, nuevo, self.reloj())
        if actual.participa is True and nuevo.participa is not True:
            self.coronas.olvidar(usuario.id)
        return nuevo
