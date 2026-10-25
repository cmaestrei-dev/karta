from dataclasses import dataclass, replace
from datetime import datetime, timezone

from shapely.geometry import LineString, Point

from src.domain.direcciones import distancia_m
from src.domain.geo import a_grados, a_metros, validar_cobertura
from src.domain.mapeo import (
    CERCA_DEL_RECORRIDO_M, CERCA_PARA_CONFIRMAR_M, REPUTACION_POR_CONFIRMAR, REPUTACION_POR_PARADERO, EstadoDeMarca,
    LejosDelRecorrido, LejosParaConfirmar, Marca, MarcaNoEncontrada, MarcaPendiente, ParaderoNoEncontrado,
    ParaderoYaUbicado, ParadaDelViaje, Pista, Resultado, Voto, VotoPropio, VotoRepetido, acertaron, estado_por_apoyo,
    peso, pistas, respuesta_del_viaje,
)
from src.domain.models import Usuario
from src.domain.paraderos import ParaderoOficial
from src.domain.ports import StopMappingRepository, TransitRepository, UserRepository


@dataclass(frozen=True)
class ParaderosDeRuta:
    paraderos: list[ParaderoOficial]
    marcas: dict[str, Marca]      # por paradero, las que están por confirmar
    hacia: dict[str, str]         # «A107-ida» → «Blas de Lezo»
    pistas: list[Pista]


class MappingService:
    """Caso de Uso: «Marca este paradero» (Kartógrafos)."""

    def __init__(self, mapeo: StopMappingRepository, transit: TransitRepository, users: UserRepository):
        self.mapeo = mapeo
        self.transit = transit
        self.users = users

    def route_stops(self, ruta: str) -> ParaderosDeRuta | None:
        """Los paraderos oficiales de la ruta en orden, cuáles faltan, las marcas por confirmar y las pistas."""
        if self.transit.route(ruta) is None:
            return None
        return ParaderosDeRuta(
            paraderos=self.mapeo.route_stop_list(ruta),
            marcas={m.paradero: m for m in self.mapeo.pending_marks(ruta)},
            hacia=self.transit.directions(),
            pistas=pistas(self.mapeo.boardings(ruta)),
        )

    def mark(self, paradero_id: str, usuario: Usuario, latitud: float, longitud: float,
             ahora: datetime | None = None) -> Marca:
        """Marca dónde está un paradero sin ubicar. Se lleva a la calle por donde pasa la ruta."""
        validar_cobertura(latitud, longitud)
        paradero = self.mapeo.official_stop(paradero_id)
        if paradero is None:
            raise ParaderoNoEncontrado(paradero_id)
        if paradero.longitud is not None:
            raise ParaderoYaUbicado(paradero_id)
        if self.mapeo.pending_mark(paradero_id) is not None:
            raise MarcaPendiente(paradero_id)
        ruta = self.transit.route(paradero.ruta)
        linea = a_metros(LineString(ruta.coordenadas))
        punto = a_metros(Point(longitud, latitud))
        if linea.distance(punto) > CERCA_DEL_RECORRIDO_M:
            raise LejosDelRecorrido(paradero_id)
        sobre_la_via = a_grados(linea.interpolate(linea.project(punto)))
        return self.mapeo.add_mark(paradero=paradero_id, ruta=paradero.ruta, longitud=round(sobre_la_via.x, 6),
                                   latitud=round(sobre_la_via.y, 6), propuesto_por=usuario.id, peso=peso(usuario.nivel),
                                   en=ahora or datetime.now(timezone.utc))

    def vote(self, marca_id: str, usuario: Usuario, esta_aqui: bool, latitud: float, longitud: float,
             ahora: datetime | None = None) -> Marca:
        """
        «¿Está aquí el paradero?», respondido desde allí (a menos de 300 m). Con apoyo suficiente queda en el mapa
        y quien lo marcó gana reputación; con suficientes «no», se descarta y se puede marcar otra vez.
        """
        marca = self.mapeo.get_mark(marca_id)
        if marca is None or marca.estado != EstadoDeMarca.POR_CONFIRMAR:
            raise MarcaNoEncontrada(marca_id)
        if marca.propuesto_por == usuario.id:
            raise VotoPropio(marca_id)
        if any(v.usuario == usuario.id for v in marca.votos):
            raise VotoRepetido(marca_id)
        if distancia_m((longitud, latitud), (marca.longitud, marca.latitud)) > CERCA_PARA_CONFIRMAR_M:
            raise LejosParaConfirmar(marca_id)
        return self._responder(marca, usuario, esta_aqui, ahora)

    def _responder(self, marca: Marca, usuario: Usuario, esta_aqui: bool, ahora: datetime | None) -> Marca:
        marca_id = marca.id
        actualizada = self.mapeo.add_vote(marca_id, Voto(usuario.id, esta_aqui, peso(usuario.nivel)))
        if actualizada is None:
            raise VotoRepetido(marca_id)
        estado = estado_por_apoyo(actualizada.apoyo)
        if estado == EstadoDeMarca.POR_CONFIRMAR:
            return actualizada
        self.mapeo.resolve(marca_id, estado, ahora or datetime.now(timezone.utc))
        resuelta = replace(actualizada, estado=estado)
        if estado == EstadoDeMarca.UBICADA:
            self.users.ajustar_reputacion(resuelta.propuesto_por, REPUTACION_POR_PARADERO)
            self.users.sumar_impacto(resuelta.propuesto_por, "paraderos")
        for quien in acertaron(resuelta):
            self.users.ajustar_reputacion(quien, REPUTACION_POR_CONFIRMAR)
        return resuelta

    def ride(self, ruta: str, sentido: str, usuario: Usuario, paradas: list[ParadaDelViaje],
             ahora: datetime | None = None) -> list[tuple[str, Resultado]]:
        """
        Viaje de mapeo: en cada paradero donde paró el bus, una marca nueva o la respuesta a la que ya había (la
        confirma si coincide, dice que no está si el bus paró lejos). Los ya ubicados no cambian.
        """
        oficial = self.transit.route(ruta)
        if oficial is None:
            raise ParaderoNoEncontrado(ruta)
        del_sentido = {p.id: p for p in self.mapeo.route_stop_list(ruta) if p.sentido == sentido}
        linea = a_metros(LineString(oficial.coordenadas))
        resultados = []
        for parada in paradas:
            paradero = del_sentido.get(parada.paradero)
            if paradero is None:
                resultados.append((parada.paradero, Resultado.OTRA_RUTA))
                continue
            if paradero.longitud is not None:
                resultados.append((paradero.id, Resultado.YA_UBICADO))
                continue
            validar_cobertura(parada.latitud, parada.longitud)
            punto = a_metros(Point(parada.longitud, parada.latitud))
            if linea.distance(punto) > CERCA_DEL_RECORRIDO_M:
                resultados.append((paradero.id, Resultado.LEJOS_DEL_RECORRIDO))
                continue
            sobre_la_via = a_grados(linea.interpolate(linea.project(punto)))
            lon, lat = round(sobre_la_via.x, 6), round(sobre_la_via.y, 6)
            marca = self.mapeo.pending_mark(paradero.id)
            if marca is None:
                self.mapeo.add_mark(paradero=paradero.id, ruta=ruta, longitud=lon, latitud=lat, propuesto_por=usuario.id,
                                    peso=peso(usuario.nivel), en=ahora or datetime.now(timezone.utc))
                resultados.append((paradero.id, Resultado.MARCADO))
                continue
            if marca.propuesto_por == usuario.id or any(v.usuario == usuario.id for v in marca.votos):
                resultados.append((paradero.id, Resultado.YA_RESPONDIDO))
                continue
            esta_aqui = respuesta_del_viaje(distancia_m((lon, lat), (marca.longitud, marca.latitud)))
            if esta_aqui is None:
                resultados.append((paradero.id, Resultado.DUDOSO))
                continue
            try:
                self._responder(marca, usuario, esta_aqui, ahora)
            except VotoRepetido:
                resultados.append((paradero.id, Resultado.YA_RESPONDIDO))
                continue
            resultados.append((paradero.id, Resultado.CONFIRMADO if esta_aqui else Resultado.CONTRADICHO))
        return resultados

    def boarding(self, ruta: str, latitud: float, longitud: float, ahora: datetime | None = None) -> None:
        """Una subida a la ruta fuera de una estación: solo la ruta y el punto, sin quién."""
        validar_cobertura(latitud, longitud)
        if self.transit.route(ruta) is None:
            raise ParaderoNoEncontrado(ruta)
        self.mapeo.add_boarding(ruta, longitud, latitud, ahora or datetime.now(timezone.utc))
