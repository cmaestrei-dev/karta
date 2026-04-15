from fastapi import APIRouter
from src.domain.schemas.route_schema import RouteRequest, DecisionResponse
from src.application.routing_strategy import DecisionEngine

router = APIRouter(prefix="/api/v1/routes", tags=["Rutas y Enrutamiento"])

@router.post("/evaluate", response_model=DecisionResponse)
def evaluate_route(request: RouteRequest):
    """
    Evalúa una ruta y orquesta el posible Salto Táctico.
    """
    resultado = DecisionEngine.evaluate_tactical_jump(request.distancia_km)
    return resultado