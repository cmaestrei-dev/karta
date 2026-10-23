from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
from geoalchemy2.elements import WKTElement
from src.infrastructure.models import Incidente
from src.domain.schemas.incident_schema import IncidentCreate
from src.domain.schemas.route_schema import RouteRiskRequest

class IncidentService:

    @classmethod
    def evaluate_route_risk(cls, db: Session, route_request: RouteRiskRequest):
        """
        Analiza cada punto de la ruta y calcula un nivel de riesgo
        basado en la cercanía y gravedad de los incidentes.
        """
        total_risk_score = 0
        incidents_found = []
        radio_busqueda = 500

        for point in route_request.route:
            punto_actual = WKTElement(f"POINT({point.lon} {point.lat})", srid=4326)

            cercanos = db.query(Incidente).filter(
                func.ST_DWithin(
                    func.ST_Transform(Incidente.ubicacion, 3857),
                    func.ST_Transform(punto_actual, 3857), 
                    radio_busqueda
                )
            ).all()

            for inc in cercanos:
                if inc.id_incidente not in [i["id"] for i in incidents_found]:
                    peso_categoria = 5 if inc.categoria.lower() == "seguridad" else 1
                    puntos_riesgo = inc.intensidad * peso_categoria
                    
                    total_risk_score += puntos_riesgo
                    incidents_found.append({
                        "id": inc.id_incidente,
                        "categoria": inc.categoria,
                        "intensidad": inc.intensidad
                    })

        nivel = "BAJO"
        if total_risk_score > 10: nivel = "MEDIO"
        if total_risk_score > 25: nivel = "ALTO"
        if total_risk_score > 50: nivel = "CRÍTICO"

        return {
            "score": total_risk_score,
            "nivel": nivel,
            "total_incidentes": len(incidents_found),
            "detalle_incidentes": incidents_found
        }

    @classmethod
    def get_active_incidents(cls, db: Session):
        """Caso de Uso: Consultar incidentes activos y extraer coordenadas para el Radar Táctico."""
        
        resultados = db.query(
            Incidente.id_incidente,
            Incidente.id_usuario,
            Incidente.categoria,
            Incidente.intensidad,
            func.ST_Y(Incidente.ubicacion).label('latitud'),
            func.ST_X(Incidente.ubicacion).label('longitud'),
            Incidente.fecha_reporte
        ).all()

        return [
            {
                "id_incidente": r.id_incidente,
                "id_usuario": r.id_usuario,
                "categoria": r.categoria,
                "intensidad": r.intensidad,
                "latitud": r.latitud,
                "longitud": r.longitud,
                "fecha_reporte": r.fecha_reporte
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

        # El modelo ORM solo guarda la geometría; la respuesta expone lat/lon planos.
        return {
            "id_incidente": nuevo_incidente.id_incidente,
            "id_usuario": nuevo_incidente.id_usuario,
            "categoria": nuevo_incidente.categoria,
            "intensidad": nuevo_incidente.intensidad,
            "latitud": incident.latitud,
            "longitud": incident.longitud,
            "fecha_reporte": nuevo_incidente.fecha_reporte
        }