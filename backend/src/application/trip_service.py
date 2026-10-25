from dataclasses import dataclass, replace
from datetime import datetime, timezone
from typing import Literal

from src.domain.geo import circulo, corredor_de_ruta, distancia_m
from src.domain.horarios import HorarioRuta, cuando, en_colombia, opera, proximo_servicio, tipo_de_dia
from src.domain.models import Estacion, RutaTransporte
from src.domain.paraderos import abordaje
from src.domain.ports import IncidentRepository, PlaceRepository, TransitRepository
from src.domain.route_risk import PENALIZACION_RIESGO_MIN, RADIO_BUSQUEDA_M, ResultadoRiesgo, evaluar_riesgo
from src.domain.trip_planning import (
    CAMINATA_MAXIMA_DE_ACCESO_M, MAX_CORTES_CONFIABLES, OpcionViaje, PasoCercano, caminata_entre, carril_de_la_troncal,
    costo_percibido, con_alternativas, donde_pasa_cerca, el_que_pase_primero, estaciones_en_orden, muestrear, paradas_del_tramo,
    planificar,
)

Criterio = Literal["rapida", "segura", "sin_transbordo"]

# Cuánto pesa el riesgo al ordenar, según el criterio que eligió el viajero.
PESO_DEL_RIESGO = {"rapida": 1, "segura": 3, "sin_transbordo": 1}
CAMINATA_LARGA_M = 2500   # si ninguna ruta pasa cerca, se busca caminando hasta esto (a pie de verdad), y se avisa
MotivoDelAviso = Literal["horario", "caminata", "caminata_larga"]


@dataclass(frozen=True)
class Sugerencias:
    opciones: list[tuple[OpcionViaje, ResultadoRiesgo]]
    salida: datetime
    criterio: Criterio
    # Por qué no hay opciones en bus («La primera sale mañana a las 5:30 a. m.»), o qué tienen de raro las que hay.
    aviso: str | None = None
    motivo_del_aviso: MotivoDelAviso | None = None


@dataclass(frozen=True)
class PaginaDeRuta:
    ruta: RutaTransporte
    estaciones: list[Estacion]       # en el orden en que la ruta las recorre
    horario: HorarioRuta | None      # None si Transcaribe no lo publica (C018)
    hoy: str                         # tipo de día de hoy en Cartagena
    opera_ahora: bool | None         # None si no hay horario para saberlo


class TripService:
    MAX_OPCIONES = 3
    CANDIDATAS_A_EVALUAR = 8   # el riesgo se calcula solo para las más rápidas
    RADIO_ESTACION_M = 150
    RADIO_CRUCE_M = 120
    RADIO_REFERENCIA_M = 300
    RADIO_PARADERO_OFICIAL_M = 150

    def __init__(self, transit: TransitRepository, places: PlaceRepository, incidents: IncidentRepository):
        self.transit = transit
        self.places = places
        self.incidents = incidents

    def suggest(self, origen: tuple[float, float], destino: tuple[float, float],
                nombre_origen: str | None = None, nombre_destino: str | None = None,
                criterio: Criterio = "rapida", salida: datetime | None = None,
                caminata_maxima_m: int | None = None) -> Sugerencias:
        """
        Caso de Uso: Consultar rutas sugeridas.
        1. MongoDB devuelve las rutas que pasan cerca del origen o del destino ($geoIntersects).
        2. Se quitan las que no operan a la hora de salida (horarios oficiales, festivos incluidos).
        3. Se calcula la mejor subida y bajada en cada ruta, los transbordos entre dos rutas (salvo que se
           pida sin transbordo) y la opción a pie si es cerca.
        4. A las más rápidas se les evalúa el riesgo con los reportes vigentes de su corredor.
        5. Se ordenan por tiempo + lo que cuesta cada transbordo + penalización por riesgo, que pesa el
           triple si se pide la más segura.
        6. Si no queda ninguna en bus, se dice por qué; y si es porque ninguna ruta pasa cerca, se busca otra vez
           caminando hasta 2,5 km, avisando que hay que caminar más de lo normal.
        """
        salida = salida or datetime.now(timezone.utc)
        horarios = self.transit.schedules()
        estaciones = self.transit.list_stations()
        cercanas, en_servicio, evaluadas = self._buscar(origen, destino, criterio, salida, caminata_maxima_m,
                                                        horarios, estaciones)
        aviso, motivo = None, None
        if not any(opcion.rutas for opcion, _ in evaluadas):
            aviso = self._aviso_de_horario(cercanas, en_servicio, horarios, estaciones, origen, destino,
                                           criterio, salida)
            motivo = "horario" if aviso else None
            if aviso is None and caminata_maxima_m and any(
                    o.rutas for o in planificar(en_servicio, estaciones, origen, destino,
                                                con_transbordos=criterio != "sin_transbordo")):
                aviso, motivo = (f"Caminando hasta {caminata_maxima_m} m no hay rutas que te sirvan. "
                                 "Si puedes caminar un poco más, sí las hay."), "caminata"
            elif aviso is None and caminata_maxima_m is None:
                # Ninguna ruta pasa cerca del origen o del destino: mejor una caminata larga que nada.
                _, _, lejanas = self._buscar(origen, destino, criterio, salida, CAMINATA_LARGA_M, horarios, estaciones)
                if any(opcion.rutas for opcion, _ in lejanas):
                    evaluadas = lejanas
                    aviso, motivo = ("Ninguna ruta pasa cerca de tu origen o de tu destino: en estas opciones hay que "
                                     "caminar más de lo normal."), "caminata_larga"

        return Sugerencias(
            opciones=[(self._etiquetar(opcion, estaciones, nombre_origen, nombre_destino), riesgo)
                      for opcion, riesgo in evaluadas[:self.MAX_OPCIONES]],
            salida=en_colombia(salida), criterio=criterio, aviso=aviso, motivo_del_aviso=motivo,
        )

    def _buscar(self, origen, destino, criterio: Criterio, salida: datetime, caminata_maxima_m: int | None,
                horarios, estaciones):
        """Las rutas cerca, las que operan a esa hora y las opciones ordenadas, con su riesgo."""
        radio = max(CAMINATA_MAXIMA_DE_ACCESO_M, caminata_maxima_m or 0)
        areas = [circulo(*origen, radio), circulo(*destino, radio)]
        cercanas = self.transit.routes_intersecting_any(areas)
        en_servicio = [r for r in cercanas if opera(horarios.get(r.id), salida)]

        carril = carril_de_la_troncal(self.transit.list_routes("troncal"))
        muestras = [m for r in en_servicio if r.cortes_en_osm <= MAX_CORTES_CONFIABLES
                    if (m := muestrear(r, estaciones, carril)) is not None]
        opciones = el_que_pase_primero(planificar(en_servicio, estaciones, origen, destino,
                                                  con_transbordos=criterio != "sin_transbordo",
                                                  caminata_maxima_m=caminata_maxima_m, muestras=muestras), estaciones)
        # Además, en cada bus de un transbordo, las otras rutas que sirven igual en ese tramo.
        opciones = sorted((con_alternativas(o, muestras, estaciones) for o in opciones), key=costo_percibido)
        ahora = datetime.now(timezone.utc)
        evaluadas = []
        for opcion in opciones[:self.CANDIDATAS_A_EVALUAR]:
            corredor = corredor_de_ruta(opcion.coordenadas, RADIO_BUSQUEDA_M)
            evaluadas.append((opcion, evaluar_riesgo(self.incidents.find_active_within(corredor, ahora))))
        peso = PESO_DEL_RIESGO[criterio]
        evaluadas.sort(key=lambda par: costo_percibido(par[0]) + peso * PENALIZACION_RIESGO_MIN[par[1].nivel])
        return cercanas, en_servicio, evaluadas

    def _aviso_de_horario(self, cercanas, en_servicio, horarios, estaciones, origen, destino,
                          criterio: Criterio, salida: datetime) -> str | None:
        """Si no hay opciones en bus porque las rutas que servirían no operan a esa hora, cuándo sale la primera.
        Si no las hay ni a otra hora, no es cosa del horario y no se avisa nada."""
        fuera_de_horario = [r for r in cercanas if r not in en_servicio]
        if not fuera_de_horario:
            return None
        servirian = planificar(cercanas, estaciones, origen, destino, con_transbordos=criterio != "sin_transbordo")
        rutas_utiles = {r.id for opcion in servirian for r in opcion.rutas}
        proximo = proximo_servicio([horarios[r.id] for r in fuera_de_horario
                                    if r.id in rutas_utiles and r.id in horarios], salida)
        if proximo is None:
            return None
        texto = f"A esta hora no pasa ninguna ruta de Transcaribe que te sirva. La primera sale {cuando(proximo, salida)}"
        return texto if texto.endswith(".") else f"{texto}."   # «… a las 5:30 a. m.» ya trae su punto

    def route_page(self, codigo: str, ahora: datetime | None = None) -> PaginaDeRuta | None:
        """Caso de Uso: Ver una ruta: su recorrido, sus estaciones en orden y su horario de servicio."""
        ruta = self.transit.route(codigo)
        if ruta is None:
            return None
        ahora = ahora or datetime.now(timezone.utc)
        horario = self.transit.schedules().get(codigo)
        return PaginaDeRuta(
            ruta=ruta,
            estaciones=estaciones_en_orden(ruta, self.transit.list_stations()),
            horario=horario,
            hoy=tipo_de_dia(en_colombia(ahora).date()),
            opera_ahora=opera(horario, ahora) if horario else None,
        )

    def routes(self, tipo: str | None = None) -> list[RutaTransporte]:
        """Rutas con su recorrido, para dibujarlas en el mapa (la troncal en el inicio)."""
        return self.transit.list_routes(tipo)

    def nearby_stations(self, lat: float, lon: float, radio_m: float, limite: int) -> list[tuple[Estacion, float]]:
        """Caso de Uso: Ver estaciones de Transcaribe cercanas, de la más cercana a la más lejana."""
        return self.transit.stations_near(lon, lat, radio_m, limite)

    def nearby_routes(self, lat: float, lon: float, radio_m: float, limite: int) -> list[tuple[PasoCercano, str]]:
        """
        Caso de Uso: Ver las rutas que pasan cerca y por dónde tomarlas («Paradero Av. Kennedy con Calle 18»).
        Los paraderos oficiales no tienen coordenadas publicadas: es el punto de la vía más cercano donde la ruta
        recoge pasajeros, nombrado por el cruce de calles.
        """
        estaciones = self.transit.list_stations()
        cercanas = self.transit.routes_intersecting_any([circulo(lon, lat, radio_m)])
        pasos = sorted((p for r in cercanas if r.cortes_en_osm <= MAX_CORTES_CONFIABLES
                        if (p := donde_pasa_cerca(r, estaciones, (lon, lat), radio_m))),
                       key=lambda p: p.distancia_m)[:limite]
        oficiales = [o for o in self.transit.official_stops([p.ruta.id for p in pasos]) if o.precision == "direccion"]

        def nombre(paso: PasoCercano) -> str:
            # El paradero oficial de esa ruta, si hay uno ubicado por su dirección a pocos metros.
            cerca = [(distancia_m((paso.longitud, paso.latitud), (o.longitud, o.latitud)), o)
                     for o in oficiales if o.ruta == paso.ruta.id]
            distancia, oficial = min(cerca, key=lambda par: par[0], default=(None, None))
            if oficial and distancia <= self.RADIO_PARADERO_OFICIAL_M:
                return f"Paradero {oficial.nombre}"
            return self._parada((paso.longitud, paso.latitud), paso.ruta, estaciones)[0]

        return [(p, nombre(p)) for p in pasos]

    def _etiquetar(self, opcion: OpcionViaje, estaciones: list[Estacion],
                   nombre_origen: str | None, nombre_destino: str | None) -> OpcionViaje:
        """Pone nombres legibles a los puntos de subida, bajada y transbordo ("Estación Bazurto")."""
        inicio, fin = nombre_origen or "Tu ubicación", nombre_destino or "Tu destino"
        tramos = list(opcion.tramos)
        buses = [k for k, t in enumerate(tramos) if t.modo == "bus"]
        if not buses:
            tramos[0] = replace(tramos[0], desde=inicio, hasta=fin)
            return OpcionViaje(tramos=tuple(tramos))

        paraderos = self.transit.official_stops([r.id for k in buses for r in (tramos[k].ruta, *tramos[k].alternativas)])
        hacia = self.transit.directions()
        for k in buses:
            ruta = tramos[k].ruta
            subida, estacion_subida = self._parada(tramos[k].coordenadas[0], ruta, estaciones)
            bajada, estacion_bajada = self._parada(tramos[k].coordenadas[-1], ruta, estaciones)
            # Si se sube o se baja en una estación, la caminata llega a la estación misma: así su distancia
            # coincide con la que muestra /stops/nearby para esa estación.
            # Las caminatas de una integración (Santa Lucía ↔ Madre Bernarda) ya miden lo que se camina de verdad.
            if estacion_subida and not tramos[k - 1].integrado:
                tramos[k - 1] = caminata_entre(tramos[k - 1].coordenadas[0],
                                               (estacion_subida.longitud, estacion_subida.latitud))
            if estacion_bajada and not tramos[k + 1].integrado:
                tramos[k + 1] = caminata_entre((estacion_bajada.longitud, estacion_bajada.latitud),
                                               tramos[k + 1].coordenadas[-1])
            # Con «el que pase primero», el módulo solo se dice si todas las rutas paran en el mismo.
            comos = [abordaje(r.id, estacion_subida.id if estacion_subida else None,
                              estacion_bajada.id if estacion_bajada else None, paraderos, hacia)
                     for r in (ruta, *tramos[k].alternativas)]
            modulos = {c.modulo if c else None for c in comos}
            destinos = list(dict.fromkeys(c.hacia for c in comos if c and c.hacia))  # «Bocagrande o el Centro»
            tramos[k] = replace(tramos[k], desde=subida, hasta=bajada, paradas=paradas_del_tramo(tramos[k], estaciones),
                                modulo=modulos.pop() if len(modulos) == 1 else None,
                                hacia=" o ".join(destinos) if destinos else None)

        # Cada caminata va del punto anterior al siguiente: el origen, una bajada, una subida o el destino.
        for k, tramo in enumerate(tramos):
            if tramo.modo == "caminata":
                desde = tramos[k - 1].hasta if k > 0 else inicio
                hasta = tramos[k + 1].desde if k + 1 < len(tramos) else fin
                tramos[k] = replace(tramo, desde=desde, hasta=hasta)
        return OpcionViaje(tramos=tuple(tramos))

    def _parada(self, punto: tuple[float, float], ruta: RutaTransporte,
                estaciones: list[Estacion]) -> tuple[str, Estacion | None]:
        """
        Nombre legible del punto de subida o bajada y, si es una estación de la ruta, la estación.
        Fuera de las estaciones, el paradero se nombra por el cruce de calles más cercano: los paraderos
        oficiales no tienen coordenadas publicadas.
        """
        propias = [(distancia_m(punto, (e.longitud, e.latitud)), e) for e in estaciones if ruta.id in e.rutas]
        if propias:
            distancia, estacion = min(propias, key=lambda par: par[0])
            if distancia <= self.RADIO_ESTACION_M:
                return f"Estación {estacion.nombre}", estacion
        cruce = self.transit.intersection_near(punto[0], punto[1], self.RADIO_CRUCE_M)
        if cruce:
            return f"Paradero {cruce}", None
        cercano = self.places.nearest(punto[0], punto[1], self.RADIO_REFERENCIA_M)
        if cercano:
            return f"Paradero cerca de {cercano[0].nombre}", None
        return "Paradero sobre la vía", None
