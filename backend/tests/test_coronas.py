"""Las reglas de las coronas y el filtro de apodos (docs/plan-juego.md, fase B). No necesitan base de datos."""
from datetime import date, datetime, timedelta, timezone

import pytest

from src.domain.apodos import ApodoRechazado, revisar_apodo
from src.domain.coronas import (
    ApodoDelDia, AportesDe, Corona, apodo_vigente, faltan, poner, puede_poner_apodo, quien_reina, recalcular,
    reportar,
)

HOY = date(2026, 11, 19)
AHORA = datetime(2026, 11, 19, 14, 0, tzinfo=timezone.utc)  # 9:00 a. m. en Cartagena


def aportes(**dias):
    """«ana=3» → Ana aportó 3 días, el primero hace 3 días."""
    return {u: AportesDe(dias=n, primero=HOY - timedelta(days=n)) for u, n in dias.items()}


@pytest.mark.parametrize("texto", [
    "Aquí sí pasa el X103", "La esquina del raspao", "¡No te duermas, cachaco!", "El mejor jugo de corozo",
    "Aquí uno se muere de calor", "Frente a la Alcaldía", "La venta de fritos",
])
def test_apodos_que_pasan(texto):
    assert revisar_apodo(f"  {texto}  ") == texto


@pytest.mark.parametrize("texto, motivo", [
    ("hp", "al menos"),
    ("Un apodo larguísimo que no cabe en el letrero", "Máximo"),
    ("12345", "palabra"),
    ("Escríbeme al 3001234567", "teléfono"),
    ("Visita www.mitienda.co", "enlaces"),
    ("Síganme @mitienda", "enlaces"),
    ("Bus 🚌 feliz", "emojis"),
    ("Parada hijueputa", "no van"),
    ("Malpa rido bus", "no van"),       # partida no se escapa
    ("Aquí es p0rn0", "no van"),        # con números en lugar de letras tampoco
    ("Putaaaa vida", "no van"),         # ni estirada
    ("Vota por el 5", "política"),
    ("Promo 2x1 en jugos", "anuncios"),
    ("Pide por whatsapp", "anuncios"),
])
def test_apodos_que_no_pasan(texto, motivo):
    with pytest.raises(ApodoRechazado, match=motivo):
        revisar_apodo(texto)


def test_reina_quien_mas_dias_aporto_y_el_empate_es_de_quien_ya_reina():
    assert quien_reina(aportes(ana=5, beto=3), actual=None, vetados=set()) == "ana"
    assert quien_reina(aportes(ana=4, beto=4), actual="beto", vetados=set()) == "beto"
    # Sin quien reine entre los empatados, quien empezó antes (los dos empezaron hace 4 días: el orden del id).
    assert quien_reina(aportes(ana=4, beto=4), actual="carla", vetados=set()) == "ana"
    assert quien_reina(aportes(ana=1), actual=None, vetados=set()) is None  # con un solo día no se reina
    assert quien_reina(aportes(ana=6, beto=3), actual=None, vetados={"ana"}) == "beto"


def test_si_la_corona_cambia_de_manos_el_apodo_se_va_con_ella():
    apodo = ApodoDelDia("La esquina del raspao", "ana", AHORA, AHORA + timedelta(hours=24))
    corona = Corona("bazurto", rey="ana", desde=HOY - timedelta(days=9), apodo=apodo, ultimo_apodo=AHORA)
    igual = recalcular(corona, aportes(ana=5, beto=3), set(), HOY)
    assert (igual.rey, igual.apodo, igual.calculada_para) == ("ana", apodo, HOY)
    otra = recalcular(corona, aportes(ana=2, beto=6), set(), HOY)
    assert (otra.rey, otra.desde, otra.apodo, otra.ultimo_apodo) == ("beto", HOY, None, None)


def test_cuanto_falta_para_la_corona():
    assert faltan(llevas=0, dias_del_rey=None, eres_rey=False) == 2
    assert faltan(llevas=2, dias_del_rey=None, eres_rey=False) == 0  # mañana puede ser suya
    assert faltan(llevas=3, dias_del_rey=5, eres_rey=False) == 3     # el empate es de quien reina
    assert faltan(llevas=7, dias_del_rey=5, eres_rey=False) == 0
    assert faltan(llevas=5, dias_del_rey=None, eres_rey=True) is None


def test_el_apodo_se_pone_al_ganar_la_corona_y_una_vez_por_semana():
    corona = Corona("bazurto", rey="ana", desde=HOY)
    assert puede_poner_apodo(corona, "ana", AHORA)
    assert not puede_poner_apodo(corona, "beto", AHORA)
    con_apodo = poner(corona, "La esquina del raspao", "ana", AHORA)
    assert apodo_vigente(con_apodo, AHORA + timedelta(hours=23)).texto == "La esquina del raspao"
    assert apodo_vigente(con_apodo, AHORA + timedelta(hours=25)) is None  # dura 24 horas
    assert not puede_poner_apodo(con_apodo, "ana", AHORA + timedelta(days=6))
    assert puede_poner_apodo(con_apodo, "ana", AHORA + timedelta(days=7))
    # Si la pierde y la recupera, al recuperarla puede ponerlo otra vez aunque no haya pasado la semana.
    de_nuevo = Corona("bazurto", rey="ana", desde=HOY + timedelta(days=3), ultimo_apodo=AHORA)
    assert puede_poner_apodo(de_nuevo, "ana", AHORA + timedelta(days=3))


def test_los_reportes_ocultan_el_apodo():
    apodo = ApodoDelDia("Algo feo", "ana", AHORA, AHORA + timedelta(hours=24))
    uno = reportar(apodo, "beto", nivel=3)
    assert not uno.oculto
    assert reportar(uno, "beto", nivel=3) == uno  # uno por viajero
    assert reportar(uno, "carla", nivel=4).oculto  # dos de confianza
    nuevos = apodo
    for quien in ("u1", "u2", "u3"):
        nuevos = reportar(nuevos, quien, nivel=1)
    assert not nuevos.oculto
    assert reportar(nuevos, "u4", nivel=1).oculto  # o cuatro de cualquiera
