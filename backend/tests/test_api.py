"""Pruebas de integración de la API contra una base MongoDB real y desechable."""
from bson import ObjectId

RUTA_CENTRO_BOCAGRANDE = [
    {"lat": 10.4233, "lon": -75.5496},
    {"lat": 10.4100, "lon": -75.5500},
    {"lat": 10.3986, "lon": -75.5532},
]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _reportar(api, token, categoria="Seguridad", intensidad=5, latitud=10.4100, longitud=-75.5500):
    return api.post("/api/v1/incidents/", headers=_auth(token), json={
        "categoria": categoria, "intensidad": intensidad, "latitud": latitud, "longitud": longitud,
    })


def test_health_reporta_la_base_de_datos(api):
    respuesta = api.get("/api/v1/health")
    assert respuesta.status_code == 200
    assert respuesta.json()["database"] == "up"


def test_registro_inicia_sesion_y_no_expone_el_hash(api, registrar):
    token, usuario = registrar(email="Ana.Perez@Karta.app")
    assert usuario["email"] == "ana.perez@karta.app"
    assert "password_hash" not in usuario

    perfil = api.get("/api/v1/users/me", headers=_auth(token))
    assert perfil.status_code == 200
    assert perfil.json()["id"] == usuario["id"]


def test_registro_rechaza_correo_duplicado_y_sin_consentimiento(api, registrar):
    _, usuario = registrar()
    duplicado = api.post("/api/v1/auth/register", json={
        "email": usuario["email"], "password": "OtraClave123", "nombre": "X",
        "tipo_viajero": "Turista", "acepta_terminos": True,
    })
    assert duplicado.status_code == 409

    sin_consentimiento = api.post("/api/v1/auth/register", json={
        "email": "nuevo@karta.app", "password": "OtraClave123", "nombre": "X",
        "tipo_viajero": "Turista", "acepta_terminos": False,
    })
    assert sin_consentimiento.status_code == 422


def test_login_con_credenciales_correctas_e_incorrectas(api, registrar):
    _, usuario = registrar(password="MiClave2026")

    ok = api.post("/api/v1/auth/login", json={"email": usuario["email"], "password": "MiClave2026"})
    assert ok.status_code == 200
    assert ok.json()["token_type"] == "bearer"

    clave_mala = api.post("/api/v1/auth/login", json={"email": usuario["email"], "password": "otra"})
    correo_inexistente = api.post("/api/v1/auth/login", json={"email": "nadie@karta.app", "password": "otra"})
    # Mismo código y mensaje: no se revela qué correos existen.
    assert clave_mala.status_code == correo_inexistente.status_code == 401
    assert clave_mala.json() == correo_inexistente.json()


def test_reportar_exige_sesion(api):
    respuesta = api.post("/api/v1/incidents/", json={
        "categoria": "Tráfico", "intensidad": 2, "latitud": 10.42, "longitud": -75.54,
    })
    assert respuesta.status_code == 401

    token_falso = _reportar(api, "no-es-un-jwt")
    assert token_falso.status_code == 401


def test_token_de_usuario_eliminado_da_401_y_no_500(api, registrar):
    from src.infrastructure.database import get_database

    token, usuario = registrar()
    get_database().users.delete_one({"_id": ObjectId(usuario["id"])})

    assert _reportar(api, token).status_code == 401


def test_reporte_valido_aparece_en_el_mapa_sin_datos_del_autor(api, registrar):
    token, _ = registrar()
    creado = _reportar(api, token, categoria="Tráfico", intensidad=3, latitud=10.4225, longitud=-75.5410)
    assert creado.status_code == 201, creado.text
    incidente = creado.json()
    assert incidente["expira_en"] > incidente["creado_en"]

    listado = api.get("/api/v1/incidents/").json()
    encontrado = next(i for i in listado if i["id"] == incidente["id"])
    assert (encontrado["latitud"], encontrado["longitud"]) == (10.4225, -75.5410)
    assert "reportado_por" not in encontrado


def test_reporte_con_datos_invalidos_da_422(api, registrar):
    token, _ = registrar()
    assert _reportar(api, token, latitud=500).status_code == 422
    assert _reportar(api, token, categoria="Didi").status_code == 422
    assert _reportar(api, token, intensidad=9).status_code == 422


def test_riesgo_de_ruta_cuenta_solo_incidentes_dentro_del_corredor(api, registrar):
    token, _ = registrar()
    ids_cercanos = {_reportar(api, token).json()["id"] for _ in range(3)}
    lejano = _reportar(api, token, latitud=10.3500, longitud=-75.4800).json()["id"]  # ~9 km

    respuesta = api.post("/api/v1/routes/risk", json={"route": RUTA_CENTRO_BOCAGRANDE})
    assert respuesta.status_code == 200
    riesgo = respuesta.json()
    detectados = {d["id"] for d in riesgo["detalle_incidentes"]}

    assert ids_cercanos <= detectados
    assert lejano not in detectados
    assert riesgo["nivel"] == "CRÍTICO"


def test_riesgo_rechaza_rutas_de_un_punto(api):
    respuesta = api.post("/api/v1/routes/risk", json={"route": RUTA_CENTRO_BOCAGRANDE[:1]})
    assert respuesta.status_code == 422
