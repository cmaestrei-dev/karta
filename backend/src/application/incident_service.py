from dataclasses import dataclass
from datetime import datetime, timezone

from src.domain.geo import corredor_de_ruta
from src.domain.models import Incidente, Usuario
from src.domain.ports import IncidentRepository, PlaceRepository, TransitRepository, UserRepository
from src.domain.reportes import (
    CATALOGO, REPUTACION_POR_CONFIRMACION, REPUTACION_POR_RETIRO, REPUTACION_POR_VOTAR, DetallesInvalidos,
    IncidenteNoEncontrado, TipoReporte, VotoPropio, debe_retirarse, expiracion_al_confirmar, validar_detalles,
)
from src.domain.route_risk import RADIO_BUSQUEDA_M, ResultadoRiesgo, evaluar_riesgo
from src.domain.schemas.route_schema import RouteRiskRequest


@dataclass(frozen=True)
class DetalleDeIncidente:
    """Lo que ve un viajero al tocar un reporte: el reporte, quién lo hizo y si ya lo validó."""
    incidente: Incidente
    alias_autor: str
    es_mio: bool
    mi_voto: bool | None


@dataclass(frozen=True)
class ResultadoDeVoto:
    incidente: Incidente
    retirado: bool


class IncidentService:
    MAX_INCIDENTES_EN_MAPA = 500
    RADIO_NOMBRE_M = 300  # el sitio se nombra por el lugar conocido más cercano dentro de este radio
    MISMO_LUGAR_M = 75

    def __init__(self, incidents: IncidentRepository, users: UserRepository,
                 places: PlaceRepository, transit: TransitRepository):
        self.incidents = incidents
        self.users = users
        self.places = places
        self.transit = transit

    @staticmethod
    def catalogo() -> list[TipoReporte]:
        return list(CATALOGO.values())

    def report(self, usuario: Usuario, *, tipo: str, detalles: dict[str, str],
               latitud: float, longitud: float) -> Incidente:
        """Caso de Uso #5: Reportar. El autor es el usuario de la sesión; los detalles se validan con el catálogo."""
        tipo_reporte = CATALOGO.get(tipo)
        if tipo_reporte is None:
            raise DetallesInvalidos("Ese tipo de reporte no existe.")
        limpios = validar_detalles(tipo_reporte, detalles, self.transit.route_codes())
        ahora = datetime.now(timezone.utc)
        return self.incidents.add(
            reportado_por=usuario.id, tipo=tipo_reporte, detalles=limpios, latitud=latitud, longitud=longitud,
            lugar=self._nombrar(latitud, longitud), creado_en=ahora, expira_en=ahora + tipo_reporte.vigencia,
            sin_cuenta=usuario.sin_cuenta,
        )

    def list_active(self, caja: tuple[float, float, float, float] | None = None) -> list[Incidente]:
        """Caso de Uso #6: Ver los reportes vigentes en el mapa (opcionalmente solo el área visible)."""
        return self.incidents.list_active(datetime.now(timezone.utc), self.MAX_INCIDENTES_EN_MAPA, caja)

    def detail(self, incidente_id: str, usuario: Usuario | None) -> DetalleDeIncidente:
        incidente = self._vigente(incidente_id)
        autor = self.users.get_by_id(incidente.reportado_por)
        return DetalleDeIncidente(
            incidente=incidente,
            alias_autor=autor.alias if autor else "Un viajero",
            es_mio=usuario is not None and usuario.id == incidente.reportado_por,
            mi_voto=self.incidents.vote_of(incidente_id, usuario.id) if usuario else None,
        )

    def vote(self, usuario: Usuario, incidente_id: str, sigue: bool) -> ResultadoDeVoto:
        """
        Caso de Uso #9: Validar un reporte («¿Sigue ahí?»).
        Un voto por viajero y reporte, nunca sobre el propio. Confirmar renueva la vigencia y da reputación
        a quien reportó; dos «ya no está» seguidos lo retiran y le restan reputación.
        """
        ahora = datetime.now(timezone.utc)
        incidente = self._vigente(incidente_id)
        if incidente.reportado_por == usuario.id:
            raise VotoPropio()
        self.incidents.register_vote(incidente_id, usuario.id, sigue, ahora)  # VotoRepetido si ya votó
        self.users.ajustar_reputacion(usuario.id, REPUTACION_POR_VOTAR)

        if sigue:
            nueva = expiracion_al_confirmar(CATALOGO[incidente.tipo], incidente.expira_en, ahora)
            actualizado = self.incidents.apply_confirmation(incidente_id, nueva)
            self.users.ajustar_reputacion(incidente.reportado_por, REPUTACION_POR_CONFIRMACION)
            return ResultadoDeVoto(actualizado, retirado=False)

        actualizado, racha = self.incidents.apply_denial(incidente_id)
        if debe_retirarse(racha):
            self.incidents.retire(incidente_id, ahora)
            self.users.ajustar_reputacion(incidente.reportado_por, REPUTACION_POR_RETIRO)
            return ResultadoDeVoto(actualizado, retirado=True)
        return ResultadoDeVoto(actualizado, retirado=False)

    def evaluate_route_risk(self, request: RouteRiskRequest) -> ResultadoRiesgo:
        """
        Caso de Uso: Escanear el riesgo de una ruta.
        Construye un corredor de 500 m alrededor de la ruta y lo consulta en una sola
        búsqueda geoespacial, en lugar de una consulta por cada punto.
        """
        area = corredor_de_ruta([(p.lon, p.lat) for p in request.route], RADIO_BUSQUEDA_M)
        cercanos = self.incidents.find_active_within(area, datetime.now(timezone.utc))
        return evaluar_riesgo(cercanos)

    def _vigente(self, incidente_id: str) -> Incidente:
        incidente = self.incidents.get_active(incidente_id, datetime.now(timezone.utc))
        if incidente is None:
            raise IncidenteNoEncontrado(incidente_id)
        return incidente

    def _nombrar(self, latitud: float, longitud: float) -> str | None:
        cercano = self.places.nearest(longitud, latitud, self.RADIO_NOMBRE_M)
        if cercano is None:
            return None
        lugar, distancia = cercano
        return lugar.nombre if distancia <= self.MISMO_LUGAR_M else f"Cerca de {lugar.nombre}"
