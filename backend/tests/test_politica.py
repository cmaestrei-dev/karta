"""La política de tratamiento de datos y la prueba de la autorización (Ley 1581)."""
from src.domain.politica import VERSION_POLITICA, a_html, politica_con_datos
from tests.test_api import _auth


def test_la_politica_se_sirve_completa_con_sus_seis_contenidos_minimos(api):
    respuesta = api.get("/api/v1/legal/politica").json()
    assert respuesta["version"] == VERSION_POLITICA
    assert respuesta["responsable"] == "Camilo Andrés Maestre Iglesias" and respuesta["correo"]
    texto = respuesta["texto"]
    assert "{{" not in texto  # ningún marcador sin llenar
    # Decreto 1074, art. 2.2.2.25.3.1: responsable, tratamiento y finalidad, derechos, quién atiende,
    # procedimiento y vigencia.
    for seccion in ("Quién es el responsable", "Qué datos tratamos", "Tus derechos", "Consultas y reclamos",
                    "10 días hábiles", "15 días hábiles", "Vigencia"):
        assert seccion in texto, seccion


def test_la_politica_tambien_es_una_pagina_web(api):
    pagina = api.get("/api/v1/legal/politica.html")
    assert pagina.status_code == 200 and pagina.headers["content-type"].startswith("text/html")
    assert "<h1>Política de tratamiento de datos personales de Karta</h1>" in pagina.text
    assert '<a href="https://github.com/cmaestrei-dev/karta">' in pagina.text


def test_el_markdown_de_la_politica_se_escapa_y_se_arma():
    assert politica_con_datos("Escribe a {{correo}}.", correo="a@b.co") == "Escribe a a@b.co."
    html = a_html("# Título\n\nUn <script> y **negrilla**.\n- uno\n- [dos](https://x.co)\n\nFin")
    assert "<script>" not in html and "&lt;script&gt;" in html
    assert html.split("\n") == ["<h1>Título</h1>", "<p>Un &lt;script&gt; y <strong>negrilla</strong>.</p>", "<ul>",
                                "<li>uno</li>", '<li><a href="https://x.co">dos</a></li>', "</ul>", "<p>Fin</p>"]


def test_aceptar_el_aviso_queda_como_prueba_y_solo_vale_la_version_vigente(api, registrar):
    from bson import ObjectId
    from src.infrastructure.database import get_database
    token, usuario = registrar()
    assert api.get("/api/v1/users/me", headers=_auth(token)).json()["autorizacion"] is None
    assert api.post("/api/v1/users/me/autorizacion", headers=_auth(token), json={"version": "0.9"}).status_code == 409
    assert api.post("/api/v1/users/me/autorizacion", headers=_auth(token),
                    json={"version": VERSION_POLITICA}).status_code == 204
    perfil = api.get("/api/v1/users/me", headers=_auth(token)).json()
    assert perfil["autorizacion"] == perfil["politica_vigente"] == VERSION_POLITICA
    prueba = get_database().users.find_one({"_id": ObjectId(usuario["id"])})["autorizaciones"]
    assert [p["version"] for p in prueba] == [VERSION_POLITICA] and prueba[0]["en"] is not None
    assert api.post("/api/v1/users/me/autorizacion", json={"version": VERSION_POLITICA}).status_code == 401
