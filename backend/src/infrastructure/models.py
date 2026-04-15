import enum
from sqlalchemy import Column, Integer, String, Float, Enum, ForeignKey, DateTime
from sqlalchemy.sql import func
from geoalchemy2 import Geometry
from src.infrastructure.database import Base

class TipoViajero(str, enum.Enum):
    RESIDENTE = "Residente"
    TURISTA = "Turista"

class Usuario(Base):
    __tablename__ = "usuarios"
    
    id_usuario = Column(Integer, primary_key=True, index=True, autoincrement=True)
    tipo_viajero = Column(Enum(TipoViajero), nullable=False)
    reputacion_puntos = Column(Integer, default=100) # Validará la veracidad de reportes

class Modalidad(Base):
    __tablename__ = "modalidades"
    
    id_modalidad = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nombre_servicio = Column(String(50), unique=True, nullable=False) # Ej: Transcaribe, Didi
    tipo_servicio = Column(String(20), nullable=False) # Público, Privado, Físico

class Incidente(Base):
    """
    Tabla transaccional central para UGC (User Generated Content).
    Aplica PostGIS para el Mapa de Eficiencia.
    """
    __tablename__ = "incidentes"
    
    id_incidente = Column(Integer, primary_key=True, index=True, autoincrement=True)
    id_usuario = Column(Integer, ForeignKey("usuarios.id_usuario"), nullable=False)
    categoria = Column(String(50), nullable=False) # Ej: Seguridad, Tráfico (SIPOC)
    intensidad = Column(Integer, nullable=False) # Escala 1-5
    
    ubicacion = Column(Geometry(geometry_type='POINT', srid=4326), nullable=False)
    
    fecha_reporte = Column(DateTime(timezone=True), server_default=func.now())