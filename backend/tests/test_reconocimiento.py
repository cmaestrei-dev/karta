"""Marcos por nivel e insignias por impacto: se ganan con aportes que la comunidad validó."""
from src.domain.models import Impacto
from src.domain.reconocimiento import insignias, marco, siguiente_insignia


def test_los_marcos_llevan_nombres_de_cartagena_desde_el_nivel_2():
    assert [marco(n) for n in range(1, 7)] == [None, "Muralla", "Bahía", "Castillo", "La Popa", "La Popa"]


def test_las_insignias_salen_del_impacto_validado():
    assert insignias(Impacto()) == []
    assert [i.clave for i in insignias(Impacto(confirmaciones=1))] == ["primer_aviso"]
    todas = insignias(Impacto(reportes=40, confirmaciones=12, gracias=10, vistas=150))
    assert [i.clave for i in todas] == ["primer_aviso", "ojo_de_halcon", "gracias_a_ti", "faro_de_la_bahia"]
    # Reportar mucho sin que nadie confirme no da insignias.
    assert insignias(Impacto(reportes=500)) == []


def test_la_siguiente_insignia_es_la_que_esta_mas_cerca():
    assert siguiente_insignia(Impacto()).insignia.clave == "primer_aviso"
    # 3 de 10 confirmaciones (30 %) frente a 8 de 10 gracias (80 %): la más cercana es «Gracias a ti».
    avance = siguiente_insignia(Impacto(confirmaciones=3, gracias=8))
    assert (avance.insignia.clave, avance.llevas, avance.meta) == ("gracias_a_ti", 8, 10)
    assert siguiente_insignia(Impacto(confirmaciones=10, gracias=10, vistas=100, paraderos=10)) is None
    # Ubicar un paradero da la insignia de Kartógrafo.
    assert "kartografo" in [i.clave for i in insignias(Impacto(paraderos=1))]


def test_el_perfil_y_el_detalle_muestran_marco_e_insignias(api, registrar):
    from bson import ObjectId
    from src.infrastructure.database import get_database
    token, usuario = registrar()
    get_database().users.update_one({"_id": ObjectId(usuario["id"])},
                                    {"$set": {"reputacion": 210, "impacto": {"confirmaciones": 3}}})
    yo = api.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"}).json()
    assert yo["marco"] == "Bahía"
    assert [i["clave"] for i in yo["insignias"]] == ["primer_aviso"]
    assert yo["siguiente_insignia"] == {
        "insignia": {"clave": "ojo_de_halcon", "nombre": "Ojo de halcón",
                     "descripcion": "Otros viajeros confirmaron 10 de tus reportes"},
        "llevas": 3, "meta": 10, "unidad": "confirmaciones"}

    reporte = api.post("/api/v1/incidents/", headers={"Authorization": f"Bearer {token}"}, json={
        "tipo": "bus_lleno", "detalles": {"ruta": "T103", "motivo": "no_se_acerco"},
        "latitud": 10.4139, "longitud": -75.5244}).json()
    detalle = api.get(f"/api/v1/incidents/{reporte['id']}").json()
    assert (detalle["nivel_autor"], detalle["marco_autor"]) == (3, "Bahía")
    assert detalle["detalles"]["motivo"] == "no_se_acerco"
