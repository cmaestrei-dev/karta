"""
La política de tratamiento de datos de Karta (Ley 1581 de 2012): su versión vigente y cómo se arma para mostrarla.

El texto vive en data/legal/politica-de-tratamiento.md con marcadores ({{correo}}, {{telefono}}…): los datos de
contacto del responsable no van en el repositorio público, sino en la configuración del servidor.
"""
import html
import re

# Cambiarla obliga a que cada viajero vuelva a aceptar el aviso antes de seguir (un cambio sustancial de la política).
# 1.1 (26 de octubre de 2026): las estadísticas agregadas y anónimas, que pueden venderse, son una finalidad más.
VERSION_POLITICA = "1.1"


def politica_con_datos(plantilla: str, **datos: str) -> str:
    """Reemplaza cada {{clave}} por su valor."""
    for clave, valor in datos.items():
        plantilla = plantilla.replace("{{" + clave + "}}", valor)
    return plantilla


def _en_linea(texto: str) -> str:
    """Negrillas y enlaces de Markdown, con todo lo demás escapado."""
    texto = html.escape(texto, quote=False)
    texto = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", texto)
    return re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", r'<a href="\2">\1</a>', texto)


def a_html(markdown: str) -> str:
    """El subconjunto de Markdown de la política (títulos, párrafos, listas, negrillas y enlaces) en HTML."""
    partes: list[str] = []
    en_lista = False
    for linea in markdown.splitlines():
        linea = linea.rstrip()
        vineta = re.match(r"^(\s*)- (.*)$", linea)
        if en_lista and not vineta:
            partes.append("</ul>")
            en_lista = False
        if not linea:
            continue
        if titulo := re.match(r"^(#{1,3}) (.*)$", linea):
            nivel = len(titulo.group(1))
            partes.append(f"<h{nivel}>{_en_linea(titulo.group(2))}</h{nivel}>")
        elif vineta:
            if not en_lista:
                partes.append("<ul>")
                en_lista = True
            partes.append(f"<li>{_en_linea(vineta.group(2))}</li>")
        else:
            partes.append(f"<p>{_en_linea(linea)}</p>")
    if en_lista:
        partes.append("</ul>")
    return "\n".join(partes)
