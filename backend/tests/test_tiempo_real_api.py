"""Integración del tiempo real: avistamientos, viajes compartidos y la llegada estimada, con MongoDB."""
BAZURTO = {"latitud": 10.413958, "longitud": -75.524358}
# Sobre la troncal, antes de Bazurto viniendo del Portal (hacia el Centro).
LOS_EJECUTIVOS = {"latitud": 10.399489, "longitud": -75.493651}
LA_BODEGUITA = {"lat": 10.420019, "lon": -75.55141}


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _llegada(api):
    return api.get("/api/v1/routes/T103/live", params={
        "desde_lat": BAZURTO["latitud"], "desde_lon": BAZURTO["longitud"],
        "hasta_lat": LA_BODEGUITA["lat"], "hasta_lon": LA_BODEGUITA["lon"],
    }).json()


def test_sin_observaciones_no_se_inventa_la_llegada(api):
    assert _llegada(api) == {"minutos": None, "fuentes": 0, "ocupacion": None, "visto_hace_min": None,
                             "varado": None}


def test_un_viaje_compartido_y_un_avistamiento_dan_la_llegada(api, registrar):
    token, _ = registrar()
    viaje = api.post("/api/v1/trips", json={"ruta": "T103", **LOS_EJECUTIVOS}, headers=_auth(token))
    assert viaje.status_code == 201, viaje.text
    cuerpo = viaje.json()
    assert cuerpo["vence_en_s"] == 300 and len(cuerpo["viaje"]) >= 16

    movido = api.put(f"/api/v1/trips/{cuerpo['viaje']}", json={**LOS_EJECUTIVOS, "ocupacion": "de_pie"},
                     headers=_auth(token))
    assert movido.status_code == 204
    assert api.post("/api/v1/sightings", json={"ruta": "T103", **LOS_EJECUTIVOS}, headers=_auth(token)).status_code == 201

    llegada = _llegada(api)
    assert llegada["minutos"] is not None and llegada["minutos"] > 0
    assert llegada["fuentes"] == 2
    assert llegada["ocupacion"] == "de_pie"

    # Ni el viaje ni el avistamiento guardan quién los envió.
    from src.infrastructure.database import get_database
    db = get_database()
    assert all(set(doc) <= {"_id", "ruta", "ubicacion", "ocupacion", "en", "expira_en"} for doc in db.live_trips.find())
    assert all(set(doc) <= {"_id", "ruta", "ubicacion", "ocupacion", "en", "expira_en"} for doc in db.sightings.find())

    assert api.delete(f"/api/v1/trips/{cuerpo['viaje']}", headers=_auth(token)).status_code == 204
    assert api.put(f"/api/v1/trips/{cuerpo['viaje']}", json=LOS_EJECUTIVOS, headers=_auth(token)).status_code == 404


def test_validaciones_del_tiempo_real(api, registrar):
    token, _ = registrar()
    assert api.post("/api/v1/sightings", json={"ruta": "T103", **LOS_EJECUTIVOS}).status_code == 401
    assert api.post("/api/v1/sightings", json={"ruta": "T999", **LOS_EJECUTIVOS}, headers=_auth(token)).status_code == 422
    assert api.post("/api/v1/sightings", json={"ruta": "T103", "latitud": 11.24, "longitud": -74.2},
                    headers=_auth(token)).status_code == 422
    assert api.post("/api/v1/sightings", json={"ruta": "T103", **LOS_EJECUTIVOS, "ocupacion": "regular"},
                    headers=_auth(token)).status_code == 422
    assert api.get("/api/v1/routes/T999/live", params={"desde_lat": 10.41, "desde_lon": -75.52, "hasta_lat": 10.42,
                                                        "hasta_lon": -75.55}).status_code == 404


def test_un_bus_varado_reportado_deja_de_contar_y_se_avisa(api, registrar):
    token, _ = registrar()
    # Un viajero ve el T103 en Los Ejecutivos; otro reporta que ese T103 se varó ahí.
    assert api.post("/api/v1/sightings", json={"ruta": "T103", **LOS_EJECUTIVOS}, headers=_auth(token)).status_code == 201
    otro, _ = registrar()
    reporte = api.post("/api/v1/incidents/", headers=_auth(otro), json={
        "tipo": "bus_varado", "detalles": {"ruta": "T103"}, **LOS_EJECUTIVOS})
    assert reporte.status_code == 201, reporte.text

    llegada = _llegada(api)
    assert llegada["minutos"] is None  # el único T103 visto es el varado
    assert llegada["varado"]["metros_antes"] > 0
    assert llegada["varado"]["hace_min"] == 0


def test_el_resultado_del_viaje_se_guarda_sin_cuenta_ni_puntos(api, registrar):
    from src.infrastructure.database import get_database
    token, usuario = registrar()
    cuerpo = {"estimado_min": 34, "real_min": 37, "buses": [
        {"ruta": "T103", "espera_estimada_min": 6, "espera_real_min": 9, "a_bordo_estimado_min": 20,
         "a_bordo_real_min": 24},
        {"ruta": "A101", "espera_estimada_min": 4, "espera_real_min": None, "a_bordo_estimado_min": 8,
         "a_bordo_real_min": 7},
    ]}
    assert api.post("/api/v1/trip-results", json=cuerpo).status_code == 401
    respuesta = api.post("/api/v1/trip-results", json=cuerpo, headers=_auth(token))
    assert respuesta.status_code == 201, respuesta.text

    doc = get_database().trip_results.find_one({"estimado_min": 34, "real_min": 37})
    assert set(doc) == {"_id", "estimado_min", "real_min", "franja", "tipo_de_dia", "buses", "expira_en"}
    assert doc["franja"].minute % 15 == 0 and doc["franja"].second == 0
    assert str(usuario["id"]) not in str(doc)
    assert [b["ruta"] for b in doc["buses"]] == ["T103", "A101"] and doc["buses"][1]["espera_real_min"] is None

    mala = {**cuerpo, "buses": [{**cuerpo["buses"][0], "ruta": "T999"}]}
    assert api.post("/api/v1/trip-results", json=mala, headers=_auth(token)).status_code == 422
    assert api.post("/api/v1/trip-results", json={**cuerpo, "buses": []}, headers=_auth(token)).status_code == 422
    assert api.post("/api/v1/trip-results", json={**cuerpo, "real_min": 0}, headers=_auth(token)).status_code == 422
