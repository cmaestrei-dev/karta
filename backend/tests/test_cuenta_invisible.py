"""La cuenta invisible: entrar sin registrarse, registrarse desde ella y los reportes «por confirmar»."""
import secrets

from src.domain.politica import VERSION_POLITICA

BAZURTO = {"latitud": 10.4139, "longitud": -75.5244}
# Un tramo de la Pedro de Heredia que pasa por Bazurto, para el riesgo de la ruta.
TRAMO = [{"lat": 10.4120, "lon": -75.5225}, {"lat": 10.4139, "lon": -75.5244}, {"lat": 10.4155, "lon": -75.5262}]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _invisible(api, secreto=None, politica=VERSION_POLITICA):
    cuerpo = {"secreto": secreto or secrets.token_urlsafe(32), "politica": politica}
    respuesta = api.post("/api/v1/auth/anonymous", json=cuerpo)
    assert respuesta.status_code == 200, respuesta.text
    return respuesta.json()


def _riesgo(api):
    return api.post("/api/v1/routes/risk", json={"route": TRAMO}).json()["score"]


def test_el_mismo_telefono_vuelve_a_su_cuenta_y_otro_tiene_la_suya(api):
    secreto = secrets.token_urlsafe(32)
    primera, otra_vez = _invisible(api, secreto), _invisible(api, secreto)
    assert primera["usuario"]["id"] == otra_vez["usuario"]["id"]
    assert primera["usuario"]["sin_cuenta"] is True
    assert primera["usuario"]["email"] is None and primera["usuario"]["alias"] == "Viajero sin cuenta"
    assert _invisible(api)["usuario"]["id"] != primera["usuario"]["id"]  # dos cuentas sin correo conviven

    yo = api.get("/api/v1/users/me", headers=_auth(otra_vez["access_token"])).json()
    assert yo["sin_cuenta"] is True and yo["nivel"] == 1
    # El secreto se guarda solo como huella.
    from src.infrastructure.database import get_database
    doc = get_database().users.find_one({"alias": "Viajero sin cuenta", "secreto": {"$exists": True}})
    assert doc is not None and secreto not in doc.values()


def test_registrarse_desde_la_cuenta_invisible_conserva_la_cuenta(api):
    secreto = secrets.token_urlsafe(32)
    invisible = _invisible(api, secreto)
    token = invisible["access_token"]
    guardado = api.post("/api/v1/users/me/places", headers=_auth(token),
                        json={"nombre": "Casa", "icono": "casa", **BAZURTO})
    assert guardado.status_code == 201, guardado.text

    correo = f"nueva-{secrets.token_hex(4)}@karta.app"
    registro = api.post("/api/v1/auth/register", headers=_auth(token), json={
        "email": correo, "password": "ClaveSegura123", "nombre": "Ana Pérez",
        "tipo_viajero": "Residente", "acepta_terminos": True,
    })
    assert registro.status_code == 201, registro.text
    usuario = registro.json()["usuario"]
    assert usuario["id"] == invisible["usuario"]["id"] and usuario["sin_cuenta"] is False
    assert usuario["alias"] == "Ana P."
    lugares = api.get("/api/v1/users/me/places", headers=_auth(registro.json()["access_token"])).json()
    assert [l["nombre"] for l in lugares] == ["Casa"]

    # El teléfono queda desligado: su secreto ahora da una cuenta invisible nueva.
    assert _invisible(api, secreto)["usuario"]["id"] != usuario["id"]
    assert api.post("/api/v1/auth/login", json={"email": correo, "password": "ClaveSegura123"}).status_code == 200


def test_registrarse_con_un_correo_tomado_no_toca_la_cuenta_invisible(api, registrar):
    _, otro = registrar()
    invisible = _invisible(api)
    registro = api.post("/api/v1/auth/register", headers=_auth(invisible["access_token"]), json={
        "email": otro["email"], "password": "ClaveSegura123", "nombre": "Ana",
        "tipo_viajero": "Residente", "acepta_terminos": True,
    })
    assert registro.status_code == 409
    yo = api.get("/api/v1/users/me", headers=_auth(invisible["access_token"])).json()
    assert yo["sin_cuenta"] is True


def test_los_reportes_sin_cuenta_quedan_por_confirmar_y_no_pesan_hasta_que_otro_confirme(api, registrar):
    antes = _riesgo(api)
    invisible = _invisible(api)
    reporte = api.post("/api/v1/incidents/", headers=_auth(invisible["access_token"]),
                       json={"tipo": "bus_no_pasa", "detalles": {"ruta": "T103"}, **BAZURTO})
    assert reporte.status_code == 201, reporte.text
    assert reporte.json()["por_confirmar"] is True
    assert _riesgo(api) == antes

    otro, _ = registrar()
    voto = api.post(f"/api/v1/incidents/{reporte.json()['id']}/votes", headers=_auth(otro), json={"sigue": True})
    assert voto.status_code == 200, voto.text
    assert voto.json()["incidente"]["por_confirmar"] is False
    assert _riesgo(api) > antes

    con_cuenta, _ = registrar()
    directo = api.post("/api/v1/incidents/", headers=_auth(con_cuenta),
                       json={"tipo": "bus_no_pasa", "detalles": {"ruta": "T103"}, **BAZURTO})
    assert directo.json()["por_confirmar"] is False


def test_sin_aceptar_la_politica_no_se_recibe_ningun_dato(api):
    """Ley 1581, art. 9: la cuenta existe, pero ningún dato suyo entra sin la prueba de la autorización."""
    secreto = secrets.token_urlsafe(32)
    sin_aceptar = _invisible(api, secreto, politica=None)
    assert sin_aceptar["usuario"]["autorizacion"] is None
    token = sin_aceptar["access_token"]
    escrituras = [
        ("/api/v1/incidents/", {"tipo": "trancon", "detalles": {"estado": "lento"}, **BAZURTO}),
        ("/api/v1/sightings", {"ruta": "X104", **BAZURTO}),
        ("/api/v1/users/me/places", {"nombre": "Casa", "icono": "casa", **BAZURTO}),
    ]
    for ruta, cuerpo in escrituras:
        respuesta = api.post(ruta, headers=_auth(token), json=cuerpo)
        assert respuesta.status_code == 403 and "política" in respuesta.json()["detail"], ruta
    # Una versión vieja no vale; la vigente, en la misma petición de la sesión, sí.
    assert _invisible(api, secreto, politica="0.9")["usuario"]["autorizacion"] is None
    renovada = _invisible(api, secreto)
    assert renovada["usuario"]["autorizacion"] == VERSION_POLITICA
    # (otra ruta que la T103: las pruebas de la llegada la consultan desde Bazurto)
    assert api.post("/api/v1/sightings", headers=_auth(renovada["access_token"]),
                    json={"ruta": "X104", **BAZURTO}).status_code == 201
