from abc import ABC, abstractmethod
from src.domain.schemas.route_schema import RouteOption

class TransportStrategy(ABC):
    @abstractmethod
    def calculate_metrics(self, distance_km: float) -> RouteOption:
        pass

class TranscaribeStrategy(TransportStrategy):
    def calculate_metrics(self, distance_km: float) -> RouteOption:
        tiempo_min = (distance_km / 15.0) * 60 + 15
        return RouteOption(
            modalidad="Transcaribe", 
            tiempo_minutos=int(tiempo_min), 
            costo_cop=3000
        )

class PrivateServiceStrategy(TransportStrategy):
    def calculate_metrics(self, distance_km: float) -> RouteOption:
        tiempo_min = (distance_km / 30.0) * 60 + 5
        costo = 5000 + (distance_km * 1200) # Base + tarifa por km
        return RouteOption(
            modalidad="Privado", 
            tiempo_minutos=int(tiempo_min), 
            costo_cop=int(costo)
        )

class DecisionEngine:
    @staticmethod
    def evaluate_tactical_jump(distance_km: float):
        """Compara las estrategias y decide si sugiere el salto."""
        transcaribe = TranscaribeStrategy().calculate_metrics(distance_km)
        privado = PrivateServiceStrategy().calculate_metrics(distance_km)
        
        tiempo_ahorrado = transcaribe.tiempo_minutos - privado.tiempo_minutos
        
        sugiere_salto = tiempo_ahorrado >= 15
        
        return {
            "opcion_actual": transcaribe,
            "opcion_alternativa": privado,
            "sugiere_salto": sugiere_salto,
            "tiempo_ahorrado": tiempo_ahorrado if sugiere_salto else 0
        }