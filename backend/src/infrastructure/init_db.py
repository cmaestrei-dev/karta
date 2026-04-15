from src.infrastructure.database import engine, Base
# Importar los modelos es vital para que SQLAlchemy los detecte antes de crear todo
from src.infrastructure.models import Usuario, Modalidad, Incidente

def init_db():
    print("Iniciando conexión con karta_db...")
    print("Sincronizando modelos ORM y generando tablas (incluyendo capas espaciales)...")
    
    # Esto busca todas las clases que hereden de Base y crea sus tablas si no existen
    Base.metadata.create_all(bind=engine)
    
    print("¡Arquitectura de base de datos desplegada con éxito!")

if __name__ == "__main__":
    init_db()