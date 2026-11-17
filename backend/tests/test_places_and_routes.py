"""Pruebas de integración del buscador, las rutas sugeridas, las estaciones y los lugares guardados."""
CENTRO = {"lat": 10.4236, "lon": -75.5510}
BAZURTO = {"lat": 10.4135, "lon": -75.5245}
BOCAGRANDE = {"lat": 10.3990, "lon": -75.5545}
SANTA_MARTA = {"lat": 11.2408, "lon": -74.1990}
MANDELA = {"lat": 10.3885, "lon": -75.4705}

# Las rutas dependen de la hora: las pruebas salen un martes cualquiera a media mañana (hora de Colombia).
MARTES_10_AM = "2026-10-27T10:00:00-05:00"
VIERNES_11_PM = "2026-10-23T23:30:00-05:00"


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_buscador_ignora_tildes_y_busca_por_prefijo(api):
    resultados = api.get("/api/v1/places/search", params={"q": "boca"}).json()
    assert any(r["nombre"] == "Bocagrande" for r in resultados)

    estaciones = api.get("/api/v1/places/search", params={"q": "estacion bazurto"}).json()
    assert estaciones[0]["nombre"] == "Estación Bazurto"
    assert estaciones[0]["tipo"] == "Estación Transcaribe"


def test_buscador_entiende_los_nombres_populares(api):
    # En OpenStreetMap es «Puerta del Reloj»; en la calle, la Torre del Reloj. También mientras se escribe.
    for consulta in ("Torre del Reloj", "torre del re"):
        assert api.get("/api/v1/places/search", params={"q": consulta}).json()[0]["nombre"] == "Puerta del Reloj"
    assert api.get("/api/v1/places/search", params={"q": "plaza de bolivar"}).json()[0]["nombre"] == "Parque de Bolívar"


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
        "origen": {**BAZURTO, "nombre": "Mercado de Bazurto"}, "destino": BOCAGRANDE, "salida": MARTES_10_AM,
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

    # El tramo en bus trae las estaciones que pasa, de la subida a la bajada.
    t103 = next(o for o in opciones if o["resumen"] == "Transcaribe T103")
    bus = next(t for t in t103["tramos"] if t["modo"] == "bus")
    nombres = [p["nombre"] for p in bus["paradas"]]
    assert nombres[0] == "Bazurto"
    assert len(nombres) >= 2 and len(set(nombres)) == len(nombres)


def test_rutas_sugeridas_con_transbordo_y_por_criterio(api):
    # De Mandela a Bocagrande ninguna ruta llega sola: hay que cambiar de bus.
    viaje = {"origen": MANDELA, "destino": BOCAGRANDE, "salida": MARTES_10_AM}
    cuerpo = api.post("/api/v1/routes/suggest", json=viaje).json()
    assert cuerpo["criterio"] == "rapida"
    con_transbordo = [o for o in cuerpo["opciones"] if o["transbordos"] == 1]
    assert con_transbordo
    opcion = con_transbordo[0]
    assert [t["modo"] for t in opcion["tramos"]] == ["caminata", "bus", "caminata", "bus", "caminata"]
    assert " y " in opcion["resumen"]
    # La caminata del transbordo une la bajada del primer bus con la subida del segundo.
    assert opcion["tramos"][2]["desde"] == opcion["tramos"][1]["hasta"]
    assert opcion["tramos"][2]["hasta"] == opcion["tramos"][3]["desde"]

    sin_transbordo = api.post("/api/v1/routes/suggest", json={**viaje, "criterio": "sin_transbordo"}).json()
    assert all(o["transbordos"] == 0 for o in sin_transbordo["opciones"])
    # Que no haya ruta directa no es culpa del horario: no se avisa nada de horarios.
    assert sin_transbordo["aviso"] is None

    assert api.post("/api/v1/routes/suggest", json={**viaje, "criterio": "segura"}).status_code == 200
    assert api.post("/api/v1/routes/suggest", json={**viaje, "criterio": "barata"}).status_code == 422


def test_de_noche_avisa_cuando_sale_la_primera_ruta(api):
    cuerpo = api.post("/api/v1/routes/suggest", json={
        "origen": BAZURTO, "destino": BOCAGRANDE, "salida": VIERNES_11_PM,
    }).json()
    assert all(o["transbordos"] == 0 and o["resumen"] == "A pie" for o in cuerpo["opciones"])
    assert cuerpo["aviso"].startswith("A esta hora no pasa ninguna ruta de Transcaribe")
    assert "mañana a las 5:" in cuerpo["aviso"]
    assert cuerpo["salida"].startswith("2026-10-23T23:30:00")


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
        "tipo": "trancon", "latitud": SANTA_MARTA["lat"], "longitud": SANTA_MARTA["lon"],
    })
    assert respuesta.status_code == 422


def test_los_paraderos_fuera_de_la_troncal_se_nombran_por_el_cruce(api):
    cuerpo = api.post("/api/v1/routes/suggest", json={
        "origen": MANDELA, "destino": BOCAGRANDE, "salida": MARTES_10_AM}).json()
    paradas = [t[clave] for o in cuerpo["opciones"] for t in o["tramos"] if t["modo"] == "bus"
               for clave in ("desde", "hasta")]
    assert any(p.startswith("Paradero ") and " con " in p for p in paradas), paradas


def test_pagina_de_una_ruta_con_sus_estaciones_en_orden_y_su_horario(api):
    ruta = api.get("/api/v1/routes/T103").json()
    assert ruta["codigo"] == "T103" and ruta["tipo"] == "troncal"
    assert ruta["geometria"]["type"] == "LineString"
    nombres = [e["nombre"] for e in ruta["estaciones"]]
    assert "Bazurto" in nombres and len(nombres) == len(set(nombres))
    # En orden de recorrido: Bazurto queda entre el Portal y Bocagrande, nunca en un extremo.
    assert 0 < nombres.index("Bazurto") < len(nombres) - 1
    assert ruta["horario"]["lunes_a_viernes"] == {"primera": "05:00", "ultima": "21:00"}
    assert ruta["hoy"] in {"lunes_a_viernes", "sabado", "domingo_y_festivos"}
    assert isinstance(ruta["opera_ahora"], bool)


def test_pagina_de_ruta_inexistente_o_mal_escrita(api):
    assert api.get("/api/v1/routes/T999").status_code == 404
    assert api.get("/api/v1/routes/hola").status_code == 422
    sin_horario = api.get("/api/v1/routes/C018").json()
    assert sin_horario["horario"] is None and sin_horario["opera_ahora"] is None
