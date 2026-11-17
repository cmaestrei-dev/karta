"""«Borrar mi cuenta y mis datos» (derecho de supresión, Ley 1581 art. 8)."""
from bson import ObjectId

from tests.test_api import _auth, _reportar
from tests.test_mapeo import _ruta_sin_ubicar


def test_borrar_la_cuenta_quita_lo_que_identifica_y_deja_lo_comunitario_sin_dueno(api, registrar):
    from src.infrastructure.database import get_database
    db = get_database()
    token, ana = registrar()
    otro_token, _ = registrar()

    # Ana guarda su casa, reporta, vota y da las gracias en el reporte de otro, y marca un paradero.
    assert api.post("/api/v1/users/me/places", headers=_auth(token),
                    json={"nombre": "Casa", "icono": "casa", "latitud": 10.40, "longitud": -75.55}).status_code == 201
    suyo = _reportar(api, token, latitud=10.4101).json()
    ajeno = _reportar(api, otro_token, latitud=10.4102).json()
    assert api.post(f"/api/v1/incidents/{ajeno['id']}/votes", headers=_auth(token), json={"sigue": True}).status_code == 200
    assert api.post(f"/api/v1/incidents/{ajeno['id']}/thanks", headers=_auth(token), json={}).status_code == 200
    paradero = _ruta_sin_ubicar(api)
    marca = api.post(f"/api/v1/stops/{paradero['id']}/marks", headers=_auth(token),
                     json={"latitud": 10.3925, "longitud": -75.4850}).json()

    assert api.delete("/api/v1/users/me", headers=_auth(token)).status_code == 204

    ana_id = ObjectId(ana["id"])
    # La cuenta ya no existe: la sesión deja de servir.
    assert api.get("/api/v1/users/me", headers=_auth(token)).status_code == 401
    assert db.users.count_documents({"_id": ana_id}) == 0
    # Nada queda a su nombre en ninguna colección.
    for coleccion in ("incidents", "incident_votes", "incident_thanks", "incident_views", "stop_marks"):
        for campo in ("usuario", "reportado_por", "propuesto_por", "votos.usuario"):
            assert db[coleccion].count_documents({campo: ana_id}) == 0, (coleccion, campo)
    assert db.rate_limits.count_documents({"_id": {"$regex": f":usuario:{ana['id']}:"}}) == 0
    # Lo comunitario sigue en el mapa, sin dueño: su reporte y su marca.
    assert api.get(f"/api/v1/incidents/{suyo['id']}").status_code == 200
    assert db.stop_marks.count_documents({"_id": ObjectId(marca["id"])}) == 1
    # Y el reporte del otro conserva el voto que ella dio.
    assert db.incidents.find_one({"_id": ObjectId(ajeno["id"])})["votos_si"] == 1


def test_borrar_la_cuenta_pide_sesion(api):
    assert api.delete("/api/v1/users/me").status_code == 401
