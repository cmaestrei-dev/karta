"""El P0 de calidad (docs/plan-calidad.md): límite por IP en memoria, caché de referencia y conteos agrupados."""
from datetime import datetime, timedelta, timezone

from src.infrastructure.limite_en_memoria import LimitePorIp, clave_de_ip
from src.infrastructure.repositories import CacheDeReferencia, ContadoresAgrupados


class _Reloj:
    def __init__(self):
        self.t = 1000.0

    def __call__(self):
        return self.t


def test_el_balde_deja_una_rafaga_y_luego_el_ritmo():
    reloj = _Reloj()
    limite = LimitePorIp(reloj=reloj)
    assert all(limite.permitir("ip", por_minuto=60, rafaga=5) is None for _ in range(5))
    espera = limite.permitir("ip", por_minuto=60, rafaga=5)
    assert espera == 1  # a 1 por segundo, la siguiente ficha llega en un segundo
    reloj.t += 1
    assert limite.permitir("ip", por_minuto=60, rafaga=5) is None
    assert limite.permitir("otra", por_minuto=60, rafaga=5) is None  # cada IP lleva su cuenta


def test_olvida_las_ip_mas_viejas_sin_crecer_sin_fin():
    limite = LimitePorIp(max_claves=3, reloj=_Reloj())
    for ip in ("a", "b", "c", "d"):
        limite.permitir(ip, 60, 1)
    assert limite.permitir("a", 60, 1) is None  # se había olvidado: vuelve con el balde lleno
    assert limite.permitir("d", 60, 1) is not None


def test_una_ipv6_cuenta_por_su_red():
    assert clave_de_ip("2800:e2:1:2:aaaa::1") == clave_de_ip("2800:e2:1:2:bbbb::9") == "2800:e2:1:2::/64"
    assert clave_de_ip("181.50.77.88") == "181.50.77.88"
    assert clave_de_ip(None) == "desconocida"


def test_la_api_responde_429_por_ip_con_retry_after(api, monkeypatch):
    from src.infrastructure import config
    monkeypatch.setattr(config, "LIMITE_IP_BUSCAR", (60, 2))
    respuestas = [api.get("/api/v1/places/search", params={"q": "Bazurto"}) for _ in range(3)]
    assert [r.status_code for r in respuestas[:2]] == [200, 200]
    assert respuestas[2].status_code == 429 and int(respuestas[2].headers["Retry-After"]) >= 1
    assert api.get("/api/v1/health").status_code == 200  # el límite de buscar no frena lo demás


def test_la_cache_de_referencia_vence_y_entrega_copias():
    reloj = _Reloj()
    cache = CacheDeReferencia(reloj=reloj)
    lecturas = []

    def leer():
        lecturas.append(1)
        return ["T101", "T103"]

    primera = cache.obtener(("base", "rutas"), leer)
    primera.append("cambiada")
    assert cache.obtener(("base", "rutas"), leer) == ["T101", "T103"] and len(lecturas) == 1
    reloj.t += CacheDeReferencia.VIGENCIA_S
    cache.obtener(("base", "rutas"), leer)
    assert len(lecturas) == 2


class _Destino:
    def __init__(self):
        self.escrito: dict[str, dict[str, int]] = {}

    def sumar(self, dia, campos):
        del_dia = self.escrito.setdefault(dia, {})
        for campo, n in campos.items():
            del_dia[campo] = del_dia.get(campo, 0) + n

    def dias(self, desde, hasta):
        return [{"_id": d, **c} for d, c in sorted(self.escrito.items()) if desde <= d <= hasta]


def test_los_conteos_se_juntan_y_se_guardan_cada_tanto():
    reloj, destino = _Reloj(), _Destino()
    conteos = ContadoresAgrupados(destino, cada_s=60, reloj=reloj)
    for _ in range(3):
        conteos.sumar("2026-11-18", {"llegadas.troncal.consultas.7": 1})
    assert destino.escrito == {}  # aún en memoria
    reloj.t += 60
    conteos.sumar("2026-11-18", {"viajes_compartidos": 1})
    assert destino.escrito == {"2026-11-18": {"llegadas.troncal.consultas.7": 3, "viajes_compartidos": 1}}
    conteos.sumar("2026-11-19", {"gracias": 1})
    assert conteos.dias("2026-11-18", "2026-11-19")[1] == {"_id": "2026-11-19", "gracias": 1}  # leer vacía antes


def test_un_viaje_compartido_vencido_ya_no_cuenta(api):
    from src.infrastructure.database import get_database
    from src.infrastructure.repositories import MongoRealtimeRepository
    db = get_database()
    ahora = datetime.now(timezone.utc)
    db.live_trips.insert_one({"_id": "vencido-hace-un-momento", "ruta": "C017", "ocupacion": None,
                              "ubicacion": {"type": "Point", "coordinates": [-75.5, 10.4]},
                              "en": ahora - timedelta(minutes=6), "expira_en": ahora - timedelta(seconds=30)})
    observaciones = MongoRealtimeRepository(db).observations("C017", ahora - timedelta(minutes=30), ahora)
    assert observaciones == []
    db.live_trips.delete_one({"_id": "vencido-hace-un-momento"})


def test_las_subidas_y_las_respuestas_de_parada_no_guardan_la_hora_exacta(api):
    from src.infrastructure.database import get_database
    from src.infrastructure.repositories import MongoRealtimeRepository, MongoStopMappingRepository
    from src.domain.conocimiento import ComoSePidio
    db = get_database()
    a_las = datetime(2026, 11, 18, 12, 37, 41, tzinfo=timezone.utc)
    MongoStopMappingRepository(db).add_boarding("A105", -75.4801, 10.3907, a_las)
    MongoRealtimeRepository(db).add_stop_answer("A105", -75.4801, 10.3907, ComoSePidio.TIMBRE, a_las)
    subida = db.boardings.find_one({"ruta": "A105", "ubicacion.coordinates": [-75.4801, 10.3907]})
    respuesta = db.stop_answers.find_one({"ruta": "A105", "ubicacion.coordinates": [-75.4801, 10.3907]})
    assert (subida["en"].hour, subida["en"].minute, subida["en"].second) == (12, 30, 0)  # el cuarto de hora
    assert (respuesta["en"].hour, respuesta["en"].minute) == (0, 0)  # solo el día
    assert subida["expira_en"] - a_las == MongoStopMappingRepository.VIGENCIA_DE_SUBIDA  # vence desde la hora real
    db.boardings.delete_one({"_id": subida["_id"]})
    db.stop_answers.delete_one({"_id": respuesta["_id"]})
