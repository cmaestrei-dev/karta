"""La política de tratamiento de datos (Ley 1581): para la app (JSON) y para cualquiera, en una página web."""
from functools import lru_cache
from pathlib import Path

from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

from src.domain.politica import VERSION_POLITICA, a_html, politica_con_datos
from src.infrastructure import config

router = APIRouter(prefix="/api/v1/legal", tags=["Legal"])

_PLANTILLA = Path(__file__).resolve().parents[3] / "data" / "legal" / "politica-de-tratamiento.md"


RESPONSABLE = "Camilo Andrés Maestre Iglesias"


class PoliticaResponse(BaseModel):
    version: str
    vigente_desde: str
    responsable: str
    correo: str  # para consultas y reclamos: el aviso de privacidad lo muestra (Decreto 1074, art. 2.2.2.25.3.3)
    texto: str  # Markdown: títulos, párrafos, listas, negrillas y enlaces


@lru_cache(maxsize=1)
def _politica() -> str:
    return politica_con_datos(
        _PLANTILLA.read_text(encoding="utf-8"),
        version=VERSION_POLITICA, vigente_desde=config.POLITICA_VIGENTE_DESDE, correo=config.RESPONSABLE_CORREO,
        telefono=config.RESPONSABLE_TELEFONO, direccion=config.RESPONSABLE_DIRECCION,
    )


@router.get("/politica", summary="Política de tratamiento de datos", response_model=PoliticaResponse)
def politica():
    """La versión vigente, con los datos de contacto del responsable. La app la muestra en el aviso de privacidad."""
    return PoliticaResponse(version=VERSION_POLITICA, vigente_desde=config.POLITICA_VIGENTE_DESDE,
                            responsable=RESPONSABLE, correo=config.RESPONSABLE_CORREO, texto=_politica())


_PAGINA = """<!doctype html>
<html lang="es-CO">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Política de tratamiento de datos · Karta</title>
<style>
  :root { color-scheme: light dark; --fondo: #f6f3ec; --texto: #1d2733; --suave: #4b5966; --acento: #0b6e6e; }
  @media (prefers-color-scheme: dark) { :root { --fondo: #0f1a24; --texto: #e8eef2; --suave: #a9b6c0; --acento: #6fd3c4; } }
  body { margin: 0; background: var(--fondo); color: var(--texto); font: 17px/1.6 system-ui, sans-serif; }
  main { max-width: 42rem; margin: 0 auto; padding: 2rem 1.25rem 4rem; }
  h1 { font-size: 1.7rem; line-height: 1.25; margin: 0 0 1rem; }
  h2 { font-size: 1.25rem; margin: 2.2rem 0 .6rem; }
  h3 { font-size: 1.05rem; margin: 1.6rem 0 .4rem; }
  p, li { color: var(--texto); }
  ul { padding-left: 1.2rem; }
  li { margin: .35rem 0; }
  a { color: var(--acento); }
</style>
</head>
<body><main>
{contenido}
</main></body>
</html>
"""


@router.get("/politica.html", response_class=HTMLResponse, include_in_schema=False)
def politica_html():
    return HTMLResponse(_PAGINA.replace("{contenido}", a_html(_politica())))
