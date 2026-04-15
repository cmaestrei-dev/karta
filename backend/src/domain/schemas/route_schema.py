from pydantic import BaseModel

class RouteRequest(BaseModel):
    """Payload del frontend pidiendo calcular una ruta."""
    distancia_km: float

class RouteOption(BaseModel):
    """Una opción de transporte evaluada."""
    modalidad: str
    tiempo_minutos: int
    costo_cop: int

class DecisionResponse(BaseModel):
    """Respuesta final del motor con el análisis comparativo."""
    opcion_actual: RouteOption
    opcion_alternativa: RouteOption
    sugiere_salto: bool
    tiempo_ahorrado: int