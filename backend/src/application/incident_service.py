from sqlalchemy.orm import Session
from sqlalchemy import func
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

    @classmethod
    def create_incident(cls, db: Session, incident: IncidentCreate):
        """Caso de Uso: Registrar un nuevo incidente convirtiendo lat/lon a Punto Espacial."""
        
        punto_wkt = f"POINT({incident.longitud} {incident.latitud})"
        ubicacion_espacial = WKTElement(punto_wkt, srid=4326)

        nuevo_incidente = Incidente(
            id_usuario=incident.id_usuario,
            categoria=incident.categoria,
            intensidad=incident.intensidad,
            ubicacion=ubicacion_espacial
        )

        db.add(nuevo_incidente)
        db.commit()
        db.refresh(nuevo_incidente)
        
        return nuevo_incidente