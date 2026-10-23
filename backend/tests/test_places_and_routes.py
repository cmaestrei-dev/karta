"""Pruebas de integración del buscador, las rutas sugeridas, las estaciones y los lugares guardados."""
CENTRO = {"lat": 10.4236, "lon": -75.5510}
BAZURTO = {"lat": 10.4135, "lon": -75.5245}
BOCAGRANDE = {"lat": 10.3990, "lon": -75.5545}
SANTA_MARTA = {"lat": 11.2408, "lon": -74.1990}


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_buscador_ignora_tildes_y_busca_por_prefijo(api):
    resultados = api.get("/api/v1/places/search", params={"q": "boca"}).json()
    assert any(r["nombre"] == "Bocagrande" for r in resultados)

    estaciones = api.get("/api/v1/places/search", params={"q": "estacion bazurto"}).json()
    assert estaciones[0]["nombre"] == "Estación Bazurto"
    assert estaciones[0]["tipo"] == "Estación Transcaribe"


def test_buscador_valida_la_consulta(api):
    assert api.get("/api/v1/places/search", params={"q": "a"}).status_code == 422
    assert api.get("/api/v1/places/search", params={"q": ".*"}).json() == []  # sin palabras: sin resultados


def test_elegir_en_el_mapa_devuelve_un_nombre_cercano(api):
    lugar = api.get("/api/v1/places/reverse", params={"lat": 10.4251, "lon": -75.5465}).json()
    assert "Centro" in lugar["nombre"] or lugar["nombre"].startswith("Cerca de")
    assert (lugar["latitud"], lugar["longitud"]) == (10.4251, -75.5465)

    fuera = api.get("/api/v1/places/reverse", params={"lat": SANTA_MARTA["lat"], "lon": SANTA_MARTA["lon"]})
    assert fuera.status_code == 422


def test_estaciones_cercanas_ordenadas_por_distancia(api):
    estaciones = api.get("/api/v1/stops/nearby", params={"lat": 10.4251, "lon": -75.5465}).json()
    assert estaciones[0]["nombre"] == "Centro"
    assert "T101" in estaciones[0]["rutas"]
    distancias = [e["distancia_m"] for e in estaciones]
    assert distancias == sorted(distancias)
    # La distancia a pie usa la misma regla que los tramos de caminata del planificador.
    assert all(e["caminata_m"] >= e["distancia_m"] and e["caminata_min"] >= 1 for e in estaciones)


def test_rutas_sugeridas_entre_bazurto_y_bocagrande(api):
    respuesta = api.post("/api/v1/routes/suggest", json={
        "origen": {**BAZURTO, "nombre": "Mercado de Bazurto"}, "destino": BOCAGRANDE,
    })
    assert respuesta.status_code == 200, respuesta.text
    cuerpo = respuesta.json()
    opciones = cuerpo["opciones"]

    assert 1 <= len(opciones) <= 3
    assert any(o["resumen"] == "Transcaribe T103" for o in opciones)
    primera = opciones[0]
    assert primera["tramos"][0]["desde"] == "Mercado de Bazurto"
    assert primera["tramos"][-1]["hasta"] == "Tu destino"
    assert primera["riesgo"]["nivel"] in {"BAJO", "MEDIO", "ALTO", "CRÍTICO"}
    assert primera["tramos"][1]["geometria"]["type"] == "LineString"
    assert "OpenStreetMap" in cuerpo["fuente"]

    # La caminata hasta la estación de subida mide lo mismo que muestra /stops/nearby para esa estación.
    caminata = primera["tramos"][0]
    assert caminata["hasta"] == "Estación Bazurto"
    estacion = api.get("/api/v1/stops/nearby", params={**BAZURTO, "limite": 1}).json()[0]
    assert estacion["nombre"] == "Bazurto"
    assert abs(caminata["distancia_m"] - estacion["caminata_m"]) <= 2


def test_rutas_sugeridas_solo_dentro_de_cartagena(api):
    respuesta = api.post("/api/v1/routes/suggest", json={"origen": CENTRO, "destino": SANTA_MARTA})
    assert respuesta.status_code == 422


def test_crud_de_lugares_guardados(api, registrar):
    token, _ = registrar()

    creado = api.post("/api/v1/users/me/places", headers=_auth(token),
                      json={"nombre": "Casa", "icono": "casa", "latitud": 10.40, "longitud": -75.55})
    assert creado.status_code == 201, creado.text
    lugar = creado.json()

    editado = api.patch(f"/api/v1/users/me/places/{lugar['id']}", headers=_auth(token), json={"nombre": "Mi casa"})
    assert editado.json()["nombre"] == "Mi casa"
    assert editado.json()["icono"] == "casa"  # lo que no se envía no cambia

    listado = api.get("/api/v1/users/me/places", headers=_auth(token)).json()
    assert [l["nombre"] for l in listado] == ["Mi casa"]

    assert api.delete(f"/api/v1/users/me/places/{lugar['id']}", headers=_auth(token)).status_code == 204
    assert api.get("/api/v1/users/me/places", headers=_auth(token)).json() == []
    assert api.delete(f"/api/v1/users/me/places/{lugar['id']}", headers=_auth(token)).status_code == 404


def test_lugares_guardados_exigen_sesion_y_son_privados(api, registrar):
    token_ana, _ = registrar()
    token_luis, _ = registrar()
    lugar = api.post("/api/v1/users/me/places", headers=_auth(token_ana),
                     json={"nombre": "Trabajo", "latitud": 10.42, "longitud": -75.54}).json()

    assert api.get("/api/v1/users/me/places").status_code == 401
    # Luis no puede ver, editar ni borrar el lugar de Ana aunque conozca su id.
    assert api.get("/api/v1/users/me/places", headers=_auth(token_luis)).json() == []
    assert api.patch(f"/api/v1/users/me/places/{lugar['id']}", headers=_auth(token_luis),
                     json={"nombre": "Robado"}).status_code == 404
    assert api.delete(f"/api/v1/users/me/places/{lugar['id']}", headers=_auth(token_luis)).status_code == 404


def test_lugares_guardados_validan_datos_y_limite(api, registrar):
    token, _ = registrar()
    fuera = api.post("/api/v1/users/me/places", headers=_auth(token),
                     json={"nombre": "Playa", "latitud": SANTA_MARTA["lat"], "longitud": SANTA_MARTA["lon"]})
    assert fuera.status_code == 422
    assert api.patch("/api/v1/users/me/places/000000000000000000000000", headers=_auth(token),
                     json={}).status_code == 422

    for n in range(10):
        assert api.post("/api/v1/users/me/places", headers=_auth(token),
                        json={"nombre": f"Lugar {n}", "latitud": 10.40, "longitud": -75.55}).status_code == 201
    extra = api.post("/api/v1/users/me/places", headers=_auth(token),
                     json={"nombre": "Uno más", "latitud": 10.40, "longitud": -75.55})
    assert extra.status_code == 409


def test_reportes_fuera_de_cartagena_se_rechazan(api, registrar):
    token, _ = registrar()
    respuesta = api.post("/api/v1/incidents/", headers=_auth(token), json={
        "categoria": "Tráfico", "intensidad": 2, "latitud": SANTA_MARTA["lat"], "longitud": SANTA_MARTA["lon"],
    })
    assert respuesta.status_code == 422
