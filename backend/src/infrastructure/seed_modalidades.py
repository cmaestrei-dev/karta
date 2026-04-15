from src.infrastructure.database import SessionLocal
from src.infrastructure.models import Modalidad

def seed_modalidades():
    db = SessionLocal()
    try:
        if db.query(Modalidad).count() == 0:
            print("Iniciando inyección de datos semilla en Karta...")
            modalidades_base = [
                Modalidad(nombre_servicio="Transcaribe", tipo_servicio="Público"),
                Modalidad(nombre_servicio="Didi", tipo_servicio="Privado"),
                Modalidad(nombre_servicio="Indriver", tipo_servicio="Privado"),
                Modalidad(nombre_servicio="Caminata", tipo_servicio="Físico")
            ]
            db.add_all(modalidades_base)
            db.commit()
            print("✅ ¡Catálogo de modalidades insertado con éxito en PostgreSQL!")
        else:
            print("⚠️ Las modalidades ya estaban registradas. No se requiere acción.")
    except Exception as e:
        print(f"❌ Error al poblar la base de datos: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_modalidades()