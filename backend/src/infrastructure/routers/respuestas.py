"""Respuestas de error documentadas en Swagger. Todas llevan el cuerpo {"detail": "..."}."""
from pydantic import BaseModel


class ErrorResponse(BaseModel):
    detail: str


def error(descripcion: str) -> dict:
    return {"model": ErrorResponse, "description": descripcion}


SIN_SESION = {401: error("Falta el token Bearer, no es válido, expiró o su usuario ya no existe.")}
FUERA_DE_COBERTURA = {422: {"description": "Datos inválidos o coordenadas fuera de Cartagena."}}
