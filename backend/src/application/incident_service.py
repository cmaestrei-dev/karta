from sqlalchemy.orm import Session
from typing import List
from geoalchemy2.elements import WKTElement
from src.infrastructure.models import Incidente
from src.domain.schemas.incident_schema import IncidentCreate

class IncidentObserver:
    """Interfaz abstracta para los observadores."""
    def update(self, incidente: Incidente):
        pass

class MapUpdaterObserver(IncidentObserver):
    def update(self, incidente: Incidente):
        print(f"[OBSERVER: MAPA] 📍 Alerta en tiempo real: Nuevo incidente de '{incidente.categoria}' (Nivel {incidente.intensidad}).")

class RoutingObserver(IncidentObserver):
    def update(self, incidente: Incidente):
        print(f"[OBSERVER: RUTA] 🚦 Evaluando recálculo de vías debido al incidente #{incidente.id_incidente}.")

class IncidentService:
    _observers: List[IncidentObserver] = [MapUpdaterObserver(), RoutingObserver()]

    @classmethod
    def attach(cls, observer: IncidentObserver):
        cls._observers.append(observer)

    @classmethod
    def notify(cls, incidente: Incidente):
        """Difunde el evento a todos los módulos que escuchan."""
        for observer in cls._observers:
            observer.update(incidente)

    @classmethod
    def create_incident(cls, db: Session, incident_data: IncidentCreate) -> Incidente:
        """Caso de Uso: Reporte de un incidente espacial UGC."""
        
        punto_wkt = f"POINT({incident_data.longitud} {incident_data.latitud})"
        
        nuevo_incidente = Incidente(
            id_usuario=incident_data.id_usuario,
            categoria=incident_data.categoria,
            intensidad=incident_data.intensidad,
            ubicacion=WKTElement(punto_wkt, srid=4326)
        )
        
        db.add(nuevo_incidente)
        db.commit()
        db.refresh(nuevo_incidente)
        
        cls.notify(nuevo_incidente)
        
        return nuevo_incidente