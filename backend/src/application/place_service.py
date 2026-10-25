from src.domain.direcciones import distancia_m, leer_direccion, ubicar
from src.domain.geo import en_cobertura
from src.domain.models import MAX_LUGARES_GUARDADOS, IconoLugar, Lugar, LugarGuardado, Usuario
from src.domain.ports import PlaceRepository, SavedPlaceRepository
from src.domain.texto import normalizar, tokens

# Al empatar, primero lo que más se usa como origen o destino de un viaje.
PRIORIDAD_POR_TIPO = {
    "Estación Transcaribe": 0, "Barrio": 1, "Sitio turístico": 2, "Centro comercial": 3,
    "Universidad": 4, "Hospital": 5, "Terminal / estación": 6, "Aeropuerto": 6,
}


class PlaceService:
    MAX_PALABRAS = 5
    RADIO_REVERSO_M = 400
    MISMO_LUGAR_M = 75

    def __init__(self, places: PlaceRepository, saved: SavedPlaceRepository):
        self.places = places
        self.saved = saved

    RADIO_ZONA_M = 1500
    RADIO_ZONA_LEJANA_M = 5000  # sectores apartados (islas, corregimientos) sin un barrio registrado cerca
    MISMA_DIRECCION_M = 120  # una doble calzada da dos cruces casi iguales: es un solo resultado

    def search(self, consulta: str, limite: int) -> list[Lugar]:
        """
        Caso de Uso: Buscar un lugar por nombre, sin importar tildes ni mayúsculas. Si el texto es una dirección
        con la nomenclatura colombiana («Calle 9 # 3-50»), primero va la dirección ubicada por los cruces.
        """
        direcciones = self._direcciones(consulta)
        if direcciones:
            return direcciones[:limite]
        palabras = [p[:30] for p in tokens(consulta)][:self.MAX_PALABRAS]
        if not palabras:
            return []
        texto = normalizar(consulta)
        candidatos = self.places.search(palabras, limite=60)
        candidatos.sort(key=lambda l: (
            not normalizar(l.nombre).startswith(texto),
            PRIORIDAD_POR_TIPO.get(l.tipo, 9),
            len(l.nombre),
        ))
        return candidatos[:limite]

    def _direcciones(self, consulta: str) -> list[Lugar]:
        direccion = leer_direccion(consulta)
        if direccion is None:
            return []
        resultados: list[Lugar] = []
        for u in ubicar(direccion, self.places.crossings_on(direccion.via.clave), limite=6):
            if not en_cobertura(u.latitud, u.longitud):
                continue  # la misma numeración existe en corregimientos fuera del área urbana (Barú)
            if any(distancia_m((u.longitud, u.latitud), (r.longitud, r.latitud)) < self.MISMA_DIRECCION_M
                   for r in resultados):
                continue
            # La zona se nombra por el barrio; si no hay uno cerca, por el lugar conocido más cercano.
            zona = (self.places.nearest(u.longitud, u.latitud, self.RADIO_ZONA_M, tipo="Barrio")
                    or self.places.nearest(u.longitud, u.latitud, self.RADIO_ZONA_LEJANA_M))
            precision = "Dirección aproximada" if u.exacta or direccion.cruce else "Vía"
            detalle = f"{precision} · {'' if zona and zona[1] <= self.RADIO_ZONA_M else 'cerca de '}" + (
                zona[0].nombre if zona else u.referencia)
            if any(r.detalle == detalle for r in resultados):
                continue  # la misma dirección en la misma zona: basta una
            resultados.append(Lugar(id=None, nombre=u.nombre, tipo="Dirección", latitud=u.latitud,
                                    longitud=u.longitud, detalle=detalle))
        return resultados

    def reverse(self, lat: float, lon: float) -> Lugar:
        """Caso de Uso: Elegir un punto en el mapa y saber cómo se llama."""
        cercano = self.places.nearest(lon, lat, self.RADIO_REVERSO_M)
        if cercano is None:
            return Lugar(id=None, nombre="Punto seleccionado en el mapa", tipo="Punto en el mapa",
                         latitud=lat, longitud=lon)
        lugar, distancia = cercano
        if distancia <= self.MISMO_LUGAR_M:
            return Lugar(id=lugar.id, nombre=lugar.nombre, tipo=lugar.tipo, latitud=lat, longitud=lon)
        return Lugar(id=None, nombre=f"Cerca de {lugar.nombre}", tipo=lugar.tipo, latitud=lat, longitud=lon)

    def list_saved(self, usuario: Usuario) -> list[LugarGuardado]:
        return self.saved.list(usuario.id)

    def add_saved(self, usuario: Usuario, *, nombre: str, icono: IconoLugar,
                  latitud: float, longitud: float) -> LugarGuardado:
        """Lanza LimiteLugaresGuardados si ya tiene el máximo permitido."""
        return self.saved.add(usuario.id, nombre=nombre.strip(), icono=icono, latitud=latitud,
                              longitud=longitud, maximo=MAX_LUGARES_GUARDADOS)

    def update_saved(self, usuario: Usuario, place_id: str, cambios: dict) -> LugarGuardado:
        if "nombre" in cambios:
            cambios = {**cambios, "nombre": cambios["nombre"].strip()}
        return self.saved.update(usuario.id, place_id, cambios)

    def delete_saved(self, usuario: Usuario, place_id: str) -> None:
        self.saved.delete(usuario.id, place_id)
