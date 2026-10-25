"""
Planificación de viajes: a pie; caminata + una ruta de Transcaribe + caminata; o con un transbordo
entre dos rutas. Los tiempos son estimaciones con velocidades promedio.

Cada ruta se muestrea cada 25 m. Para cada punto se calcula, en los dos sentidos del recorrido, lo antes
que se puede llegar a él desde el origen (caminar, esperar, ir en bus) y lo que falta desde él hasta el
destino. Un viaje directo une esos dos cálculos en la misma ruta; un transbordo los une en dos rutas que
pasan a menos de 300 m una de la otra.

Un transbordo no cuesta lo mismo en todas partes. Dentro de una estación (el Portal) o entre las dos estaciones
que Transcaribe integra frente a frente (Santa Lucía, de las alimentadoras, y Madre Bernarda, de las troncales:
40 m por la cebra) se camina poco y el pasaje no se vuelve a cobrar. Entrar desde la calle a una estación troncal,
que está en el separador de la avenida, obliga a cruzarla: eso suma minutos que la línea recta no ve.
"""
from dataclasses import dataclass, field, replace

import numpy as np
import shapely
from shapely.geometry import LineString, Point
from shapely.ops import substring

from src.domain.geo import a_grados, a_metros
from src.domain.models import Estacion, RutaTransporte

VELOCIDAD_CAMINATA_M_POR_MIN = 75   # 4,5 km/h
FACTOR_RODEO = 1.3                  # las calles no van en línea recta
CAMINATA_MAXIMA_DE_ACCESO_M = 800   # lo máximo que se camina hasta o desde una ruta
CAMINATA_DIRECTA_MAXIMA_M = 2500    # distancia en línea recta para ofrecer ir a pie
PASO_DE_MUESTREO_M = 25
RADIO_DE_ESTACION_M = 60            # en el corredor de la troncal solo se sube o baja en estaciones
ANCHO_CORREDOR_TRONCAL_M = 700      # más lejos de toda estación, la troncal va en vía mixta con paraderos
MAX_CORTES_CONFIABLES = 2           # rutas con más huecos en OSM no se usan para planificar
TRANSBORDO_MAXIMO_M = 300           # lo máximo que se camina entre una ruta y la otra
PENALIZACION_TRANSBORDO_MIN = 4     # cambiar de bus cuesta más que los minutos que dura
PENALIZACION_TRANSBORDO_INTEGRADO_MIN = 2  # en la misma estación o en una integración oficial: menos incómodo
CRUCE_A_ESTACION_MIN = 2            # cruzar la avenida hasta una estación troncal (semáforo o cebra) y entrar
TRANSBORDO_EN_ESTACION_M = 60       # cambiar de andén dentro de la misma estación
# Las pretroncales (X) también van por el carril de Transcaribe y ahí solo paran en estaciones; fuera del
# corredor, en paraderos de la vía como cualquier bus.
SOLO_EN_ESTACIONES = ("troncal", "pretroncal")


@dataclass(frozen=True)
class Integracion:
    """Dos estaciones separadas por una calle que funcionan como una sola para transbordar."""
    caminata_m: float
    cruce_min: float
    indicacion: str


# Fuente: Transcaribe, «Rutas y recorridos» (julio de 2024), y OpenStreetMap (paso cebra, way 1249740541).
INTEGRACIONES = {
    frozenset({"santa-lucia", "madre-bernarda"}): Integracion(
        caminata_m=40, cruce_min=1,
        indicacion="Sal de Santa Lucía y cruza por la cebra hasta Madre Bernarda: 40 m. "
                   "Al entrar vuelves a pasar la tarjeta, pero no te cobra si cambias en menos de 90 minutos."),
}

VELOCIDAD_BUS_KMH = {"troncal": 22, "pretroncal": 18, "alimentadora": 15, "complementaria": 15}
ESPERA_ESTIMADA_MIN = {"troncal": 5, "pretroncal": 8, "alimentadora": 10, "complementaria": 10}


@dataclass(frozen=True)
class Tramo:
    modo: str  # "caminata" | "bus"
    coordenadas: tuple[tuple[float, float], ...]  # (lon, lat)
    distancia_m: float
    duracion_min: float
    espera_min: float = 0.0
    ruta: RutaTransporte | None = None
    desde: str = ""
    hasta: str = ""
    paradas: tuple[Estacion, ...] = ()  # estaciones por las que pasa el bus, en orden (incluye subida y bajada)
    integrado: bool = False             # caminata de un transbordo en la misma estación o en una integración
    indicacion: str | None = None       # cómo hacer el cambio («Sal de Santa Lucía y cruza por la cebra…»)


@dataclass(frozen=True)
class OpcionViaje:
    tramos: tuple[Tramo, ...] = field(default_factory=tuple)

    @property
    def tiempo_total_min(self) -> float:
        return sum(t.duracion_min + t.espera_min for t in self.tramos)

    @property
    def distancia_caminata_m(self) -> float:
        return sum(t.distancia_m for t in self.tramos if t.modo == "caminata")

    @property
    def rutas(self) -> list[RutaTransporte]:
        return [t.ruta for t in self.tramos if t.ruta]

    @property
    def ruta(self) -> RutaTransporte | None:
        return next(iter(self.rutas), None)

    @property
    def transbordos(self) -> int:
        return max(len(self.rutas) - 1, 0)

    @property
    def penalizacion_de_transbordos(self) -> float:
        """Lo que cuestan los cambios de bus además de sus minutos: menos en una estación integrada."""
        buses = [k for k, t in enumerate(self.tramos) if t.modo == "bus"]
        return sum(PENALIZACION_TRANSBORDO_INTEGRADO_MIN if any(t.integrado for t in self.tramos[k1 + 1:k2])
                   else PENALIZACION_TRANSBORDO_MIN for k1, k2 in zip(buses, buses[1:]))

    @property
    def coordenadas(self) -> list[tuple[float, float]]:
        puntos: list[tuple[float, float]] = []
        for tramo in self.tramos:
            puntos.extend(tramo.coordenadas[1:] if puntos else tramo.coordenadas)
        return puntos


def costo_percibido(opcion: "OpcionViaje") -> float:
    """El tiempo del viaje más lo que cuesta cada cambio de bus: con esto se comparan opciones."""
    return opcion.tiempo_total_min + opcion.penalizacion_de_transbordos


def minutos_caminando(distancia_m):
    return distancia_m * FACTOR_RODEO / VELOCIDAD_CAMINATA_M_POR_MIN


def _caminata(desde: tuple[float, float], hasta: tuple[float, float], distancia_m: float) -> Tramo:
    distancia_m = float(distancia_m)
    return Tramo(modo="caminata", coordenadas=(desde, hasta),
                 distancia_m=distancia_m * FACTOR_RODEO, duracion_min=minutos_caminando(distancia_m))


def caminata_entre(desde: tuple[float, float], hasta: tuple[float, float]) -> Tramo:
    """Tramo a pie entre dos puntos (lon, lat), con la misma regla de rodeo y velocidad de todo el planificador."""
    return _caminata(desde, hasta, a_metros(Point(desde)).distance(a_metros(Point(hasta))))


def opcion_caminando(origen: tuple[float, float], destino: tuple[float, float]) -> OpcionViaje | None:
    o, d = a_metros(Point(origen)), a_metros(Point(destino))
    distancia = o.distance(d)
    if distancia > CAMINATA_DIRECTA_MAXIMA_M:
        return None
    return OpcionViaje(tramos=(_caminata(origen, destino, distancia),))


# ---------------------------------------------------------------- rutas muestreadas


@dataclass(frozen=True, eq=False)
class RutaMuestreada:
    ruta: RutaTransporte
    linea: LineString        # en metros
    posiciones: np.ndarray   # metros recorridos desde el inicio de la relación de OSM
    puntos: np.ndarray       # (n, 2) en metros
    abordable: np.ndarray    # dónde se puede subir o bajar
    velocidad: float         # m/min
    estacion: np.ndarray = field(default_factory=lambda: np.array([], dtype=object))  # id de la estación propia o ""

    @property
    def espera(self) -> float:
        return ESPERA_ESTIMADA_MIN[self.ruta.tipo]

    def sentidos(self):
        """OSM guarda una relación por ruta aunque los buses van y vuelven: se evalúan los dos sentidos.
        Cada sentido es (índices en orden de avance, metros avanzados en ese orden)."""
        ida = np.arange(len(self.posiciones))
        return [(ida, self.posiciones), (ida[::-1], self.linea.length - self.posiciones[::-1])]

    def lonlat(self, k: int) -> tuple[float, float]:
        return tuple(a_grados(Point(self.puntos[k])).coords[0])

    def tramo(self, i: int, j: int) -> Tramo:
        """El bus entre los puntos i y j (en cualquier sentido: substring invierte si j < i)."""
        recorrido = a_grados(substring(self.linea, self.posiciones[i], self.posiciones[j]))
        distancia = float(abs(self.posiciones[j] - self.posiciones[i]))
        return Tramo(modo="bus", coordenadas=tuple(recorrido.coords), distancia_m=distancia,
                     duracion_min=distancia / self.velocidad, espera_min=self.espera, ruta=self.ruta)


def _distancia_minima(puntos: np.ndarray, estaciones: list[Estacion]) -> np.ndarray:
    """Para cada punto (en metros), la distancia a la estación más cercana."""
    en_metros = shapely.get_coordinates(a_metros(shapely.points([(e.longitud, e.latitud) for e in estaciones])))
    return np.hypot(puntos[:, None, 0] - en_metros[None, :, 0], puntos[:, None, 1] - en_metros[None, :, 1]).min(axis=1)


def muestrear(ruta: RutaTransporte, estaciones: list[Estacion]) -> RutaMuestreada | None:
    linea = a_metros(LineString(ruta.coordenadas))
    posiciones = np.append(np.arange(0, linea.length, PASO_DE_MUESTREO_M), linea.length)
    puntos = shapely.get_coordinates(shapely.line_interpolate_point(linea, posiciones))

    abordable = np.ones(len(posiciones), dtype=bool)
    propias = [e for e in estaciones if ruta.id in e.rutas]
    if ruta.tipo == "troncal" and not propias:
        return None
    if ruta.tipo in SOLO_EN_ESTACIONES and propias:
        # Dentro del corredor (cerca de cualquier estación) solo se sube en las estaciones de esta
        # ruta: el expreso T100E pasa por Los Ejecutivos sin parar. Fuera del corredor va en vía mixta.
        cerca_de_propia = _distancia_minima(puntos, propias) <= RADIO_DE_ESTACION_M
        fuera_del_corredor = _distancia_minima(puntos, estaciones) > ANCHO_CORREDOR_TRONCAL_M
        abordable = cerca_de_propia | fuera_del_corredor
    velocidad = VELOCIDAD_BUS_KMH[ruta.tipo] * 1000 / 60
    return RutaMuestreada(ruta, linea, posiciones, puntos, abordable, velocidad, _estacion_propia(puntos, ruta, estaciones))


def _estacion_propia(puntos: np.ndarray, ruta: RutaTransporte, estaciones: list[Estacion]) -> np.ndarray:
    """Para cada punto, la estación de esta ruta en la que está (a menos de 60 m), o "" si no está en ninguna."""
    resultado = np.full(len(puntos), "", dtype=object)
    propias = [e for e in estaciones if ruta.id in e.rutas]
    if not propias:
        return resultado
    en_metros = shapely.get_coordinates(a_metros(shapely.points([(e.longitud, e.latitud) for e in propias])))
    distancias = np.hypot(puntos[:, None, 0] - en_metros[None, :, 0], puntos[:, None, 1] - en_metros[None, :, 1])
    cercana = distancias.argmin(axis=1)
    dentro = distancias[np.arange(len(puntos)), cercana] <= RADIO_DE_ESTACION_M
    resultado[dentro] = np.array([propias[k].id for k in cercana[dentro]], dtype=object)
    return resultado


def _distancias(m: RutaMuestreada, punto: tuple[float, float]) -> np.ndarray:
    p = a_metros(Point(punto))
    return np.hypot(m.puntos[:, 0] - p.x, m.puntos[:, 1] - p.y)


def _argmin_acumulado(valores: np.ndarray) -> np.ndarray:
    """Para cada k, el índice del menor valor en valores[0..k] (−1 si todos son infinitos)."""
    minimo = np.minimum.accumulate(valores)
    es_minimo = np.isfinite(valores) & (valores == minimo)
    return np.maximum.accumulate(np.where(es_minimo, np.arange(len(valores)), -1))


@dataclass(frozen=True, eq=False)
class _Sentido:
    orden: np.ndarray     # índices de la ruta en orden de avance
    minutos: np.ndarray   # por posición en `orden`: tiempo acumulado (llegada) o restante (salida)
    extremo: np.ndarray   # por posición en `orden`: índice de la ruta donde se sube (llegada) o se baja (salida)


def _llegadas(m: RutaMuestreada, a_origen: np.ndarray) -> list[_Sentido]:
    """En cada sentido, lo antes que se llega en bus a cada punto saliendo del origen (caminata, espera y
    viaje), y dónde conviene subirse para eso. Solo cuenta en los puntos donde se puede bajar."""
    sentidos = []
    for orden, avance in m.sentidos():
        puede_subir = m.abordable[orden] & (a_origen[orden] <= CAMINATA_MAXIMA_DE_ACCESO_M)
        costo = np.where(puede_subir, minutos_caminando(a_origen[orden]) - avance / m.velocidad, np.inf)
        # Subirse estrictamente antes del punto: el mínimo acumulado hasta k − 1.
        previo = np.concatenate(([np.inf], np.minimum.accumulate(costo)[:-1]))
        subida = np.concatenate(([-1], _argmin_acumulado(costo)[:-1]))
        minutos = np.where(m.abordable[orden], previo + avance / m.velocidad + m.espera, np.inf)
        sentidos.append(_Sentido(orden, minutos, np.where(subida >= 0, orden[np.maximum(subida, 0)], -1)))
    return sentidos


def _salidas(m: RutaMuestreada, a_destino: np.ndarray) -> list[_Sentido]:
    """En cada sentido, lo que falta para llegar al destino subiéndose en cada punto (espera aparte),
    y dónde conviene bajarse."""
    sentidos = []
    for orden, avance in m.sentidos():
        puede_bajar = m.abordable[orden] & (a_destino[orden] <= CAMINATA_MAXIMA_DE_ACCESO_M)
        costo = np.where(puede_bajar, avance / m.velocidad + minutos_caminando(a_destino[orden]), np.inf)
        # Bajarse estrictamente después del punto: el mínimo de k + 1 en adelante.
        al_reves = costo[::-1]
        siguiente = np.concatenate((np.minimum.accumulate(al_reves)[::-1][1:], [np.inf]))
        arg = _argmin_acumulado(al_reves)
        bajada = np.concatenate((np.where(arg >= 0, len(costo) - 1 - arg, -1)[::-1][1:], [-1]))
        minutos = np.where(m.abordable[orden], siguiente - avance / m.velocidad, np.inf)
        sentidos.append(_Sentido(orden, minutos, np.where(bajada >= 0, orden[np.maximum(bajada, 0)], -1)))
    return sentidos


def _en_indices_de_ruta(sentido: _Sentido) -> tuple[np.ndarray, np.ndarray]:
    """Pasa minutos y extremos del orden de avance a los índices de la ruta."""
    minutos = np.empty_like(sentido.minutos)
    extremo = np.empty_like(sentido.extremo)
    minutos[sentido.orden] = sentido.minutos
    extremo[sentido.orden] = sentido.extremo
    return minutos, extremo


# ---------------------------------------------------------------- opciones


def _directa(m: RutaMuestreada, origen, destino, a_origen, a_destino) -> OpcionViaje | None:
    mejor = None
    for llegada in _llegadas(m, a_origen):
        # Llegar en bus a j y caminar desde ahí al destino.
        total = llegada.minutos + np.where(a_destino[llegada.orden] <= CAMINATA_MAXIMA_DE_ACCESO_M,
                                           minutos_caminando(a_destino[llegada.orden]), np.inf)
        k = int(np.argmin(total))
        if np.isfinite(total[k]) and (mejor is None or total[k] < mejor[0]):
            mejor = (float(total[k]), int(llegada.extremo[k]), int(llegada.orden[k]))
    if mejor is None:
        return None
    _, i, j = mejor
    return OpcionViaje(tramos=(
        _caminata(origen, m.lonlat(i), a_origen[i]),
        m.tramo(i, j),
        _caminata(m.lonlat(j), destino, a_destino[j]),
    ))


def mejor_opcion_en_ruta(ruta: RutaTransporte, estaciones: list[Estacion],
                         origen: tuple[float, float], destino: tuple[float, float]) -> OpcionViaje | None:
    """Dónde subirse y bajarse de una sola ruta para llegar lo antes posible."""
    m = muestrear(ruta, estaciones)
    if m is None:
        return None
    return _directa(m, origen, destino, _distancias(m, origen), _distancias(m, destino))


def _con_transbordo(a: RutaMuestreada, b: RutaMuestreada, origen, destino,
                    a_origen, b_destino) -> OpcionViaje | None:
    """La mejor combinación: subir a `a` cerca del origen, bajar donde `b` pasa a menos de 300 m, caminar,
    subir a `b` y bajar cerca del destino."""
    arbol = shapely.STRtree(shapely.points(b.puntos))
    ia, ib = arbol.query(shapely.points(a.puntos), predicate="dwithin", distance=TRANSBORDO_MAXIMO_M)
    if len(ia) == 0:
        return None
    entre = np.hypot(a.puntos[ia, 0] - b.puntos[ib, 0], a.puntos[ia, 1] - b.puntos[ib, 1])
    caminar, integrado = _caminata_de_transbordo(a.estacion[ia], b.estacion[ib], entre)
    cambio = caminar + b.espera + np.where(integrado, PENALIZACION_TRANSBORDO_INTEGRADO_MIN, PENALIZACION_TRANSBORDO_MIN)

    mejor = None
    for llegada in _llegadas(a, a_origen):
        llega_a, sube_a = _en_indices_de_ruta(llegada)
        for salida in _salidas(b, b_destino):
            falta_b, baja_b = _en_indices_de_ruta(salida)
            total = llega_a[ia] + cambio + falta_b[ib]
            k = int(np.argmin(total))
            if np.isfinite(total[k]) and (mejor is None or total[k] < mejor[0]):
                mejor = (float(total[k]), int(sube_a[ia[k]]), int(ia[k]), int(ib[k]), int(baja_b[ib[k]]),
                         float(entre[k]))
    if mejor is None:
        return None
    _, sube, baja_en_a, sube_en_b, baja, entre_m = mejor
    return OpcionViaje(tramos=(
        _caminata(origen, a.lonlat(sube), a_origen[sube]),
        a.tramo(sube, baja_en_a),
        _cambio(a.lonlat(baja_en_a), b.lonlat(sube_en_b), entre_m, a.estacion[baja_en_a], b.estacion[sube_en_b]),
        b.tramo(sube_en_b, baja),
        _caminata(b.lonlat(baja), destino, b_destino[baja]),
    ))


def _caminata_de_transbordo(estacion_a: np.ndarray, estacion_b: np.ndarray,
                            entre: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """
    Minutos de la caminata de cada transbordo posible y si es integrado. En la misma estación se cambia de
    andén; en una integración oficial se camina lo que mide de verdad; si no, la línea recta con rodeo y, si
    se sube en una estación troncal desde la calle, el cruce de la avenida.
    """
    misma = (estacion_a != "") & (estacion_a == estacion_b)
    integracion = [INTEGRACIONES.get(frozenset({x, y})) if x and y and x != y else None
                   for x, y in zip(estacion_a, estacion_b)]
    oficial = np.array([i is not None for i in integracion], dtype=bool)
    por_integracion = np.array([i.caminata_m / VELOCIDAD_CAMINATA_M_POR_MIN + i.cruce_min if i else 0.0
                                for i in integracion])
    desde_la_calle = minutos_caminando(entre) + np.where(estacion_b != "", CRUCE_A_ESTACION_MIN, 0.0)
    minutos = np.where(misma, TRANSBORDO_EN_ESTACION_M / VELOCIDAD_CAMINATA_M_POR_MIN,
                       np.where(oficial, por_integracion, desde_la_calle))
    return minutos, misma | oficial


def _cambio(desde: tuple[float, float], hasta: tuple[float, float], entre_m: float,
            estacion_a: str, estacion_b: str) -> Tramo:
    """La caminata entre los dos buses, con cómo hacerla cuando es una integración."""
    if estacion_a and estacion_a == estacion_b:
        return Tramo(modo="caminata", coordenadas=(desde, hasta), distancia_m=TRANSBORDO_EN_ESTACION_M,
                     duracion_min=TRANSBORDO_EN_ESTACION_M / VELOCIDAD_CAMINATA_M_POR_MIN, integrado=True,
                     indicacion="Cambia de bus dentro de la estación, sin volver a pagar.")
    integracion = INTEGRACIONES.get(frozenset({estacion_a, estacion_b})) if estacion_a and estacion_b else None
    if integracion:
        return Tramo(modo="caminata", coordenadas=(desde, hasta), distancia_m=integracion.caminata_m,
                     duracion_min=integracion.caminata_m / VELOCIDAD_CAMINATA_M_POR_MIN + integracion.cruce_min,
                     integrado=True, indicacion=integracion.indicacion)
    tramo = _caminata(desde, hasta, entre_m)
    if estacion_b:
        return replace(tramo, duracion_min=tramo.duracion_min + CRUCE_A_ESTACION_MIN)
    return tramo


def planificar(rutas: list[RutaTransporte], estaciones: list[Estacion],
               origen: tuple[float, float], destino: tuple[float, float],
               con_transbordos: bool = True, muestras: list[RutaMuestreada] | None = None) -> list[OpcionViaje]:
    """
    Opciones posibles: a pie (si es cerca), una por cada ruta que sirve sola y, con `con_transbordos`, la mejor
    combinación de cada par de rutas (una que pasa cerca del origen y otra que pasa cerca del destino).
    Se descartan las que tardan más que caminar.
    """
    caminando = opcion_caminando(origen, destino)
    if muestras is None:  # quien planifica muchos viajes seguidos (scripts/analizar_transbordos.py) las reutiliza
        muestras = [m for r in rutas if r.cortes_en_osm <= MAX_CORTES_CONFIABLES
                    if (m := muestrear(r, estaciones)) is not None]
    a_origen = {m.ruta.id: _distancias(m, origen) for m in muestras}
    a_destino = {m.ruta.id: _distancias(m, destino) for m in muestras}
    cerca_del_origen = [m for m in muestras if a_origen[m.ruta.id].min() <= CAMINATA_MAXIMA_DE_ACCESO_M]
    cerca_del_destino = [m for m in muestras if a_destino[m.ruta.id].min() <= CAMINATA_MAXIMA_DE_ACCESO_M]

    sirven_al_destino = {m.ruta.id for m in cerca_del_destino}
    opciones = []
    for m in cerca_del_origen:
        if m.ruta.id in sirven_al_destino:
            opciones.append(_directa(m, origen, destino, a_origen[m.ruta.id], a_destino[m.ruta.id]))
    if con_transbordos:
        for a in cerca_del_origen:
            for b in cerca_del_destino:
                if a.ruta.id != b.ruta.id:
                    opciones.append(_con_transbordo(a, b, origen, destino, a_origen[a.ruta.id], a_destino[b.ruta.id]))
    utiles = _depurar([o for o in opciones
                       if o and (caminando is None or o.tiempo_total_min < caminando.tiempo_total_min)])
    if caminando:
        utiles.append(caminando)
    return utiles


def _depurar(opciones: list[OpcionViaje]) -> list[OpcionViaje]:
    """
    Quita los transbordos que no le sirven al viajero:
    - los que tardan lo mismo o más que ir directo en una de sus dos rutas («T102 > T103» donde la T103 sola
      llega antes): solo agregan un cambio de bus;
    - entre los que empiezan en la misma ruta, todos menos el mejor: «A101 > T101» y «A101 > T102» son
      el mismo viaje por el mismo corredor.
    """
    directas = {o.ruta.id: o.tiempo_total_min for o in opciones if o.transbordos == 0}
    mejor_por_primera_ruta: dict[str, OpcionViaje] = {}
    resultado = [o for o in opciones if o.transbordos == 0]
    for o in opciones:
        if o.transbordos == 0:
            continue
        # Cambiar de bus tiene que ganar aun contando lo que cuesta: un minuto menos no compensa el transbordo.
        if any(directas.get(r.id, np.inf) <= costo_percibido(o) for r in o.rutas):
            continue
        actual = mejor_por_primera_ruta.get(o.ruta.id)
        if actual is None or costo_percibido(o) < costo_percibido(actual):
            mejor_por_primera_ruta[o.ruta.id] = o
    return resultado + list(mejor_por_primera_ruta.values())


def estaciones_en_orden(ruta: RutaTransporte, estaciones: list[Estacion]) -> list[Estacion]:
    """
    Las estaciones de la ruta en el orden en que las recorre. Muchas relaciones de OSM son de ida y vuelta
    («Portal - Bocagrande - Portal»): proyectar sobre el trazado puede caer en la vuelta, así que cuenta la
    primera vez que la ruta pasa cerca de cada estación.
    """
    linea = a_metros(LineString(ruta.coordenadas))
    posiciones = np.append(np.arange(0, linea.length, PASO_DE_MUESTREO_M), linea.length)
    puntos = shapely.get_coordinates(shapely.line_interpolate_point(linea, posiciones))

    def primera_pasada(estacion: Estacion) -> float:
        p = a_metros(Point(estacion.longitud, estacion.latitud))
        cerca = np.flatnonzero(np.hypot(puntos[:, 0] - p.x, puntos[:, 1] - p.y) <= RADIO_DE_ESTACION_M * 2)
        return float(posiciones[cerca[0]]) if len(cerca) else linea.project(p)

    return sorted((e for e in estaciones if ruta.id in e.rutas), key=primera_pasada)


def paradas_del_tramo(tramo: Tramo, estaciones: list[Estacion]) -> tuple[Estacion, ...]:
    """Las estaciones de la ruta que el bus pasa en este tramo, en el orden en que las pasa."""
    if tramo.ruta is None or len(tramo.coordenadas) < 2:
        return ()
    linea = a_metros(LineString(tramo.coordenadas))
    cerca = []
    for e in estaciones:
        if tramo.ruta.id not in e.rutas:
            continue
        punto = a_metros(Point(e.longitud, e.latitud))
        if linea.distance(punto) <= RADIO_DE_ESTACION_M * 2:
            cerca.append((linea.project(punto), e))
    return tuple(e for _, e in sorted(cerca, key=lambda par: par[0]))
