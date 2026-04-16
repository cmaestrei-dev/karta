from sqlalchemy.orm import Session
from sqlalchemy import func # <-- 1. AGREGA ESTA IMPORTACIÓN
from typing import List
from geoalchemy2.elements import WKTElement
from src.infrastructure.models import Incidente
from src.domain.schemas.incident_schema import IncidentCreate


class IncidentService:

    @classmethod
    def get_active_incidents(cls, db: Session):
        """Caso de Uso: Consultar incidentes activos y extraer coordenadas para el Radar Táctico."""
        
        resultados = db.query(
            Incidente.id_incidente,
            Incidente.id_usuario,
            Incidente.categoria,
            Incidente.intensidad,
            func.ST_Y(Incidente.ubicacion).label('latitud'),
            func.ST_X(Incidente.ubicacion).label('longitud')
        ).all()

        return [
            {
                "id_incidente": r.id_incidente,
                "id_usuario": r.id_usuario,
                "categoria": r.categoria,
                "intensidad": r.intensidad,
                "latitud": r.latitud,
                "longitud": r.longitud
            }
            for r in resultados
        ]