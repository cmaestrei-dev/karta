import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from dotenv import load_dotenv

load_dotenv()

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL")

if not SQLALCHEMY_DATABASE_URL:
    raise ValueError("Error Crítico: DATABASE_URL no está configurada en el entorno.")

engine = create_engine(SQLALCHEMY_DATABASE_URL, echo=False)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    """
    Genera una sesión de base de datos aislada por cada petición HTTP.
    Garantiza el cierre de la conexión incluso si ocurre un error (Clean Architecture).
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()